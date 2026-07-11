<cfcomponent output="false" accessors="true">
	<!---
		CompanyScoreService — Phase 2, PR 2.2.

		Combines three evidence sources into a company-level CF likelihood score
		(0–100), persists the result to company_scores, and updates
		companies.cf_likelihood_score for the dashboard.

		Scoring breakdown:
		  Fingerprint evidence  0–50   sum(signal weights) / MAX_WEIGHT * 50
		  Discovery signals     0–30   average top-3 confidence / 100 * 30
		  Job history           0–20   tiered by total job count for that company
		  ─────────────────────────────────────────────────────────────────────
		  MAX = 100

		Rule version: v1_company_cf_likelihood
		  (bumped when algorithm changes; old rows kept for history)

		Tag syntax only (project standard).
	--->

	<cfproperty name="dataGateway"   type="any" />
	<cfproperty name="loggerService" type="any" />

	<cfset variables.RULE_VERSION   = "v1_company_cf_likelihood" />
	<!--- Mirror of TechFingerprinter.MAX_WEIGHT for subscore normalisation. --->
	<cfset variables.MAX_FP_WEIGHT  = 3.5 + 3.5 + 3.0 + 3.0 + 2.5 + 2.5 + 2.0 + 2.0 />

	<cffunction name="init" access="public" returntype="any" output="false">
		<cfargument name="dataGateway"   type="any" required="true" />
		<cfargument name="loggerService" type="any" required="true" />
		<cfset variables.dataGateway   = arguments.dataGateway />
		<cfset variables.loggerService = arguments.loggerService />
		<cfreturn this />
	</cffunction>

	<!--- ===== Public API ===== --->

	<!---
		scoreCompany( companyId ) — load evidence, compute score, persist, return result.
		Returns { score, reasons, fpScore, discovScore, jobScore, ruleVersion }.
	--->
	<cffunction name="scoreCompany" access="public" returntype="struct" output="false">
		<cfargument name="companyId" type="numeric" required="true" />
		<cfset var cid = val( arguments.companyId ) />

		<!--- Load fingerprint signals. --->
		<cfset var fpRows = variables.dataGateway.queryArray(
			"SELECT signal, evidence, weight FROM tech_fingerprints WHERE company_id = ?",
			[ { value: cid, cfsqltype: "cf_sql_integer" } ]
		) />

		<!--- Load discovery signals — join via company domain extracted from website. --->
		<cfset var companyRow = variables.dataGateway.queryRow(
			"SELECT website FROM companies WHERE id = ?",
			[ { value: cid, cfsqltype: "cf_sql_integer" } ]
		) />
		<cfset var sigRows = [] />
		<cfif structKeyExists( companyRow, "website" ) AND len( trim( companyRow.website ) )>
			<!--- Extract host from website URL for a fuzzy domain match. --->
			<cfset var domainHint = extractDomainFromUrl( companyRow.website ) />
			<cfif len( domainHint )>
				<cfset sigRows = variables.dataGateway.queryArray(
					"SELECT confidence_score
					 FROM discovery_signals
					 WHERE company_domain LIKE ?
					 ORDER BY confidence_score DESC
					 LIMIT 3",
					[ { value: "%" & domainHint & "%", cfsqltype: "cf_sql_varchar" } ]
				) />
			</cfif>
		</cfif>

		<!--- Job history with a recency window: jobs in the last 365 days drive the base
		     sub-score; jobs in the last 90 days add a "hiring now" bump. --->
		<cfset var jobs365Row = variables.dataGateway.queryRow(
			"SELECT COUNT(*) AS cnt FROM jobs
			 WHERE company_id = ? AND COALESCE(first_seen_at, fetched_at) >= datetime('now', '-365 days')",
			[ { value: cid, cfsqltype: "cf_sql_integer" } ]
		) />
		<cfset var jobs90Row = variables.dataGateway.queryRow(
			"SELECT COUNT(*) AS cnt FROM jobs
			 WHERE company_id = ? AND COALESCE(first_seen_at, fetched_at) >= datetime('now', '-90 days')",
			[ { value: cid, cfsqltype: "cf_sql_integer" } ]
		) />
		<cfset var jobs365 = structKeyExists( jobs365Row, "cnt" ) ? val( jobs365Row.cnt ) : 0 />
		<cfset var jobs90  = structKeyExists( jobs90Row, "cnt" ) ? val( jobs90Row.cnt ) : 0 />

		<!--- Compute pure score (jobCount = last-12-month count; jobs90d = last-90-day count). --->
		<cfset var result = scoreCompanyData( fpRows, sigRows, jobs365, jobs90 ) />

		<!--- Persist to company_scores and update companies.cf_likelihood_score. --->
		<cfset persistCompanyScore( cid, result.score, result.reasons ) />

		<cfreturn result />
	</cffunction>

	<!---
		scoreCompanyData( fpRows, signalRows, jobCount )
		  Pure scoring function — separated so it can be unit-tested without a DB.
		  fpRows:      array of { signal, evidence, weight }
		  signalRows:  array of { confidence_score }
		  jobCount:    integer
	--->
	<cffunction name="scoreCompanyData" access="public" returntype="struct" output="false">
		<cfargument name="fpRows"     type="array"   required="true" />
		<cfargument name="signalRows" type="array"   required="true" />
		<cfargument name="jobCount"   type="numeric" required="true" /><!--- jobs in last 12 months --->
		<cfargument name="jobs90d"    type="numeric" required="false" default="0" /><!--- jobs in last 90 days --->


		<cfset var reasons = [] />

		<!--- Fingerprint subscore (0-50). --->
		<cfset var fpWeight = 0 />
		<cfloop array="#arguments.fpRows#" index="fp">
			<cfset fpWeight = fpWeight + val( fp.weight ) />
			<cfset arrayAppend( reasons, "fp:" & fp.signal ) />
		</cfloop>
		<cfset var fpScore = 0 />
		<cfif variables.MAX_FP_WEIGHT GT 0 AND fpWeight GT 0>
			<cfset fpScore = min( 50, int( ( fpWeight / variables.MAX_FP_WEIGHT ) * 50 ) ) />
		</cfif>
		<cfif fpScore GT 0>
			<cfset arrayAppend( reasons, "fp_score=" & fpScore ) />
		</cfif>

		<!--- Discovery subscore (0-30): average of top-3 confidence scores * 30 / 100. --->
		<cfset var discovScore = 0 />
		<cfif arrayLen( arguments.signalRows ) GT 0>
			<cfset var sigTotal = 0 />
			<cfloop array="#arguments.signalRows#" index="sig">
				<cfset sigTotal = sigTotal + val( sig.confidence_score ) />
			</cfloop>
			<cfset var sigAvg = sigTotal / arrayLen( arguments.signalRows ) />
			<cfset discovScore = min( 30, int( ( sigAvg / 100 ) * 30 ) ) />
			<cfif discovScore GT 0>
				<cfset arrayAppend( reasons, "discovery:avg_confidence=" & int( sigAvg ) ) />
			</cfif>
		</cfif>

		<!--- Job history subscore (0-20): base by 12-month volume, + recency bump. --->
		<cfset var jobScore = 0 />
		<cfif arguments.jobCount GTE 10>
			<cfset jobScore = 20 />
		<cfelseif arguments.jobCount GTE 5>
			<cfset jobScore = 15 />
		<cfelseif arguments.jobCount GTE 1>
			<cfset jobScore = 10 />
		</cfif>
		<cfif arguments.jobCount GT 0>
			<cfset arrayAppend( reasons, "jobs:" & arguments.jobCount ) />
		</cfif>
		<!--- Recently-hiring companies are stronger leads: bump if they posted in the last 90 days. --->
		<cfif arguments.jobs90d GTE 3>
			<cfset jobScore = min( 20, jobScore + 5 ) />
			<cfset arrayAppend( reasons, "hiring_now:" & arguments.jobs90d & "_in_90d" ) />
		<cfelseif arguments.jobs90d GTE 1>
			<cfset arrayAppend( reasons, "recent_posting:" & arguments.jobs90d & "_in_90d" ) />
		</cfif>

		<cfset var totalScore = min( 100, fpScore + discovScore + jobScore ) />

		<cfreturn {
			score:        totalScore,
			reasons:      reasons,
			fpScore:      fpScore,
			discovScore:  discovScore,
			jobScore:     jobScore,
			ruleVersion:  variables.RULE_VERSION
		} />
	</cffunction>

	<!---
		scoreAllCompanies() — score every company in one run.
		Returns { scored, errors }.
	--->
	<cffunction name="scoreAllCompanies" access="public" returntype="struct" output="false">
		<cfset var q = variables.dataGateway.query( "SELECT id FROM companies ORDER BY id" ) />
		<cfset var scored = 0 />
		<cfset var errors = [] />
		<cfloop query="q">
			<cftry>
				<cfset scoreCompany( val( q.id ) ) />
				<cfset scored = scored + 1 />
				<cfcatch type="any">
					<cfset arrayAppend( errors, "company_id=#q.id#: #cfcatch.message#" ) />
					<cfset variables.loggerService.warn( "CompanyScoreService error company #q.id#: #cfcatch.message#" ) />
				</cfcatch>
			</cftry>
		</cfloop>
		<cfreturn { scored: scored, errors: errors } />
	</cffunction>

	<!--- ===== Private helpers ===== --->

	<cffunction name="persistCompanyScore" access="private" returntype="void" output="false">
		<cfargument name="companyId" type="numeric" required="true" />
		<cfargument name="score"     type="numeric" required="true" />
		<cfargument name="reasons"   type="array"   required="true" />

		<!--- Insert versioned score row. --->
		<cfset variables.dataGateway.execute(
			"INSERT INTO company_scores (company_id, rule_version, score, reasons_json, created_at)
			 VALUES (?, ?, ?, ?, datetime('now'))",
			[
				{ value: val( arguments.companyId ), cfsqltype: "cf_sql_integer" },
				{ value: variables.RULE_VERSION,      cfsqltype: "cf_sql_varchar" },
				{ value: int( arguments.score ),       cfsqltype: "cf_sql_integer" },
				{ value: serializeJSON( arguments.reasons ), cfsqltype: "cf_sql_longvarchar" }
			]
		) />

		<!--- Denormalise: keep companies.cf_likelihood_score current for fast dashboard sorts. --->
		<cfset variables.dataGateway.execute(
			"UPDATE companies SET cf_likelihood_score = ?, updated_at = datetime('now') WHERE id = ?",
			[
				{ value: int( arguments.score ),       cfsqltype: "cf_sql_integer" },
				{ value: val( arguments.companyId ), cfsqltype: "cf_sql_integer" }
			]
		) />
	</cffunction>

	<!---
		extractDomainFromUrl — strips protocol and path from a URL to get the bare host.
		"https://www.example.com/page" -> "example.com"
	--->
	<cffunction name="extractDomainFromUrl" access="private" returntype="string" output="false">
		<cfargument name="url" type="string" required="true" />
		<cfset var u = trim( arguments.url ) />
		<!--- Remove protocol --->
		<cfset u = reReplaceNoCase( u, "^https?://", "", "one" ) />
		<!--- Remove path --->
		<cfset var slashPos = find( "/", u ) />
		<cfif slashPos GT 1><cfset u = left( u, slashPos - 1 ) /></cfif>
		<!--- Remove www. prefix for better matching --->
		<cfset u = reReplaceNoCase( u, "^www\.", "", "one" ) />
		<cfreturn lCase( trim( u ) ) />
	</cffunction>

</cfcomponent>
