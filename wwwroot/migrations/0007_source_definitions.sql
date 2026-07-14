-- 0007_source_definitions.sql
-- Phase 3, PR 3.3: config-driven source onboarding.
-- A new ATS/board/career-scan is onboarded by inserting a row here (no code edit);
-- SourceRegistryService syncs enabled definitions into the companies the pipeline scans.

CREATE TABLE IF NOT EXISTS source_definitions (
    id                   INTEGER PRIMARY KEY AUTOINCREMENT,
    source_key           TEXT    NOT NULL UNIQUE,
    adapter_kind         TEXT    NOT NULL,
    label                TEXT,
    url_template         TEXT,
    parser_kind          TEXT,
    max_runs_per_day     INTEGER NOT NULL DEFAULT 1,
    min_interval_minutes INTEGER NOT NULL DEFAULT 1440,
    enabled              INTEGER NOT NULL DEFAULT 1,
    config_json          TEXT,
    created_at           TEXT    NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_source_definitions_enabled ON source_definitions(enabled);
