# ColdFusion Intelligence Engine (Phase 2a)

Production-oriented **Adobe ColdFusion 2025 (CFML)** system that seeds companies, ingests public **Greenhouse board JSON** (no API key), stores rows in **SQLite**, and provides both JSON APIs and a server-rendered Bootstrap dashboard.

## What is implemented now

- **Syntax standard**: ColdFusion tag syntax only (no `cfscript` blocks)
- **SQLite** schema: `companies`, `jobs`, `job_scores`, `alerts`, `discovery_signals`, `source_run_log`
- **Modular services**: database bootstrap, HTTP client, Greenhouse parser, scrape orchestrator (rate-limited delay between companies), job UPSERT
- **Seed data**: six **Greenhouse** demo boards plus open **Remotive/ArbeitNow** feeds and a **curated `career_page_scan` list** (notable CF/Lucee user organizations—telecom, auto, retail, media, agencies, hosts, recruiters); see `wwwroot/config/seed_companies.json`
- **Scoring / ingest gate**: jobs are stored and scored only when title or description mentions **coldfusion**, **cfml**, **lucee**, or **mura** (Mura CMS; case-insensitive substring). Rule version `v2_cf_direct`. Optional **Prune non-CF jobs** task removes legacy rows that fail this check.
- **UI**: ColdFusion-only Bootstrap dashboard at `/index.cfm`
- **Dashboard UX**: sortable job/alert columns, pagination, last-run status panel, **discovery signals** table (Bing RSS evidence for CF/Lucee-related domains), and job description previews
- **Multi-source ingestion**: Greenhouse + Remotive + ArbeitNow + **[GetCFMLJobs.com](https://www.getcfmljobs.com/)** (HTML listing + per-job pages; community CFML board) + Adzuna (API keys)
- **Discovery V1**: stack/job/career/community/ecosystem queries via **Bing RSS** (`discovery_signals` + optional `career_page_scan` company rows). The dashboard lists recent signals so you can see **who the web is associating with CF/Lucee** — that is separate from the **Jobs** table (real postings from feeds and ATS).
- **Career page scan**: only creates a **job** row when the chosen link looks like an **ATS or job-detail URL** (Greenhouse, Workday, `/jobs/…`, `gh_jid`, etc.), so marketing sites that merely mention ColdFusion no longer appear as fake job postings.
- **Endpoints**: `api/companies.cfm`, `api/jobs.cfm` (filters: `company_id`, `keyword`, `min_score`), `api/alerts.cfm`
- **Tasks**: `tasks/seed.cfm`, `tasks/runDiscovery.cfm`, `tasks/scoreJobs.cfm`, `tasks/generateAlerts.cfm`, `tasks/runDailyScrape.cfm`, `tasks/pruneIrrelevantJobs.cfm`
- **JDBC**: `wwwroot/lib/sqlite-jdbc.jar` (bundled; `$0`)

## Prerequisites (CF2025 only)

- **Adobe ColdFusion 2025**
- **Java 17+** (required by CF2025 runtime)

## Run locally (Lucee Express — quick dev)

If you have **JDK 17** but no full Adobe CF install, you can run the same `wwwroot` on **Lucee 6** (Tomcat, port **8888**):

```bash
chmod +x scripts/start-lucee.sh
./scripts/start-lucee.sh
```

Then open `http://127.0.0.1:8888/index.cfm` (add `?reinit=1` after pulling code changes). The first run downloads Lucee Express into `.runtime/` (gitignored).

Production target remains **Adobe ColdFusion 2025**; Lucee is for local smoke-testing only.

## Run locally (Adobe ColdFusion 2025)

1. Configure your site so `wwwroot/` is the web root.
2. Ensure `Application.cfc` can load `wwwroot/lib/sqlite-jdbc.jar`.
3. Open your local URL and run:
   - `GET /tasks/seed.cfm`
   - `GET /tasks/runDiscovery.cfm?force=1` (optional manual discovery refresh)
   - `GET /tasks/runDailyScrape.cfm` (scrape -> score -> alerts)
   - `GET /api/companies.cfm`
   - `GET /api/jobs.cfm?keyword=engineer`

## External source notes

- `remotive_feed` and `arbeitnow_feed` are auto-added at startup (`CompanyService.ensureFeedSources()`).
- `adzuna_feed` is optional and requires `ats_config` keys: `app_id`, `app_key`, optional `country`.

Database file: `wwwroot/data/coldfusion_intel.db`  
Log file: `wwwroot/logs/scrape.log`

## Scheduled task (daily)

In **Adobe ColdFusion Administrator** -> **Scheduled Tasks**, create a daily HTTP task for:

`/tasks/runDailyScrape.cfm`

(Use IP allowlisting or a secret key guard before exposing task URLs on the public internet.)

## Architecture (concise)

| Layer | Responsibility |
|--------|------------------|
| `Application.cfc` | Datasource, JDBC classpath, service wiring, schema + seed on startup |
| `services/DatabaseService.cfc` | Schema apply, `PRAGMA foreign_keys`, query -> array |
| `services/CompanyService.cfc` | Companies + JSON seed |
| `services/JobService.cfc` | List with filters, UPSERT |
| `services/HttpClientService.cfc` | CFHTTP with timeout and stable User-Agent |
| `services/GreenhouseParser.cfc` | Public board JSON -> normalized job structs |
| `services/ScrapeOrchestrator.cfc` | Per-company ingestion, delays, logging |
| `api/*.cfm` | JSON for internal integrations and future clients |

## Honest limits

- **This is not a Google replacement.** With $0-only sources you do not get the full web index; you get what public APIs and RSS expose (Greenhouse boards, open feeds, Bing result snippets). For “every company that runs ColdFusion,” discovery signals are **heuristic leads** — verify in your own research workflow.
- **Greenhouse** ingestion uses **`/jobs?content=true`** so each post includes full body text for CF/CFML/Lucee matching and the dashboard preview column.
- Default seeds include **Greenhouse demos**, open feeds, and a **curated CF/Lucee watch list** (large employers, CF shops, hosts, plus **Insight Global** and **Right People Group** for recruiter-led roles) in `wwwroot/config/seed_companies.json`; edit that file for your own targets.
- **robots.txt**: enforced in spirit via rate limiting and public ATS endpoints; add a dedicated robots parser before generic HTML scraping.

## Next phases (from your roadmap)

- **Phase 2b**: Telegram/email delivery channels on top of persisted alerts
- **Phase 3**: Improve ColdFusion dashboard UX and add role-based access (if needed)
- **Phase 4**: Playwright for JS-heavy sites, PostgreSQL, scale-out workers if needed
