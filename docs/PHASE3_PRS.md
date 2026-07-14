# Phase 3 — Pull Request Breakdown

Four logical PRs that make the system *self-expanding*: a provenance source graph, a yield-based expansion engine, config-driven onboarding, and a tiered continuous scheduler. Built on the Phase 1/2 seams (DataGateway, MigrationRunner). All additive — no existing component rewritten.

---

## PR 3.1 — Source graph model + service
**What:** Migration `0006` adds `sources` (nodes), `source_edges` (provenance), `source_metrics` (yield). `SourceGraphService.cfc` registers nodes, records dedup'd edges, accumulates per-source run metrics, and computes `yield_score = (companies+jobs)/runs`. `backfillFromExisting()` seeds nodes from current companies.
**Why:** Foundation for "which source found what" and for deciding what to grow/cut (D12).
**Risk:** Low — additive tables + service. **Rollback:** drop the three tables.
**Tests:** `SourceGraphServiceTest` (DB-integration, guarded) — register/list, status preservation, metric accumulation + yield, edge dedupe, status change.

## PR 3.2 — Source expansion engine
**What:** `SourceExpansionService.cfc`. `classifyMetric()` (pure) returns `promote` / `quarantine` / `keep` from a metric using configurable thresholds (minRuns, promoteYield, quarantineYield, maxErrorRate). `runExpansion()` promotes proven `candidate` sources to `active` and quarantines dead/erroring `active` ones.
**Why:** The system learns — productive sources get kept/expanded, dead ones drop out.
**Risk:** Low — only flips `sources.status`. **Rollback:** revert; statuses are advisory.
**Tests:** `SourceExpansionServiceTest` (pure) — evidence threshold, promote, quarantine (zero-yield + high-error), keep, custom thresholds.

## PR 3.3 — Automated source onboarding
**What:** Migration `0007` adds `source_definitions`. `SourceAdapter.cfc` maps an `adapter_kind` to the `careers_source` the orchestrator already dispatches on. `SourceRegistryService.cfc` upserts definitions and `syncDefinitions()` turns enabled per-company definitions (greenhouse / career_page_scan) into `companies` rows + registers them as `candidate` graph nodes.
**Why:** Onboard a new ATS/board by inserting a row, not editing `ScrapeOrchestrator` (D13).
**Risk:** Low — creates company rows the existing pipeline understands; global feeds are left to `ensureFeedSources()`. **Rollback:** delete the definitions/companies.
**Tests:** `SourceRegistryServiceTest` — adapter kind mapping (pure) + onboarding into a company/graph node and no-double-onboard (DB-integration, guarded).

## PR 3.4 — Continuous tiered scheduler
**What:** `SourceScheduler.cfc`. `tierFor()` buckets sources hot/warm/cold by yield; `intervalMinutesFor()` gives the cadence (6h / 1d / 7d); `dueGivenElapsed()` (pure) and `isDue()` (real clock) decide if a source should run; `selectDue()` filters a metric set.
**Why:** Moves from once-daily to continuous, yield-weighted cadence — hot sources checked often, cold rarely.
**Risk:** Low — pure decision logic; integrates by selecting which sources to run. **Rollback:** keep the daily schedule.
**Tests:** `SourceSchedulerTest` (pure) — tiers, intervals, elapsed/due, never-run, fresh, selectDue filtering.

---

## Wiring & tasks

`Application.cfc` wires `sourceGraphService`, `sourceExpansionService`, `sourceAdapter`, `sourceRegistryService`, `sourceScheduler`. New task endpoints:

- `tasks/buildSourceGraph.cfm` — backfill graph nodes from existing companies.
- `tasks/expandSources.cfm` — run the promotion/quarantine pass.
- `tasks/syncSourceDefinitions.cfm` — onboard config-driven sources (optionally add one inline via URL params).

## Verification status

- **Migrations 0006/0007:** validated against real SQLite incl. the `source_metrics` upsert + `yield_score` recompute and edge-dedupe unique index.
- **TestBox specs:** Phase 3 adds `SourceGraphServiceTest`, `SourceExpansionServiceTest`, `SourceRegistryServiceTest`, `SourceSchedulerTest`. Pure-logic specs run anywhere; DB-integration specs guard on the SQLite driver and soft-skip without it. Run the full suite green before pushing.
