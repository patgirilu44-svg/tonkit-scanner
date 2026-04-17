#!/bin/bash
# run-agent.sh
# Called by cron every 4 hours.
# Pulls latest, checks for PENDING tasks, invokes Claude Code if found.

set -euo pipefail

REPO_DIR="/home/$(whoami)/tonkit"
LOG_DIR="$REPO_DIR/logs"
LOCK_FILE="/tmp/tonkit-agent.lock"

mkdir -p "$LOG_DIR"

LOG="$LOG_DIR/agent-$(date +%Y-%m-%d).log"

log() {
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) $1" | tee -a "$LOG"
}

# ── Lock check ───────────────────────────────────────────────────────────────
if [ -f "$LOCK_FILE" ]; then
  LOCK_AGE=$(( $(date +%s) - $(stat -c %Y "$LOCK_FILE") ))
  if [ "$LOCK_AGE" -lt 7200 ]; then
    log "AGENT: active session in progress ($LOCK_AGE seconds old), skipping"
    exit 0
  fi
  log "AGENT: stale lock ($LOCK_AGE seconds old), removing and continuing"
  rm "$LOCK_FILE"
fi

# ── Pull latest ───────────────────────────────────────────────────────────────
cd "$REPO_DIR"
git pull origin main 2>&1 | tee -a "$LOG"

# ── Check for PENDING tasks ───────────────────────────────────────────────────
# ── ROADMAP integrity check + auto-restore ──────────────────────────────────
# Clean up any leftover temp file from crashed previous session
rm -f "$REPO_DIR/ROADMAP.md.tmp"

# Validate ROADMAP structure
TASK_COUNT=$(grep -c "## TASK:" ROADMAP.md 2>/dev/null || echo 0)
STATUS_COUNT=$(grep -c "^STATUS:" ROADMAP.md 2>/dev/null || echo 0)
if [ "$TASK_COUNT" -ne "$STATUS_COUNT" ] || [ "$TASK_COUNT" -eq 0 ]; then
  log "AGENT: ROADMAP corrupt (tasks=$TASK_COUNT statuses=$STATUS_COUNT) — auto-restoring from git"
  git checkout ROADMAP.md
  TASK_COUNT=$(grep -c "## TASK:" ROADMAP.md 2>/dev/null || echo 0)
  STATUS_COUNT=$(grep -c "^STATUS:" ROADMAP.md 2>/dev/null || echo 0)
  if [ "$TASK_COUNT" -ne "$STATUS_COUNT" ]; then
    log "AGENT: git restore failed — ROADMAP still corrupt, requires human fix"
    echo "{"type":"ROADMAP_CORRUPT","timestamp":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","tasks":$TASK_COUNT,"statuses":$STATUS_COUNT}" >> "$LOG_DIR/failures.jsonl"
    exit 1
  fi
  log "AGENT: ROADMAP restored from git successfully"
fi


PENDING_COUNT=$(grep -c "STATUS: PENDING" ROADMAP.md 2>/dev/null || echo 0)

if [ "$PENDING_COUNT" -eq 0 ]; then
  log "AGENT: no PENDING tasks found, nothing to do"
  echo "{\"type\":\"AGENT_IDLE\",\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"pending\":0}" >> "$LOG_DIR/events.jsonl"
  exit 0
fi

# ── Check for FAILED tasks (require human decision) ───────────────────────────
FAILED_COUNT=$(grep -c "STATUS: FAILED" ROADMAP.md 2>/dev/null || echo 0)
if [ "$FAILED_COUNT" -gt 0 ]; then
  log "AGENT: $FAILED_COUNT FAILED task(s) in ROADMAP — requires human decision, skipping"
  echo "{\"type\":\"BLOCKED_BY_FAILURE\",\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"failed_tasks\":$FAILED_COUNT}" >> "$LOG_DIR/events.jsonl"
  exit 0
fi

log "AGENT: found $PENDING_COUNT PENDING task(s), invoking Claude Code"
echo "{\"type\":\"AGENT_START\",\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"pending\":$PENDING_COUNT}" >> "$LOG_DIR/events.jsonl"

# ── Read system prompt ────────────────────────────────────────────────────────
SYSTEM_PROMPT=$(cat "$REPO_DIR/CLAUDE_CODE_SYSTEM_PROMPT.md")

# ── Invoke Claude Code ────────────────────────────────────────────────────────
# The --print flag runs non-interactively with the given prompt
claude \
  --print \
  "$SYSTEM_PROMPT" \
  2>&1 | tee -a "$LOG"

EXIT_CODE=${PIPESTATUS[0]}

if [ $EXIT_CODE -eq 0 ]; then
  log "AGENT: Claude Code session completed successfully"
  echo "{\"type\":\"AGENT_COMPLETE\",\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"exit_code\":0}" >> "$LOG_DIR/events.jsonl"
else
  log "AGENT: Claude Code session failed with exit code $EXIT_CODE"
  echo "{\"type\":\"AGENT_FAILED\",\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"exit_code\":$EXIT_CODE}" >> "$LOG_DIR/failures.jsonl"
fi

# Lock is managed by Claude Code itself per the system prompt.
# If Claude Code crashed without removing the lock, clean it up here.
if [ -f "$LOCK_FILE" ]; then
  LOCK_AGE=$(( $(date +%s) - $(stat -c %Y "$LOCK_FILE") ))
  if [ "$LOCK_AGE" -gt 60 ]; then
    log "AGENT: cleaning up orphaned lock file"
    rm "$LOCK_FILE"
  fi
fi
