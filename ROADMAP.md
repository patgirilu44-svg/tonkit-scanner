# TonKit Scanner — Autonomous Build Roadmap

Claude Code: Read PROJECT_CONTEXT.md before reading this file.
Process tasks in order. Never skip. Never overlap. One task per session.

Format reference:
- STATUS: PENDING → IN_PROGRESS → DONE | FAILED
- Each task is atomic: completable in one Claude Code session
- FILES_AFFECTED: only modify listed files
- OUT_OF_SCOPE: never implement these in this task

---

## TASK: T001
STATUS: PENDING
TITLE: Project initialization and dependency setup
PHASE: Foundation

DESCRIPTION:
Initialize Next.js 14 App Router project with TypeScript strict mode.
Install all required dependencies. Set up Jest testing infrastructure.
Create base directory structure. Create .env.example and .gitignore.

ACCEPTANCE_CRITERIA:
- [ ] Next.js 14 App Router project created with TypeScript strict mode
- [ ] All dependencies installed: @supabase/ssr @supabase/supabase-js @anthropic-ai/sdk @vercel/og lemon-squeezy-js
- [ ] All dev dependencies installed: jest ts-jest @types/jest @types/node
- [ ] jest.config.ts created and working
- [ ] tsconfig.json has strict: true
- [ ] .env.example contains all required variables from PROJECT_CONTEXT.md
- [ ] .gitignore excludes .env.local, node_modules, .next, logs/
- [ ] Base directory structure created: app/ lib/ components/ __tests__/ fixtures/ public/

FILES_AFFECTED:
- package.json
- package-lock.json
- tsconfig.json
- jest.config.ts
- next.config.ts
- .env.example
- .gitignore
- app/layout.tsx
- app/globals.css

TEST_COMMAND:
npx tsc --noEmit && npx jest --passWithNoTests

COMPLETION_SIGNAL:
TEST_COMMAND exits 0 with no TypeScript errors.

OUT_OF_SCOPE:
- No UI components yet
- No database connections yet
- No API routes yet
- No rule engine yet

---

## TASK: T002
STATUS: PENDING
TITLE: Supabase client setup and database schema
PHASE: Foundation

DESCRIPTION:
Create Supabase client for server and browser contexts.
Write the complete SQL schema. Create typed database helper functions.
Schema must match PROJECT_CONTEXT.md exactly — no deviations.

ACCEPTANCE_CRITERIA:
- [ ] lib/db/client.ts exports createServerClient and createBrowserClient using @supabase/ssr
- [ ] lib/db/schema.sql contains complete schema from PROJECT_CONTEXT.md (reports, monitored_contracts, disputed_findings, rule_versions tables)
- [ ] lib/db/reports.ts exports: createReport, getReport, updateReportPaid, markReportStale, getReportsByHash
- [ ] All database functions use SUPABASE_SERVICE_ROLE_KEY for writes, ANON_KEY for reads
- [ ] TypeScript types defined for Report, MonitoredContract, DisputedFinding in lib/db/types.ts
- [ ] No contract_code column exists anywhere in schema or types

FILES_AFFECTED:
- lib/db/client.ts
- lib/db/schema.sql
- lib/db/reports.ts
- lib/db/types.ts

TEST_COMMAND:
npx tsc --noEmit

COMPLETION_SIGNAL:
TEST_COMMAND exits 0. lib/db/types.ts exports Report type with no contract_code field.

OUT_OF_SCOPE:
- No actual database connection at test time (env vars not set)
- No API routes
- No UI

---

## TASK: T003
STATUS: PENDING
TITLE: Fixture library infrastructure and CI test runner
PHASE: Foundation

DESCRIPTION:
Create the fixture directory structure and Jest test runner that validates
all rule engine rules against known-vulnerable and known-clean contract samples.
This infrastructure must exist BEFORE any rules are written.
Write placeholder fixture files for all 5 Tact rules.

ACCEPTANCE_CRITERIA:
- [ ] fixtures/tact/ directory created with subdirectory per rule: require-placement/, map-iteration/, reply-forward/, ownership-check/, arithmetic-overflow/
- [ ] Each subdirectory contains: vulnerable.tact, clean.tact, exploit-scenario.md
- [ ] vulnerable.tact files contain minimal Tact contract code that SHOULD trigger the rule
- [ ] clean.tact files contain minimal Tact contract code that should NOT trigger the rule
- [ ] __tests__/fixtures/fixture-runner.test.ts created — imports each rule, runs against its fixture pair, asserts vulnerable.tact triggers and clean.tact does not
- [ ] fixture-runner.test.ts is structured so adding a new rule+fixture pair requires only 2 lines
- [ ] All 5 fixture pairs written (vulnerable + clean) based on rule descriptions in PROJECT_CONTEXT.md
- [ ] exploit-scenario.md written for each rule (3-5 sentences describing attack)

FILES_AFFECTED:
- fixtures/tact/require-placement/vulnerable.tact
- fixtures/tact/require-placement/clean.tact
- fixtures/tact/require-placement/exploit-scenario.md
- fixtures/tact/map-iteration/vulnerable.tact
- fixtures/tact/map-iteration/clean.tact
- fixtures/tact/map-iteration/exploit-scenario.md
- fixtures/tact/reply-forward/vulnerable.tact
- fixtures/tact/reply-forward/clean.tact
- fixtures/tact/reply-forward/exploit-scenario.md
- fixtures/tact/ownership-check/vulnerable.tact
- fixtures/tact/ownership-check/clean.tact
- fixtures/tact/ownership-check/exploit-scenario.md
- fixtures/tact/arithmetic-overflow/vulnerable.tact
- fixtures/tact/arithmetic-overflow/clean.tact
- fixtures/tact/arithmetic-overflow/exploit-scenario.md
- __tests__/fixtures/fixture-runner.test.ts

TEST_COMMAND:
npx jest __tests__/fixtures/fixture-runner.test.ts --passWithNoTests

COMPLETION_SIGNAL:
TEST_COMMAND exits 0. fixtures/ directory has 5 subdirectories each with 3 files.

OUT_OF_SCOPE:
- Actual rule implementations (rules don't exist yet — fixture-runner.test.ts imports stubs)
- FunC fixtures (Phase 2 only)

---

## TASK: T004
STATUS: PENDING
TITLE: Rule engine orchestrator and shared utilities
PHASE: Rule Engine

DESCRIPTION:
Create the rule engine orchestrator that runs all rules and aggregates results.
Create shared utility functions used by all rules: extractFunctionBody, tokenizeContract, extractReceiveHandlers.
Create the scoring algorithm from PROJECT_CONTEXT.md spec.
All rules return a standardized RuleResult type.

ACCEPTANCE_CRITERIA:
- [ ] lib/rule-engine/types.ts defines: RuleResult, Finding, Severity, Confidence, RuleEngineOutput
- [ ] lib/rule-engine/utils.ts exports: extractFunctionBody(source, name), tokenizeContract(source), extractReceiveHandlers(source)
- [ ] lib/rule-engine/index.ts exports runRuleEngine(source, language) that runs all registered rules and returns RuleEngineOutput
- [ ] lib/rule-engine/index.ts imports from rules/ directory — adding a new rule requires only adding one import and one array entry
- [ ] lib/scoring.ts exports calculateScore(findings, lineCount) implementing the complexity-normalized algorithm from PROJECT_CONTEXT.md
- [ ] calculateScore uses log10(lineCount) normalization and diminishing returns on stacked same-severity findings
- [ ] calculateScore never returns > 100 or < 0
- [ ] __tests__/scoring.test.ts tests: all-clean contract = 100, single CRITICAL HIGH = ~55-65, multiple LOW findings < single CRITICAL
- [ ] No rule implementations yet — runRuleEngine runs empty rules array and returns zeroed output

FILES_AFFECTED:
- lib/rule-engine/types.ts
- lib/rule-engine/utils.ts
- lib/rule-engine/index.ts
- lib/scoring.ts
- __tests__/scoring.test.ts

TEST_COMMAND:
npx jest __tests__/scoring.test.ts

COMPLETION_SIGNAL:
TEST_COMMAND exits 0 with all scoring tests passing.

OUT_OF_SCOPE:
- Actual rule implementations
- AI integration
- API routes

---

## TASK: T005
STATUS: PENDING
TITLE: Tact Rule TACT-001 — Incorrect require() placement
PHASE: Rule Engine

DESCRIPTION:
Implement TACT-001: detects require() calls that appear AFTER state mutations
in receive() handlers. In Tact, a thrown exception after state mutation does not
revert the mutation, unlike Solidity's revert behavior.

ACCEPTANCE_CRITERIA:
- [ ] lib/rule-engine/rules/tact-001-require-placement.ts exports checkRequirePlacement(source)
- [ ] Rule returns RuleResult with ruleId: 'TACT-001', severity: 'HIGH'
- [ ] Detection logic: find all receive() handler bodies, check if any require()/throwIf()/throwUnless() appears after a state assignment (self.field =)
- [ ] Confidence: HIGH when require() is clearly after state mutation on same variable path, MEDIUM when ordering is ambiguous
- [ ] Finding includes line number hint and specific message explaining the issue
- [ ] Rule is registered in lib/rule-engine/index.ts
- [ ] __tests__/rule-engine/tact-001.test.ts passes for vulnerable.tact (triggers) and clean.tact (no trigger)
- [ ] fixture-runner.test.ts passes for this rule

FILES_AFFECTED:
- lib/rule-engine/rules/tact-001-require-placement.ts
- lib/rule-engine/index.ts
- __tests__/rule-engine/tact-001.test.ts

TEST_COMMAND:
npx jest __tests__/rule-engine/tact-001.test.ts __tests__/fixtures/fixture-runner.test.ts

COMPLETION_SIGNAL:
TEST_COMMAND exits 0. Both fixture tests pass (vulnerable triggers, clean does not).

OUT_OF_SCOPE:
- FunC rules
- AI integration
- Any rule other than TACT-001

---

## TASK: T006
STATUS: PENDING
TITLE: Tact Rule TACT-002 — Unbounded map iteration
PHASE: Rule Engine

DESCRIPTION:
Implement TACT-002: detects map iteration patterns where the map has a public
write path (allowing attacker to grow it unboundedly), creating a DoS vector
via gas exhaustion.

ACCEPTANCE_CRITERIA:
- [ ] lib/rule-engine/rules/tact-002-map-iteration.ts exports checkMapIteration(source)
- [ ] Rule returns RuleResult with ruleId: 'TACT-002', severity: 'HIGH'
- [ ] Detection logic: find map<K,V> declarations, check if a forEach or manual iteration exists over that map, check if the same map has a write path in any receive() handler without access control
- [ ] Confidence: HIGH when iteration + public write path confirmed, MEDIUM when only iteration found without confirming write path
- [ ] Rule registered in lib/rule-engine/index.ts
- [ ] __tests__/rule-engine/tact-002.test.ts passes
- [ ] fixture-runner.test.ts passes for this rule

FILES_AFFECTED:
- lib/rule-engine/rules/tact-002-map-iteration.ts
- lib/rule-engine/index.ts
- __tests__/rule-engine/tact-002.test.ts

TEST_COMMAND:
npx jest __tests__/rule-engine/tact-002.test.ts __tests__/fixtures/fixture-runner.test.ts

COMPLETION_SIGNAL:
TEST_COMMAND exits 0. Both fixture tests pass.

OUT_OF_SCOPE:
- Any rule other than TACT-002
- FunC rules

---

## TASK: T007
STATUS: PENDING
TITLE: Tact Rule TACT-003 — Improper reply() vs forward() usage
PHASE: Rule Engine

DESCRIPTION:
Implement TACT-003: detects self.forward() calls where the destination address
is derived from message body fields without validation, enabling fund drain
to attacker-controlled addresses.

ACCEPTANCE_CRITERIA:
- [ ] lib/rule-engine/rules/tact-003-reply-forward.ts exports checkReplyForward(source)
- [ ] Rule returns RuleResult with ruleId: 'TACT-003', severity: 'HIGH'
- [ ] Detection logic: find self.forward() calls, check if destination argument is a message body field (msg.field or context().sender chain) without a require()/throwUnless() validating the address immediately before the call
- [ ] Confidence: HIGH when forward() destination is directly from message body, MEDIUM when indirect
- [ ] Rule registered in lib/rule-engine/index.ts
- [ ] __tests__/rule-engine/tact-003.test.ts passes
- [ ] fixture-runner.test.ts passes for this rule

FILES_AFFECTED:
- lib/rule-engine/rules/tact-003-reply-forward.ts
- lib/rule-engine/index.ts
- __tests__/rule-engine/tact-003.test.ts

TEST_COMMAND:
npx jest __tests__/rule-engine/tact-003.test.ts __tests__/fixtures/fixture-runner.test.ts

COMPLETION_SIGNAL:
TEST_COMMAND exits 0. Both fixture tests pass.

OUT_OF_SCOPE:
- Any rule other than TACT-003

---

## TASK: T008
STATUS: PENDING
TITLE: Tact Rule TACT-004 — Missing throwUnless on ownership checks
PHASE: Rule Engine

DESCRIPTION:
Implement TACT-004: detects privileged operations (state mutations, sends)
guarded by if/return patterns instead of throwUnless/require, where a silent
return fails to revert state changes made before the check.

ACCEPTANCE_CRITERIA:
- [ ] lib/rule-engine/rules/tact-004-ownership-check.ts exports checkOwnershipCheck(source)
- [ ] Rule returns RuleResult with ruleId: 'TACT-004', severity: 'HIGH'
- [ ] Detection logic: find receive() handlers containing privileged operations (self.field = or send()), check if ownership guard uses if(sender != self.owner) { return; } pattern instead of throwUnless(sender == self.owner)
- [ ] Confidence: HIGH when if/return guard found on privileged handler, MEDIUM when pattern is ambiguous
- [ ] Rule registered in lib/rule-engine/index.ts
- [ ] __tests__/rule-engine/tact-004.test.ts passes
- [ ] fixture-runner.test.ts passes for this rule

FILES_AFFECTED:
- lib/rule-engine/rules/tact-004-ownership-check.ts
- lib/rule-engine/index.ts
- __tests__/rule-engine/tact-004.test.ts

TEST_COMMAND:
npx jest __tests__/rule-engine/tact-004.test.ts __tests__/fixtures/fixture-runner.test.ts

COMPLETION_SIGNAL:
TEST_COMMAND exits 0. Both fixture tests pass.

OUT_OF_SCOPE:
- Any rule other than TACT-004

---

## TASK: T009
STATUS: PENDING
TITLE: Tact Rule TACT-005 — Integer arithmetic overflow
PHASE: Rule Engine

DESCRIPTION:
Implement TACT-005: detects division-before-multiplication patterns in fee,
percentage, or ratio calculations that produce zero due to integer truncation
in Tact's 257-bit integer arithmetic.

ACCEPTANCE_CRITERIA:
- [ ] lib/rule-engine/rules/tact-005-arithmetic-overflow.ts exports checkArithmeticOverflow(source)
- [ ] Rule returns RuleResult with ruleId: 'TACT-005', severity: 'MEDIUM'
- [ ] Detection logic: find arithmetic expressions containing both division (/) and multiplication (*), flag any where division operator appears before multiplication operator in the expression evaluation order
- [ ] Also flag: integer literals used as percentage denominators without explicit scaling (e.g., amount / 100 * fee instead of amount * fee / 100)
- [ ] Confidence: HIGH when clear division-before-multiplication on fee/ratio variables, LOW when uncertain
- [ ] Rule registered in lib/rule-engine/index.ts
- [ ] __tests__/rule-engine/tact-005.test.ts passes
- [ ] fixture-runner.test.ts passes for this rule

FILES_AFFECTED:
- lib/rule-engine/rules/tact-005-arithmetic-overflow.ts
- lib/rule-engine/index.ts
- __tests__/rule-engine/tact-005.test.ts

TEST_COMMAND:
npx jest __tests__/rule-engine/tact-005.test.ts __tests__/fixtures/fixture-runner.test.ts

COMPLETION_SIGNAL:
TEST_COMMAND exits 0. All 5 rule tests pass. All 5 fixture pairs pass.

OUT_OF_SCOPE:
- Any rule other than TACT-005
- FunC rules

---

## TASK: T010
STATUS: PENDING
TITLE: Claude API integration and /api/scan route
PHASE: AI Integration

DESCRIPTION:
Create the Claude API analysis layer and the main scan endpoint that chains
rule engine → Claude AI → Supabase storage → return report ID.

ACCEPTANCE_CRITERIA:
- [ ] lib/ai/prompts.ts exports buildSystemPrompt(language) and buildUserPrompt(source, language, ruleSummary)
- [ ] buildSystemPrompt() includes: (1) "Think step by step before outputting findings" (2) TON async actor model context (3) per-finding reasoning requirement (4) anti-hallucination guard for low-confidence findings
- [ ] AI response JSON includes `reasoning` field at top level AND per finding
- [ ] Low confidence findings without clear reasoning are downgraded to INFO severity in the parser
- [ ] System prompt instructs Claude to respond ONLY with valid JSON matching AiAnalysisResult type
- [ ] System prompt explicitly says: do not repeat findings already in ruleSummary, focus on logic/semantic issues
- [ ] lib/ai/analyze.ts exports analyzeWithClaude(source, language, ruleFindings) using claude-sonnet-4-6
- [ ] analyzeWithClaude handles JSON parse errors gracefully — strips markdown fences, retries once, returns empty findings on second failure
- [ ] app/api/scan/route.ts exports POST handler and const maxDuration = 60
- [ ] /api/scan accepts: { contractCode: string, language: 'tact' | 'func', contractName?: string, tonAddress?: string, email?: string }
- [ ] /api/scan validates input: max 100KB contract code, language must be tact or func
- [ ] /api/scan chains: input validation → rule engine → Claude API → calculateScore → createReport (no code stored) → return { reportId }
- [ ] /api/scan returns 400 on validation errors, 500 on internal errors with structured error response
- [ ] __tests__/api/scan.test.ts mocks Claude API and Supabase, tests: valid input returns reportId, oversized input returns 400, invalid language returns 400

FILES_AFFECTED:
- lib/ai/prompts.ts
- lib/ai/analyze.ts
- app/api/scan/route.ts
- __tests__/api/scan.test.ts

TEST_COMMAND:
npx jest __tests__/api/scan.test.ts

COMPLETION_SIGNAL:
TEST_COMMAND exits 0. npx tsc --noEmit exits 0.

OUT_OF_SCOPE:
- Payment integration
- OG image generation
- Frontend UI

---

## TASK: T011
STATUS: PENDING
TITLE: OG image generation and report page
PHASE: Report

DESCRIPTION:
Create the dynamic OG image endpoint using @vercel/og Edge Runtime.
Create the public report page with SSR metadata for Telegram preview cards.

ACCEPTANCE_CRITERIA:
- [ ] app/api/og/[reportId]/route.ts uses @vercel/og ImageResponse with export const runtime = 'edge'
- [ ] OG image shows: contract name, severity counts (Critical/High/Medium as colored badges), score number prominently, "tonkit.dev" attribution
- [ ] OG image uses dark theme (#0f1117 background)
- [ ] OG image dimensions: 1200x630
- [ ] OG image fetches report data from Supabase REST API directly (not Supabase JS SDK — Edge Runtime incompatibility)
- [ ] app/report/[reportId]/page.tsx exports generateMetadata that returns og:title, og:description, og:image pointing to /api/og/[reportId]
- [ ] Report page renders: score display with "No critical patterns detected" / "X critical patterns detected", rule findings list, AI findings list, severity badges, share button
- [ ] Free tier gate: shows first 3 findings freely, remaining findings blurred with PaymentGate component placeholder
- [ ] components/ShareButton.tsx renders Telegram share link: t.me/share/url?url=REPORT_URL
- [ ] components/SeverityBadge.tsx renders colored badges for CRITICAL/HIGH/MEDIUM/LOW/INFO

FILES_AFFECTED:
- app/api/og/[reportId]/route.ts
- app/report/[reportId]/page.tsx
- app/report/[reportId]/loading.tsx
- components/ShareButton.tsx
- components/SeverityBadge.tsx
- components/PaymentGate.tsx

TEST_COMMAND:
npx tsc --noEmit

COMPLETION_SIGNAL:
TEST_COMMAND exits 0. app/api/og/[reportId]/route.ts has export const runtime = 'edge'.

OUT_OF_SCOPE:
- Actual payment processing
- PDF generation
- Monitoring features

---

## TASK: T012
STATUS: PENDING
TITLE: Landing page and scan form
PHASE: Frontend

DESCRIPTION:
Create the landing page and scan form. Dark theme throughout.
Minimal but professional. Mobile-first.

ACCEPTANCE_CRITERIA:
- [ ] app/page.tsx renders landing page with: headline, subheadline, CTA button to /scan
- [ ] Landing page copy never uses the word "audit" — uses "scan", "analysis", "vulnerability scan"
- [ ] app/scan/page.tsx renders scan form with: textarea for contract code (monospace font), radio for Tact/FunC selection, optional contract name field, optional email field, submit button
- [ ] Scan form client component handles submit: POST to /api/scan, shows loading state, on success redirects to /report/[id], on error shows error message
- [ ] Loading state shows during scan: spinner + "Scanning contract..." message
- [ ] Contract textarea has character counter showing KB remaining (max 100KB)
- [ ] Form validation: empty contract code shows error before submitting
- [ ] Dark theme: background #0f1117, text #e2e8f0, monospace font for textarea
- [ ] Responsive: works on mobile screens (375px width minimum)

FILES_AFFECTED:
- app/page.tsx
- app/scan/page.tsx
- app/scan/loading.tsx

TEST_COMMAND:
npx tsc --noEmit

COMPLETION_SIGNAL:
TEST_COMMAND exits 0. app/page.tsx and app/scan/page.tsx exist with no TypeScript errors.

OUT_OF_SCOPE:
- Payment integration
- Authentication
- User accounts

---

## TASK: T013
STATUS: PENDING
TITLE: Lemon Squeezy payment integration
PHASE: Payments

DESCRIPTION:
Implement $49 payment gate. Checkout creates a Lemon Squeezy session.
Webhook unlocks the full report on successful payment.

ACCEPTANCE_CRITERIA:
- [ ] app/api/checkout/route.ts exports POST handler that creates Lemon Squeezy checkout for $49 product
- [ ] Checkout request includes: email, custom data with report_id
- [ ] Checkout response returns: { checkoutUrl: string }
- [ ] app/api/webhooks/lemonsqueezy/route.ts exports POST handler
- [ ] Webhook verifies HMAC-SHA256 signature using LS_WEBHOOK_SECRET before processing
- [ ] Webhook handles order_created event: reads report_id from custom_data, calls updateReportPaid(reportId, orderId)
- [ ] Webhook returns 401 on invalid signature, 200 on success
- [ ] components/PaymentGate.tsx renders: blurred findings overlay, "Unlock Full Report — $49" button, button calls /api/checkout and redirects to checkoutUrl
- [ ] PaymentGate shows loading state while checkout session creates
- [ ] Report page (/report/[reportId]) checks is_paid, shows full findings if true, PaymentGate if false

FILES_AFFECTED:
- app/api/checkout/route.ts
- app/api/webhooks/lemonsqueezy/route.ts
- components/PaymentGate.tsx
- app/report/[reportId]/page.tsx

TEST_COMMAND:
npx tsc --noEmit

COMPLETION_SIGNAL:
TEST_COMMAND exits 0. Webhook route validates signature before any processing.

OUT_OF_SCOPE:
- TON crypto payments (handled in T013b — separate task)
- Subscription/monitoring payments
- Refund handling

---

---

## TASK: T013b
STATUS: PENDING
TITLE: USDT-TON crypto payment integration
PHASE: Payments

DESCRIPTION:
Implement USDT-TON Jetton transfer payment detection as Day 1 feature.
India payment complexity makes crypto mandatory from launch — not optional.
TON developers are crypto-native. USDT-TON = instant settlement, no SWIFT/bank delays.
Payout flow: USDT-TON → TON wallet → WazirX/CoinDCX → INR same day.

ACCEPTANCE_CRITERIA:
- [ ] app/api/crypto-checkout/route.ts exports POST handler that generates unique TON payment address per report
- [ ] Payment address derived via HD wallet path from MASTER_TON_SEED + reportId (deterministic, no storage needed)
- [ ] Returns: { tonAddress: string, usdtAmount: number, expiresAt: string }
- [ ] USDT amount calculated from $49 USD at current rate via TON API price feed
- [ ] app/api/webhooks/ton-payment/route.ts polls TONapi for USDT-TON Jetton transfers to payment address
- [ ] Webhook detects incoming USDT transfer matching expected amount (±2% tolerance for rate fluctuation)
- [ ] On confirmed payment: calls updateReportPaid(reportId, txHash)
- [ ] Polling cron: Vercel cron job checks pending crypto payments every 5 minutes
- [ ] Report page shows two payment options: "Pay $49 by Card" and "Pay with USDT-TON"
- [ ] USDT-TON option shows QR code + TON address + amount + expiry timer (30 min)
- [ ] components/CryptoPaymentGate.tsx renders QR code using qrcode library
- [ ] Expired payments (>30 min, no payment received) show "Payment expired — generate new address" button
- [ ] .env.example updated with MASTER_TON_SEED and TONAPI_KEY

FILES_AFFECTED:
- app/api/crypto-checkout/route.ts
- app/api/webhooks/ton-payment/route.ts
- components/CryptoPaymentGate.tsx
- app/report/[reportId]/page.tsx
- .env.example
- vercel.json

TEST_COMMAND:
npx tsc --noEmit

COMPLETION_SIGNAL:
TEST_COMMAND exits 0. app/api/crypto-checkout/route.ts exists and returns tonAddress + usdtAmount.

OUT_OF_SCOPE:
- TON (native) payments — USDT-TON only (stablecoin, no price volatility)
- Other crypto (ETH, BTC, SOL)
- Subscription crypto payments


## TASK: T014
STATUS: PENDING
TITLE: Rate limiting, health endpoint, and dispute mechanism
PHASE: Polish

DESCRIPTION:
Add rate limiting to /api/scan using Vercel KV.
Add /api/health endpoint for deployment verification.
Add dispute finding mechanism (flag button on report page).

ACCEPTANCE_CRITERIA:
- [ ] app/api/scan/route.ts checks rate limit: max 3 free scans per IP per 24 hours using @vercel/kv
- [ ] Rate limit check uses x-forwarded-for header, falls back to 'unknown'
- [ ] Returns 429 with { error: 'Rate limit exceeded. Try again tomorrow.' } when exceeded
- [ ] app/api/health/route.ts exports GET handler returning { status: 'ok', version: process.env.VERCEL_GIT_COMMIT_SHA ?? 'local', timestamp: new Date().toISOString() }
- [ ] app/api/dispute/route.ts exports POST handler accepting { reportId, ruleId, comment }
- [ ] Dispute handler inserts into disputed_findings table, returns { received: true }
- [ ] components/FindingItem.tsx renders individual finding with: severity badge, title, description, recommendation, confidence indicator, "Flag as incorrect" button
- [ ] Flag button calls /api/dispute, shows "Flagged for review" confirmation after click
- [ ] __tests__/api/health.test.ts verifies health endpoint returns 200 with status ok

FILES_AFFECTED:
- app/api/scan/route.ts
- app/api/health/route.ts
- app/api/dispute/route.ts
- components/FindingItem.tsx
- __tests__/api/health.test.ts

TEST_COMMAND:
npx jest __tests__/api/health.test.ts && npx tsc --noEmit

COMPLETION_SIGNAL:
TEST_COMMAND exits 0. app/api/health/route.ts exists and returns correct shape.

OUT_OF_SCOPE:
- Admin panel for reviewing disputes
- Email notifications for disputes
- User authentication

---

## TASK: T015
STATUS: PENDING
TITLE: SEO vulnerability reference pages
PHASE: SEO

DESCRIPTION:
Create 5 static vulnerability reference pages, one per Tact rule.
These pages target "Tact [vulnerability name]" search queries.
Each page: what the vulnerability is, vulnerable code example, fixed code example, CTA.

ACCEPTANCE_CRITERIA:
- [ ] app/vulnerabilities/tact-require-placement/page.tsx exists
- [ ] app/vulnerabilities/tact-map-iteration/page.tsx exists
- [ ] app/vulnerabilities/tact-reply-forward/page.tsx exists
- [ ] app/vulnerabilities/tact-ownership-check/page.tsx exists
- [ ] app/vulnerabilities/tact-arithmetic-overflow/page.tsx exists
- [ ] Each page exports generateMetadata with descriptive og:title and og:description
- [ ] Each page contains: H1 title, vulnerability description (3-4 sentences), vulnerable code block (real Tact code from fixture), fixed code block, "Scan your contract" CTA linking to /scan
- [ ] app/vulnerabilities/page.tsx lists all vulnerabilities with links
- [ ] Code blocks use monospace font on dark background

FILES_AFFECTED:
- app/vulnerabilities/page.tsx
- app/vulnerabilities/tact-require-placement/page.tsx
- app/vulnerabilities/tact-map-iteration/page.tsx
- app/vulnerabilities/tact-reply-forward/page.tsx
- app/vulnerabilities/tact-ownership-check/page.tsx
- app/vulnerabilities/tact-arithmetic-overflow/page.tsx

TEST_COMMAND:
npx tsc --noEmit

COMPLETION_SIGNAL:
TEST_COMMAND exits 0. All 5 vulnerability pages exist with generateMetadata exports.

OUT_OF_SCOPE:
- FunC vulnerability pages (add when FunC rules built)
- Blog posts
- Dynamic content

---

## TASK: T016
STATUS: PENDING
TITLE: FunC Rule FUNC-001 — Bounce message handling
PHASE: FunC Rules

DESCRIPTION:
Implement FUNC-001 for FunC contracts. Detects recv_internal implementations
that read op-code without first checking the bounce flag bit.

ACCEPTANCE_CRITERIA:
- [ ] fixtures/func/ directory created with same structure as fixtures/tact/
- [ ] fixtures/func/bounce-handling/vulnerable.fc — recv_internal reads load_uint(32) without bounce check
- [ ] fixtures/func/bounce-handling/clean.fc — recv_internal correctly checks load_uint(4) and flags & 1 before op dispatch
- [ ] fixtures/func/bounce-handling/exploit-scenario.md written
- [ ] lib/rule-engine/rules/func-001-bounce-handling.ts exports checkBounceHandling(source)
- [ ] Rule implements extractFunctionBody logic for FunC syntax (different from Tact)
- [ ] Rule registered in lib/rule-engine/index.ts (only runs when language === 'func')
- [ ] __tests__/rule-engine/func-001.test.ts passes for both fixture contracts
- [ ] fixture-runner.test.ts updated to include FunC fixtures

FILES_AFFECTED:
- fixtures/func/bounce-handling/vulnerable.fc
- fixtures/func/bounce-handling/clean.fc
- fixtures/func/bounce-handling/exploit-scenario.md
- lib/rule-engine/rules/func-001-bounce-handling.ts
- lib/rule-engine/index.ts
- __tests__/rule-engine/func-001.test.ts
- __tests__/fixtures/fixture-runner.test.ts

TEST_COMMAND:
npx jest __tests__/rule-engine/func-001.test.ts __tests__/fixtures/fixture-runner.test.ts

COMPLETION_SIGNAL:
TEST_COMMAND exits 0. FunC fixture pair passes.

OUT_OF_SCOPE:
- FUNC-002 through FUNC-005 (separate tasks)

---

## TASK: T017
STATUS: PENDING
TITLE: FunC Rules FUNC-002 through FUNC-005
PHASE: FunC Rules

DESCRIPTION:
Implement remaining 4 FunC rules with fixtures and tests.

ACCEPTANCE_CRITERIA:
- [ ] FUNC-002: checkOpCodeValidation — recv_internal with no op-code dispatch pattern
- [ ] FUNC-003: checkGasDrain — send_raw_message in loop without RESERVE_AT_MOST
- [ ] FUNC-004: checkIntegerOverflow — load_uint(n where n<64) arithmetic without range validation
- [ ] FUNC-005: checkAdminValidation — privileged operations without sender validation against stored address (CRITICAL severity)
- [ ] All 4 rules have fixture pairs (vulnerable.fc + clean.fc + exploit-scenario.md)
- [ ] All 4 rules have passing __tests__/rule-engine/ tests
- [ ] All 4 rules registered in lib/rule-engine/index.ts with language === 'func' guard
- [ ] fixture-runner.test.ts includes all 4 new FunC fixture pairs
- [ ] Full test suite (all rules, all fixtures) passes

FILES_AFFECTED:
- fixtures/func/opcode-validation/vulnerable.fc
- fixtures/func/opcode-validation/clean.fc
- fixtures/func/opcode-validation/exploit-scenario.md
- fixtures/func/gas-drain/vulnerable.fc
- fixtures/func/gas-drain/clean.fc
- fixtures/func/gas-drain/exploit-scenario.md
- fixtures/func/integer-overflow/vulnerable.fc
- fixtures/func/integer-overflow/clean.fc
- fixtures/func/integer-overflow/exploit-scenario.md
- fixtures/func/admin-validation/vulnerable.fc
- fixtures/func/admin-validation/clean.fc
- fixtures/func/admin-validation/exploit-scenario.md
- lib/rule-engine/rules/func-002-opcode-validation.ts
- lib/rule-engine/rules/func-003-gas-drain.ts
- lib/rule-engine/rules/func-004-integer-overflow.ts
- lib/rule-engine/rules/func-005-admin-validation.ts
- lib/rule-engine/index.ts
- __tests__/rule-engine/func-002.test.ts
- __tests__/rule-engine/func-003.test.ts
- __tests__/rule-engine/func-004.test.ts
- __tests__/rule-engine/func-005.test.ts
- __tests__/fixtures/fixture-runner.test.ts

TEST_COMMAND:
npx jest --testPathPattern="rule-engine|fixture-runner"

COMPLETION_SIGNAL:
TEST_COMMAND exits 0. All 9 rules (5 Tact + 4 FunC) pass all fixture tests.

OUT_OF_SCOPE:
- Monitoring tier
- B2B API
- New vulnerability pages for FunC rules (add after this task)
