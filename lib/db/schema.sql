-- TonKit Scanner — Supabase Schema
-- Run this in Supabase SQL Editor (Dashboard → SQL Editor → New Query)
-- Run once on project creation

-- ─────────────────────────────────────────────────────────────
-- Reports table
-- Stores scan results. Contract source code is NEVER stored here.
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  contract_hash text NOT NULL,           -- sha256(source_code) for deduplication
  contract_name text,                     -- optional, provided by developer
  language text NOT NULL DEFAULT 'tact'   -- 'tact' or 'func'
    CHECK (language IN ('tact', 'func')),
  ton_address text,                       -- optional deployed contract address
  rule_findings jsonb NOT NULL DEFAULT '[]',
  ai_findings jsonb NOT NULL DEFAULT '[]',
  score integer NOT NULL DEFAULT 0
    CHECK (score >= 0 AND score <= 100),
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

-- Index for deduplication lookup
CREATE INDEX IF NOT EXISTS idx_reports_contract_hash ON reports(contract_hash);

-- Index for ton_address registry lookups
CREATE INDEX IF NOT EXISTS idx_reports_ton_address ON reports(ton_address)
  WHERE ton_address IS NOT NULL;

-- Index for staleness updates (find reports with old rule engine versions)
CREATE INDEX IF NOT EXISTS idx_reports_rule_engine_version ON reports(rule_engine_version);

-- ─────────────────────────────────────────────────────────────
-- Monitored contracts table
-- For the $79/month monitoring tier (Month 4+)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS monitored_contracts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text NOT NULL,
  ton_address text NOT NULL,
  baseline_code_hash text,
  baseline_report_id uuid REFERENCES reports(id) ON DELETE SET NULL,
  last_checked_at timestamptz,
  alert_email text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_monitored_active ON monitored_contracts(is_active, last_checked_at)
  WHERE is_active = true;

-- ─────────────────────────────────────────────────────────────
-- Disputed findings table
-- Developers flag false positives — reviewed manually
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS disputed_findings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  report_id uuid REFERENCES reports(id) ON DELETE CASCADE NOT NULL,
  rule_id text NOT NULL,
  developer_comment text,
  reviewed boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- ─────────────────────────────────────────────────────────────
-- Rule versions table
-- Tracks rule engine changelog for staleness detection
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS rule_versions (
  version text PRIMARY KEY,
  released_at timestamptz NOT NULL DEFAULT now(),
  changes jsonb NOT NULL DEFAULT '{}'
    -- shape: { "added": ["TACT-001"], "modified": [], "deprecated": [] }
);

-- Seed initial version
INSERT INTO rule_versions (version, changes)
VALUES (
  '1.0.0',
  '{"added": ["TACT-001", "TACT-002", "TACT-003", "TACT-004", "TACT-005"], "modified": [], "deprecated": []}'
)
ON CONFLICT (version) DO NOTHING;

-- ─────────────────────────────────────────────────────────────
-- Row Level Security
-- Anon key can only read paid/public reports
-- Service role key has full access (used for writes)
-- ─────────────────────────────────────────────────────────────
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE monitored_contracts ENABLE ROW LEVEL SECURITY;
ALTER TABLE disputed_findings ENABLE ROW LEVEL SECURITY;
ALTER TABLE rule_versions ENABLE ROW LEVEL SECURITY;

-- Reports: anon can read any report by ID (public share links)
CREATE POLICY "Public reports are readable by anyone"
  ON reports FOR SELECT
  TO anon
  USING (true);

-- Reports: only service role can insert/update
CREATE POLICY "Service role can write reports"
  ON reports FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- Rule versions: anyone can read
CREATE POLICY "Rule versions readable by anyone"
  ON rule_versions FOR SELECT
  TO anon
  USING (true);

-- Monitored contracts: only service role
CREATE POLICY "Service role manages monitored contracts"
  ON monitored_contracts FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- Disputed findings: anon can insert (flagging), service role manages
CREATE POLICY "Anyone can flag a finding"
  ON disputed_findings FOR INSERT
  TO anon
  WITH CHECK (true);

CREATE POLICY "Service role manages disputes"
  ON disputed_findings FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);
