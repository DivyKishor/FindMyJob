-- 0001_baseline.sql
-- Baseline schema for the ColdFusion Intelligence Engine.
-- Mirrors the pre-migration-runner state. All statements are idempotent
-- (CREATE ... IF NOT EXISTS) so this is safe to apply to an existing database.

CREATE TABLE IF NOT EXISTS companies (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  website TEXT,
  careers_url TEXT NOT NULL,
  careers_source TEXT NOT NULL DEFAULT 'html',
  ats_config TEXT,
  cf_likelihood_score INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_companies_source ON companies(careers_source);

CREATE TABLE IF NOT EXISTS jobs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  company_id INTEGER NOT NULL,
  external_id TEXT NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  location TEXT,
  link TEXT NOT NULL,
  raw_source TEXT NOT NULL,
  fetched_at TEXT NOT NULL DEFAULT (datetime('now')),
  FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE CASCADE,
  UNIQUE (company_id, external_id)
);

CREATE INDEX IF NOT EXISTS idx_jobs_company ON jobs(company_id);
CREATE INDEX IF NOT EXISTS idx_jobs_fetched ON jobs(fetched_at);

CREATE TABLE IF NOT EXISTS job_scores (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  job_id INTEGER NOT NULL,
  rule_version TEXT NOT NULL,
  score INTEGER NOT NULL,
  reasons_json TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  FOREIGN KEY (job_id) REFERENCES jobs(id) ON DELETE CASCADE,
  UNIQUE (job_id, rule_version)
);

CREATE INDEX IF NOT EXISTS idx_job_scores_job ON job_scores(job_id);

CREATE TABLE IF NOT EXISTS alerts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  job_id INTEGER NOT NULL,
  channel TEXT NOT NULL,
  payload_json TEXT,
  sent_at TEXT NOT NULL DEFAULT (datetime('now')),
  dedupe_key TEXT NOT NULL UNIQUE,
  FOREIGN KEY (job_id) REFERENCES jobs(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_alerts_sent ON alerts(sent_at);

CREATE TABLE IF NOT EXISTS pipeline_runs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  run_at TEXT NOT NULL DEFAULT (datetime('now')),
  status TEXT NOT NULL,
  jobs_upserted INTEGER NOT NULL DEFAULT 0,
  jobs_scored INTEGER NOT NULL DEFAULT 0,
  alerts_created INTEGER NOT NULL DEFAULT 0,
  error_count INTEGER NOT NULL DEFAULT 0,
  summary_json TEXT,
  errors_json TEXT
);

CREATE INDEX IF NOT EXISTS idx_pipeline_runs_run_at ON pipeline_runs(run_at);

CREATE TABLE IF NOT EXISTS source_run_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  source_key TEXT NOT NULL,
  run_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_source_run_log_key_time ON source_run_log(source_key, run_at);

CREATE TABLE IF NOT EXISTS discovery_signals (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  signal_type TEXT NOT NULL,
  source_name TEXT NOT NULL,
  query_text TEXT NOT NULL,
  company_name TEXT,
  company_domain TEXT,
  target_url TEXT,
  evidence_text TEXT,
  confidence_score INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_discovery_signals_domain ON discovery_signals(company_domain);
CREATE INDEX IF NOT EXISTS idx_discovery_signals_time ON discovery_signals(created_at);
