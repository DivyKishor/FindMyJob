<cfcomponent output="false" accessors="true">
	<cfproperty name="datasource" type="string" />

	<cffunction name="init" access="public" returntype="any" output="false">
		<cfargument name="datasource" type="string" required="true" />
		<cfset variables.datasource = arguments.datasource />
		<cfreturn this />
	</cffunction>

	<cffunction name="getDatasource" access="public" returntype="string" output="false">
		<cfreturn variables.datasource />
	</cffunction>

	<cffunction name="ensureForeignKeys" access="public" returntype="void" output="false">
		<cfset queryExecute( "PRAGMA foreign_keys = ON", {}, { datasource: variables.datasource } ) />
	</cffunction>

	<cffunction name="ensureSchema" access="public" returntype="void" output="false">
		<cfargument name="schemaPath" type="string" required="true" />
		<cfif NOT fileExists( arguments.schemaPath )>
			<cfthrow message="Schema file not found: #arguments.schemaPath#" />
		</cfif>
		<!---
			Use explicit ordered DDL statements.
			This avoids parser edge-cases when splitting large schema files by delimiters.
		--->
		<cfset tableStatements = [
			"PRAGMA foreign_keys = ON",
			"CREATE TABLE IF NOT EXISTS companies (
			  id INTEGER PRIMARY KEY AUTOINCREMENT,
			  name TEXT NOT NULL,
			  website TEXT,
			  careers_url TEXT NOT NULL,
			  careers_source TEXT NOT NULL DEFAULT 'html',
			  ats_config TEXT,
			  cf_likelihood_score INTEGER NOT NULL DEFAULT 0,
			  created_at TEXT NOT NULL DEFAULT (datetime('now')),
			  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
			)",
			"CREATE TABLE IF NOT EXISTS jobs (
			  id INTEGER PRIMARY KEY AUTOINCREMENT,
			  company_id INTEGER NOT NULL,
			  external_id TEXT NOT NULL,
			  title TEXT NOT NULL,
			  description TEXT,
			  location TEXT,
			  link TEXT NOT NULL,
			  raw_source TEXT NOT NULL,
			  fetched_at TEXT NOT NULL DEFAULT (datetime('now')),
			  FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE CASCADE,
			  UNIQUE (company_id, external_id)
			)",
			"CREATE TABLE IF NOT EXISTS job_scores (
			  id INTEGER PRIMARY KEY AUTOINCREMENT,
			  job_id INTEGER NOT NULL,
			  rule_version TEXT NOT NULL,
			  score INTEGER NOT NULL,
			  reasons_json TEXT,
			  created_at TEXT NOT NULL DEFAULT (datetime('now')),
			  FOREIGN KEY (job_id) REFERENCES jobs(id) ON DELETE CASCADE,
			  UNIQUE (job_id, rule_version)
			)",
			"CREATE TABLE IF NOT EXISTS alerts (
			  id INTEGER PRIMARY KEY AUTOINCREMENT,
			  job_id INTEGER NOT NULL,
			  channel TEXT NOT NULL,
			  payload_json TEXT,
			  sent_at TEXT NOT NULL DEFAULT (datetime('now')),
			  dedupe_key TEXT NOT NULL UNIQUE,
			  FOREIGN KEY (job_id) REFERENCES jobs(id) ON DELETE CASCADE
			)",
			"CREATE TABLE IF NOT EXISTS pipeline_runs (
			  id INTEGER PRIMARY KEY AUTOINCREMENT,
			  run_at TEXT NOT NULL DEFAULT (datetime('now')),
			  status TEXT NOT NULL,
			  jobs_upserted INTEGER NOT NULL DEFAULT 0,
			  jobs_scored INTEGER NOT NULL DEFAULT 0,
			  alerts_created INTEGER NOT NULL DEFAULT 0,
			  error_count INTEGER NOT NULL DEFAULT 0,
			  summary_json TEXT,
			  errors_json TEXT
			)",
			"CREATE TABLE IF NOT EXISTS source_run_log (
			  id INTEGER PRIMARY KEY AUTOINCREMENT,
			  source_key TEXT NOT NULL,
			  run_at TEXT NOT NULL DEFAULT (datetime('now'))
			)",
			"CREATE TABLE IF NOT EXISTS discovery_signals (
			  id INTEGER PRIMARY KEY AUTOINCREMENT,
			  signal_type TEXT NOT NULL,
			  source_name TEXT NOT NULL,
			  query_text TEXT NOT NULL,
			  company_name TEXT,
			  company_domain TEXT,
			  target_url TEXT,
			  evidence_text TEXT,
			  confidence_score INTEGER NOT NULL DEFAULT 0,
			  created_at TEXT NOT NULL DEFAULT (datetime('now'))
			)"
		] />
		<cfset executeStatements( tableStatements ) />

		<cfset indexStatements = [
			"CREATE INDEX IF NOT EXISTS idx_companies_source ON companies(careers_source)",
			"CREATE INDEX IF NOT EXISTS idx_jobs_company ON jobs(company_id)",
			"CREATE INDEX IF NOT EXISTS idx_jobs_fetched ON jobs(fetched_at)",
			"CREATE INDEX IF NOT EXISTS idx_job_scores_job ON job_scores(job_id)",
			"CREATE INDEX IF NOT EXISTS idx_alerts_sent ON alerts(sent_at)",
			"CREATE INDEX IF NOT EXISTS idx_pipeline_runs_run_at ON pipeline_runs(run_at)",
			"CREATE INDEX IF NOT EXISTS idx_source_run_log_key_time ON source_run_log(source_key, run_at)",
			"CREATE INDEX IF NOT EXISTS idx_discovery_signals_domain ON discovery_signals(company_domain)",
			"CREATE INDEX IF NOT EXISTS idx_discovery_signals_time ON discovery_signals(created_at)"
		] />
		<cfset executeStatements( indexStatements ) />
	</cffunction>

	<!---
		Safe column migrations for existing databases.
		SQLite does not support ALTER TABLE ADD COLUMN IF NOT EXISTS before 3.37,
		so we wrap each in try/catch and ignore "duplicate column" errors.
	--->
	<cffunction name="ensureMigrations" access="public" returntype="void" output="false">
		<cfset var migrations = [
			"ALTER TABLE jobs ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1",
			"ALTER TABLE jobs ADD COLUMN last_checked_at TEXT",
			"ALTER TABLE jobs ADD COLUMN work_type TEXT NOT NULL DEFAULT 'unknown'",
			"ALTER TABLE jobs ADD COLUMN first_seen_at TEXT",
			"UPDATE jobs SET first_seen_at = fetched_at WHERE first_seen_at IS NULL",
			"CREATE INDEX IF NOT EXISTS idx_jobs_active ON jobs(is_active)",
			"CREATE INDEX IF NOT EXISTS idx_jobs_work_type ON jobs(work_type)",
			"CREATE INDEX IF NOT EXISTS idx_jobs_first_seen ON jobs(first_seen_at)"
		] />
		<cfloop array="#migrations#" index="stmt">
			<cftry>
				<cfset queryExecute( stmt, {}, { datasource: variables.datasource } ) />
				<cfcatch type="any"><!--- column already exists or other non-fatal — skip ---></cfcatch>
			</cftry>
		</cfloop>
	</cffunction>

	<cffunction name="executeStatements" access="private" returntype="void" output="false">
		<cfargument name="statements" type="array" required="true" />
		<cfloop array="#arguments.statements#" index="stmt">
			<cfset queryExecute( stmt, {}, { datasource: variables.datasource } ) />
		</cfloop>
	</cffunction>

	<cffunction name="queryToArray" access="public" returntype="array" output="false">
		<cfargument name="q" type="query" required="true" />
		<cfset out = [] />
		<cfset cols = listToArray( arguments.q.columnList ) />
		<cfloop from="1" to="#arguments.q.recordCount#" index="rowNum">
			<cfset rowStruct = {} />
			<cfloop array="#cols#" index="col">
				<!--- Lowercase keys: Lucee + SQLite JDBC often return UPPERCASE column names, which breaks views expecting jobRow.link etc. --->
				<cfset rowStruct[ lCase( col ) ] = arguments.q[ col ][ rowNum ] />
			</cfloop>
			<cfset arrayAppend( out, rowStruct ) />
		</cfloop>
		<cfreturn out />
	</cffunction>
</cfcomponent>
