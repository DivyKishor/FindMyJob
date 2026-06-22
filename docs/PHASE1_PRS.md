# Phase 1 — Pull Request Breakdown

Seven logical PRs, each additive or behaviour-preserving, each with tests. The `scripts/commit-phase1.sh` script lays these down as separate commits on a `phase1` branch; you can push as one PR or split into seven.

All new code is **ColdFusion tag syntax** (project standard). New services are wired as application-scoped singletons in `Application.cfc`.

---

## PR 1.1 — DataGateway seam
**What:** `wwwroot/services/DataGateway.cfc` — a thin, dialect-aware wrapper over `queryExecute` (`nowExpr`, `jsonExtract`, insert-ignore, `affectedRows`, `queryArray/queryRow/scalar`). Wired as `application.dataGateway`.
**Why:** Isolates SQLite-specific SQL so a later PostgreSQL move is a dialect swap, not a rewrite ("SQLite now, Postgres-ready"). Pays down D11.
**Risk:** None — additive; existing `queryExecute` calls untouched. **Rollback:** delete the file + wiring.
**Tests:** `DataGatewayTest` — dialect SQL fragments for sqlite + postgres.

## PR 1.2 — Numbered migration runner
**What:** `MigrationRunner.cfc` + `migrations/0001_baseline.sql`, `0002_job_lifecycle_columns.sql` + `schema_migrations` table. `Application.cfc` runs the runner instead of `ensureSchema()`/`ensureMigrations()` (kept as deprecated shims).
**Why:** Removes the dual source of truth (schema.sql + hardcoded DDL) and the ad-hoc ALTER list. Pays down D3.
**Risk:** Low — statements are idempotent and benign-error tolerant; validated against SQLite (fresh, idempotent, legacy-DB). **Rollback:** restore the old `ensureSchema`/`ensureMigrations` calls.
**Tests:** `MigrationRunnerTest` — statement splitting + benign-error detection.

## PR 1.3 — Config/secrets seam
**What:** `AppConfig.cfc` + `config/app.example.json` (real `app.json` gitignored). Precedence env > app.json > `ats_config` > default. Wired as `application.appConfig`.
**Why:** Moves API keys out of the SQLite `ats_config`/repo without breaking existing rows. Pays down D10.
**Risk:** None — backward compatible (ats_config is the fallback layer). **Rollback:** delete file + wiring.
**Tests:** `AppConfigTest` — precedence, env override, ats_config fallback.

## PR 1.4 — Test harness + GitHub Actions CI
**What:** `box.json` (TestBox dev dep), `server-ci.json` (Lucee 6), `tests/Application.cfc`, `tests/runner.cfm`, `tests/stubs/HttpClientStub.cfc`, `.github/workflows/ci.yml`.
**Why:** Zero tests existed (D2/D14). Makes the PR 1.1–1.7 specs runnable and gates every push/PR.
**Risk:** None — dev/CI only; not shipped to the CF2025 runtime. **Rollback:** delete files.
**Tests:** the harness itself; runs the full suite.

## PR 1.5 — Tech taxonomy + scoring/keyword fix  *(primary-goal core)*
**What:** `TechTaxonomy.cfc` — one source of truth for the **8** target techs incl. **ColdBox, FuseBox, CommandBox, WireBox** (previously undetected). `ScoringService` uses it (word-boundary matching, ingest gate, reasons); rule version bumped **v3 → v4_cf_ecosystem**. `JobService` rule-version default aligned to v4 (fixes the v2/v3 mismatch) and keyword expansion delegated to the taxonomy.
**Why:** The system literally missed half the target technologies. Pays down D4, D5.
**Risk:** Medium — changes scoring output; requires a re-score (`scoreJobs.cfm`) after deploy. **Rollback:** revert files + re-run scoreJobs.
**Tests:** `TechTaxonomyTest` (8-tech coverage, `.cfm` symbols, word boundaries, umbrella expansion), `ScoringServiceTest` (v4, ColdBox/CommandBox/WireBox scoring, India eligibility, US-auth penalty).

## PR 1.6 — ATS registry + detector
**What:** `AtsRegistry.cfc` (declarative catalogue of 26 ATS providers) + `AtsDetector.cfc` (provider detection + behaviour-preserving `isProbableJobPostingUrl`). `ScrapeOrchestrator.isProbableJobPostingUrl` now delegates to the detector (first carve-out from the 2.8k-line file). Migration `0003` adds `companies.ats_provider` / `ats_external_id`.
**Why:** ATS detection was a giant inline `findNoCase` OR-chain; new ATSs now onboard by adding a registry row. Pays down D6, starts D1.
**Risk:** Low — characterization tests pin the legacy positives. **Rollback:** restore the inline function body.
**Tests:** `AtsDetectorTest` — provider detection + legacy "is a job posting" characterization.

## PR 1.7 — Extract CareerPageDiscoverer
**What:** `CareerPageDiscoverer.cfc` owns the self-contained career/job URL helpers (`extractHostFromUrl`, `isJobBoardOrSocialHost`, `hrefLooksLikeJobListingPath`, `absolutizeUrl`, `extractHref`, `firstProbableJobUrlFromArray`). The orchestrator keeps thin private shims delegating to it, so all internal callers are unchanged.
**Why:** Continues shrinking the god object (D1) with zero behaviour change.
**Risk:** Low — behaviour-preserving extraction; shims keep call sites intact. **Rollback:** inline the helpers again.
**Tests:** `CareerPageDiscovererTest` — every extracted helper.

---

## Verification status

- **Migrations:** validated against real SQLite — fresh install, idempotent re-run, and legacy-DB (pre-existing columns) all pass.
- **CFML structure:** new components verified for balanced `cfcomponent`/`cffunction`/`cftry` and correct shim wiring (via the editor, which reads the true files).
- **TestBox specs:** written for every PR; they run in CI (CommandBox could not be installed in the authoring sandbox, so they execute on GitHub Actions / locally per `DEPLOY_PHASE1.md`).

## Note on commit mechanics

These files were authored directly into your working tree. The authoring sandbox's filesystem mount corrupted reads of large/edited files during `git add`, so commits had to be deferred to your (consistent) local filesystem via `scripts/commit-phase1.sh`. The source files themselves are correct on disk.

The pre-Phase-1 local edits you had not yet pushed (e.g. expanded `seed_companies.json`, dashboard updates, `ExpiryCheckerService`) are committed first by the script as a "sync" commit. Three files I edited for Phase 1 (`ScoringService`, `JobService`, `ScrapeOrchestrator`) also carried small pre-Phase-1 edits of yours; those ride along in their respective PR commits.
