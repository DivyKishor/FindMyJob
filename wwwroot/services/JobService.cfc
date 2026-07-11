<cfcomponent output="false" accessors="true">
	<cfproperty name="databaseService" type="any" />
	<cfproperty name="jobScoreRuleVersion" type="string" />
	<cfproperty name="taxonomy" type="any" />

	<cffunction name="init" access="public" returntype="any" output="false">
		<cfargument name="databaseService" type="any" required="true" />
		<cfargument name="jobScoreRuleVersion" type="string" required="false" default="v4_cf_ecosystem" />
		<cfargument name="taxonomy" type="any" required="false" default="" />
		<cfset variables.databaseService = arguments.databaseService />
		<cfset variables.jobScoreRuleVersion = arguments.jobScoreRuleVersion />
		<cfif isObject( arguments.taxonomy )>
			<cfset variables.taxonomy = arguments.taxonomy />
		<cfelse>
			<cfset variables.taxonomy = createObject( "component", "services.TechTaxonomy" ).init() />
		</cfif>
		<cfreturn this />
	</cffunction>

	<cffunction name="ds" access="private" returntype="string" output="false">
		<cfreturn variables.databaseService.getDatasource() />
	</cffunction>

	<!--- When the user searches an umbrella term ("coldfusion"/"cf"/...), match all
	      ecosystem terms (incl. ColdBox/FuseBox/CommandBox/WireBox) via the taxonomy. --->
	<cffunction name="expandCfKeywordTerms" access="private" returntype="array" output="false">
		<cfargument name="keyword" type="string" required="true" />
		<cfreturn variables.taxonomy.expandKeyword( arguments.keyword ) />
	</cffunction>

	<cffunction name="countAll" access="public" returntype="numeric" output="false">
		<cfset q = queryExecute( "SELECT COUNT(*) AS cnt FROM jobs", {}, { datasource: ds() } ) />
		<cfreturn val( q[ listFirst( q.columnList ) ][ 1 ] ) />
	</cffunction>

	<cffunction name="list" access="public" returntype="array" output="false">
		<cfargument name="companyId" type="numeric" required="false" default="0" />
		<cfargument name="keyword" type="string" required="false" default="" />
		<cfargument name="minScore" type="numeric" required="false" default="0" />
		<cfargument name="locationKeyword" type="string" required="false" default="" />
		<cfargument name="rawSource" type="string" required="false" default="" />
		<cfset pageData = listPaged(
			companyId = arguments.companyId,
			keyword = arguments.keyword,
			minScore = arguments.minScore,
			page = 1,
			pageSize = 5000,
			sortBy = "fetched_at",
			sortDir = "desc",
			locationKeyword = arguments.locationKeyword,
			rawSource = arguments.rawSource
		) />
		<cfreturn pageData.rows />
	</cffunction>

	<!---
		Classify work arrangement from job text.
		Checks title + location first (highest signal), then up to 2000 chars of description.
		Returns: remote | hybrid | onsite | unknown
	--->
	<cffunction name="classifyWorkType" access="public" returntype="string" output="false">
		<cfargument name="title" type="string" required="false" default="" />
		<cfargument name="location" type="string" required="false" default="" />
		<cfargument name="description" type="string" required="false" default="" />
		<cfset var haystack = lCase( trim( arguments.title ) & " " & trim( arguments.location ) & " " & left( trim( arguments.description ), 2000 ) ) />
		<cfset var p = "" />
		<cfloop list="remote,work from home,wfh,telecommute,fully remote,100% remote,work remotely,remote only,remote-only,remote first,remote-first,anywhere in the world,distributed team,globally remote,location independent,location: remote,remote position,remote role,remote opportunity" index="p">
			<cfif find( trim( p ), haystack )><cfreturn "remote" /></cfif>
		</cfloop>
		<cfloop list="hybrid,partial remote,semi-remote,flexible work,flex work,2-3 days,3 days in office,mix of remote,occasional office,blended work" index="p">
			<cfif find( trim( p ), haystack )><cfreturn "hybrid" /></cfif>
		</cfloop>
		<cfloop list="on-site only,onsite only,no remote work,no remote,required to be in office,in-office required,must be local,relocation required,must relocate,office-based,physically present" index="p">
			<cfif find( trim( p ), haystack )><cfreturn "onsite" /></cfif>
		</cfloop>
		<cfloop list="on-site,onsite,on site,in office,in-office" index="p">
			<cfif find( trim( p ), haystack )><cfreturn "onsite" /></cfif>
		</cfloop>
		<cfreturn "unknown" />
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
		<cfargument name="rawSource" type="string" required="false" default="" />
		<cfargument name="workType" type="string" required="false" default="" />
		<cfargument name="sponsorshipOnly" type="boolean" required="false" default="false" />
		<cfargument name="newWithinHours" type="numeric" required="false" default="0" />

		<cfif arguments.page LT 1><cfset arguments.page = 1 /></cfif>
		<cfif arguments.pageSize LT 1><cfset arguments.pageSize = 25 /></cfif>
		<cfif arguments.pageSize GT 200><cfset arguments.pageSize = 200 /></cfif>

		<cfset sortMap = {
			"fetched_at": "j.fetched_at",
			"first_seen": "COALESCE(j.first_seen_at, j.fetched_at)",
			"title": "j.title",
			"location": "j.location",
			"company_name": "c.name",
			"score": "COALESCE(js.score, 0)"
		} />
		<cfset safeSortBy = lCase( arguments.sortBy ) />
		<cfif NOT structKeyExists( sortMap, safeSortBy )>
			<cfset safeSortBy = "fetched_at" />
		</cfif>
		<cfset safeSortDir = lCase( arguments.sortDir ) />
		<cfif safeSortDir NEQ "asc"><cfset safeSortDir = "desc" /></cfif>

		<!--- Join each job's LATEST score row (any rule_version) so the board never breaks
		     when the scoring rule version is bumped before a re-score has run. --->
		<cfset fromSql = " FROM jobs j INNER JOIN companies c ON c.id = j.company_id
			LEFT JOIN job_scores js ON js.id = (
				SELECT jsx.id FROM job_scores jsx WHERE jsx.job_id = j.id
				ORDER BY jsx.created_at DESC, jsx.id DESC LIMIT 1
			) WHERE 1=1" />
		<cfset params = [] />

		<cfif arguments.companyId GT 0>
			<cfset fromSql = fromSql & " AND j.company_id = ?" />
			<cfset arrayAppend( params, { value: arguments.companyId, cfsqltype: "cf_sql_integer" } ) />
		</cfif>
		<cfif len( trim( arguments.keyword ) )>
			<cfset kwTerms = expandCfKeywordTerms( arguments.keyword ) />
			<cfset fromSql = fromSql & " AND (" />
			<cfloop from="1" to="#arrayLen( kwTerms )#" index="kwIdx">
				<cfif kwIdx GT 1><cfset fromSql = fromSql & " OR " /></cfif>
				<cfset likeValue = "%" & kwTerms[ kwIdx ] & "%" />
				<cfset fromSql = fromSql & "(lower(j.title) LIKE lower(?) OR lower(j.description) LIKE lower(?))" />
				<cfset arrayAppend( params, { value: likeValue, cfsqltype: "cf_sql_varchar" } ) />
				<cfset arrayAppend( params, { value: likeValue, cfsqltype: "cf_sql_longvarchar" } ) />
			</cfloop>
			<cfset fromSql = fromSql & ")" />
		</cfif>
		<cfif arguments.minScore GT 0>
			<cfset fromSql = fromSql & " AND COALESCE(js.score, 0) >= ?" />
			<cfset arrayAppend( params, { value: arguments.minScore, cfsqltype: "cf_sql_integer" } ) />
		</cfif>
		<cfif arguments.sponsorshipOnly>
			<cfset fromSql = fromSql & " AND js.reasons_json LIKE '%visa_sponsorship%'" />
		</cfif>
		<cfif arguments.newWithinHours GT 0>
			<cfset fromSql = fromSql & " AND COALESCE(j.first_seen_at, j.fetched_at) >= datetime('now', ?)" />
			<cfset arrayAppend( params, { value: "-" & int( arguments.newWithinHours ) & " hours", cfsqltype: "cf_sql_varchar" } ) />
		</cfif>
		<cfif len( trim( arguments.locationKeyword ) )>
			<cfset locKw = lCase( trim( arguments.locationKeyword ) ) />
			<cfif locKw EQ "india">
				<!--- Whole-word "india" only; exclude US state Indiana --->
				<cfset fromSql = fromSql & " AND NOT (lower(j.location) LIKE '%indiana%' OR lower(j.title) LIKE '%indiana%' OR lower(j.description) LIKE '%indiana%')" />
				<cfset fromSql = fromSql & " AND (" />
				<cfset indiaFieldClauses = [] />
				<cfloop list="j.location,j.title,j.description" index="fieldCol">
					<cfset arrayAppend( indiaFieldClauses, "lower(" & fieldCol & ") LIKE '% india %'" ) />
					<cfset arrayAppend( indiaFieldClauses, "lower(" & fieldCol & ") LIKE 'india %'" ) />
					<cfset arrayAppend( indiaFieldClauses, "lower(" & fieldCol & ") LIKE '% india'" ) />
					<cfset arrayAppend( indiaFieldClauses, "lower(" & fieldCol & ") LIKE '% india,%'" ) />
					<cfset arrayAppend( indiaFieldClauses, "lower(" & fieldCol & ") LIKE '% india" & chr(41) & "'" ) />
					<cfset arrayAppend( indiaFieldClauses, "lower(" & fieldCol & ") = 'india'" ) />
				</cfloop>
				<cfset indiaCities = [ "bengaluru", "bangalore", "hyderabad", "chennai", "mumbai", "pune", "delhi", "noida", "gurgaon", "gurugram", "kolkata", "ahmedabad", "jaipur", "kochi", "coimbatore", "indore" ] />
				<cfloop array="#indiaCities#" index="cityTerm">
					<cfset cityLike = "%#cityTerm#%" />
					<cfset arrayAppend( indiaFieldClauses, 'lower(j.location) LIKE ?' ) />
					<cfset arrayAppend( params, { value: cityLike, cfsqltype: "cf_sql_varchar" } ) />
					<cfset arrayAppend( indiaFieldClauses, 'lower(j.title) LIKE ?' ) />
					<cfset arrayAppend( params, { value: cityLike, cfsqltype: "cf_sql_varchar" } ) />
					<cfset arrayAppend( indiaFieldClauses, 'lower(j.description) LIKE ?' ) />
					<cfset arrayAppend( params, { value: cityLike, cfsqltype: "cf_sql_longvarchar" } ) />
				</cfloop>
				<cfset fromSql = fromSql & arrayToList( indiaFieldClauses, " OR " ) & ")" />

			<cfelseif locKw EQ "india-eligible" OR locKw EQ "worldwide">
				<!---
					Globally accessible filter: exclude jobs whose location field explicitly
					restricts to US, UK, AU, or CA.  Does NOT require India to be mentioned —
					it passes through "Remote", "Worldwide", blank locations, etc.
				--->
				<cfset fromSql = fromSql & " AND NOT (
					lower(j.location) LIKE '%united states%'
					OR lower(j.location) LIKE '%united kingdom%'
					OR lower(j.location) LIKE '% usa%'
					OR lower(j.location) LIKE '%, australia%'
					OR lower(j.location) LIKE '%, canada%'
					OR lower(j.location) LIKE '%us only%'
					OR lower(j.location) LIKE '%uk only%'
					OR lower(j.location) LIKE '%, us,%'
					OR lower(j.location) LIKE '%, us'
					OR lower(j.description) LIKE '%must be authorized to work in the united states%'
					OR lower(j.description) LIKE '%authorized to work in the u.s.%'
					OR lower(j.description) LIKE '%us citizens only%'
					OR lower(j.description) LIKE '%united states citizens%'
					OR lower(j.description) LIKE '%security clearance%'
				)" />

			<cfelse>
				<cfset locationLike = "%" & arguments.locationKeyword & "%" />
				<!--- India/remote often appear in title or description, not only the location column --->
				<cfset fromSql = fromSql & " AND (lower(j.location) LIKE lower(?) OR lower(j.title) LIKE lower(?) OR lower(j.description) LIKE lower(?))" />
				<cfset arrayAppend( params, { value: locationLike, cfsqltype: "cf_sql_varchar" } ) />
				<cfset arrayAppend( params, { value: locationLike, cfsqltype: "cf_sql_varchar" } ) />
				<cfset arrayAppend( params, { value: locationLike, cfsqltype: "cf_sql_longvarchar" } ) />
			</cfif>
		</cfif>
		<cfif len( trim( arguments.rawSource ) )>
			<cfset fromSql = fromSql & " AND j.raw_source = ?" />
			<cfset arrayAppend( params, { value: trim( arguments.rawSource ), cfsqltype: "cf_sql_varchar" } ) />
		</cfif>
		<cfif len( trim( arguments.workType ) ) AND listFind( "remote,hybrid,onsite,unknown", lCase( trim( arguments.workType ) ) )>
			<cfset fromSql = fromSql & " AND j.work_type = ?" />
			<cfset arrayAppend( params, { value: lCase( trim( arguments.workType ) ), cfsqltype: "cf_sql_varchar" } ) />
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
		                         COALESCE(j.first_seen_at, j.fetched_at) AS first_seen_at,
		                         COALESCE(j.work_type, 'unknown') AS work_type, COALESCE(j.is_active, 1) AS is_active,
		                         c.name AS company_name, COALESCE(js.score, 0) AS score, js.reasons_json" &
			fromSql &
			" ORDER BY " & sortMap[ safeSortBy ] & " " & safeSortDir & ", COALESCE(j.first_seen_at, j.fetched_at) DESC, j.id DESC LIMIT ? OFFSET ?" />

		<cfset dataParams = duplicate( params ) />
		<cfset arrayAppend( dataParams, { value: arguments.pageSize, cfsqltype: "cf_sql_integer" } ) />
		<cfset arrayAppend( dataParams, { value: offsetRows, cfsqltype: "cf_sql_integer" } ) />

		<cfset q = queryExecute( dataSql, dataParams, { datasource: ds() } ) />
		<cfset rows = variables.databaseService.queryToArray( q ) />
		<cfloop array="#rows#" index="rowItem">
			<cfset rowItem.score = val( rowItem.score ) />
			<!--- Expose v5 scoring reasons (cf_tech, remote_fit, visa_sponsorship, india_eligible, ...). --->
			<cfset rowItem.reasons = parseReasonsList( structKeyExists( rowItem, "reasons_json" ) ? rowItem.reasons_json : "" ) />
			<cfif structKeyExists( rowItem, "reasons_json" )><cfset structDelete( rowItem, "reasons_json" ) /></cfif>
			<cfset rowItem.has_sponsorship = reasonsContain( rowItem.reasons, "visa_sponsorship" ) />
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

	<!--- Parse a job_scores.reasons_json string into an array (empty array on null/bad JSON). --->
	<cffunction name="parseReasonsList" access="private" returntype="array" output="false">
		<cfargument name="reasonsJson" type="any" required="true" />
		<cfif isSimpleValue( arguments.reasonsJson ) AND len( trim( arguments.reasonsJson ) )>
			<cftry>
				<cfset var parsed = deserializeJSON( arguments.reasonsJson ) />
				<cfif isArray( parsed )><cfreturn parsed /></cfif>
				<cfcatch type="any"><cfreturn [] /></cfcatch>
			</cftry>
		</cfif>
		<cfreturn [] />
	</cffunction>

	<cffunction name="reasonsContain" access="private" returntype="boolean" output="false">
		<cfargument name="reasons" type="array" required="true" />
		<cfargument name="needle" type="string" required="true" />
		<cfset var r = "" />
		<cfloop array="#arguments.reasons#" index="r">
			<cfif findNoCase( arguments.needle, r ) GT 0><cfreturn true /></cfif>
		</cfloop>
		<cfreturn false />
	</cffunction>

	<cffunction name="upsertJob" access="public" returntype="void" output="false">
		<cfargument name="companyId" type="numeric" required="true" />
		<cfargument name="externalId" type="string" required="true" />
		<cfargument name="title" type="string" required="true" />
		<cfargument name="description" type="string" required="false" default="" />
		<cfargument name="location" type="string" required="false" default="" />
		<cfargument name="link" type="string" required="true" />
		<cfargument name="rawSource" type="string" required="true" />
		<cfset var wt = classifyWorkType( arguments.title, arguments.location, arguments.description ) />
		<cfset queryExecute(
			"INSERT INTO jobs (company_id, external_id, title, description, location, link, raw_source, fetched_at, first_seen_at, work_type, is_active)
			 VALUES (?, ?, ?, ?, ?, ?, ?, datetime('now'), datetime('now'), ?, 1)
			 ON CONFLICT(company_id, external_id) DO UPDATE SET
			   title = excluded.title,
			   description = excluded.description,
			   location = excluded.location,
			   link = excluded.link,
			   raw_source = excluded.raw_source,
			   fetched_at = datetime('now'),
			   work_type = excluded.work_type,
			   is_active = 1",
			[
				{ value: arguments.companyId, cfsqltype: "cf_sql_integer" },
				{ value: arguments.externalId, cfsqltype: "cf_sql_varchar" },
				{ value: arguments.title, cfsqltype: "cf_sql_varchar" },
				{ value: arguments.description, cfsqltype: "cf_sql_longvarchar" },
				{ value: arguments.location, cfsqltype: "cf_sql_varchar" },
				{ value: arguments.link, cfsqltype: "cf_sql_varchar" },
				{ value: arguments.rawSource, cfsqltype: "cf_sql_varchar" },
				{ value: wt, cfsqltype: "cf_sql_varchar" }
			],
			{ datasource: ds() }
		) />
	</cffunction>

	<!--- Jobs assigned to a placeholder "Unknown Company" external_feed row (for company-name backfill). --->
	<cffunction name="getUnknownCompanyJobs" access="public" returntype="query" output="false">
		<cfreturn queryExecute(
			"SELECT j.id, j.link, j.title, j.external_id, j.raw_source
			 FROM jobs j
			 INNER JOIN companies c ON c.id = j.company_id
			 WHERE c.name = 'Unknown Company' AND c.careers_source = 'external_feed'
			 ORDER BY j.id",
			{},
			{ datasource: ds() }
		) />
	</cffunction>

	<!--- True when another job (not excludeJobId) already holds this externalId under companyId (a deduped twin). --->
	<cffunction name="duplicateJobExists" access="public" returntype="boolean" output="false">
		<cfargument name="companyId" type="numeric" required="true" />
		<cfargument name="externalId" type="string" required="true" />
		<cfargument name="excludeJobId" type="numeric" required="false" default="0" />
		<cfset q = queryExecute(
			"SELECT id FROM jobs WHERE company_id = ? AND external_id = ? AND id <> ? LIMIT 1",
			[
				{ value: arguments.companyId, cfsqltype: "cf_sql_integer" },
				{ value: arguments.externalId, cfsqltype: "cf_sql_varchar" },
				{ value: arguments.excludeJobId, cfsqltype: "cf_sql_integer" }
			],
			{ datasource: ds() }
		) />
		<cfreturn q.recordCount GT 0 />
	</cffunction>

	<cffunction name="reassignJobCompany" access="public" returntype="void" output="false">
		<cfargument name="jobId" type="numeric" required="true" />
		<cfargument name="companyId" type="numeric" required="true" />
		<cfargument name="title" type="string" required="false" default="" />
		<cfif len( trim( arguments.title ) )>
			<cfset queryExecute(
				"UPDATE jobs SET company_id = ?, title = ? WHERE id = ?",
				[
					{ value: arguments.companyId, cfsqltype: "cf_sql_integer" },
					{ value: trim( arguments.title ), cfsqltype: "cf_sql_varchar" },
					{ value: arguments.jobId, cfsqltype: "cf_sql_integer" }
				],
				{ datasource: ds() }
			) />
		<cfelse>
			<cfset queryExecute(
				"UPDATE jobs SET company_id = ? WHERE id = ?",
				[
					{ value: arguments.companyId, cfsqltype: "cf_sql_integer" },
					{ value: arguments.jobId, cfsqltype: "cf_sql_integer" }
				],
				{ datasource: ds() }
			) />
		</cfif>
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

	<!--- Jobs due for an expiry HTTP check: not checked in minDays days, oldest first. --->
	<cffunction name="listForExpiryCheck" access="public" returntype="array" output="false">
		<cfargument name="limit" type="numeric" required="false" default="50" />
		<cfargument name="minDaysSinceCheck" type="numeric" required="false" default="7" />
		<cfset var safeLimit = max( 1, min( 200, int( arguments.limit ) ) ) />
		<cfset var safeDays = max( 1, int( arguments.minDaysSinceCheck ) ) />
		<cfset var q = queryExecute(
			"SELECT j.id, j.title, j.link, j.is_active, c.name AS company_name
			 FROM jobs j INNER JOIN companies c ON c.id = j.company_id
			 WHERE ( j.last_checked_at IS NULL OR j.last_checked_at <= datetime('now', '-#safeDays# days') )
			   AND j.link IS NOT NULL AND trim(j.link) <> ''
			 ORDER BY j.last_checked_at ASC, j.fetched_at ASC
			 LIMIT #safeLimit#",
			{},
			{ datasource: ds() }
		) />
		<cfset var rows = [] />
		<cfloop query="q">
			<cfset arrayAppend( rows, { id: q.id, title: q.title, link: q.link, is_active: q.is_active, company_name: q.company_name } ) />
		</cfloop>
		<cfreturn rows />
	</cffunction>

	<!--- Update a job's active status and last-checked timestamp. --->
	<cffunction name="updateJobStatus" access="public" returntype="void" output="false">
		<cfargument name="jobId" type="numeric" required="true" />
		<cfargument name="isActive" type="boolean" required="true" />
		<cfset queryExecute(
			"UPDATE jobs SET is_active = ?, last_checked_at = datetime('now') WHERE id = ?",
			[
				{ value: arguments.isActive ? 1 : 0, cfsqltype: "cf_sql_integer" },
				{ value: arguments.jobId, cfsqltype: "cf_sql_integer" }
			],
			{ datasource: ds() }
		) />
	</cffunction>

	<!--- Jobs first seen within the last N hours, ordered by most recent then highest score. --->
	<cffunction name="listNew" access="public" returntype="array" output="false">
		<cfargument name="hoursAgo" type="numeric" required="false" default="24" />
		<cfargument name="maxRows"  type="numeric" required="false" default="20" />
		<cfset var safeHours = max( 1, int( arguments.hoursAgo ) ) />
		<cfset var safeMax   = max( 1, min( 200, int( arguments.maxRows ) ) ) />
		<cfset var q = queryExecute(
			"SELECT j.id, j.title, j.location, j.link, COALESCE(j.first_seen_at, j.fetched_at) AS fetched_at, j.raw_source,
			        COALESCE(j.work_type, 'unknown') AS work_type,
			        c.name AS company_name, COALESCE(js.score, 0) AS score
			 FROM jobs j
			 INNER JOIN companies c ON c.id = j.company_id
			 LEFT JOIN job_scores js ON js.job_id = j.id AND js.rule_version = ?
			 WHERE COALESCE(j.first_seen_at, j.fetched_at) >= datetime('now', '-#safeHours# hours')
			 ORDER BY COALESCE(j.first_seen_at, j.fetched_at) DESC, COALESCE(js.score, 0) DESC
			 LIMIT #safeMax#",
			[ { value: variables.jobScoreRuleVersion, cfsqltype: "cf_sql_varchar" } ],
			{ datasource: ds() }
		) />
		<cfset var rows = [] />
		<cfloop query="q">
			<cfset arrayAppend( rows, {
				id:           q.id,
				title:        q.title,
				company_name: q.company_name,
				location:     q.location,
				link:         q.link,
				fetched_at:   q.fetched_at,
				raw_source:   q.raw_source,
				score:        q.score
			}) />
		</cfloop>
		<cfreturn rows />
	</cffunction>

	<!--- Count of jobs first seen within the last N hours. --->
	<cffunction name="countNew" access="public" returntype="numeric" output="false">
		<cfargument name="hoursAgo" type="numeric" required="false" default="24" />
		<cfset var safeHours = max( 1, int( arguments.hoursAgo ) ) />
		<cfset var q = queryExecute(
			"SELECT COUNT(*) AS n FROM jobs WHERE fetched_at >= datetime('now', '-#safeHours# hours')",
			{},
			{ datasource: ds() }
		) />
		<cfreturn val( q.n ) />
	</cffunction>
</cfcomponent>
