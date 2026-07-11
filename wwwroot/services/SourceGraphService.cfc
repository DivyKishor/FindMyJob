<cfcomponent output="false" accessors="true">
	<!---
		SourceGraphService — Phase 3, PR 3.1.

		Maintains the source graph: nodes (sources), provenance edges (source_edges),
		and yield metrics (source_metrics). The expansion engine (PR 3.2) and the
		scheduler (PR 3.4) read these to grow/shrink and pace the source set.

		DB access goes through DataGateway so dialect quirks stay in one place.
		Tag syntax only (project standard).
	--->
	<cfproperty name="gw" type="any" />
	<cfproperty name="loggerService" type="any" />

	<cffunction name="init" access="public" returntype="any" output="false">
		<cfargument name="dataGateway" type="any" required="true" />
		<cfargument name="loggerService" type="any" required="false" default="" />
		<cfset variables.gw = arguments.dataGateway />
		<cfset variables.loggerService = arguments.loggerService />
		<cfreturn this />
	</cffunction>

	<!--- Upsert a source node. Existing status is preserved on conflict. --->
	<cffunction name="registerSource" access="public" returntype="void" output="false">
		<cfargument name="sourceKey" type="string" required="true" />
		<cfargument name="sourceType" type="string" required="true" />
		<cfargument name="label" type="string" required="false" default="" />
		<cfargument name="status" type="string" required="false" default="active" />
		<cfargument name="originSourceKey" type="string" required="false" default="" />
		<cfset variables.gw.execute(
			"INSERT INTO sources (source_key, source_type, label, status, origin_source_key, created_at, updated_at)
			 VALUES (?, ?, ?, ?, ?, " & variables.gw.nowExpr() & ", " & variables.gw.nowExpr() & ")
			 ON CONFLICT(source_key) DO UPDATE SET
			   source_type = excluded.source_type,
			   label       = excluded.label,
			   updated_at  = " & variables.gw.nowExpr(),
			[
				{ value: arguments.sourceKey, cfsqltype: "cf_sql_varchar" },
				{ value: arguments.sourceType, cfsqltype: "cf_sql_varchar" },
				{ value: arguments.label, cfsqltype: "cf_sql_varchar" },
				{ value: arguments.status, cfsqltype: "cf_sql_varchar" },
				{ value: arguments.originSourceKey, cfsqltype: "cf_sql_varchar" }
			]
		) />
	</cffunction>

	<cffunction name="setStatus" access="public" returntype="void" output="false">
		<cfargument name="sourceKey" type="string" required="true" />
		<cfargument name="status" type="string" required="true" />
		<cfset variables.gw.execute(
			"UPDATE sources SET status = ?, updated_at = " & variables.gw.nowExpr() & " WHERE source_key = ?",
			[
				{ value: arguments.status, cfsqltype: "cf_sql_varchar" },
				{ value: arguments.sourceKey, cfsqltype: "cf_sql_varchar" }
			]
		) />
	</cffunction>

	<!--- Record a provenance edge (deduped on from+relation+target). --->
	<cffunction name="addEdge" access="public" returntype="void" output="false">
		<cfargument name="fromSourceKey" type="string" required="true" />
		<cfargument name="relation" type="string" required="true" />
		<cfargument name="targetRef" type="string" required="true" />
		<cfargument name="weight" type="numeric" required="false" default="1" />
		<cfset variables.gw.execute(
			variables.gw.insertIgnorePrefix()
			& " INTO source_edges (from_source_key, relation, target_ref, weight, created_at)
			    VALUES (?, ?, ?, ?, " & variables.gw.nowExpr() & ")"
			& variables.gw.insertIgnoreConflict( "from_source_key, relation, target_ref" ),
			[
				{ value: arguments.fromSourceKey, cfsqltype: "cf_sql_varchar" },
				{ value: arguments.relation, cfsqltype: "cf_sql_varchar" },
				{ value: arguments.targetRef, cfsqltype: "cf_sql_varchar" },
				{ value: arguments.weight, cfsqltype: "cf_sql_double" }
			]
		) />
	</cffunction>

	<!--- Increment run metrics for a source and recompute its yield score. --->
	<cffunction name="recordRun" access="public" returntype="void" output="false">
		<cfargument name="sourceKey" type="string" required="true" />
		<cfargument name="itemsFound" type="numeric" required="false" default="0" />
		<cfargument name="companiesFound" type="numeric" required="false" default="0" />
		<cfargument name="jobsFound" type="numeric" required="false" default="0" />
		<cfargument name="errors" type="numeric" required="false" default="0" />
		<cfset variables.gw.execute(
			"INSERT INTO source_metrics (source_key, runs, items_found, companies_found, jobs_found, errors, last_run_at, updated_at)
			 VALUES (?, 1, ?, ?, ?, ?, " & variables.gw.nowExpr() & ", " & variables.gw.nowExpr() & ")
			 ON CONFLICT(source_key) DO UPDATE SET
			   runs            = source_metrics.runs + 1,
			   items_found     = source_metrics.items_found + excluded.items_found,
			   companies_found = source_metrics.companies_found + excluded.companies_found,
			   jobs_found      = source_metrics.jobs_found + excluded.jobs_found,
			   errors          = source_metrics.errors + excluded.errors,
			   last_run_at     = " & variables.gw.nowExpr() & ",
			   updated_at      = " & variables.gw.nowExpr(),
			[
				{ value: arguments.sourceKey, cfsqltype: "cf_sql_varchar" },
				{ value: arguments.itemsFound, cfsqltype: "cf_sql_integer" },
				{ value: arguments.companiesFound, cfsqltype: "cf_sql_integer" },
				{ value: arguments.jobsFound, cfsqltype: "cf_sql_integer" },
				{ value: arguments.errors, cfsqltype: "cf_sql_integer" }
			]
		) />
		<!--- yield = (companies + jobs) per run; guard divide-by-zero. --->
		<cfset variables.gw.execute(
			"UPDATE source_metrics
			 SET yield_score = ( companies_found + jobs_found ) * 1.0 / ( CASE WHEN runs = 0 THEN 1 ELSE runs END )
			 WHERE source_key = ?",
			[ { value: arguments.sourceKey, cfsqltype: "cf_sql_varchar" } ]
		) />
	</cffunction>

	<cffunction name="getMetric" access="public" returntype="struct" output="false">
		<cfargument name="sourceKey" type="string" required="true" />
		<cfreturn variables.gw.queryRow(
			"SELECT source_key, runs, items_found, companies_found, jobs_found, errors, yield_score, last_run_at
			 FROM source_metrics WHERE source_key = ?",
			[ { value: arguments.sourceKey, cfsqltype: "cf_sql_varchar" } ]
		) />
	</cffunction>

	<cffunction name="listMetrics" access="public" returntype="array" output="false">
		<cfreturn variables.gw.queryArray(
			"SELECT source_key, runs, items_found, companies_found, jobs_found, errors, yield_score, last_run_at
			 FROM source_metrics ORDER BY yield_score DESC, runs DESC"
		) />
	</cffunction>

	<cffunction name="listSourcesByStatus" access="public" returntype="array" output="false">
		<cfargument name="status" type="string" required="true" />
		<cfreturn variables.gw.queryArray(
			"SELECT source_key, source_type, label, status, origin_source_key
			 FROM sources WHERE status = ? ORDER BY source_key",
			[ { value: arguments.status, cfsqltype: "cf_sql_varchar" } ]
		) />
	</cffunction>

	<cffunction name="countEdgesFrom" access="public" returntype="numeric" output="false">
		<cfargument name="fromSourceKey" type="string" required="true" />
		<cfreturn val( variables.gw.scalar(
			"SELECT COUNT(*) FROM source_edges WHERE from_source_key = ?",
			[ { value: arguments.fromSourceKey, cfsqltype: "cf_sql_varchar" } ],
			0
		) ) />
	</cffunction>

	<!--- Seed graph nodes from existing companies so the graph reflects current state. --->
	<cffunction name="backfillFromExisting" access="public" returntype="struct" output="false">
		<cfset var summary = { nodes: 0 } />
		<cfset var rows = variables.gw.queryArray(
			"SELECT DISTINCT careers_source FROM companies WHERE careers_source IS NOT NULL AND trim(careers_source) <> ''"
		) />
		<cfset var r = "" />
		<cfloop array="#rows#" index="r">
			<cfset registerSource( r.careers_source, "ingest_source", r.careers_source, "active" ) />
			<cfset summary.nodes = summary.nodes + 1 />
		</cfloop>
		<cfif isObject( variables.loggerService )>
			<cfset variables.loggerService.info( "Source graph backfill: " & summary.nodes & " nodes" ) />
		</cfif>
		<cfreturn summary />
	</cffunction>
</cfcomponent>
