#!/bin/bash
# fix-agent.sh
# Called by GitHub Actions when AI review fails.
# Reads /tmp/review_issues.json, invokes Claude Code to fix them, pushes fix.
# Fix cycle counter persisted to disk — prevents infinite API cost loops.

set -euo pipefail

REPO_DIR="/home/$(whoami)/tonkit"
LOG_DIR="$REPO_DIR/logs"
LOCK_FILE="/tmp/tonkit-fix.lock"
COUNTER_DIR="/tmp/tonkit-fix-counters"

mkdir -p "$LOG_DIR"
mkdir -p "$COUNTER_DIR"

log() {
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) FIX-AGENT: $1" | tee -a "$LOG_DIR/fix-agent.log"
}

# ── Lock check ──────────────────────────────────────────────────────────────
if [ -f "$LOCK_FILE" ]; then
  LOCK_AGE=$(( $(date +%s) - $(stat -c %Y "$LOCK_FILE") ))
  if [ "$LOCK_AGE" -lt 7200 ]; then
    log "lock exists ($LOCK_AGE seconds old), exiting"
    exit 0
  fi
  log "stale lock detected ($LOCK_AGE seconds old), removing"
  rm "$LOCK_FILE"
fi

echo $$ > "$LOCK_FILE"

cleanup() {
  rm -f "$LOCK_FILE"
}
trap cleanup EXIT


# ── Check run-agent is not active ─────────────────────────────────────────────
# fix-agent must not run concurrently with run-agent
if [ -f "/tmp/tonkit-agent.lock" ]; then
  AGENT_LOCK_AGE=$(( $(date +%s) - $(stat -c %Y /tmp/tonkit-agent.lock) ))
  if [ "$AGENT_LOCK_AGE" -lt 7200 ]; then
    log "run-agent is active ($AGENT_LOCK_AGE seconds old) — deferring fix-agent to avoid concurrent ROADMAP writes"
    exit 0
  fi
fi

# ── Read issues ──────────────────────────────────────────────────────────────
if [ ! -f /tmp/review_issues.json ]; then
  log "no review_issues.json found, exiting"
  exit 1
fi

ISSUES=$(cat /tmp/review_issues.json)
log "triggered with issues: $ISSUES"

# ── Pull latest ──────────────────────────────────────────────────────────────
cd "$REPO_DIR"
git pull origin main 2>&1 | tee -a "$LOG_DIR/fix-agent.log"

# ── Get current task from ROADMAP (authoritative source) ──────────────────────
# NEVER derive task ID from commit message — it may be missing or malformed
CURRENT_TASK=$(grep -B1 "STATUS: IN_PROGRESS" ROADMAP.md | grep "## TASK:" | sed 's/## TASK: //' | head -1 || echo "UNKNOWN")
log "current task: $CURRENT_TASK"

# ── Disk-based fix cycle counter ──────────────────────────────────────────────
# Counter key = task ID so each task gets its own cycle count
# Prevents infinite loop if a task is fundamentally broken
COUNTER_FILE="$COUNTER_DIR/cycles-${CURRENT_TASK}"
CURRENT_COUNT=$(cat "$COUNTER_FILE" 2>/dev/null || echo 0)
NEW_COUNT=$((CURRENT_COUNT + 1))
# NOTE: Counter written to disk immediately so SSH drops don't allow unlimited retries
# Counter is incremented at START of attempt (not after) — conservative approach
echo "$NEW_COUNT" > "$COUNTER_FILE"

log "fix cycle $NEW_COUNT of 3 for task $CURRENT_TASK"

if [ "$NEW_COUNT" -gt 3 ]; then
  log "MAX FIX CYCLES EXCEEDED for task $CURRENT_TASK — requires human decision"
  echo "{\"type\":\"MAX_REVIEW_CYCLES_EXCEEDED\",\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"task\":\"$CURRENT_TASK\",\"cycles\":$NEW_COUNT}" >> "$LOG_DIR/failures.jsonl"

  # Send Telegram alert if configured
  if [ -n "${TELEGRAM_BOT_TOKEN:-}" ] && [ -n "${TELEGRAM_CHAT_ID:-}" ]; then
    curl -s "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
      -d "chat_id=${TELEGRAM_CHAT_ID}" \
      -d "text=⚠️ TonKit Pipeline BLOCKED: Task ${CURRENT_TASK} failed review 3 times. Human decision needed. Check /status" \
      >> "$LOG_DIR/fix-agent.log" 2>&1 || true
  fi

  # Mark task as FAILED in ROADMAP using atomic write
  if [ "$CURRENT_TASK" != "UNKNOWN" ]; then
    sed "/## TASK: ${CURRENT_TASK}/,/^---$/{s/STATUS: IN_PROGRESS/STATUS: FAILED/}" ROADMAP.md > ROADMAP.tmp && mv ROADMAP.tmp ROADMAP.md
    git add ROADMAP.md
    git commit -m "fix: mark task ${CURRENT_TASK} FAILED after max review cycles [skip ci]" || true
    git push origin main || true
  fi

  exit 1
fi

# ── Build fix prompt ─────────────────────────────────────────────────────────
FIX_PROMPT="You are fixing specific code review issues in the TonKit Scanner project.

The AI code reviewer rejected the last commit with these issues:
$ISSUES

Current task context: $CURRENT_TASK
Fix cycle: $NEW_COUNT of 3

Instructions:
1. Read each issue carefully
2. Find the exact file and line causing each issue
3. Fix only what the review flagged — do not refactor unrelated code
4. Run the relevant test command for the affected task after fixing
5. If tests pass, commit with message: 'fix: address review issues for $CURRENT_TASK [review-fix]'
   CRITICAL: The [review-fix] tag is NON-NEGOTIABLE and MUST appear verbatim at the end of the commit message
6. Push to main
7. Remove /tmp/review_issues.json
8. Exit

IMPORTANT: Do not modify ROADMAP.md.
Do not use sed -i on any file — use temp file + mv pattern.
Do not ask questions. Fix and push."

# ── Invoke Claude Code ───────────────────────────────────────────────────────
log "invoking Claude Code (cycle $NEW_COUNT)"

claude --print "$FIX_PROMPT" >> "$LOG_DIR/fix-agent.log" 2>&1

EXIT_CODE=$?
log "Claude Code exited with code $EXIT_CODE"

if [ $EXIT_CODE -ne 0 ]; then
  echo "{\"type\":\"FIX_AGENT_FAILED\",\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"task\":\"$CURRENT_TASK\",\"cycle\":$NEW_COUNT,\"exit_code\":$EXIT_CODE}" >> "$LOG_DIR/failures.jsonl"
  exit 1
fi

# ── Clear counter on success ──────────────────────────────────────────────────
# If fix succeeded, reset counter so next task starts fresh
rm -f "$COUNTER_FILE"

rm -f /tmp/review_issues.json
log "complete — fix cycle $NEW_COUNT succeeded"
