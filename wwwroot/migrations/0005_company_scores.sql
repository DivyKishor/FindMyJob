-- 0005_company_scores.sql
-- Phase 2, PR 2.2: versioned company-level CF likelihood scores.
-- Mirrors the job_scores pattern so score history survives rule-version bumps.
-- Also adds a cf_likelihood_score index to companies for dashboard sorting.

CREATE TABLE IF NOT EXISTS company_scores (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    company_id   INTEGER NOT NULL REFERENCES companies(id),
    rule_version TEXT    NOT NULL,
    score        INTEGER NOT NULL DEFAULT 0,
    reasons_json TEXT,
    created_at   TEXT    NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_company_scores_company_version
    ON company_scores(company_id, rule_version, created_at);

CREATE INDEX IF NOT EXISTS idx_companies_cf_likelihood
    ON companies(cf_likelihood_score);
