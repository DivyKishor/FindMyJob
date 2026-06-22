# Phase 1 — Deployment & Verification

Phase 1 adds foundational seams (DB gateway, migration runner, config/secrets, test harness + CI) and the first feature work toward the goal: full 8-technology detection, a structured ATS registry/detector, and a first extraction from the `ScrapeOrchestrator` god object. Everything is additive or behaviour-preserving.

## 0. Commit & push (run on your machine)

The work is in your working tree. Create the branch and commits locally, then push:

```bash
bash scripts/commit-phase1.sh
git log --oneline origin/main..phase1     # review
git push -u origin phase1
```

Then open a PR from `phase1` into `main` on GitHub. (See `docs/PHASE1_PRS.md` for the per-PR breakdown if you prefer to split into separate PRs.)

> Why a script: the environment that authored these files could not commit reliably (its filesystem mount corrupted reads of large/edited files during `git add`). Your local filesystem is consistent, so the script commits correctly.

## 1. Database migrations

No manual SQL needed. On the next app start (or `?reinit=1`), `Application.cfc` runs `MigrationRunner.run()`, which:

- creates `schema_migrations`,
- applies `migrations/0001_baseline.sql`, `0002_job_lifecycle_columns.sql`, `0003_company_ats_provider.sql` in order,
- records each so it never re-runs,
- tolerates "duplicate column / already exists" on databases that already received these columns via the old ad-hoc path.

Verified against SQLite locally: fresh install, idempotent re-run, and the legacy-DB path (columns pre-existing) all pass. Migration 0003 adds `companies.ats_provider` and `companies.ats_external_id` (nullable).

Rollback: migrations only add tables/columns/indexes; to revert, drop the added columns/`schema_migrations` rows. The `DatabaseService.ensureSchema()`/`ensureMigrations()` methods remain as deprecated shims for one release.

## 2. Environment variables (secrets)

Secrets can now live outside the DB/repo. Precedence: **env var > `config/app.json` > a company's `ats_config` > default**. Existing `ats_config` keys keep working, so nothing breaks if you skip this.

Copy the template and/or set env vars (env key = `CFINTEL_` + UPPER_SNAKE of the dotted key):

```bash
cp wwwroot/config/app.example.json wwwroot/config/app.json   # gitignored
# or, e.g.:
export CFINTEL_SECRETS_BRAVE_API_KEY=...
export CFINTEL_SECRETS_ADZUNA_APP_ID=...
export CFINTEL_SECRETS_ADZUNA_APP_KEY=...
```

## 3. Re-score existing jobs (required)

Scoring moved from `v3_india_word_boundary` to **`v4_cf_ecosystem`** (now covers ColdBox/FuseBox/CommandBox/WireBox and aligns the JobService/ScoringService rule version). Existing `job_scores` rows are v3; the dashboard joins on v4. Run once after deploy:

```
GET /tasks/scoreJobs.cfm
```

This writes v4 score rows. Until then, scores display as 0 for already-ingested jobs.

## 4. Run the tests

Locally (needs CommandBox; CI does this automatically):

```bash
box install
box server start serverConfigFile=server-ci.json
box testbox run runner="http://localhost:8599/tests/runner.cfm" verbose=true
```

CI runs on every push/PR via `.github/workflows/ci.yml`. The suite covers: DataGateway dialect SQL, MigrationRunner splitting/benign-errors, AppConfig precedence, TechTaxonomy (all 8 techs + word boundaries), ScoringService v4, AtsDetector (incl. legacy-positive characterization), and CareerPageDiscoverer helpers.

## 5. Smoke test after deploy

1. App starts clean (`?reinit=1`) — migrations apply, no errors in `wwwroot/logs/scrape.log`.
2. `GET /tasks/scoreJobs.cfm` — re-scores without error.
3. Dashboard `/index.cfm` loads; search "coldfusion" still returns results (keyword expansion now also matches ColdBox/etc.).
4. `GET /api/jobs.cfm?keyword=coldbox` — returns any ColdBox roles (newly detectable).
5. Run `/tasks/runDailyScrape.cfm` once — pipeline completes; `pipeline_runs` gets a success row.

## 6. Rollback

Phase 1 is additive. To roll back, revert the `phase1` merge: new services become unreferenced, migrations are forward-only but harmless, and scoring returns to v3 only if you also revert `ScoringService`/`JobService` (then re-run `scoreJobs.cfm`).
