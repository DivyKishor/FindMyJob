# Phase 2 — Deployment & Verification

Phase 2 adds HTTP technology fingerprinting, company CF-likelihood scoring, layered job scoring (v5), and the alert channel seam. All changes are additive or backward-compatible.

## 0. Commit & push (run on your machine)

```bash
cd "C:\Claude Space\FindMyJob"
git add -A
git commit -m "Phase 2: fingerprinting, company scoring, v5 layered scoring, alert channels"
git push origin phase2
```

Then open a PR from `phase2` into `main` on GitHub.

## 1. Database migrations

On the next app start (or `?reinit=1`), `MigrationRunner` auto-applies:
- **0004_tech_fingerprints.sql** — `tech_fingerprints` table with UNIQUE index on `(company_id, signal)`.
- **0005_company_scores.sql** — `company_scores` table + index on `companies.cf_likelihood_score`.

Both migrations are idempotent (CREATE TABLE IF NOT EXISTS, CREATE INDEX IF NOT EXISTS).

Rollback: migrations are forward-only and additive; to revert, drop the two tables and their indexes. No existing data is altered.

## 2. Re-score existing jobs (required)

Scoring moved from `v4_cf_ecosystem` to **`v5_layered`**. Existing `job_scores` rows for v4 jobs remain valid for the alert join (most-recent-row logic) but new jobs get v5 scores. To backfill all jobs with v5 scores:

```
GET /tasks/scoreJobs.cfm
```

This writes v5 score rows. Until then, jobs already scored under v4 still appear in alerts at their v4 score.

## 3. Fingerprint companies (optional first run)

Fingerprinting is quota-safe (short HTTP timeouts, no rate-limited APIs). Run it manually to populate initial `tech_fingerprints` data:

```
GET /tasks/fingerprintCompanies.cfm?max=50
```

- Processes up to `max` companies (default 25) ordered by least-recently-updated.
- For a single company: `?company_id=<id>`.
- After fingerprinting, company scores update automatically (includes fingerprint evidence).

## 4. Score all companies (optional first run)

To immediately populate `companies.cf_likelihood_score` from job history and discovery signals (before fingerprinting runs), visit:

```
GET /tasks/scoreCompanies.cfm
```

## 5. Run the tests

```bash
box install
box server start serverConfigFile=server-ci.json
box testbox run runner="http://localhost:8599/tests/runner.cfm" verbose=true
```

New test files in this phase:
- `tests/specs/TechFingerprinterTest.cfc` (10 cases — pure signal evaluation, no HTTP)
- `tests/specs/CompanyScoreServiceTest.cfc` (8 cases — pure scoring math)
- `tests/specs/ScoringServiceV5Test.cfc` (17 cases — all four layers)
- `tests/specs/AlertChannelTest.cfc` (6 cases — channel interface and dispatch)

Updated:
- `tests/specs/ScoringServiceTest.cfc` — updated for v5 rule version string.

## 6. Smoke test after deploy

1. App starts clean (`?reinit=1`) — migrations 0004–0005 apply, no errors in scrape.log.
2. `GET /tasks/scoreJobs.cfm` — v5 re-score completes without error.
3. Dashboard `/index.cfm` loads; companies column shows `cf_likelihood_score` values (0 initially, non-zero after step 4).
4. `GET /tasks/fingerprintCompanies.cfm?max=5` — fingerprints 5 companies, returns scores table.
5. `GET /tasks/scoreCompanies.cfm` — all companies scored; dashboard shows non-zero `score` column.
6. `GET /tasks/generateAlerts.cfm` — alerts generated; result JSON includes `channelResults` array.
7. `GET /api/jobs.cfm?keyword=coldfusion` — still returns results.

## 7. Dashboard changes

- Companies table now meaningfully sorts by **CF Likelihood Score** (was always 0 before).
- Fingerprinting and company-score tasks added to task list on `index.cfm` (update manually or via PR).

## 8. Phase 4 note (alert channels)

To add Telegram or WhatsApp in Phase 4:
1. Create `TelegramChannel.cfc` / `WhatsAppChannel.cfc` extending `AlertChannel`.
2. In `Application.cfc`, after creating `alertService`, call:
   ```cfml
   <cfset application.alertService.addChannel(
       createObject("component", "services.TelegramChannel").init(application.appConfig)
   ) />
   ```
3. No changes to `AlertService` or `generateAlerts.cfm` needed.

## 9. Rollback

Phase 2 is additive. To roll back:
- Revert `ScoringService.cfc` to v4 (restore from git). Run `scoreJobs.cfm` to re-write v4 scores.
- `AlertService.cfc` falls back cleanly to `LogChannel` with default init.
- `tech_fingerprints` and `company_scores` tables can be left in place (they're ignored by v4 code).
