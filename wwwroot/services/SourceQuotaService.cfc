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

	<cffunction name="canRun" access="public" returntype="struct" output="false">
		<cfargument name="sourceKey" type="string" required="true" />
		<cfargument name="maxRunsPerDay" type="numeric" required="false" default="1" />
		<cfargument name="minIntervalMinutes" type="numeric" required="false" default="1440" />

		<cfif arguments.maxRunsPerDay LT 1><cfset arguments.maxRunsPerDay = 1 /></cfif>
		<cfif arguments.minIntervalMinutes LT 0><cfset arguments.minIntervalMinutes = 0 /></cfif>

		<cfset qDaily = queryExecute(
			"SELECT COUNT(*) AS cnt
			 FROM source_run_log
			 WHERE source_key = ?
			   AND date(run_at) = date('now')",
			[ { value: arguments.sourceKey, cfsqltype: "cf_sql_varchar" } ],
			{ datasource: ds() }
		) />
		<cfset cntCol = listFirst( qDaily.columnList ) />
		<cfset todayCount = val( qDaily[ cntCol ][ 1 ] ) />
		<cfif todayCount GTE arguments.maxRunsPerDay>
			<cfreturn { allowed: false, reason: "daily_quota_exceeded", todayCount: todayCount } />
		</cfif>

		<cfif arguments.minIntervalMinutes GT 0>
			<cfset qLast = queryExecute(
				"SELECT run_at
				 FROM source_run_log
				 WHERE source_key = ?
				 ORDER BY id DESC
				 LIMIT 1",
				[ { value: arguments.sourceKey, cfsqltype: "cf_sql_varchar" } ],
				{ datasource: ds() }
			) />
			<cfif qLast.recordCount GT 0>
				<cfset lastRun = parseDateTime( qLast.run_at[ 1 ] ) />
				<cfset diffMin = dateDiff( "n", lastRun, now() ) />
				<cfif diffMin LT arguments.minIntervalMinutes>
					<cfreturn { allowed: false, reason: "interval_not_elapsed", minutesSinceLastRun: diffMin } />
				</cfif>
			</cfif>
		</cfif>

		<cfreturn { allowed: true, reason: "ok", todayCount: todayCount } />
	</cffunction>

	<cffunction name="markRun" access="public" returntype="void" output="false">
		<cfargument name="sourceKey" type="string" required="true" />
		<cfset queryExecute(
			"INSERT INTO source_run_log (source_key, run_at)
			 VALUES (?, datetime('now'))",
			[ { value: arguments.sourceKey, cfsqltype: "cf_sql_varchar" } ],
			{ datasource: ds() }
		) />
	</cffunction>
</cfcomponent>
