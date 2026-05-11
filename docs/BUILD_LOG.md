# Build log

## 2026-03-27 - Phase 1 backend scaffold

- Created modular CFML backend services for company ingest, job storage, ATS parsing, and orchestration.
- Added SQLite schema (`companies`, `jobs`) and placeholder tables (`job_scores`, `alerts`).
- Added API endpoints for companies/jobs/alerts and task endpoints for seed + daily scrape.
- Added seed dataset using public Greenhouse board tokens.
- Added runtime docs and quick-start docs.

## 2026-03-27 - Runtime alignment to Adobe ColdFusion 2025

- Converted project guidance to CF2025-only (removed Lucee/CommandBox references).
- Removed `server.json` and `box.json` to avoid runtime ambiguity.
- Updated `README.md`, `docs/ENVIRONMENT.md`, `docs/PROJECT.md`, and `wwwroot/index.cfm`.
- Standardized task output serialization for compatibility (`serializeJSON(summary)`).

## 2026-03-27 - Tag syntax standard + Phase 2 pipeline

- Converted all runtime files to ColdFusion tag syntax (removed `cfscript` blocks and script-style components).
- Added rule-based scoring service (`ScoringService`) and score persistence (`JobScoreService`).
- Added deduplicated alert generation/listing service (`AlertService`).
- Added daily pipeline orchestration (`PipelineService`) and wired it in `Application.cfc`.
- Updated task endpoints so `runDailyScrape.cfm` now runs scrape -> score -> alerts.

## 2026-03-27 - ColdFusion-only dashboard (no React)

- Replaced simple landing page with a server-rendered Bootstrap dashboard in `wwwroot/index.cfm`.
- Added filterable job view (`keyword`, `min_score`, `company_id`) and alert limit control.
- Added summary cards and table views for companies, jobs, and alerts.
- Updated docs to remove React UI direction and keep UI roadmap in ColdFusion.

## 2026-03-27 - Pagination, sorting, and run status panel

- Added paged/sortable job listing via `JobService.listPaged()`.
- Added paged/sortable alert listing via `AlertService.listAlertsPaged()`.
- Added persistent pipeline run tracking table `pipeline_runs`.
- Added `RunStatusService` and wired pipeline success/failure recording.
- Added compact last-run status panel to `wwwroot/index.cfm`.

## 2026-03-27 - CF2025 runtime hardening and production startup fixes

- Fixed `/JobFinder` deployment path behavior by using absolute app-root paths in `Application.cfc`.
- Added explicit app reinit support using `?reinit=1` in `onRequestStart`.
- Replaced fragile schema splitting with ordered explicit DDL execution in `DatabaseService.ensureSchema()`.
- Fixed Adobe CF compatibility issues (`directoryCreate` signature and `cfheader` unsupported `statusText` attribute).
- Resolved scrape runtime bug from URL scope collision in `ScrapeOrchestrator`.

## 2026-03-27 - Additional job-source adapters

- Added feed-source auto-seeding (`remotive_feed`, `arbeitnow_feed`) in `CompanyService.ensureFeedSources()`.
- Added external company upsert helper (`getOrCreateExternalCompany`) to map feed jobs to company rows.
- Extended `ScrapeOrchestrator` with `ingestRemotive()`, `ingestArbeitnow()`, and optional `ingestAdzuna()`.
- Fixed dashboard literal rendering by wrapping page output in `<cfoutput>`.

## 2026-03-27 - ColdFusion-focused company scans + quota-safe scheduling

- Added your requested company list into `config/seed_companies.json` using `career_page_scan` sources.
- Added `SourceQuotaService` with DB-backed run tracking (`source_run_log`) to enforce `max_runs_per_day` and `min_interval_minutes`.
- Added scan-budget cap per run for `career_page_scan` to avoid long-running request timeouts.
- Added careers-page keyword signal scan focused on ColdFusion/related terms (`coldfusion`, `cfml`, `lucee`, modernization/migration signals).
- Increased task timeout for `tasks/runDailyScrape.cfm` and excluded `external_feed` companies from orchestrator source loops.

## 2026-03-27 - Discovery engine V1 (stack, jobs, careers, community, ecosystem)

- Added `DiscoveryService` to collect discovery signals using query presets for:
  - stack-tech detection (`BuiltWith`, `Wappalyzer`, `CFML websites` keywords),
  - job-based discovery (`ColdFusion developer jobs`, hiring queries),
  - career keyword discovery (`ColdFusion careers`),
  - community/forum discovery (reddit/stackoverflow intent),
  - ecosystem discovery (`Mura`, `ColdBox`, `Lucee`).
- Added `discovery_signals` table + indexes for storing raw discovery evidence and confidence score.
- Wired discovery into the daily pipeline before scraping (`PipelineService`) so newly found domains are converted into `career_page_scan` company targets automatically.
- Added `tasks/runDiscovery.cfm` for discovery-only runs and dashboard button in `index.cfm`.
- Added discovery relevance and domain-noise filters so auto-upsert focuses on ColdFusion/CFML/Lucee/ColdBox/Mura signals and avoids high-noise community/news domains.
