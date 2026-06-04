<cfcomponent output="false" accessors="true">
	<cfproperty name="databaseService" type="any" />
	<cfproperty name="scoringService" type="any" />
	<cfproperty name="loggerService" type="any" />

	<cffunction name="init" access="public" returntype="any" output="false">
		<cfargument name="databaseService" type="any" required="true" />
		<cfargument name="scoringService" type="any" required="true" />
		<cfargument name="loggerService" type="any" required="true" />
		<cfset variables.databaseService = arguments.databaseService />
		<cfset variables.scoringService = arguments.scoringService />
		<cfset variables.loggerService = arguments.loggerService />
		<cfreturn this />
	</cffunction>

	<cffunction name="ds" access="private" returntype="string" output="false">
		<cfreturn variables.databaseService.getDatasource() />
	</cffunction>

	<cffunction name="scoreAllJobs" access="public" returntype="struct" output="false">
		<cfset q = queryExecute( "SELECT id, company_id, title, description, location FROM jobs ORDER BY id", {}, { datasource: ds() } ) />
		<cfset scored = 0 />
		<cfset alertEligible = 0 />
		<cfset indiaYes = 0 />
		<cfloop from="1" to="#q.recordCount#" index="rowNum">
			<cfset loc = "" />
			<cftry><cfset loc = q.location[ rowNum ] /><cfcatch type="any"></cfcatch></cftry>
			<cfset scoreResult = variables.scoringService.scoreJob( title = q.title[ rowNum ], description = q.description[ rowNum ], location = loc ) />
			<cfset upsertScore( q.id[ rowNum ], scoreResult.ruleVersion, scoreResult.score, scoreResult.reasons ) />
			<cfset scored = scored + 1 />
			<cfif scoreResult.alertEligible>
				<cfset alertEligible = alertEligible + 1 />
			</cfif>
			<cfif structKeyExists( scoreResult, "indiaEligible" ) AND ( scoreResult.indiaEligible EQ "yes" OR scoreResult.indiaEligible EQ "likely" )>
				<cfset indiaYes = indiaYes + 1 />
			</cfif>
		</cfloop>
		<cfset refreshCompanyScores() />
		<cfset variables.loggerService.info( "Scoring finished: jobsScored=#scored# alertEligible=#alertEligible#" ) />
		<cfreturn {
			jobsScored: scored,
			alertEligible: alertEligible,
			indiaEligible: indiaYes,
			ruleVersion: variables.scoringService.getRuleVersion()
		} />
	</cffunction>

	<cffunction name="upsertScore" access="private" returntype="void" output="false">
		<cfargument name="jobId" type="numeric" required="true" />
		<cfargument name="ruleVersion" type="string" required="true" />
		<cfargument name="score" type="numeric" required="true" />
		<cfargument name="reasons" type="array" required="true" />
		<cfset queryExecute(
			"INSERT INTO job_scores (job_id, rule_version, score, reasons_json, created_at)
			 VALUES (?, ?, ?, ?, datetime('now'))
			 ON CONFLICT(job_id, rule_version) DO UPDATE SET
			   score = excluded.score,
			   reasons_json = excluded.reasons_json,
			   created_at = datetime('now')",
			[
				{ value: arguments.jobId, cfsqltype: "cf_sql_integer" },
				{ value: arguments.ruleVersion, cfsqltype: "cf_sql_varchar" },
				{ value: arguments.score, cfsqltype: "cf_sql_integer" },
				{ value: serializeJSON( arguments.reasons ), cfsqltype: "cf_sql_longvarchar" }
			],
			{ datasource: ds() }
		) />
	</cffunction>

	<cffunction name="refreshCompanyScores" access="public" returntype="void" output="false">
		<cfset queryExecute(
			"UPDATE companies
			 SET cf_likelihood_score = COALESCE((
			   SELECT MAX(js.score)
			   FROM jobs j
			   INNER JOIN job_scores js ON js.job_id = j.id AND js.rule_version = ?
			   WHERE j.company_id = companies.id
			 ), 0),
			     updated_at = datetime('now')",
			[ { value: variables.scoringService.getRuleVersion(), cfsqltype: "cf_sql_varchar" } ],
			{ datasource: ds() }
		) />
	</cffunction>
</cfcomponent>
