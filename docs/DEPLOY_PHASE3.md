# Phase 3 — Deployment & Verification

Phase 3 adds the self-expanding source graph, expansion engine, config-driven onboarding, and a tiered scheduler. All additive; built on the Phase 1/2 seams.

## 1. Migrations

No manual SQL. On next app start (`?reinit=1`), `MigrationRunner` applies `0006_source_graph.sql` and `0007_source_definitions.sql` (idempotent, recorded in `schema_migrations`). New tables: `sources`, `source_edges`, `source_metrics`, `source_definitions`.

## 2. One-time backfill

```
GET /tasks/buildSourceGraph.cfm
```
Seeds graph nodes from existing companies' `careers_source` values. Returns `{ ok, nodes }`.

## 3. Onboard a new source (config-driven)

Insert a definition and sync in one call (or call repeatedly):

```
GET /tasks/syncSourceDefinitions.cfm?source_key=acme_scan&adapter_kind=career_page_scan&label=Acme&url=https://acme.com/careers
```
Returns `{ ok, onboarded:[...], skipped:[...] }`. The new source becomes a `career_page_scan` company the daily pipeline scans, and a `candidate` graph node. Supported per-company kinds: `career_page_scan`, `greenhouse`. Global feeds remain managed by `ensureFeedSources()`.

## 4. Let it learn

Record yield over normal pipeline runs (the graph's `recordRun` is called as sources produce companies/jobs), then periodically:

```
GET /tasks/expandSources.cfm
```
Promotes `candidate` sources with proven yield to `active`, quarantines dead/erroring `active` ones. Returns `{ ok, evaluated, promoted, quarantined }`.

Recommended cadence: register `expandSources.cfm` weekly and `syncSourceDefinitions.cfm` daily via the same scheduled-task mechanism as `setupSchedule.cfm`.

## 5. Tests

```bash
box server restart serverConfigFile=server-ci.json
box testbox run runner="http://localhost:8599/tests/runner.cfm" verbose=true
```
Phase 3 adds `SourceGraphServiceTest`, `SourceExpansionServiceTest`, `SourceRegistryServiceTest`, `SourceSchedulerTest`. Restart is needed so the test app re-runs migrations (`0006`/`0007`) against the fixture DB.

## 6. Rollback

Additive. To revert: drop `sources`, `source_edges`, `source_metrics`, `source_definitions`, and remove the Phase 3 service wiring from `Application.cfc`. Migrations are forward-only but harmless.
