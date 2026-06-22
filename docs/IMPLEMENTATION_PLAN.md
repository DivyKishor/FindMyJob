# Autonomous Discovery System — Phased Implementation Plan

**Repo:** https://github.com/DivyKishor/FindMyJob
**Author:** Senior Staff Engineer review
**Date:** 2026-06-15
**Status:** Awaiting approval for Phase 1

---

## 1. Goal restatement

**Primary goal.** Turn the existing job aggregator into an *autonomous discovery system* that continuously finds jobs across the full ColdFusion ecosystem — not just `coldfusion` / `cfml` / `lucee` / `mura`, but also **ColdBox, FuseBox, CommandBox, WireBox**.

**Secondary goal.** Identify *companies* that use these technologies even when they have no open jobs right now, so we have a warm pipeline the moment a role appears.

**Operating principle for this plan.** The current system works. We do **not** rewrite working components. Every change is incremental, lands behind a phase-scoped PR, ships with tests + a migration script + deploy notes, and waits for your approval before the next phase starts.

---

## 2. Current architecture (as built)

A single Adobe ColdFusion 2025 app (tag syntax only; runs on Lucee 6 for local dev), SQLite via JDBC, services wired as application-scoped singletons in `Application.cfc`.

**Daily pipeline** (`PipelineService.runDaily`):
`CF Global Watcher → Discovery → scrape runAll → score → alerts`

**Data model** (`wwwroot/sql/schema.sql` + `DatabaseService.ensureMigrations`):
`companies`, `jobs`, `job_scores`, `alerts`, `pipeline_runs`, `source_run_log`, `discovery_signals`.

**Ingestion** (~25 adapters, all inside `ScrapeOrchestrator.cfc`): Greenhouse, Remotive, ArbeitNow, RemoteOK, Jobicy, We Work Remotely RSS, Adzuna, Jooble, GetCFMLJobs, USAJOBS, Reddit, Google CSE, CF Global Watcher (Bing RSS + Brave fallback), DevJobsScanner, plus India board HTML scans (LinkedIn public, Cutshort, Foundit, Shine, Weekday, Indeed, Instahyre, Expertini) and `career_page_scan`.

**Cross-cutting services:** `HttpClientService` (retry/backoff), `SourceQuotaService` (DB-backed rate limits), `LoggerService`, `RunStatusService`, `ScoringService`, `JobScoreService`, `AlertService`, `DiscoveryService`, `ExpiryCheckerService`.

**Frontend:** server-rendered CF/OBSERVER dashboard (`index.cfm`, `discovery-signals.cfm`) + JSON APIs (`api/jobs.cfm`, `companies.cfm`, `alerts.cfm`). A React prototype exists under `prototype/` (not wired).

---

## 3. Technical debt register

Ranked by how much it blocks the autonomous-discovery goal. File references are to the current tree.

| # | Debt | Where | Impact | Phase it's paid down |
|---|------|-------|--------|----------------------|
| D1 | **God object.** `ScrapeOrchestrator.cfc` is **2,826 lines / 75 functions** — every source adapter, HTML parser, URL util, config helper, and health counter in one file. | `services/ScrapeOrchestrator.cfc` | Unmergeable, untestable, high regression risk for any new source. | Phase 1 (carve out seams), continued P2–P3 |
| D2 | **No tests anywhere.** Zero test files, no harness. | repo-wide | Every change is hand-verified; refactoring is dangerous. | Phase 1 (harness + first suites) |
| D3 | **Schema defined twice.** DDL lives in both `sql/schema.sql` *and* hardcoded in `DatabaseService.ensureSchema()`; column changes live in an ad-hoc try/catch `ensureMigrations()` list. Drift risk. | `services/DatabaseService.cfc`, `sql/schema.sql` | New tables/columns must be written in 2–3 places; no version tracking. | Phase 1 (numbered migration runner) |
| D4 | **Keyword coverage is incomplete vs. the goal.** `ScoringService.directKeywords = [coldfusion, cfml, lucee, mura]`. **ColdBox, FuseBox, CommandBox, WireBox are not detected at all.** | `services/ScoringService.cfc`, `services/JobService.expandCfKeywordTerms` | We literally miss target jobs today. | Phase 1 (taxonomy) |
| D5 | **Rule-version mismatch.** `ScoringService` returns `v3_india_word_boundary`; `JobService` defaults to `v2_cf_direct`. Score joins can silently miss rows. | `ScoringService.init`, `JobService.init` | Dashboard/score joins fragile. | Phase 1 |
| D6 | **No real ATS detection.** ATS recognition is one giant `findNoCase` OR-chain (`isProbableJobPostingUrl`); no structured ATS registry, no per-ATS adapter contract. | `ScrapeOrchestrator.isProbableJobPostingUrl` | Can't systematically add/extend ATS coverage; the explicit Phase 1 deliverable. | Phase 1 |
| D7 | **No technology fingerprinting.** "Stack detection" is just Bing query strings like `"builtwith coldfusion"`. No HTTP-level fingerprint (`.cfm`, `X-Powered-By`, `CFID/CFTOKEN`/`cfid` cookies, Lucee headers, ColdBox/Mura markers). | `DiscoveryService.buildQueryPlans` | Secondary goal (companies-without-jobs) is guesswork. | Phase 2 |
| D8 | **Company scoring unused.** `companies.cf_likelihood_score` exists but is always `0`. | schema + `CompanyService` | No way to rank/triage discovered companies. | Phase 2 |
| D9 | **Alerts never leave the DB.** `AlertService` only writes `channel='log'`; no delivery transport. | `services/AlertService.cfc` | Phase 4 channels not built. | Phase 4 (on a transport seam added P2) |
| D10 | **Secrets live in SQLite.** API keys (Adzuna, Brave, USAJOBS, Google CSE) sit in `ats_config` JSON in the DB. No env/secret layer. | `seed_companies.json`, `companies.ats_config` | Keys in the DB/repo; rotation is manual. | Phase 1 (config/secrets seam) |
| D11 | **DB access is not abstracted.** Raw `queryExecute(..., {datasource})` with SQLite-specific SQL (`datetime('now')`, `json_extract`, `INSERT OR IGNORE`, `changes()`) scattered across services. | all services | Blocks the "Postgres-ready" requirement. | Phase 1 (DB gateway) |
| D12 | **No source graph.** Discovery upserts companies but there's no model of *which source found what*, no provenance, no feedback loop to spawn new sources. | — | Phase 3 ("self-expanding source graph") has no foundation. | Phase 3 (built on P1/P2 seams) |
| D13 | **Hardcoded config in code.** Query plans, watcher queries, source lists, thresholds baked into CFCs. | `DiscoveryService`, `ScrapeOrchestrator` | Can't tune without a deploy; blocks automated source onboarding. | Phase 2–3 (config tables) |
| D14 | **No CI gate.** Deploy is bash scripts; nothing runs tests before deploy. | `deploy/*.sh` | Manual quality gate. | Phase 1 (CI runs the new test harness) |

---

## 4. Cross-cutting foundations (built incrementally, not all at once)

These are the seams that make Phases 2–4 safe. Each is introduced *as a small PR inside the phase that first needs it* — we don't stop to build a framework up front.

- **F1 — DB Gateway (`DataGateway.cfc`).** Thin wrapper over `queryExecute` that centralizes the datasource, dialect quirks (`now()`, upsert, JSON access), and returns arrays-of-structs. SQLite dialect today; a `PostgresDialect` drop-in later. Satisfies "SQLite now, Postgres-ready." *(Phase 1, PR 1.1)*
- **F2 — Numbered migration runner.** `migrations/0001_*.sql … NNNN_*.sql` + a `schema_migrations` table + `MigrationRunner.cfc`. Replaces the dual DDL + ad-hoc `ensureMigrations`. `schema.sql` becomes generated/reference-only. *(Phase 1, PR 1.2)*
- **F3 — Config & secrets seam (`AppConfig.cfc`).** Reads `config/app.json` + environment variables (CF: `server.system.environment`), so API keys move out of the DB/repo. Backward compatible: falls back to existing `ats_config`. *(Phase 1, PR 1.3)*
- **F4 — Test harness.** TestBox (CommandBox dev-dependency, dev-only; production stays CF2025) with an in-memory/temp SQLite fixture DB and HTTP stubbing for `HttpClientService`. Plus a tiny GitHub Actions workflow. *(Phase 1, PR 1.4)*
- **F5 — Technology taxonomy (`TechTaxonomy.cfc`).** Single source of truth for the 8 target techs + aliases (e.g. `cold fusion`, `cfscript`, `box-json`, `wirebox`, `coldbox`, `fusebox`, `commandbox`, `mura`), used by scoring, keyword expansion, fingerprinting, and discovery queries. Kills D4. *(Phase 1, PR 1.5)*

---

## 5. Phased plan

Each phase = a set of small PRs. **After every phase I deliver: (a) the PRs as feature branches + diffs, (b) tests, (c) migration scripts, (d) deployment instructions, then stop for your approval.** You sync approved branches to GitHub.

### Phase 1 — ATS detection · company discovery · career-page discovery

**Outcome:** a structured, testable foundation for finding companies and their job pages across all ATSs, with the full tech taxonomy in place. Mostly *extraction + extension*, minimal behavior change.

PRs (in dependency order):

- **PR 1.1 — DataGateway seam (F1).** Introduce `DataGateway.cfc`; route *new* code through it. Existing queries untouched (incremental). *Migration:* none. *Tests:* gateway unit tests against fixture DB.
- **PR 1.2 — Migration runner (F2).** Add `MigrationRunner` + `0001_baseline.sql` (captures current schema) + `0002_*` for later. `Application.cfc` calls the runner instead of `ensureSchema`/`ensureMigrations` (old methods kept as no-op shims one release for safety). *Migration:* `0001`, `0002`. *Tests:* runner idempotency, fresh-DB vs existing-DB.
- **PR 1.3 — Config/secrets seam (F3).** `AppConfig.cfc` + `config/app.example.json`; move keys to env with DB fallback. *Tests:* precedence (env > app.json > ats_config).
- **PR 1.4 — Test harness + CI (F4).** TestBox wiring, fixtures, HTTP stub, GitHub Actions running the suite on PRs. *Tests:* the harness itself + smoke test.
- **PR 1.5 — Tech taxonomy (F5) + scoring/keyword fix (D4, D5).** All 8 techs detected; align rule version between `ScoringService` and `JobService`; expand `expandCfKeywordTerms`. *Migration:* none (re-score is a task run). *Tests:* taxonomy match table (positive/negative incl. `indiana`≠`india`, `coldbox` etc.).
- **PR 1.6 — ATS Registry + Detector (D6).** New `AtsRegistry.cfc` / `AtsDetector.cfc`: declarative table of ATS providers (Greenhouse, Lever, Workday, Ashby, SmartRecruiters, iCIMS, Taleo, BrassRing, SuccessFactors, Jobvite, BambooHR, Rippling, Darwinbox, Recruitee, Workable, Personio, Teamtailor, …) with URL patterns + detection rules. Replace the `isProbableJobPostingUrl` OR-chain by delegating to the detector (old function becomes a thin shim). *Migration:* add `companies.ats_provider`, `companies.ats_external_id` (nullable). *Tests:* detection fixtures per provider.
- **PR 1.7 — Career-page discovery module (D1 carve-out).** Extract the career-page/link logic (`pickCareerJobPostingUrl`, `findBestJobLink`, `collectSameHostJobLikeUrls`, `enrichCompanyLinks`, etc.) out of `ScrapeOrchestrator` into `CareerPageDiscoverer.cfc` — behavior-preserving move + tests. First real cut at the god object. *Tests:* characterization tests pin current behavior before/after.

**Phase 1 deliverables:** branches `phase1/pr-1.1` … `phase1/pr-1.7`, diffs, TestBox suites, migrations `0001`–`0003`, and `docs/DEPLOY_PHASE1.md` (run migrations, set env vars, re-score task, rollback steps). **→ approval gate.**

### Phase 2 — technology fingerprinting · company scoring · remote & visa scoring

**Outcome:** we can rank companies (incl. no-jobs ones) by how likely they use the stack, and rank jobs by remote/visa fit — replacing today's India-only heuristic with a transparent, extensible model.

- **PR 2.1 — Fingerprint engine (D7).** `TechFingerprinter.cfc`: fetches a domain and scores HTTP-level evidence — `.cfm`/`.cfc` URLs, `X-Powered-By`, `Set-Cookie` (`CFID`/`CFTOKEN`/`cfid`/`cftoken`), `Lucee`/`Railo` headers, ColdBox/Mura/FuseBox HTML markers, `box.json`/CommandBox traces. Pluggable signal rules from the taxonomy (F5). *Migration:* `tech_fingerprints` table (company_id, signal, evidence, weight, observed_at). *Tests:* fixture HTML/header sets per tech.
- **PR 2.2 — Company scoring (D8).** `CompanyScoreService.cfc` combines fingerprint evidence + discovery signals + job history into `companies.cf_likelihood_score` (now meaningful), with reasons. Dashboard column + sort. *Migration:* `company_scores` (versioned, like `job_scores`). *Tests:* scoring math + reasons.
- **PR 2.3 — Remote & visa-sponsorship scoring.** Refactor `ScoringService` into composable layers: `cf_match` (taxonomy), `remote_fit`, `visa_sponsorship` (detect "sponsorship available", H-1B/visa language, blockers), `geo_eligibility` (today's India layer, now one pluggable layer among several). Bump rule version cleanly via migration-tracked re-score task. *Tests:* layered scoring fixtures incl. sponsorship positive/negative.
- **PR 2.4 — Alert transport seam (prep for P4).** Introduce `AlertChannel` interface + `LogChannel` (current behavior) so `AlertService` dispatches through channels. No new external channel yet. *Tests:* dispatch routing.

**Phase 2 deliverables:** branches, diffs, tests, migrations `0004`–`0006`, `docs/DEPLOY_PHASE2.md` (fingerprint backfill task, re-score task, new dashboard columns). **→ approval gate.**

### Phase 3 — self-expanding source graph · automated source onboarding

**Outcome:** the system learns. Productive sources spawn new sources; provenance is tracked; new boards/ATSs onboard with config, not code.

- **PR 3.1 — Source graph model (D12).** `sources`, `source_edges` (provenance: which source/discovery produced which company/job/source), `source_metrics` (yield, hit-rate, cost). Backfill existing sources as nodes. *Migration:* `0007`–`0008`. *Tests:* graph insert/traverse, metric rollups.
- **PR 3.2 — Source scoring & expansion engine.** Periodic job that reads `source_metrics`, promotes high-yield discovery domains/ATS tokens into first-class recurring sources, and demotes/quarantines dead ones. Feeds back into `SourceQuotaService`. *Tests:* promotion/demotion thresholds.
- **PR 3.3 — Automated source onboarding (D13).** Config-driven adapter contract (`ISourceAdapter`) + a `source_definitions` table so a new ATS/board is onboarded by inserting a definition (URL template, parser kind, quota) rather than editing `ScrapeOrchestrator`. Migrate 2–3 existing adapters onto the contract as proof. *Tests:* contract conformance + one migrated adapter parity test.
- **PR 3.4 — Continuous scheduling.** Move from once-daily to a tiered, continuous cadence (hot sources frequent, cold sources rare) using the metrics + quota services. *Tests:* scheduler selection logic.

**Phase 3 deliverables:** branches, diffs, tests, migrations `0007`–`0010`, `docs/DEPLOY_PHASE3.md` (source backfill, scheduler cutover, monitoring). **→ approval gate.**

### Phase 4 — Telegram & WhatsApp alerts

**Outcome:** high-fit jobs and newly-found companies reach you in real time on Telegram and WhatsApp.

- **PR 4.1 — Telegram channel.** `TelegramChannel` implementing the P2 `AlertChannel` seam (Bot API `sendMessage`, chat IDs + token from `AppConfig`). Per-channel dedupe via existing `alerts.dedupe_key`. *Migration:* add channel rows/prefs. *Tests:* payload formatting + dispatch (HTTP stubbed).
- **PR 4.2 — WhatsApp channel.** `WhatsAppChannel` via WhatsApp Business Cloud API (template messages, token/phone-number-id from `AppConfig`). *Tests:* same pattern. *(Requires you to provision a Meta WhatsApp Business number + token — I'll document the setup; sending needs your credentials.)*
- **PR 4.3 — Alert routing & throttling.** Subscriptions table (which scores/techs/geos go to which channel), rate limiting, quiet hours. *Tests:* routing matrix.

**Phase 4 deliverables:** branches, diffs, tests, migrations `0011`+, `docs/DEPLOY_PHASE4.md` (Telegram bot setup, WhatsApp provisioning, env vars, test-send runbook). **→ done.**

---

## 6. PR & git workflow

- One feature branch per PR: `phaseN/pr-N.x-short-slug`, small and reviewable.
- Each PR ships **code + tests + migration (if any) + a PR description** (what/why, risk, rollback) and updates `docs/BUILD_LOG.md`.
- I prepare branches and diffs locally; **you review and sync approved branches to `github.com/DivyKishor/FindMyJob`.** (If you later install a GitHub connector, I can open the PRs directly.)
- **No working component is rewritten in place** — refactors are extract-and-delegate with characterization tests pinning behavior first.
- CI (added PR 1.4) runs the TestBox suite + migration check on every branch.

## 7. Key risks & mitigations

- **Refactoring the 2,826-line orchestrator** → always characterization-test first, extract behind a shim, delete only after green. Spread across phases, never one big-bang.
- **SQLite single-writer under continuous discovery (Phase 3)** → the DataGateway + dialect seam (F1) makes the Postgres move a config change, not a rewrite, when concurrency demands it.
- **Scraping fragility / rate limits** → reuse existing `HttpClientService` retry + `SourceQuotaService`; fingerprinting (P2) is HEAD/GET-light and quota-bounded.
- **WhatsApp/Telegram provider requirements** → flagged in Phase 4; channels are credential-gated and behind the alert seam so the rest of the system is unaffected if a channel is unconfigured.

---

## 8. What I need from you to start Phase 1

Approval to begin. Optionally, whether you want CI on GitHub Actions now (PR 1.4) or deferred. On approval I'll generate the Phase 1 branches, diffs, tests, migrations, and `DEPLOY_PHASE1.md`, then stop for review.
