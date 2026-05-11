# ColdFusion Intelligence Engine - project documentation

## Purpose

Internal tool (MVP) to discover and track job postings from public career sources, with a path toward ColdFusion-related signals (direct keywords and later heuristics). Phase 1 focuses on reliable ingestion and structured storage.

## What is implemented (Phase 1)

| Piece | Description |
|-------|-------------|
| **Runtime** | Adobe ColdFusion 2025 (CFML), configured via `wwwroot/Application.cfc` |
| **Code style** | ColdFusion tag syntax only (`<cfcomponent>`, `<cffunction>`, tag-based endpoint/task files) |
| **Database** | SQLite (`wwwroot/data/coldfusion_intel.db`), schema in `wwwroot/sql/schema.sql` |
| **JDBC** | SQLite driver JAR in `wwwroot/lib/sqlite-jdbc.jar` |
| **Company seed** | JSON file `wwwroot/config/seed_companies.json` (Greenhouse board tokens) |
| **Ingestion** | Public Greenhouse board JSON API only (`ScrapeOrchestrator`, `GreenhouseParser`, `HttpClientService`) |
| **Jobs** | UPSERT by `(company_id, external_id)` in `JobService` |
| **UI** | `wwwroot/index.cfm` ColdFusion-rendered dashboard with Bootstrap |
| **APIs** | `wwwroot/api/companies.cfm`, `jobs.cfm`, `alerts.cfm` |
| **Tasks** | `tasks/seed.cfm`, `tasks/scoreJobs.cfm`, `tasks/generateAlerts.cfm`, `tasks/runDailyScrape.cfm` |
| **Logging** | `wwwroot/logs/scrape.log` via `LoggerService` |
| **Run status** | `pipeline_runs` table + `RunStatusService` for last-run/error panel |

## Planned (not built yet)

- **Phase 2b**: Telegram/email delivery channels on top of persisted alerts
- **Phase 3**: Expand ColdFusion dashboard UX (saved filters, pagination, optional auth)
- **Phase 4**: Playwright for JS-heavy sites, PostgreSQL, stronger scale-out

## Repository layout (high level)

```
Job Finder/
|- README.md                 # Quick start
|- docs/
|  |- ENVIRONMENT.md         # Tooling check / prerequisites
|  |- PROJECT.md             # This file
|  `- BUILD_LOG.md           # Ongoing implementation notes
`- wwwroot/
   |- Application.cfc        # App scope, datasource, service wiring
   |- index.cfm              # Human-readable endpoint index
   |- sql/schema.sql
   |- config/seed_companies.json
   |- lib/sqlite-jdbc.jar
   |- services/              # Business logic (CFML components)
   |- api/                   # JSON endpoints for UI
   `- tasks/                 # Seed + daily scrape entry points
```

## Documentation policy

For every feature change:

1. Update `docs/BUILD_LOG.md` with what changed and why.
2. Update `README.md` if run/setup steps changed.
3. Update this file if architecture or scope changed.
