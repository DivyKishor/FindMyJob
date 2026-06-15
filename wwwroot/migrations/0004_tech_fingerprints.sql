-- 0004_tech_fingerprints.sql
-- Phase 2, PR 2.1: HTTP technology fingerprint signals per company.
-- One row per (company_id, signal); upsert replaces on re-scan so scores stay current.

CREATE TABLE IF NOT EXISTS tech_fingerprints (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    company_id  INTEGER NOT NULL REFERENCES companies(id),
    signal      TEXT    NOT NULL,
    evidence    TEXT,
    weight      REAL    NOT NULL DEFAULT 1.0,
    observed_at TEXT    NOT NULL DEFAULT (datetime('now'))
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_tech_fingerprints_company_signal
    ON tech_fingerprints(company_id, signal);

CREATE INDEX IF NOT EXISTS idx_tech_fingerprints_company
    ON tech_fingerprints(company_id);
