#!/bin/bash
# run-agent.sh — Autonomous Claude Code trigger
# CRITICAL: trap must be FIRST statement before any logic

set -uo pipefail

# ── TRAP FIRST — ensures lock clears even on SIGKILL of children ──────────────
trap 'rm -f /tmp/tonkit-agent.lock 2>/dev/null' EXIT TERM HUP INT

REPO_DIR="/home/$(whoami)/tonkit-scanner"
LOG_DIR="$REPO_DIR/logs"
LOCK_FILE="/tmp/tonkit-agent.lock"

mkdir -p "$LOG_DIR"

log() {
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) AGENT: $1" | tee -a "$LOG_DIR/run-agent.log"
}

# ── Node memory cap to prevent OOM on CX22 ────────────────────────────────────
export NODE_OPTIONS="--max-old-space-size=2048"

# ── Lock check ────────────────────────────────────────────────────────────────
if [ -f "$LOCK_FILE" ]; then
  LOCK_AGE=$(( $(date +%s) - $(stat -c %Y "$LOCK_FILE") ))
  if [ "$LOCK_AGE" -lt 7200 ]; then
    log "lock exists ($LOCK_AGE seconds old), exiting"
    exit 0
  fi
  log "stale lock ($LOCK_AGE seconds old), removing and resetting stuck task"
  rm "$LOCK_FILE"
  cd "$REPO_DIR"
  # Reset stuck IN_PROGRESS task to PENDING
  if grep -q "STATUS: IN_PROGRESS" ROADMAP.md 2>/dev/null; then
    STUCK_TASK=$(grep -B1 "STATUS: IN_PROGRESS" ROADMAP.md | grep "## TASK:" | sed 's/## TASK: //' | head -1)
    log "resetting stuck task $STUCK_TASK from IN_PROGRESS to PENDING"
    sed "/## TASK: ${STUCK_TASK}/,/^---$/{s/STATUS: IN_PROGRESS/STATUS: PENDING/}" ROADMAP.md > ROADMAP.md.tmp && mv ROADMAP.md.tmp ROADMAP.md || true
    git add ROADMAP.md
    git commit -m "fix: reset stuck task ${STUCK_TASK} after stale lock [skip ci]" || true
    git push origin main || true
  fi
fi

echo $$ > "$LOCK_FILE"

cd "$REPO_DIR"

# ── Pull latest + reset to main (prevents merge conflict chaos) ───────────────
git fetch origin main
git reset --hard origin/main

# ── Clean up any leftover temp files from crashed sessions ────────────────────
rm -f "$REPO_DIR/ROADMAP.md.tmp"

# ── ROADMAP integrity check + auto-restore ────────────────────────────────────
TASK_COUNT=$(grep -c "## TASK:" ROADMAP.md 2>/dev/null || echo 0)
STATUS_COUNT=$(grep -c "^STATUS:" ROADMAP.md 2>/dev/null || echo 0)
if [ "$TASK_COUNT" -ne "$STATUS_COUNT" ] || [ "$TASK_COUNT" -eq 0 ]; then
  log "ROADMAP corrupt (tasks=$TASK_COUNT statuses=$STATUS_COUNT) — auto-restoring from git"
  git checkout ROADMAP.md
  TASK_COUNT=$(grep -c "## TASK:" ROADMAP.md 2>/dev/null || echo 0)
  STATUS_COUNT=$(grep -c "^STATUS:" ROADMAP.md 2>/dev/null || echo 0)
  if [ "$TASK_COUNT" -ne "$STATUS_COUNT" ]; then
    log "git restore failed — ROADMAP still corrupt"
    echo "{\"type\":\"ROADMAP_CORRUPT\",\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" >> "$LOG_DIR/failures.jsonl"
    exit 1
  fi
fi

# ── Check for FAILED tasks (requires human) ───────────────────────────────────
FAILED_COUNT=$(grep -c "STATUS: FAILED" ROADMAP.md 2>/dev/null || echo 0)
if [ "$FAILED_COUNT" -gt 0 ]; then
  log "$FAILED_COUNT FAILED task(s) in ROADMAP — requires human decision, skipping"
  exit 0
fi

# ── Check for PENDING work ────────────────────────────────────────────────────
PENDING_COUNT=$(grep -c "STATUS: PENDING" ROADMAP.md 2>/dev/null || echo 0)
if [ "$PENDING_COUNT" -eq 0 ]; then
  log "ROADMAP COMPLETE — no PENDING tasks"
  exit 0
fi

# ── Invoke Claude Code ────────────────────────────────────────────────────────
log "invoking Claude Code for next PENDING task"
claude --print "Read CLAUDE_CODE_SYSTEM_PROMPT.md and PROJECT_CONTEXT.md, then execute the 10-step procedure to complete the next PENDING task in ROADMAP.md" >> "$LOG_DIR/run-agent.log" 2>&1 &

CLAUDE_PID=$!
# 90-minute timeout on Claude Code — prevents infinite hangs
(
  sleep 5400
  if kill -0 $CLAUDE_PID 2>/dev/null; then
    log "Claude Code exceeded 90 min timeout — killing"
    kill -TERM $CLAUDE_PID 2>/dev/null
    sleep 10
    kill -KILL $CLAUDE_PID 2>/dev/null
  fi
) &
WATCHDOG_PID=$!

wait $CLAUDE_PID
CLAUDE_EXIT=$?
kill $WATCHDOG_PID 2>/dev/null

log "Claude Code exited with code $CLAUDE_EXIT"

# ── POST-HOC VERIFICATION — DO NOT TRUST CLAUDE CODE EXIT CODE ────────────────
# Claude Code exits 0 on most failures. We verify independently.
git fetch origin main
git reset --hard origin/main

# Check if any task was actually marked DONE in this session
RECENT_DONE=$(git log --since='2 hours ago' --oneline --grep='feat(' | wc -l)
if [ "$RECENT_DONE" -eq 0 ]; then
  log "WARNING: Claude Code session completed but no feat() commit detected"
  # Check if a task is stuck at IN_PROGRESS
  if grep -q "STATUS: IN_PROGRESS" ROADMAP.md 2>/dev/null; then
    STUCK=$(grep -B1 "STATUS: IN_PROGRESS" ROADMAP.md | grep "## TASK:" | sed 's/## TASK: //' | head -1)
    log "Task $STUCK left IN_PROGRESS — next run will reset to PENDING after stale lock"
    
    # Send Telegram alert if configured
    if [ -n "${TELEGRAM_BOT_TOKEN:-}" ] && [ -n "${TELEGRAM_CHAT_ID:-}" ]; then
      curl -s "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        -d "text=⚠️ Task ${STUCK} left IN_PROGRESS after Claude Code session. Will auto-reset on next cron." \
        >> "$LOG_DIR/run-agent.log" 2>&1 || true
    fi
  fi
fi

log "run-agent session complete"
exit 0
