# TonKit Scanner — Complete Progress Tracker
## Last Updated: April 17, 2026 (9:40 PM IST)

---

## ✅ COMPLETED

### Product & Strategy
- [x] Product concept validated (5 LLMs adversarial review)
- [x] Name locked: **TonKit Scanner** (not "Auditor" — liability)
- [x] Pricing locked: **$19 full report** (volume strategy)
- [x] Positioning locked: "Adds Claude AI Chain-of-Thought + hosted reports on top of Misti-level detection"
- [x] Misti competitor acknowledged (42 detectors, TON Foundation grant-funded)
- [x] USDT-TON crypto payments: Day 1 feature
- [x] Distribution strategy: Telegram OG cards + 100 manual DMs + badge viral loop
- [x] 12-month moat strategy: scan corpus → threat-intel SaaS pivot

### Architecture Locked
- [x] Privacy-first: contract code NEVER stored (hash only)
- [x] Rule engine: Tact first (5 rules), FunC second (5 rules)
- [x] Scoring algorithm: complexity-normalized, no "Secure" label
- [x] Confidence tiers: HIGH/MEDIUM/LOW per finding
- [x] Chain of Thought AI: per-finding reasoning mandatory
- [x] Stack: Next.js 14 + Supabase Pro + Vercel Pro + Claude sonnet-4-6

### Repository
- [x] GitHub repo live: `github.com/patgirilu44-svg/tonkit-scanner`
- [x] 19 atomic tasks (T001-T017 + T013b + T019)
- [x] All tasks have ACCEPTANCE criteria (verifiable commands)
- [x] PROJECT_CONTEXT.md v4
- [x] CLAUDE_CODE_SYSTEM_PROMPT.md v5
- [x] PIPELINE_SETUP.md
- [x] schema.sql
- [x] .env.example
- [x] .eslintrc.json (bans @ts-expect-error)
- [x] SESSION_SUMMARY.md + PROGRESS.md

### Pipeline (6 jobs)
- [x] build-and-test
- [x] ai-review
- [x] deploy
- [x] trigger-fix
- [x] smoke-test (NEW)
- [x] notify-failure

### Bug Fixes Applied (19 total)
1. [x] Atomic writes: same-directory temp + mv
2. [x] Fix cycle counter persisted to disk
3. [x] ROADMAP corruption auto-restore via git checkout
4. [x] [review-fix] tag mandatory
5. [x] FAILED commits include [skip ci]
6. [x] fix-agent checks run-agent.lock
7. [x] Stale lock resets IN_PROGRESS → PENDING
8. [x] STEP 8.5: acceptance verification before DONE
9. [x] 19 ACCEPTANCE sections in ROADMAP
10. [x] Chain of Thought AI with per-finding reasoning
11. [x] Weekly ROADMAP backup (Sundays only)
12. [x] Intraday Telegram alerts
13. [x] OUTPUTS section for context continuity
14. [x] ROADMAP enum validation
15. [x] Trap-first lock (catches SIGKILL)
16. [x] Post-hoc verification (no exit code trust)
17. [x] 90-min Claude Code timeout
18. [x] Smoke test job (real /api/scan POST)
19. [x] Ban @ts-expect-error without TODO tag

### Supabase
- [x] Project created: `tonkit-scanner` (Singapore)
- [x] Project ref: `ivauhvsqbqhrwnrnefwv`
- [x] Schema pushed via psql from Termux
- [x] 4 tables + RLS policies

### GitHub Secrets (5 of 14)
- [x] TELEGRAM_BOT_TOKEN
- [x] TELEGRAM_CHAT_ID
- [x] NEXT_PUBLIC_SUPABASE_URL
- [x] NEXT_PUBLIC_SUPABASE_ANON_KEY
- [x] SUPABASE_SERVICE_ROLE_KEY

### Telegram Bot
- [x] @TonKitScanBot created
- [x] Token + Chat ID in GitHub Secrets

### Commits
- [x] 16 total
- [x] Latest: trap-first lock, smoke test, ban ts-expect-error

---

## ❌ PENDING

### 1. Anthropic API — Can do now
- [ ] console.anthropic.com → Add $10 credits
- [ ] Create API key
- [ ] Add GitHub Secret: ANTHROPIC_API_KEY

### 2. SCAN_SALT — Can do now
- [ ] Termux: `openssl rand -hex 32`
- [ ] Add GitHub Secret: SCAN_SALT

### 3. Vercel Pro — $20/month MANDATORY
- [ ] vercel.com → Import tonkit-scanner repo
- [ ] Upgrade to Pro
- [ ] Add all env variables
- [ ] Set VERCEL_FORCE_NO_BUILD_CACHE=1
- [ ] Get deploy hook → GitHub Secret: VERCEL_DEPLOY_HOOK
- [ ] Note deployed URL → GitHub Secret: NEXT_PUBLIC_APP_URL

### 4. Supabase Pro — $25/month MANDATORY
- [ ] Dashboard → Billing → Upgrade to Pro
- [ ] Prevents free tier auto-pause

### 5. Hetzner VPS — €3.79/month
- [ ] hetzner.com account
- [ ] CX22 droplet Ubuntu 24.04
- [ ] Add 4GB swap
- [ ] SSH key setup
- [ ] Clone repo
- [ ] Install Node 20
- [ ] Install Claude Code CLI
- [ ] Auth Claude Code
- [ ] chmod +x scripts/*.sh
- [ ] git config user.email
- [ ] Add GitHub deploy key
- [ ] Crontab setup

### 6. GitHub Secrets Remaining (9)
- [ ] ANTHROPIC_API_KEY
- [ ] SCAN_SALT
- [ ] NEXT_PUBLIC_APP_URL
- [ ] VERCEL_DEPLOY_HOOK
- [ ] VPS_SSH_KEY
- [ ] VPS_HOST
- [ ] VPS_USER
- [ ] LEMONSQUEEZY_API_KEY
- [ ] LS_STORE_ID
- [ ] LS_VARIANT_ID
- [ ] LS_WEBHOOK_SECRET

### 7. Bootstrap (one-time on VPS)
- [ ] bash scripts/bootstrap.sh
- [ ] Pipeline auto-starts T001 at next cron

### 8. Lemon Squeezy
- [ ] Account + store
- [ ] $19 product created
- [ ] Webhook configured
- [ ] 4 secrets added

---

## 📋 SETUP ORDER

```
1. Anthropic API + $10        ← Can do now
2. SCAN_SALT                  ← Can do now (Termux)
3. Vercel Pro                 ← $20/month
4. Supabase Pro upgrade       ← $25/month
5. Hetzner VPS                ← €3.79/month
6. Remaining GitHub Secrets   ← After 1-5
7. bootstrap.sh on VPS        ← After step 5
8. Lemon Squeezy              ← Anytime after step 3
```

---

## 💰 COSTS

| Service | Cost | Status |
|---|---|---|
| Hetzner CX22 | ~₹340/month | ⏳ |
| Vercel Pro | ~₹1,680/month | ⏳ MANDATORY |
| Supabase Pro | ~₹2,100/month | ⏳ MANDATORY |
| Anthropic API | ~$10 total | ⏳ |
| Lemon Squeezy | 5% per sale | ⏳ |
| GitHub | Free | ✅ |
| **Monthly floor** | **~₹5,600** | |
| **Break-even** | **4 sales @ $19** | |

---

## 🚀 AFTER FULL SETUP

- Cron every 4h → Claude Code builds next task
- 6 pipeline jobs validate every push
- Smoke test POSTs real fixture to /api/scan
- Auto-fix on review failure (max 3 cycles)
- Telegram alerts on any failure
- Weekly ROADMAP backup Sundays
- Daily /status dashboard

**Your role: 30 min/week**

---

## 📊 STATS

| Metric | Value |
|---|---|
| Commits | 16 |
| Tasks | 19 |
| Pipeline jobs | 6 |
| Bugs fixed | 19 |
| LLM audits | 5 |
| Build time | 3-5 days (VPS 24/7) |
| Complexity | 8.7/10 |
| Month 1 revenue | $200-800 |
| Break-even | Month 2-3 |

---

## 🔥 CRITICAL FIXES THIS SESSION

**Pipeline audit:**
1. Trap-first lock strategy
2. Post-hoc verification
3. End-to-end smoke test
4. Ban @ts-expect-error
5. git reset --hard prevents merge chaos
6. 90-min timeout

**Product audit:**
1. Misti competitor acknowledged
2. Pricing $49 → $19
3. Vercel Pro + Supabase Pro mandatory
4. T019 added: badge + redacted tier

---

## NEXT ACTION

**Right now:** console.anthropic.com → Add $10 credits → Create API key → GitHub Secret ANTHROPIC_API_KEY
