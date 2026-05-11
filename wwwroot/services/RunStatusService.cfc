<cfcomponent output="false" accessors="true">
	<cfproperty name="databaseService" type="any" />

	<cffunction name="init" access="public" returntype="any" output="false">
		<cfargument name="databaseService" type="any" required="true" />
		<cfset variables.databaseService = arguments.databaseService />
		<cfreturn this />
	</cffunction>

	<cffunction name="ds" access="private" returntype="string" output="false">
		<cfreturn variables.databaseService.getDatasource() />
	</cffunction>

	<cffunction name="recordSuccess" access="public" returntype="void" output="false">
		<cfargument name="summary" type="struct" required="true" />
		<cfset allErrors = [] />
		<cfif structKeyExists( arguments.summary, "discovery" ) AND structKeyExists( arguments.summary.discovery, "errors" ) AND isArray( arguments.summary.discovery.errors )>
			<cfloop array="#arguments.summary.discovery.errors#" index="errMsg"><cfset arrayAppend( allErrors, errMsg ) /></cfloop>
		</cfif>
		<cfif structKeyExists( arguments.summary, "scrape" ) AND structKeyExists( arguments.summary.scrape, "errors" ) AND isArray( arguments.summary.scrape.errors )>
			<cfloop array="#arguments.summary.scrape.errors#" index="errMsg"><cfset arrayAppend( allErrors, errMsg ) /></cfloop>
		</cfif>
		<cfset errorCount = arrayLen( allErrors ) />
		<cfset errorsJson = serializeJSON( allErrors ) />
		<cfset queryExecute(
			"INSERT INTO pipeline_runs (run_at, status, jobs_upserted, jobs_scored, alerts_created, error_count, summary_json, errors_json)
			 VALUES (datetime('now'), 'success', ?, ?, ?, ?, ?, ?)",
			[
				{ value: getStructValueOrDefault( arguments.summary.scrape, "jobsUpserted", 0 ), cfsqltype: "cf_sql_integer" },
				{ value: getStructValueOrDefault( arguments.summary.score, "jobsScored", 0 ), cfsqltype: "cf_sql_integer" },
				{ value: getStructValueOrDefault( arguments.summary.alerts, "alertsCreated", 0 ), cfsqltype: "cf_sql_integer" },
				{ value: errorCount, cfsqltype: "cf_sql_integer" },
				{ value: serializeJSON( arguments.summary ), cfsqltype: "cf_sql_longvarchar" },
				{ value: errorsJson, cfsqltype: "cf_sql_longvarchar" }
			],
			{ datasource: ds() }
		) />
	</cffunction>

	<cffunction name="recordFailure" access="public" returntype="void" output="false">
		<cfargument name="message" type="string" required="true" />
		<cfargument name="detail" type="string" required="false" default="" />
		<cfset errArray = [ arguments.message ] />
		<cfif len( trim( arguments.detail ) )>
			<cfset arrayAppend( errArray, arguments.detail ) />
		</cfif>
		<cfset queryExecute(
			"INSERT INTO pipeline_runs (run_at, status, jobs_upserted, jobs_scored, alerts_created, error_count, summary_json, errors_json)
			 VALUES (datetime('now'), 'failed', 0, 0, 0, ?, ?, ?)",
			[
				{ value: arrayLen( errArray ), cfsqltype: "cf_sql_integer" },
				{ value: "{}", cfsqltype: "cf_sql_longvarchar" },
				{ value: serializeJSON( errArray ), cfsqltype: "cf_sql_longvarchar" }
			],
			{ datasource: ds() }
		) />
	</cffunction>

	<cffunction name="getLatestRun" access="public" returntype="struct" output="false">
		<cfset q = queryExecute(
			"SELECT id, run_at, status, jobs_upserted, jobs_scored, alerts_created, error_count, summary_json, errors_json
			 FROM pipeline_runs
			 ORDER BY id DESC
			 LIMIT 1",
			{},
			{ datasource: ds() }
		) />
		<cfif q.recordCount EQ 0>
			<cfreturn {} />
		</cfif>
		<cfset row = variables.databaseService.queryToArray( q )[ 1 ] />
		<cfset row.summary = parseJsonStruct( row.summary_json ) />
		<cfset row.errors = parseJsonArray( row.errors_json ) />
		<cfset structDelete( row, "summary_json" ) />
		<cfset structDelete( row, "errors_json" ) />
		<cfreturn row />
	</cffunction>

	<cffunction name="parseJsonStruct" access="private" returntype="struct" output="false">
		<cfargument name="jsonText" type="any" required="true" />
		<cfif isSimpleValue( arguments.jsonText ) AND len( trim( arguments.jsonText ) )>
			<cftry>
				<cfreturn deserializeJSON( arguments.jsonText ) />
				<cfcatch type="any">
					<cfreturn {} />
				</cfcatch>
			</cftry>
		</cfif>
		<cfreturn {} />
	</cffunction>

	<cffunction name="parseJsonArray" access="private" returntype="array" output="false">
		<cfargument name="jsonText" type="any" required="true" />
		<cfif isSimpleValue( arguments.jsonText ) AND len( trim( arguments.jsonText ) )>
			<cftry>
				<cfset parsed = deserializeJSON( arguments.jsonText ) />
				<cfif isArray( parsed )>
					<cfreturn parsed />
				</cfif>
				<cfcatch type="any">
					<cfreturn [] />
				</cfcatch>
			</cftry>
		</cfif>
		<cfreturn [] />
	</cffunction>

	<cffunction name="getStructValueOrDefault" access="private" returntype="any" output="false">
		<cfargument name="target" type="any" required="true" />
		<cfargument name="keyName" type="string" required="true" />
		<cfargument name="defaultValue" type="any" required="true" />
		<cfif isStruct( arguments.target ) AND structKeyExists( arguments.target, arguments.keyName )>
			<cfreturn arguments.target[ arguments.keyName ] />
		</cfif>
		<cfreturn arguments.defaultValue />
	</cffunction>
</cfcomponent>
