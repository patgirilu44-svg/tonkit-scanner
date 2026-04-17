# TonKit Scanner — Project Context

This file is the single source of truth for all product and architecture decisions.
Claude Code must read this file at the start of every session before reading ROADMAP.md.

---

## What This Product Is

TonKit Scanner is a self-serve Tact/FunC smart contract vulnerability scanner for the TON blockchain.
Developers paste their contract source code, the system runs a rule engine + AI analysis,
and produces a public shareable report URL with a dynamic OG image for Telegram sharing.

**NOT an auditor. NOT a replacement for manual audit. A pre-audit scanner.**
The word "audit" must never appear in product copy, report titles, or UI text.
Use: "scan", "analysis", "vulnerability scan", "security scan".

---

## Brand

- Product name: TonKit Scanner
- Domain: tonkit.dev (subdirectory /scan or standalone)
- CLI command: `tonkit scan`
- Part of TonKit ecosystem ("the Hardhat for TON")
- GitHub org: same as TonKit repo

---

## Target Users (ICP)

1. Tact developers (primary) — Web2 migrants, less security intuition, more tooling willingness
2. FunC developers (secondary) — existing cohort, more security-aware
3. Grant applicants — need credibility artifacts before TON Foundation submissions
4. DeFi teams — deploying contracts with real TVL

---

## Pricing

| Tier | Price | What they get |
|---|---|---|
| Free | $0 | Summary report, 3 findings visible, shareable URL, Telegram OG card |
| Full Report | $49 | All findings, confidence tiers, PDF export, full AI analysis |
| B2B API | $149+/month | White-label, monitoring, volume (Month 8+) |

Payment processor: Lemon Squeezy (merchant of record, no Indian company required, handles global VAT) — for international card payments
Crypto payments: USDT-TON via Jetton transfers — DAY 1 FEATURE (not Month 2)
Reason: India international payment complexity (SWIFT delays 15-30 days, bank friction). TON developers are crypto-native. USDT-TON = instant settlement, no bank drama.
Payout flow: USDT-TON → TON wallet → WazirX/CoinDCX → INR same day
Both payment methods live from launch: Lemon Squeezy for card, USDT-TON for crypto

---

## Tech Stack (Locked — Do Not Change)

- Framework: Next.js 14 App Router, TypeScript strict mode
- Database: Supabase free tier (PostgreSQL)
- Deployment: Vercel (auto-deploy on push to main)
- AI: Claude API — model: claude-sonnet-4-6 (NOT Opus, cost reasons)
- OG Images: @vercel/og Edge Runtime (NOT Puppeteer — too large for Vercel free tier)
- Payments: Lemon Squeezy
- Testing: Jest with ts-jest
- Node version: 20

---

## Architecture Decisions (Locked — Do Not Change)

### Privacy-First — Contract Code Never Stored
- Source code lives in memory during the request only
- report_id = sha256(code + timestamp + salt)
- contract_hash = sha256(code only) — deduplication key
- Database stores: findings, score, metadata, contract_hash — NEVER source code
- Registry maps: {ton_address → report_id} — developer optionally provides deployed address

### Rule Engine Architecture
- Layer 1: Hardcoded structural rules (regex + text pattern matching)
- Layer 2: Claude AI analysis on top (handles semantic/logic issues)
- Two layers NEVER blended into one confidence signal — shown separately in UI
- Confidence tiers per finding: HIGH | MEDIUM | LOW
- LOW confidence = "Possible issue — manual review recommended" in UI, 20% score weight
- Tune for PRECISION over RECALL — better to miss than false positive

### Scoring Algorithm
- Complexity normalization: log10(lineCount) prevents small contracts looking artificially clean
- Diminishing returns on stacked same-severity findings
- Display: "87/100 — No critical patterns detected" NOT "87/100 — Secure"
- Never imply security guarantee

### Rule Versioning
- Every report stores rule_engine_version at scan time
- Reports never retroactively modified
- Staleness banner shown when rule_engine_version < current: "New patterns added — re-scan recommended"
- Free re-scans for paying customers on major rule version bumps (monitoring tier retention mechanic)

---

## Database Schema (Locked)

```sql
CREATE TABLE reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  contract_hash text NOT NULL,
  contract_name text,
  language text NOT NULL DEFAULT 'tact', -- 'tact' or 'func'
  ton_address text, -- optional, provided by developer
  rule_findings jsonb NOT NULL DEFAULT '[]',
  ai_findings jsonb NOT NULL DEFAULT '[]',
  score integer NOT NULL DEFAULT 0,
  critical_count integer NOT NULL DEFAULT 0,
  high_count integer NOT NULL DEFAULT 0,
  medium_count integer NOT NULL DEFAULT 0,
  low_count integer NOT NULL DEFAULT 0,
  rule_engine_version text NOT NULL DEFAULT '1.0.0',
  is_paid boolean NOT NULL DEFAULT false,
  paid_at timestamptz,
  order_id text,
  email text,
  stale boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE monitored_contracts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text NOT NULL,
  ton_address text NOT NULL,
  baseline_code_hash text,
  baseline_report_id uuid REFERENCES reports(id),
  last_checked_at timestamptz,
  alert_email text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE disputed_findings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  report_id uuid REFERENCES reports(id) NOT NULL,
  rule_id text NOT NULL,
  developer_comment text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE rule_versions (
  version text PRIMARY KEY,
  released_at timestamptz NOT NULL DEFAULT now(),
  changes jsonb NOT NULL DEFAULT '{}'
);

INSERT INTO rule_versions (version, changes) VALUES (
  '1.0.0',
  '{"added": ["TACT-001", "TACT-002", "TACT-003", "TACT-004", "TACT-005"], "modified": [], "deprecated": []}'
);
```

---

## Rule Engine — Tact Rules (MVP)

| Rule ID | Name | Severity |
|---|---|---|
| TACT-001 | Incorrect require() placement in receive() handlers | HIGH |
| TACT-002 | Unbounded map iteration | HIGH |
| TACT-003 | Improper self.reply() vs self.forward() usage | HIGH |
| TACT-004 | Missing throwUnless on ownership checks | HIGH |
| TACT-005 | Integer arithmetic overflow (division before multiplication) | MEDIUM |

## Rule Engine — FunC Rules (Month 2)

| Rule ID | Name | Severity |
|---|---|---|
| FUNC-001 | Missing bounce message validation | HIGH |
| FUNC-002 | Missing op-code validation | HIGH |
| FUNC-003 | Gas drain via forced message chains | HIGH |
| FUNC-004 | Integer overflow in cell deserialization | MEDIUM |
| FUNC-005 | Unprotected admin functions | CRITICAL |

---

## Distribution Strategy

1. Telegram OG card — dynamic image with severity counts, score, contract name
2. Share button → t.me/share/url with report URL
3. 100 manual Telegram DMs at launch — scan real public TON contracts, send free reports
4. Exploit-driven rule updates — post in @tondev_eng when new pattern added
5. SEO — vulnerability reference pages at launch (/vulnerabilities/tact-*)
6. Pillar post — "TON Smart Contract Security: Complete Developer Guide"

---

## Fixture Library (Must Build Before Rules)

Location: /fixtures/tact/ and /fixtures/func/
Structure per rule:
- vulnerable.[tact|fc] — triggers the rule
- clean.[tact|fc] — must NOT trigger the rule
- exploit-scenario.md — attack description

Sources:
- github.com/ton-community/tact-challenge — real vulnerable Tact contracts
- github.com/ton-blockchain/token-contract — known-clean baselines
- Write clean counterparts manually (1-2 hours per rule)

CI must run all fixtures on every push and fail if any rule produces wrong result.

---

## Viral Loop Mechanics

1. Developer scans contract → gets report URL
2. Report page has Telegram share button
3. Dynamic OG image shows: contract name + severity counts + score number
4. Image must show a NUMBER — "3 Critical" gets clicked, "Audit Complete" does not
5. Shared URL → group members click → land on public report → see CTA to scan their contract
6. OG image generated at /api/og/[reportId] using @vercel/og Edge Runtime
7. SSR required for OG meta tags — Next.js App Router generateMetadata handles this

---

## Competitive Landscape

- BlockChainSentry: 32 rules, enterprise-facing, zero community presence — not a real threat
- Trail of Bits: institutionally embedded in TON grants, charges $10K+ — different buyer, different tier
- TONScanner/TSA: academic research tools, no product, no UI
- Manual audit firms (CertiK, TonBit, HashEx): $5K-50K, weeks — they are proof of demand, not competition

Positioning: "Catch issues BEFORE you pay for a manual audit" — complementary to Trail of Bits, not competing.

---

## Revenue Timeline

| Month | Activity | Revenue |
|---|---|---|
| 1-2 | $49 one-time reports | $500-1,500 |
| 3-4 | Reports scaling | $2,000-4,000 |
| 5-6 | Monitoring tier launches ($79/month) | $3,000-6,000/month |
| 8-12 | B2B API deals | $500-2,000/month recurring |

Break-even: Month 4-5

---

## Environment Variables Required

```
ANTHROPIC_API_KEY=
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_ANON_KEY=
SUPABASE_SERVICE_ROLE_KEY=
LEMONSQUEEZY_API_KEY=
LS_STORE_ID=
LS_VARIANT_ID=
LS_WEBHOOK_SECRET=
SCAN_SALT=
NEXT_PUBLIC_APP_URL=
```

---

## Absolute Rules Claude Code Must Follow

1. Never store contract source code in the database
2. Never use the word "audit" in any user-facing copy
3. Never display "Secure" — always "No critical patterns detected"
4. Never blend rule findings and AI findings into one score — show separately
5. Never push if tests are failing
6. Never create placeholder implementations — every function must work correctly
7. Always use claude-sonnet-4-6 as model string, never Opus
8. Always include rule_engine_version in every report record
9. Always set maxDuration = 60 on the /api/scan route
10. Always use @vercel/og with runtime = 'edge' for OG image generation

---

## AI Analysis — Chain of Thought Requirement

Claude API analysis must use Chain of Thought reasoning — NOT just output findings directly.

**Required JSON response shape from AI:**
```json
{
  "reasoning": "Step-by-step explanation of what the contract does, what patterns were checked, and why each finding was flagged or cleared",
  "summary": "2-3 sentence overall assessment",
  "gas_efficiency_score": 0-100,
  "additional_findings": [
    {
      "id": "AI-001",
      "title": "string",
      "severity": "CRITICAL|HIGH|MEDIUM|LOW|INFO",
      "confidence": "HIGH|MEDIUM|LOW",
      "reasoning": "Why this specific code pattern is dangerous in TON's async actor model",
      "description": "string",
      "recommendation": "string",
      "line_hint": "string or null"
    }
  ]
}
```

**Why this matters:**
- Claude without CoT = pattern matching on surface syntax = misses TVM-specific exploits
- Claude with CoT = forced to reason about TON's async message model before concluding
- Each finding must have its own `reasoning` field explaining WHY it's dangerous in TON context
- Low confidence findings without clear reasoning = downgraded to INFO severity automatically

**System prompt must include:**
- Explicit instruction: "Think step by step before outputting findings"
- TON actor model context: "TON contracts communicate via asynchronous messages, not synchronous calls"
- Reasoning requirement: "For each finding, explain why it is dangerous specifically in TON's execution model"
- Anti-hallucination guard: "If you are not confident about a finding, set confidence to LOW and explain your uncertainty in the reasoning field"

**In lib/ai/prompts.ts:**
- buildSystemPrompt() must include all 4 instructions above
- buildUserPrompt() must ask Claude to reason before concluding
- Response parser must extract and store `reasoning` field in ai_findings jsonb column

---

## CRITICAL UPDATES (Post Final Audit)

### Misti Competitor — Changes Positioning Entirely
Misti (github.com/nowarp/misti) is TON Foundation grant-funded static analyzer with 42 detectors.
It is FREE, open source, has Blueprint plugin and GitHub Actions integration.
Our 5 Tact rules are a subset of Misti's coverage.

**New positioning:** "TonKit Scanner adds Claude AI Chain-of-Thought reasoning and shareable report URLs on top of Misti-level detection — catch issues, understand WHY they're dangerous in TON's async model, share proof."

We do NOT replace Misti. We ADD reasoning layer + hosted reports + viral badge network.

### Pricing Change
$49 is the dead zone — too expensive for hobbyists, too cheap to be credible.
Decision needed before launch: either $19 (volume, mass-market) or $299 (pre-token-launch teams).
$49 pricing deprecated.

### Infrastructure Upgrade — Mandatory From Day One
Vercel Hobby = ToS violation on first commercial transaction. Must use Vercel Pro ($20/month).
Supabase Free = auto-pause kills payments silently. Must use Supabase Pro ($25/month).

**Revised monthly cost floor:** $67/month (~₹5,600)
- Hetzner CX22: €3.79 (~₹340)
- Vercel Pro: $20 (~₹1,680)
- Supabase Pro: $25 (~₹2,100)
- Anthropic API: ~$10 (~₹840)

### T019 Added — Highest Priority Feature
Redacted free tier (line numbers visible, content hidden) + TonKit Verified badge embed.
This is the single highest-leverage conversion feature. Added as T019 to ROADMAP.

### Supabase Connection Pooling
Use Supabase Supavisor in transaction mode — not direct connection.
Vercel cold starts exhaust free tier connection pool under burst traffic.

### USDT-TON Payment — Updated Rules
- Accept ±2% tolerance band (wallet fee deductions)
- 6-hour pending-payment fallback before hard 30-min expiry
- HD wallet: BIP32 hardened derivation only, never log seed alongside addresses
- MASTER_TON_SEED rotation: annually even if uncompromised

### 12-Month Moat Strategy
Scanner has 12-18 month lifespan before Misti + IDE integration commoditizes it.
Real moat: anonymized vulnerability intelligence database from scan corpus.
Pivot target at Month 12: threat-intel SaaS for TON protocol teams ($500-2,000/month).
Insurance policy: study TAC (TON Application Chain, EVM L2) for ecosystem hedge.
