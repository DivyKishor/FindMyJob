-- 0003_company_ats_provider.sql
-- Structured ATS provenance for companies, populated by AtsDetector.
-- Nullable + idempotent index so this is safe on existing rows.

ALTER TABLE companies ADD COLUMN ats_provider TEXT;
ALTER TABLE companies ADD COLUMN ats_external_id TEXT;
CREATE INDEX IF NOT EXISTS idx_companies_ats_provider ON companies(ats_provider);
