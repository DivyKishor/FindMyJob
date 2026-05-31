# ColdFusion Intelligence Engine (Phase 2a)

Production-oriented **Adobe ColdFusion 2025 (CFML)** system that seeds companies, ingests **ColdFusion / CFML / Lucee** job postings from many public sources (job-board APIs, ATS boards, open-web search, and curated career pages), stores rows in **SQLite**, and provides both JSON APIs and a server-rendered Bootstrap dashboard. Focused on **India & remote-eligible** roles while still capturing CF openings worldwide.

## What is implemented now

- **Syntax standard**: ColdFusion tag syntax only (no `cfscript` blocks)
- **SQLite** schema: `companies`, `jobs`, `job_scores`, `alerts`, `discovery_signals`, `source_run_log`
- **Modular services**: database bootstrap, HTTP client, Greenhouse parser, scrape orchestrator (rate-limited delay between companies), job UPSERT
- **Seed data**: Greenhouse demo boards, the full set of feed sources (board APIs, ATS scans, CF Global Watcher, Reddit, USAJOBS), CF **product-stack** employers (e.g. ZOLL/emsCharts), and a **curated `career_page_scan` list** (notable CF/Lucee organizations—telecom, auto, retail, media, agencies, hosts, recruiters); see `wwwroot/config/seed_companies.json`
- **Scoring / ingest gate**: jobs are stored and scored only when title or description mentions **coldfusion**, **cfml**, **lucee**, or **mura** (Mura CMS; case-insensitive), **or** when a full-stack role names ColdFusion/CFML as the backend. Rule version `v3_india_eligible`: scores 0–100 where **100** = CF + India or confirmed global-remote, **80** = CF + likely remote-friendly, **50** = CF match but location unclear, **20** = CF match but US work-auth / clearance required. India eligibility is a **score layer**, not an ingest gate, so global jobs still appear at low scores. Optional **Prune non-CF jobs** task removes legacy rows that fail the keyword check.
- **UI**: ColdFusion-only Bootstrap dashboard at `/index.cfm`
- **Dashboard UX**: sortable job/alert columns, pagination, last-run status panel, **discovery signals** table (Bing RSS evidence for CF/Lucee-related domains), job description previews, and quick filters including **India-eligible (70+)**, **Best matches (80+)**, location shortcuts, and **Global CF (any location)** (`source=cf_global_watcher`, min score 0).
- **Multi-source ingestion**:
  - **Job-board / remote APIs**: Remotive, ArbeitNow, **Remote OK**, **Jobicy**, **We Work Remotely (RSS)**, **Adzuna** (multi-country: us, gb, ca, au, de, in, fr, nl, sg, nz, at, ch, be, br, za, pl), **Jooble** (multi-region), **[GetCFMLJobs.com](https://www.getcfmljobs.com/)** (community CFML board)
  - **India boards / ATS scans**: LinkedIn public search, Cutshort, Foundit, Shine, Weekday, Indeed, Instahyre, Expertini, Greenhouse
  - **Government**: **USAJOBS.gov** official API (large legacy-CF employer)
  - **Community**: **Reddit** public JSON (`r/coldfusion`, `r/forhire`, `r/jobbit`, `r/remotejs`, hiring searches)
  - **Open web**: **CF Global Watcher** + **Google Programmable Search (CSE)**
- **CF Global Watcher** (`cf_global_watcher`): runs **first** in the daily pipeline. Rotates ~40 global queries (open web + ATS `site:` + regional) through **Bing RSS**, classifies job-posting URLs, **fetches the full job page**, parses it, and persists if the CF rules pass (`raw_source = cf_global_watcher`, deduped by URL hash). Optional **Brave Search API** fallback (`brave_api_key`) kicks in only when Bing throttles or returns nothing.
- **Resilient HTTP**: `HttpClientService` retries transient failures (connection drops, `429`/`5xx`) up to **3 attempts** with exponential backoff + jitter; supports per-request header overrides (Reddit User-Agent, Brave token, USAJOBS auth).
- **Discovery V1**: stack/job/career/community/ecosystem queries via **Bing RSS** (`discovery_signals` + optional `career_page_scan` company rows). The dashboard lists recent signals so you can see **who the web is associating with CF/Lucee** — that is separate from the **Jobs** table (real postings from feeds and ATS).
- **Career page scan**: only creates a **job** row when the chosen link looks like an **ATS or job-detail URL** (Greenhouse, Workday, `/jobs/…`, `gh_jid`, etc.), so marketing sites that merely mention ColdFusion no longer appear as fake job postings.
- **Company-name backfill**: `tasks/backfillJobCompanies.cfm` re-fetches any job stuck under the "Unknown Company" placeholder, recovers the real employer from the live page, reassigns it (or dedupes against an existing twin), and removes the empty placeholder.
- **Endpoints**: `api/companies.cfm`, `api/jobs.cfm` (filters: `company_id`, `keyword`, `min_score`, `location`, `source`), `api/alerts.cfm`
- **Tasks**: `tasks/seed.cfm`, `tasks/runDiscovery.cfm`, `tasks/scoreJobs.cfm`, `tasks/generateAlerts.cfm`, `tasks/runDailyScrape.cfm`, `tasks/pruneIrrelevantJobs.cfm`, `tasks/backfillJobCompanies.cfm`
- **JDBC**: `wwwroot/lib/sqlite-jdbc.jar` (download via `scripts/install-deps.sh`; gitignored)

## Prerequisites (CF2025 only)

- **Adobe ColdFusion 2025**
- **Java 17+** (required by CF2025 runtime)

## Run locally (Lucee Express — quick dev)

If you have **JDK 17** but no full Adobe CF install, you can run the same `wwwroot` on **Lucee 6** (Tomcat, port **8888**):

```bash
./scripts/install-deps.sh   # downloads wwwroot/lib/sqlite-jdbc.jar (gitignored)
chmod +x scripts/start-lucee.sh
./scripts/start-lucee.sh
```

Then open `http://127.0.0.1:8888/index.cfm` (add `?reinit=1` after pulling code changes). The first run downloads Lucee Express into `.runtime/` (gitignored).

Production target remains **Adobe ColdFusion 2025**; Lucee is for local smoke-testing only.

## Run locally (Adobe ColdFusion 2025)

1. Configure your site so `wwwroot/` is the web root.
2. Run `./scripts/install-deps.sh` so `wwwroot/lib/sqlite-jdbc.jar` exists, and ensure `Application.cfc` can load it.
3. Open your local URL and run:
   - `GET /tasks/seed.cfm`
   - `GET /tasks/runDiscovery.cfm?force=1` (optional manual discovery refresh)
   - `GET /tasks/runDailyScrape.cfm` (scrape -> score -> alerts)
   - `GET /api/companies.cfm`
   - `GET /api/jobs.cfm?keyword=engineer`

## External source notes

All feed sources are auto-added at startup via `CompanyService.ensureFeedSources()` (and seeded in `wwwroot/config/seed_companies.json`). Most work with **no key**; a few need credentials in their `ats_config`:

- **No key needed**: `remotive_feed`, `arbeitnow_feed`, `remoteok_feed`, `jobicy_feed`, `remote_rss_feed` (We Work Remotely), `getcfmljobs_feed`, `reddit_feed`, plus the HTML scans (LinkedIn public, Cutshort, Foundit, Shine, Weekday, Indeed, Instahyre, Expertini) and the `cf_global_watcher`.
- `adzuna_feed`: requires `app_id`, `app_key`; optional `countries` (array) or `country`.
- `google_cse_feed`: requires `api_key` + `cx` (Google Programmable Search Engine).
- `usajobs_feed`: requires `api_key` (Authorization-Key from developer.usajobs.gov) + `user_agent` (your registered email).
- `cf_global_watcher`: optional `brave_api_key` for the Brave Search fallback; `max_queries_per_run`, `max_url_fetches_per_query`, and `global_watcher_queries` are configurable.
- `reddit_feed`: sends a descriptive `user_agent` and polite delays to respect Reddit's unauthenticated rate limits.

Pipeline order (`PipelineService.runDaily`): **CF Global Watcher → Discovery → scrape `runAll` → score → alerts**.

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
| `services/JobService.cfc` | List with filters (`company_id`, `keyword`, `min_score`, `location`, `source`), UPSERT, company reassign/dedupe |
| `services/HttpClientService.cfc` | CFHTTP with timeout, header overrides, and retry-with-backoff on transient failures |
| `services/GreenhouseParser.cfc` | Public board JSON -> normalized job structs |
| `services/ScrapeOrchestrator.cfc` | Per-source ingestion (boards, ATS scans, CF Global Watcher, Reddit, USAJOBS), delays, logging, backfill |
| `services/PipelineService.cfc` | Orchestrates watcher → discovery → scrape → score → alerts |
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
