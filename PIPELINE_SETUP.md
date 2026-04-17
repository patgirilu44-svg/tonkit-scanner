# TonKit Scanner — Autonomous Pipeline: Complete Setup & Reference

---

## VPS Setup (Run Once)

```bash
# 1. Clone repo
git clone git@github.com:yourusername/tonkit-scanner.git ~/tonkit
cd ~/tonkit

# 2. Install Node 20
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# 3. Install Claude Code CLI
npm install -g @anthropic-ai/claude-code

# 4. Authenticate Claude Code (one-time)
claude auth

# 5. Make scripts executable
chmod +x scripts/run-agent.sh
chmod +x scripts/fix-agent.sh

# 6. Create log directory
mkdir -p logs

# 7. Configure git identity (for automated commits)
git config user.email "tonkit-agent@yourdomain.com"
git config user.name "TonKit Agent"

# 8. Add GitHub deploy key (so VPS can push without password)
ssh-keygen -t ed25519 -C "tonkit-vps" -f ~/.ssh/github_deploy -N ""
# Copy ~/.ssh/github_deploy.pub to GitHub repo Settings → Deploy Keys → Allow write access
git remote set-url origin git@github.com:yourusername/tonkit-scanner.git
```

---

## Crontab Configuration

```cron
# Run agent every 4 hours (builds next task)
0 */4 * * * /home/ubuntu/tonkit/scripts/run-agent.sh >> /home/ubuntu/tonkit/logs/cron.log 2>&1

# Generate status dashboard daily at 00:30 UTC
30 0 * * * python3 /home/ubuntu/tonkit/scripts/generate-status.py >> /home/ubuntu/tonkit/logs/cron.log 2>&1

# Watchdog: check for stale IN_PROGRESS tasks every 3 hours
0 */3 * * * /home/ubuntu/tonkit/scripts/watchdog.sh >> /home/ubuntu/tonkit/logs/cron.log 2>&1
```

Install with: `crontab -e`

---

## GitHub Secrets Required

Set these in your repo at Settings → Secrets and Variables → Actions:

| Secret | Value |
|--------|-------|
| `ANTHROPIC_API_KEY` | Your Anthropic API key |
| `VPS_SSH_KEY` | Contents of `~/.ssh/github_deploy` private key |
| `VPS_HOST` | Your DigitalOcean droplet IP |
| `VPS_USER` | `ubuntu` or your VPS username |
| `VERCEL_DEPLOY_HOOK` | From Vercel project settings → Git → Deploy Hooks |
| `NEXT_PUBLIC_SUPABASE_URL` | From Supabase project settings |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | From Supabase project settings |

---

## Handoff Protocol Between Actors

### Normal flow (no collision)

```
Cron fires run-agent.sh
  → Checks lock file (none exists)
  → Creates /tmp/tonkit-agent.lock
  → Claude Code claims task (commits ROADMAP.md [skip ci])
  → Claude Code builds and tests
  → Claude Code commits feature + pushes
  → GitHub Actions triggers (push detected, not [skip ci])
    → build-and-test job runs
    → ai-review job runs
    → IF passed: deploy job triggers Vercel hook
    → IF failed: trigger-fix job SSHes to VPS → fix-agent.sh
      → fix-agent.sh checks for /tmp/tonkit-fix.lock
      → Creates /tmp/tonkit-fix.lock
      → Claude Code reads review issues, fixes, commits, pushes
      → GitHub Actions triggers again (new push)
      → Cycle repeats up to 3 times
      → After 3 failures: writes to failures.jsonl, workflow fails
  → Claude Code removes /tmp/tonkit-agent.lock
  → Claude Code exits
```

### Collision scenarios and resolutions

**Scenario A: GitHub Actions fix-agent SSH fires while run-agent is mid-task**

Resolution: `fix-agent.sh` checks `/tmp/tonkit-agent.lock`. If it exists and is < 2 hours old, fix-agent exits without doing anything. The review failure is logged to failures.jsonl. The next cron cycle (up to 4 hours later) will complete the current task, push, trigger a fresh review cycle, and fix-agent will run cleanly then.

This means: a collision delays the fix by at most one cron cycle (4 hours). Acceptable.

**Scenario B: Two cron triggers fire simultaneously**

This cannot happen if crontab intervals are > task duration. But as defense: both `run-agent.sh` and Claude Code itself check `/tmp/tonkit-agent.lock`. The second invocation sees the lock, logs "LOCK EXISTS", and exits. The first invocation continues.

**Scenario C: Claude Code crashes mid-task, lock not removed**

`run-agent.sh` runs a post-exit cleanup: if lock file exists after Claude Code exits AND its age is > 60 seconds, it removes it. On the next cron cycle (4 hours), run-agent sees no lock, pulls latest, and attempts the task again. Because the task is STATUS: IN_PROGRESS from the failed session, Claude Code's STEP 2 will find it and attempt to resume from STEP 5 (build) rather than re-claiming.

**Scenario D: Git push conflict (two processes push simultaneously)**

Claude Code's STEP 3 pulls before pushing. Fix-agent also pulls before making changes. Since they cannot run simultaneously (lock file), the only conflict scenario is a human pushing while automation runs. The next pull will rebase cleanly as long as humans don't force-push. Do not force-push to main.

---

## Watchdog Script

```bash
#!/bin/bash
# watchdog.sh — detects stuck IN_PROGRESS tasks and alerts

REPO_DIR="/home/$(whoami)/tonkit"
LOG_DIR="$REPO_DIR/logs"

IN_PROGRESS=$(grep -c "STATUS: IN_PROGRESS" "$REPO_DIR/ROADMAP.md" 2>/dev/null || echo 0)

if [ "$IN_PROGRESS" -gt 0 ]; then
  # Find the git commit that set it to IN_PROGRESS
  TASK_ID=$(grep -B5 "STATUS: IN_PROGRESS" "$REPO_DIR/ROADMAP.md" | grep "## TASK:" | tail -1 | sed 's/## TASK: //')
  CLAIM_TIME=$(git -C "$REPO_DIR" log --oneline --format="%ci" -1 -- ROADMAP.md 2>/dev/null | head -1)
  
  echo "{\"type\":\"WATCHDOG_IN_PROGRESS\",\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"task\":\"$TASK_ID\",\"claimed_at\":\"$CLAIM_TIME\"}" >> "$LOG_DIR/events.jsonl"

  # If task has been IN_PROGRESS for more than 6 hours, it's stuck
  if [ -f /tmp/tonkit-agent.lock ]; then
    LOCK_AGE=$(( $(date +%s) - $(stat -c %Y /tmp/tonkit-agent.lock) ))
    if [ "$LOCK_AGE" -gt 21600 ]; then
      echo "{\"type\":\"STUCK_TASK_DETECTED\",\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"task\":\"$TASK_ID\",\"lock_age_hours\":$(( LOCK_AGE / 3600 ))}" >> "$LOG_DIR/failures.jsonl"
      rm /tmp/tonkit-agent.lock
    fi
  fi
fi
```

---

## Top 5 Silent Failure Modes

### 1. Claude Code exits 0 but didn't actually push

**How it fails silently:** Claude Code runs, produces output that looks successful, but the git push fails due to authentication expiry or network timeout. The lock is removed, the task stays IN_PROGRESS in ROADMAP.md (on the local copy that was never pushed), and the next cron cycle pulls the remote (which has the old PENDING status) and re-runs the same task. The task gets built twice.

**Detection:** The watchdog script detects IN_PROGRESS status persisting across multiple cron cycles (the remote still shows PENDING after the agent claimed IN_PROGRESS). Log entry: `WATCHDOG_IN_PROGRESS` appearing in events.jsonl more than once for the same task.

**Recovery:** Keep the deploy key's permissions current. Add this to run-agent.sh after Claude Code exits:
```bash
REMOTE_STATUS=$(git -C "$REPO_DIR" fetch origin && git show origin/main:ROADMAP.md | grep -A1 "## TASK: $CURRENT_TASK" | grep STATUS)
if echo "$REMOTE_STATUS" | grep -q "IN_PROGRESS"; then
  echo "PUSH VERIFICATION FAILED - task not on remote" >> "$LOG_DIR/failures.jsonl"
fi
```

### 2. GitHub Actions review always returns "passed" due to Claude API error handling

**How it fails silently:** The Python JSON parsing in the review step fails (malformed response from Claude API), defaults to `passed=false` ... wait — actually the opposite risk: if the `try/except` block catches an error and you default to `passed=true`, every push deploys without real review.

**The fix is critical:** The review step defaults to `passed=false` on any parse error, not `passed=true`. The workflow as written does this correctly. Verify this is the case. A bad actor (or a bad Claude response) that makes the review return garbage JSON should block deployment, not allow it.

**Detection:** Check deploys.jsonl — if you see a high deploy frequency with no corresponding agent build events, the review is rubber-stamping.

**Recovery:** Review step defaults to `passed=false`. Any exception in review parsing = deploy blocked = logged to failures.jsonl = visible on status dashboard.

### 3. ROADMAP.md sed command matches wrong task

**How it fails silently:** The sed command that sets STATUS: IN_PROGRESS uses a range match on `## TASK: T001` to the next `---`. If the file format drifts (a developer edits ROADMAP.md and removes a `---` separator), the sed range runs past the task boundary and modifies multiple tasks. Claude Code then builds everything in the range.

**Detection:** After each ROADMAP.md commit, validate the file has exactly the right number of STATUS lines:
```bash
TOTAL_TASKS=$(grep -c "## TASK:" ROADMAP.md)
TOTAL_STATUSES=$(grep -c "^STATUS:" ROADMAP.md)
if [ "$TOTAL_TASKS" -ne "$TOTAL_STATUSES" ]; then
  echo "ROADMAP INTEGRITY FAIL: $TOTAL_TASKS tasks but $TOTAL_STATUSES status lines" >> "$LOG_DIR/failures.jsonl"
fi
```
Add this check to run-agent.sh before invoking Claude Code.

**Recovery:** ROADMAP.md is version controlled — `git revert` the bad commit.

### 4. Fix-agent SSH fires repeatedly without making progress

**How it fails silently:** Review fails → fix-agent SSHes → Claude Code can't actually fix the issue (e.g., it's an architectural problem, not a typo) → commits the same broken code → review fails again → fix-agent fires again. GitHub Actions run_attempt counter prevents infinite loops (stops at 3), but 3 broken commits land on main before the workflow fails.

**Detection:** The `fail-on-max-cycles` job writes to failures.jsonl. The status dashboard surfaces this as "Review cycle exceeded N time(s)."

**Recovery:** Manual reset. Mark the task FAILED in ROADMAP.md, commit with [skip ci], examine what the review is flagging, fix ROADMAP.md acceptance criteria to be more specific, reset to PENDING.

### 5. Vercel deploy hook fires but deployment fails silently

**How it fails silently:** The `deploy` job sends a POST to the Vercel deploy hook, which returns 200 (hook received), but the Vercel build fails. GitHub Actions reports success. The deployed app is running an old version. The agent continues building the next task on top of a broken deployed state.

**Detection:** Add a post-deploy verification step to the workflow:
```yaml
- name: Verify deploy
  run: |
    sleep 30  # wait for Vercel build
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://your-app.vercel.app/api/health)
    if [ "$STATUS" != "200" ]; then
      echo "{\"type\":\"DEPLOY_HEALTH_CHECK_FAILED\",\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"status\":$STATUS}" >> failures
    fi
```

Add `app/api/health/route.ts` that returns `{ status: "ok", version: process.env.VERCEL_GIT_COMMIT_SHA }`.

**Recovery:** Check Vercel dashboard (yes, this requires a GUI check, but it's a 2-minute phone task, not a debugging session). The fix is always in the code — GitHub Actions review should have caught build failures, so a Vercel-only failure usually means an environment variable is missing in Vercel's settings.

---

## Your 30-Minute Weekly Check

Open `https://your-app.vercel.app/status` on your phone.

**Green state (0 minutes needed):** No "HUMAN DECISION REQUIRED" section. Failures log is empty. Tasks are advancing.

**Yellow state (10 minutes):** Failed tasks in ROADMAP. Reset them: SSH to VPS, edit ROADMAP.md to change STATUS: FAILED to STATUS: PENDING, git add + commit "[skip ci]" + push. Done.

**Red state (30 minutes):** MAX_REVIEW_CYCLES_EXCEEDED in failures. Read the issues in the failures log. They tell you exactly what the AI cannot self-fix. Edit ROADMAP.md to tighten the acceptance criteria for that task and reset to PENDING.

You will never read code. You read the failures log, which is in plain English.
