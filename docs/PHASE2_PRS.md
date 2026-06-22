# Phase 2 — Pull Request Breakdown

Four logical PRs delivering: HTTP technology fingerprinting, company-level CF-likelihood scoring, layered job scoring (remote + visa), and an alert-channel seam (the foundation for Phase 4 Telegram/WhatsApp). Built on the Phase 1 seams (DataGateway, MigrationRunner, AppConfig, TechTaxonomy, test harness).

> Phases 1 and 2 ship on a single branch (`phase1-2`) because Phase 2 was developed on top of uncommitted Phase 1 and shares edited files. The commit history separates all 11 logical PRs. See `docs/PHASE1_PRS.md` for Phase 1.

---

## PR 2.1 — HTTP technology fingerprinting
**What:** `TechFingerprinter.cfc` scans a company domain (HEAD + GET) and scores HTTP-level evidence of the CF ecosystem — `X-Powered-By` ColdFusion, Lucee/Railo server headers, `CFID/CFTOKEN` cookies, `.cfm`/`.cfc` URLs, ColdBox/WireBox/FuseBox and Mura markers, and a `/box.json` probe. Signal rules are driven by `TechTaxonomy`, so new techs extend detection automatically. Migration `0004` adds `tech_fingerprints` (unique per company+signal, upsert on re-scan). Task `tasks/fingerprintCompanies.cfm` runs it.
**Why:** Realises the secondary goal — identifying companies that use the stack even with no current jobs (D7).
**Risk:** Low — read-only HTTP, quota-bounded, additive table. **Rollback:** drop the table + remove the service/task.
**Tests:** `TechFingerprinterTest` — fixture headers/HTML per signal.

## PR 2.2 — Company CF-likelihood scoring
**What:** `CompanyScoreService.cfc` combines fingerprint evidence (0–50), discovery signals (0–30), and job history (0–20) into a 0–100 score (`v1_company_cf_likelihood`), persists versioned rows to `company_scores`, and updates `companies.cf_likelihood_score` for dashboard sorting. Migration `0005` adds `company_scores` + a likelihood index. Task `tasks/scoreCompanies.cfm` runs it.
**Why:** Makes the previously-unused `cf_likelihood_score` meaningful; lets you rank/triage discovered companies (D8).
**Risk:** Low — additive, versioned like `job_scores`. **Rollback:** drop the table; column stays at 0.
**Tests:** `CompanyScoreServiceTest` — scoring math + reasons.

## PR 2.3 — Layered job scoring (remote + visa)
**What:** `ScoringService` refactored into four composable layers — `cf_match` (taxonomy baseline, required), `geo_eligibility` (the former India logic, renamed `classifyGeoEligibility`), `remote_fit` (+10 for explicit remote signals), and `visa_sponsorship` (+15 when an employer explicitly sponsors). Rule version bumped **v4 → v5_layered**. Backward compatible: the return struct keeps `indiaEligible` as an alias for `geoEligibility`, and `classifyIndiaEligibility` remains as a deprecated alias.
**Why:** Replaces the single India-only heuristic with transparent, extensible layers incl. visa-sponsorship detection.
**Risk:** Medium — changes job scores; requires a re-score (`scoreJobs.cfm`) after deploy. **Rollback:** revert the file + re-run scoreJobs.
**Tests:** `ScoringServiceV5Test` + updated `ScoringServiceTest` — each layer in isolation incl. remote bonus and visa positives vs work-auth blockers.

## PR 2.4 — Alert channel seam
**What:** `AlertChannel.cfc` (base contract, `send(payload)`, per-channel enable/error isolation) + `LogChannel.cfc` (current DB+log behaviour expressed as the first channel). `AlertService` now dispatches through an injected list of channels (defaults to `[LogChannel]`), with the dedupe key unchanged so existing alert rows aren't duplicated.
**Why:** Decouples delivery from generation so Phase 4 (Telegram, WhatsApp) adds a channel without touching `AlertService` (D9 groundwork).
**Risk:** Low — default behaviour identical to before. **Rollback:** restore the direct-write `AlertService`.
**Tests:** `AlertChannelTest` — LogChannel dispatch + multi-channel routing.

---

## Deploy / verify

See `docs/DEPLOY_PHASE2.md`. Key steps after merge: migrations `0004`/`0005` apply on boot; run `tasks/fingerprintCompanies.cfm` then `tasks/scoreCompanies.cfm` to populate company scores; run `tasks/scoreJobs.cfm` to re-score jobs under `v5_layered`.

## Verification status

- **Migrations 0004/0005:** standard idempotent DDL, consistent with the validated 0001–0003 runner path.
- **TestBox specs:** Phase 2 adds `TechFingerprinterTest`, `CompanyScoreServiceTest`, `ScoringServiceV5Test`, `AlertChannelTest`; run with the Phase 1 suite via CI or locally (`DEPLOY_PHASE1.md`). Run the full suite green before pushing.
