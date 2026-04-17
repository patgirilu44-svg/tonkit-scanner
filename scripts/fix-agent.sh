#!/bin/bash
# fix-agent.sh
# Called by GitHub Actions when AI review fails.
# Reads /tmp/review_issues.json, invokes Claude Code to fix them, pushes fix.

set -euo pipefail

REPO_DIR="/home/$(whoami)/tonkit"
LOG_DIR="$REPO_DIR/logs"
LOCK_FILE="/tmp/tonkit-fix.lock"

mkdir -p "$LOG_DIR"

# ── Lock check ──────────────────────────────────────────────────────────────
if [ -f "$LOCK_FILE" ]; then
  LOCK_AGE=$(( $(date +%s) - $(stat -c %Y "$LOCK_FILE") ))
  if [ "$LOCK_AGE" -lt 7200 ]; then
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) FIX-AGENT: lock exists ($LOCK_AGE seconds old), exiting" | tee -a "$LOG_DIR/fix-agent.log"
    exit 0
  fi
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) FIX-AGENT: stale lock detected, removing" >> "$LOG_DIR/fix-agent.log"
  rm "$LOCK_FILE"
fi

echo $$ > "$LOCK_FILE"

cleanup() {
  rm -f "$LOCK_FILE"
}
trap cleanup EXIT

# ── Read issues ──────────────────────────────────────────────────────────────
if [ ! -f /tmp/review_issues.json ]; then
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) FIX-AGENT: no review_issues.json found, exiting" >> "$LOG_DIR/fix-agent.log"
  exit 1
fi

ISSUES=$(cat /tmp/review_issues.json)
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) FIX-AGENT: triggered with issues: $ISSUES" >> "$LOG_DIR/fix-agent.log"

# ── Pull latest ──────────────────────────────────────────────────────────────
cd "$REPO_DIR"
git pull origin main

# ── Get current task context ─────────────────────────────────────────────────
CURRENT_TASK=$(grep -A1 "STATUS: DONE\|STATUS: IN_PROGRESS" ROADMAP.md | grep "## TASK:" | tail -1 | sed 's/## TASK: //' || echo "UNKNOWN")

# ── Build fix prompt ─────────────────────────────────────────────────────────
FIX_PROMPT="You are fixing specific code review issues in the TonKit Scanner project. 

The AI code reviewer rejected the last commit with these issues:
$ISSUES

Current task context: $CURRENT_TASK

Instructions:
1. Read each issue carefully
2. Find the exact file and line causing each issue
3. Fix only what the review flagged — do not refactor unrelated code
4. Run the relevant test command for the affected task after fixing
5. If tests pass, commit with message: 'fix: address review issues for $CURRENT_TASK [review-fix]'
6. Push to main
7. Remove /tmp/review_issues.json
8. Exit

Do not ask questions. Do not make changes beyond what the review flagged. Do not modify ROADMAP.md."

# ── Invoke Claude Code ───────────────────────────────────────────────────────
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) FIX-AGENT: invoking Claude Code" >> "$LOG_DIR/fix-agent.log"

# Claude Code CLI invocation — adjust path to your claude binary
claude --print "$FIX_PROMPT" >> "$LOG_DIR/fix-agent.log" 2>&1

EXIT_CODE=$?
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) FIX-AGENT: Claude Code exited with code $EXIT_CODE" >> "$LOG_DIR/fix-agent.log"

if [ $EXIT_CODE -ne 0 ]; then
  echo "{\"type\":\"FIX_AGENT_FAILED\",\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"issues\":$ISSUES,\"exit_code\":$EXIT_CODE}" >> "$LOG_DIR/failures.jsonl"
  exit 1
fi

rm -f /tmp/review_issues.json
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) FIX-AGENT: complete" >> "$LOG_DIR/fix-agent.log"
