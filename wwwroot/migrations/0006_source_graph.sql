-- 0006_source_graph.sql
-- Phase 3, PR 3.1: self-expanding source graph.
--   sources        — every ingest source as a node (feed, career scan, discovery domain, ATS token)
--   source_edges   — provenance: which source produced which company/job/source
--   source_metrics — per-source yield tracking that drives expansion + scheduling

CREATE TABLE IF NOT EXISTS sources (
    id                INTEGER PRIMARY KEY AUTOINCREMENT,
    source_key        TEXT    NOT NULL UNIQUE,
    source_type       TEXT    NOT NULL,
    label             TEXT,
    status            TEXT    NOT NULL DEFAULT 'active',
    origin_source_key TEXT,
    created_at        TEXT    NOT NULL DEFAULT (datetime('now')),
    updated_at        TEXT    NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_sources_status ON sources(status);
CREATE INDEX IF NOT EXISTS idx_sources_type   ON sources(source_type);

CREATE TABLE IF NOT EXISTS source_edges (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    from_source_key TEXT    NOT NULL,
    relation        TEXT    NOT NULL,
    target_ref      TEXT    NOT NULL,
    weight          REAL    NOT NULL DEFAULT 1.0,
    created_at      TEXT    NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_source_edges_from ON source_edges(from_source_key);
CREATE UNIQUE INDEX IF NOT EXISTS idx_source_edges_unique
    ON source_edges(from_source_key, relation, target_ref);

CREATE TABLE IF NOT EXISTS source_metrics (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    source_key      TEXT    NOT NULL UNIQUE,
    runs            INTEGER NOT NULL DEFAULT 0,
    items_found     INTEGER NOT NULL DEFAULT 0,
    companies_found INTEGER NOT NULL DEFAULT 0,
    jobs_found      INTEGER NOT NULL DEFAULT 0,
    errors          INTEGER NOT NULL DEFAULT 0,
    yield_score     REAL    NOT NULL DEFAULT 0,
    last_run_at     TEXT,
    updated_at      TEXT    NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_source_metrics_yield ON source_metrics(yield_score);
