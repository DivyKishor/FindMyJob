# Build log

## 2026-06-15 - Phase 2: fingerprinting · company scoring · layered job scoring · alert channels

### PR 2.1 — Technology Fingerprinter (`TechFingerprinter.cfc`)
- New `wwwroot/services/TechFingerprinter.cfc`: fetches a company domain with HEAD + selective GET and evaluates 8 HTTP-level signals for ColdFusion-ecosystem presence (powered_by, lucee_header, cf_cookie, cfm_url, coldbox_marker, mura_marker, box_json, commandbox). Returns a 0–100 score proportional to total signal weight.
- `evaluateSignals()` is a pure function (no HTTP), enabling unit tests with fixture data.
- New migration `wwwroot/migrations/0004_tech_fingerprints.sql`: `tech_fingerprints` table (company_id, signal, evidence, weight, observed_at) with a UNIQUE index on (company_id, signal) so re-scans upsert in place.
- New task `wwwroot/tasks/fingerprintCompanies.cfm`: batch or single-company fingerprint run.
- New test `tests/specs/TechFingerprinterTest.cfc` (10 cases, no HTTP).

### PR 2.2 — Company Scoring (`CompanyScoreService.cfc`)
- New `wwwroot/services/CompanyScoreService.cfc`: combines fingerprint evidence (0–50), discovery signals (0–30), and job history (0–20) into `companies.cf_likelihood_score` (now meaningful).
- `scoreCompanyData()` is a pure function for testability. `scoreAllCompanies()` iterates every company.
- Versioned score rows in `company_scores` table (rule version `v1_company_cf_likelihood`).
- New migration `wwwroot/migrations/0005_company_scores.sql`: `company_scores` table + index on `companies.cf_likelihood_score` for dashboard sorting.
- New task `wwwroot/tasks/scoreCompanies.cfm`: full company score backfill.
- New test `tests/specs/CompanyScoreServiceTest.cfc` (8 cases).

### PR 2.3 — Layered Job Scoring (`ScoringService` v5_layered)
- Bumped rule version from `v4_cf_ecosystem` to `v5_layered`.
- `scoreJob()` now explicitly composes four layers: `cf_match` (50 pts required gate), `geo_eligibility` (+50/+30/0/-30, replaces indiaEligibility logic), `remote_fit` (+10 bonus for any explicit remote signal), `visa_sponsorship` (+15 bonus when employer explicitly offers visa sponsorship).
- Return struct gains `geoEligibility`, `remoteFit`, `visaSponsorship` keys; retains `indiaEligible` alias for backward compat.
- New `classifyGeoEligibility()` (canonical), `classifyRemoteFit()`, `classifyVisaSponsorship()` public methods.
- `classifyIndiaEligibility()` kept as a deprecated public alias delegating to `classifyGeoEligibility()`.
- New test `tests/specs/ScoringServiceV5Test.cfc` (17 cases); existing `ScoringServiceTest.cfc` updated for v5 rule version and adjusted score expectations.
- **Re-score required after deploy**: v4 scores remain valid for the alert join but new jobs get v5 scores; run `/tasks/scoreJobs.cfm` to backfill.

### PR 2.4 — Alert Channel Seam
- New `wwwroot/services/AlertChannel.cfc`: base class / interface with `send(alertPayload)` → `{sent, error}` and `isEnabled()`/`getChannelName()` contract.
- New `wwwroot/services/LogChannel.cfc` (extends AlertChannel): current write-to-`alerts`-table behaviour as a first-class channel. Dedupe key format unchanged so existing alert rows are not duplicated.
- `AlertService.init()` now accepts an optional `channels` array (defaults to `[LogChannel]` for backward compat). `addChannel()` registers channels at runtime.
- `generateAlerts()` dispatches to each enabled channel; returns `channelResults` array alongside `alertsCreated`.
- `Application.cfc` updated: `TechFingerprinter`, `CompanyScoreService` wired; `AlertService` re-inited with explicit `LogChannel`.
- New test `tests/specs/AlertChannelTest.cfc` (6 cases covering base, LogChannel, and dispatch).

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
