<cfcomponent output="false" accessors="true">
	<!---
		SourceRegistryService — Phase 3, PR 3.3.

		Config-driven source onboarding. Definitions live in source_definitions;
		syncDefinitions() turns each enabled, supported definition into a company row
		the existing ScrapeOrchestrator already knows how to scan — so a new ATS/board
		is onboarded by inserting a row, not by editing scraping code.

		Newly onboarded sources are registered in the graph as 'candidate' so the
		expansion engine (PR 3.2) promotes them only once they prove yield.

		Tag syntax only (project standard).
	--->
	<cfproperty name="gw" type="any" />
	<cfproperty name="adapter" type="any" />
	<cfproperty name="graph" type="any" />
	<cfproperty name="loggerService" type="any" />

	<cffunction name="init" access="public" returntype="any" output="false">
		<cfargument name="dataGateway" type="any" required="true" />
		<cfargument name="sourceAdapter" type="any" required="false" default="" />
		<cfargument name="graphService" type="any" required="false" default="" />
		<cfargument name="loggerService" type="any" required="false" default="" />
		<cfset variables.gw = arguments.dataGateway />
		<cfif isObject( arguments.sourceAdapter )>
			<cfset variables.adapter = arguments.sourceAdapter />
		<cfelse>
			<cfset variables.adapter = createObject( "component", "services.SourceAdapter" ).init() />
		</cfif>
		<cfset variables.graph = arguments.graphService />
		<cfset variables.loggerService = arguments.loggerService />
		<cfreturn this />
	</cffunction>

	<cffunction name="upsertDefinition" access="public" returntype="void" output="false">
		<cfargument name="sourceKey" type="string" required="true" />
		<cfargument name="adapterKind" type="string" required="true" />
		<cfargument name="label" type="string" required="false" default="" />
		<cfargument name="urlTemplate" type="string" required="false" default="" />
		<cfargument name="parserKind" type="string" required="false" default="" />
		<cfargument name="maxRunsPerDay" type="numeric" required="false" default="1" />
		<cfargument name="minIntervalMinutes" type="numeric" required="false" default="1440" />
		<cfargument name="enabled" type="numeric" required="false" default="1" />
		<cfargument name="configJson" type="string" required="false" default="" />
		<cfset variables.gw.execute(
			"INSERT INTO source_definitions
			   (source_key, adapter_kind, label, url_template, parser_kind, max_runs_per_day, min_interval_minutes, enabled, config_json, created_at)
			 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, " & variables.gw.nowExpr() & ")
			 ON CONFLICT(source_key) DO UPDATE SET
			   adapter_kind         = excluded.adapter_kind,
			   label                = excluded.label,
			   url_template         = excluded.url_template,
			   parser_kind          = excluded.parser_kind,
			   max_runs_per_day     = excluded.max_runs_per_day,
			   min_interval_minutes = excluded.min_interval_minutes,
			   enabled              = excluded.enabled,
			   config_json          = excluded.config_json",
			[
				{ value: arguments.sourceKey, cfsqltype: "cf_sql_varchar" },
				{ value: arguments.adapterKind, cfsqltype: "cf_sql_varchar" },
				{ value: arguments.label, cfsqltype: "cf_sql_varchar" },
				{ value: arguments.urlTemplate, cfsqltype: "cf_sql_varchar" },
				{ value: arguments.parserKind, cfsqltype: "cf_sql_varchar" },
				{ value: arguments.maxRunsPerDay, cfsqltype: "cf_sql_integer" },
				{ value: arguments.minIntervalMinutes, cfsqltype: "cf_sql_integer" },
				{ value: arguments.enabled, cfsqltype: "cf_sql_integer" },
				{ value: arguments.configJson, cfsqltype: "cf_sql_longvarchar" }
			]
		) />
	</cffunction>

	<cffunction name="listDefinitions" access="public" returntype="array" output="false">
		<cfargument name="enabledOnly" type="boolean" required="false" default="true" />
		<cfif arguments.enabledOnly>
			<cfreturn variables.gw.queryArray(
				"SELECT source_key, adapter_kind, label, url_template, parser_kind, config_json, enabled
				 FROM source_definitions WHERE enabled = 1 ORDER BY source_key"
			) />
		</cfif>
		<cfreturn variables.gw.queryArray(
			"SELECT source_key, adapter_kind, label, url_template, parser_kind, config_json, enabled
			 FROM source_definitions ORDER BY source_key"
		) />
	</cffunction>

	<!--- Onboard enabled per-company definitions into companies the pipeline scans. --->
	<cffunction name="syncDefinitions" access="public" returntype="struct" output="false">
		<cfset var summary = { onboarded: [], skipped: [] } />
		<cfset var defs = listDefinitions( true ) />
		<cfset var d = "" />
		<cfloop array="#defs#" index="d">
			<cfset var careersSource = variables.adapter.careersSourceFor( d.adapter_kind ) />

			<!--- Only per-company source kinds are onboarded here; global feeds are
			     managed by ensureFeedSources(). --->
			<cfif NOT listFindNoCase( "greenhouse,career_page_scan", careersSource )>
				<cfset arrayAppend( summary.skipped, d.source_key & " (kind not onboardable: " & d.adapter_kind & ")" ) />
				<cfcontinue />
			</cfif>

			<cfset var careersUrl = trim( d.url_template ) />
			<cfif NOT len( careersUrl )>
				<cfset arrayAppend( summary.skipped, d.source_key & " (no url_template)" ) />
				<cfcontinue />
			</cfif>

			<cfset var existing = variables.gw.queryRow(
				"SELECT id FROM companies WHERE careers_url = ?",
				[ { value: careersUrl, cfsqltype: "cf_sql_varchar" } ]
			) />
			<cfif NOT structIsEmpty( existing )>
				<cfset arrayAppend( summary.skipped, d.source_key & " (company already exists)" ) />
				<cfcontinue />
			</cfif>

			<cfset var nm = len( trim( d.label ) ) ? d.label : d.source_key />
			<cfset var atsConfig = len( trim( d.config_json ) ) ? d.config_json : "" />
			<cfset variables.gw.execute(
				"INSERT INTO companies (name, website, careers_url, careers_source, ats_config, created_at, updated_at)
				 VALUES (?, '', ?, ?, ?, " & variables.gw.nowExpr() & ", " & variables.gw.nowExpr() & ")",
				[
					{ value: nm, cfsqltype: "cf_sql_varchar" },
					{ value: careersUrl, cfsqltype: "cf_sql_varchar" },
					{ value: careersSource, cfsqltype: "cf_sql_varchar" },
					{ value: atsConfig, cfsqltype: "cf_sql_longvarchar" }
				]
			) />
			<cfset arrayAppend( summary.onboarded, d.source_key ) />

			<!--- Register as a candidate graph node + provenance edge. --->
			<cfif isObject( variables.graph )>
				<cfset variables.graph.registerSource( d.source_key, "ingest_source", nm, "candidate" ) />
				<cfset variables.graph.addEdge( "source_definition", "spawned_source", d.source_key ) />
			</cfif>
		</cfloop>

		<cfif isObject( variables.loggerService )>
			<cfset variables.loggerService.info(
				"Source onboarding: onboarded=" & arrayLen( summary.onboarded )
				& " skipped=" & arrayLen( summary.skipped )
			) />
		</cfif>
		<cfreturn summary />
	</cffunction>
</cfcomponent>
