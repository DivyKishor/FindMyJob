<cfcomponent output="false" accessors="true">
	<cfproperty name="databaseService" type="any" />
	<cfproperty name="jobScoreRuleVersion" type="string" />

	<cffunction name="init" access="public" returntype="any" output="false">
		<cfargument name="databaseService" type="any" required="true" />
		<cfargument name="jobScoreRuleVersion" type="string" required="false" default="v2_cf_direct" />
		<cfset variables.databaseService = arguments.databaseService />
		<cfset variables.jobScoreRuleVersion = arguments.jobScoreRuleVersion />
		<cfreturn this />
	</cffunction>

	<cffunction name="ds" access="private" returntype="string" output="false">
		<cfreturn variables.databaseService.getDatasource() />
	</cffunction>

	<cffunction name="list" access="public" returntype="array" output="false">
		<cfargument name="companyId" type="numeric" required="false" default="0" />
		<cfargument name="keyword" type="string" required="false" default="" />
		<cfargument name="minScore" type="numeric" required="false" default="0" />
		<cfargument name="locationKeyword" type="string" required="false" default="" />
		<cfset pageData = listPaged(
			companyId = arguments.companyId,
			keyword = arguments.keyword,
			minScore = arguments.minScore,
			page = 1,
			pageSize = 5000,
			sortBy = "fetched_at",
			sortDir = "desc",
			locationKeyword = arguments.locationKeyword
		) />
		<cfreturn pageData.rows />
	</cffunction>

	<cffunction name="listPaged" access="public" returntype="struct" output="false">
		<cfargument name="companyId" type="numeric" required="false" default="0" />
		<cfargument name="keyword" type="string" required="false" default="" />
		<cfargument name="minScore" type="numeric" required="false" default="0" />
		<cfargument name="page" type="numeric" required="false" default="1" />
		<cfargument name="pageSize" type="numeric" required="false" default="25" />
		<cfargument name="sortBy" type="string" required="false" default="fetched_at" />
		<cfargument name="sortDir" type="string" required="false" default="desc" />
		<cfargument name="locationKeyword" type="string" required="false" default="" />

		<cfif arguments.page LT 1><cfset arguments.page = 1 /></cfif>
		<cfif arguments.pageSize LT 1><cfset arguments.pageSize = 25 /></cfif>
		<cfif arguments.pageSize GT 200><cfset arguments.pageSize = 200 /></cfif>

		<cfset sortMap = {
			"fetched_at": "j.fetched_at",
			"title": "j.title",
			"location": "j.location",
			"company_name": "c.name",
			"score": "c.cf_likelihood_score"
		} />
		<cfset safeSortBy = lCase( arguments.sortBy ) />
		<cfif NOT structKeyExists( sortMap, safeSortBy )>
			<cfset safeSortBy = "fetched_at" />
		</cfif>
		<cfset safeSortDir = lCase( arguments.sortDir ) />
		<cfif safeSortDir NEQ "asc"><cfset safeSortDir = "desc" /></cfif>

		<cfset fromSql = " FROM jobs j INNER JOIN companies c ON c.id = j.company_id
			LEFT JOIN job_scores js ON js.job_id = j.id AND js.rule_version = ? WHERE 1=1" />
		<cfset params = [ { value: variables.jobScoreRuleVersion, cfsqltype: "cf_sql_varchar" } ] />

		<cfif arguments.companyId GT 0>
			<cfset fromSql = fromSql & " AND j.company_id = ?" />
			<cfset arrayAppend( params, { value: arguments.companyId, cfsqltype: "cf_sql_integer" } ) />
		</cfif>
		<cfif len( trim( arguments.keyword ) )>
			<cfset likeValue = "%" & arguments.keyword & "%" />
			<cfset fromSql = fromSql & " AND (j.title LIKE ? OR j.description LIKE ?)" />
			<cfset arrayAppend( params, { value: likeValue, cfsqltype: "cf_sql_varchar" } ) />
			<cfset arrayAppend( params, { value: likeValue, cfsqltype: "cf_sql_longvarchar" } ) />
		</cfif>
		<cfif arguments.minScore GT 0>
			<cfset fromSql = fromSql & " AND COALESCE(js.score, 0) >= ?" />
			<cfset arrayAppend( params, { value: arguments.minScore, cfsqltype: "cf_sql_integer" } ) />
		</cfif>
		<cfif len( trim( arguments.locationKeyword ) )>
			<cfset locationLike = "%" & arguments.locationKeyword & "%" />
			<cfset fromSql = fromSql & " AND lower(j.location) LIKE lower(?)" />
			<cfset arrayAppend( params, { value: locationLike, cfsqltype: "cf_sql_varchar" } ) />
		</cfif>

		<cfset countQ = queryExecute( "SELECT COUNT(*) AS cnt" & fromSql, params, { datasource: ds() } ) />
		<cfset cntCol = listFirst( countQ.columnList ) />
		<cfset totalRows = val( countQ[ cntCol ][ 1 ] ) />
		<cfif totalRows EQ 0>
			<cfset totalPages = 1 />
		<cfelse>
			<cfset totalPages = ceiling( totalRows / arguments.pageSize ) />
		</cfif>
		<cfif arguments.page GT totalPages><cfset arguments.page = totalPages /></cfif>
		<cfset offsetRows = ( arguments.page - 1 ) * arguments.pageSize />

		<cfset dataSql = "SELECT j.id, j.company_id, j.external_id, j.title, j.description, j.location, j.link, j.raw_source, j.fetched_at,
		                         c.name AS company_name, COALESCE(js.score, 0) AS score" &
			fromSql &
			" ORDER BY " & sortMap[ safeSortBy ] & " " & safeSortDir & ", j.id DESC LIMIT ? OFFSET ?" />

		<cfset dataParams = duplicate( params ) />
		<cfset arrayAppend( dataParams, { value: arguments.pageSize, cfsqltype: "cf_sql_integer" } ) />
		<cfset arrayAppend( dataParams, { value: offsetRows, cfsqltype: "cf_sql_integer" } ) />

		<cfset q = queryExecute( dataSql, dataParams, { datasource: ds() } ) />
		<cfset rows = variables.databaseService.queryToArray( q ) />
		<cfloop array="#rows#" index="rowItem">
			<cfset rowItem.score = val( rowItem.score ) />
		</cfloop>

		<cfreturn {
			rows: rows,
			totalRows: totalRows,
			page: arguments.page,
			pageSize: arguments.pageSize,
			totalPages: totalPages,
			sortBy: safeSortBy,
			sortDir: safeSortDir
		} />
	</cffunction>

	<cffunction name="upsertJob" access="public" returntype="void" output="false">
		<cfargument name="companyId" type="numeric" required="true" />
		<cfargument name="externalId" type="string" required="true" />
		<cfargument name="title" type="string" required="true" />
		<cfargument name="description" type="string" required="false" default="" />
		<cfargument name="location" type="string" required="false" default="" />
		<cfargument name="link" type="string" required="true" />
		<cfargument name="rawSource" type="string" required="true" />
		<cfset queryExecute(
			"INSERT INTO jobs (company_id, external_id, title, description, location, link, raw_source, fetched_at)
			 VALUES (?, ?, ?, ?, ?, ?, ?, datetime('now'))
			 ON CONFLICT(company_id, external_id) DO UPDATE SET
			   title = excluded.title,
			   description = excluded.description,
			   location = excluded.location,
			   link = excluded.link,
			   raw_source = excluded.raw_source,
			   fetched_at = datetime('now')",
			[
				{ value: arguments.companyId, cfsqltype: "cf_sql_integer" },
				{ value: arguments.externalId, cfsqltype: "cf_sql_varchar" },
				{ value: arguments.title, cfsqltype: "cf_sql_varchar" },
				{ value: arguments.description, cfsqltype: "cf_sql_longvarchar" },
				{ value: arguments.location, cfsqltype: "cf_sql_varchar" },
				{ value: arguments.link, cfsqltype: "cf_sql_varchar" },
				{ value: arguments.rawSource, cfsqltype: "cf_sql_varchar" }
			],
			{ datasource: ds() }
		) />
	</cffunction>

	<cffunction name="deleteJobById" access="public" returntype="void" output="false">
		<cfargument name="jobId" type="numeric" required="true" />
		<cfset queryExecute(
			"DELETE FROM jobs WHERE id = ?",
			[ { value: arguments.jobId, cfsqltype: "cf_sql_integer" } ],
			{ datasource: ds() }
		) />
	</cffunction>

	<cffunction name="getCareerPageScanJobsForPrune" access="public" returntype="query" output="false">
		<cfreturn queryExecute(
			"SELECT j.id, j.link, c.careers_url AS careers_url
			 FROM jobs j
			 INNER JOIN companies c ON c.id = j.company_id
			 WHERE j.raw_source = 'career_page_scan'
			 ORDER BY j.id",
			{},
			{ datasource: ds() }
		) />
	</cffunction>
</cfcomponent>
