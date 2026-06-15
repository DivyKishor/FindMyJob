-- 0002_job_lifecycle_columns.sql
-- Job lifecycle + work-type columns (previously applied ad-hoc in
-- DatabaseService.ensureMigrations). The runner tolerates "duplicate column"
-- errors so this is safe on databases where these columns already exist.

ALTER TABLE jobs ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1;
ALTER TABLE jobs ADD COLUMN last_checked_at TEXT;
ALTER TABLE jobs ADD COLUMN work_type TEXT NOT NULL DEFAULT 'unknown';
ALTER TABLE jobs ADD COLUMN first_seen_at TEXT;
UPDATE jobs SET first_seen_at = fetched_at WHERE first_seen_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_jobs_active ON jobs(is_active);
CREATE INDEX IF NOT EXISTS idx_jobs_work_type ON jobs(work_type);
CREATE INDEX IF NOT EXISTS idx_jobs_first_seen ON jobs(first_seen_at);
