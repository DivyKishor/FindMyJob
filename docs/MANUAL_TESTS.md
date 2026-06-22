# Manual Test Cases — Phase 1 & 2 (UAT)

Run against the local dev server. Unit tests already prove the logic in isolation; these confirm the wiring end-to-end in the running app.

## Setup

```bash
./scripts/install-deps.sh        # ensures wwwroot/lib/sqlite-jdbc.jar
./scripts/start-lucee.sh         # http://127.0.0.1:8888
```

Open `http://127.0.0.1:8888/index.cfm?reinit=1` (the `?reinit=1` forces a fresh app start so all new services wire up and migrations run).

Optional but recommended for deep checks: open `wwwroot/data/coldfusion_intel.db` in **DB Browser for SQLite** to inspect tables directly.

Pass = matches "Expected". If anything deviates, note the URL + `wwwroot/logs/scrape.log` lines.

---

## Phase 1

### MT‑1 — App boots & migrations apply (PR 1.2)
**Steps:** Open `/index.cfm?reinit=1`. Then inspect the DB.
**Expected:** Dashboard renders with no error; `scrape.log` shows no migration errors. In `schema_migrations` table: rows for `0001`–`0005`. `jobs` has `is_active`/`work_type`/`first_seen_at`; `companies` has `ats_provider`/`ats_external_id`; tables `tech_fingerprints` and `company_scores` exist.

### MT‑2 — Re-init is safe / idempotent (PR 1.2)
**Steps:** Hit `/index.cfm?reinit=1` a second time.
**Expected:** Still loads cleanly, no "duplicate column" or "table exists" errors in the log (runner skips already-applied migrations).

### MT‑3 — 8‑technology coverage (PR 1.5 / 2.3)
**Steps:** Run `/tasks/runDailyScrape.cfm` (wait for the JSON summary), then `/tasks/scoreJobs.cfm`. Then query each:
`/api/jobs.cfm?keyword=coldbox`, `…?keyword=lucee`, `…?keyword=wirebox`, `…?keyword=commandbox`, `…?keyword=fusebox`, `…?keyword=mura`.
**Expected:** `scoreJobs` returns a JSON summary (no error). Searches return any matching roles with a non‑zero `score`. On the dashboard, searching **"coldfusion"** now also surfaces ColdBox/Lucee/etc. roles (umbrella expansion). *(If a given keyword has no live postings today that's fine — the point is the query runs and matches when data exists; MT‑3b proves the logic deterministically.)*

### MT‑3b — Scoring logic spot-check (deterministic)
**Steps:** Confirm the green unit run for `ScoringServiceV5Test` + `TechTaxonomyTest` (already done), OR in DB Browser open `job_scores.reasons_json` for a CF job.
**Expected:** reasons contain `cf_tech:<keys>` and the rule_version is `v5_layered`.

### MT‑4 — ATS / job-posting detection (PR 1.6)
**Steps:** After a scrape, open the dashboard **Job Feed**; click a few **Apply** links from `career_page_scan`-sourced jobs.
**Expected:** Links go to real job/ATS detail pages (Greenhouse/Lever/Workday/`/jobs/…`, etc.), not marketing/home pages. No careers-index pages stored as fake jobs.

### MT‑5 — Config/secrets seam (PR 1.3)
**Steps:** `copy wwwroot\config\app.example.json wwwroot\config\app.json`, then `/index.cfm?reinit=1`.
**Expected:** App boots with no error (config layer loads); existing keyed sources still run because `ats_config` remains the fallback. (Set a real `CFINTEL_SECRETS_*` env var only if you want to exercise a keyed feed like Adzuna.)

---

## Phase 2

### MT‑6 — HTTP technology fingerprinting (PR 2.1)
**Steps:** Run `/tasks/fingerprintCompanies.cfm?max=15`. For a known CF site, target it directly: `/tasks/fingerprintCompanies.cfm?company_id=<id>` (pick a CF-stack employer such as the seeded ZOLL/emsCharts row).
**Expected:** An HTML table with **Signals** and **FP Score** columns; at least one CF company shows Signals ≥ 1 and FP Score > 0. In DB Browser, `tech_fingerprints` has rows (e.g. `cfm_url`, `cf_cookie`, `lucee_header`) for that company.

### MT‑7 — Company CF‑likelihood scoring (PR 2.2)
**Steps:** Run `/tasks/scoreCompanies.cfm`. Then `/api/companies.cfm`.
**Expected:** Page reports "Scored: N companies." Companies with fingerprint/discovery/job evidence now have `cf_likelihood_score` > 0. In DB Browser, `company_scores` has versioned rows (`v1_company_cf_likelihood`) with `reasons_json`.

### MT‑8 — Remote & visa-sponsorship layers (PR 2.3)
**Steps:** After `scoreJobs`, open `job_scores.reasons_json` (DB Browser) for a remote CF job and for one mentioning visa sponsorship.
**Expected:** Remote job reasons include `remote_fit:+10`; a sponsorship job includes `visa_sponsorship:+15`; an India role includes `india_eligible`; a US-citizen-only role includes `work_auth_restricted` and a lower score. Scores stay within 0–100.

### MT‑9 — Alert channel dispatch (PR 2.4)
**Steps:** Run `/tasks/generateAlerts.cfm`.
**Expected:** Summary includes `alertsCreated` and a `channelResults` array (the LogChannel). New high-score jobs appear in the dashboard **Alerts** section and as `ALERT …` lines in `scrape.log`. Re-running does **not** duplicate alerts (dedupe by key).

### MT‑10 — Full pipeline (regression)
**Steps:** Run `/tasks/runDailyScrape.cfm` once end-to-end.
**Expected:** Completes with a success summary; `pipeline_runs` gets a `status='success'` row; no uncaught errors in `scrape.log`.

---

## Quick pass/fail summary to record

| ID | Area | Pass? |
|----|------|-------|
| MT‑1 | Boot + migrations | |
| MT‑2 | Idempotent reinit | |
| MT‑3 | 8‑tech search | |
| MT‑4 | ATS detection | |
| MT‑5 | Config/secrets | |
| MT‑6 | Fingerprinting | |
| MT‑7 | Company scoring | |
| MT‑8 | Remote/visa layers | |
| MT‑9 | Alert channels | |
| MT‑10 | Full pipeline | |
