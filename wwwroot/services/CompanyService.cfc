<cfcomponent output="false" accessors="true">
	<cfproperty name="databaseService" type="any" />
	<cfproperty name="seedJsonPath" type="string" />

	<cffunction name="init" access="public" returntype="any" output="false">
		<cfargument name="databaseService" type="any" required="true" />
		<cfargument name="seedJsonPath" type="string" required="true" />
		<cfset variables.databaseService = arguments.databaseService />
		<cfset variables.seedJsonPath = arguments.seedJsonPath />
		<cfreturn this />
	</cffunction>

	<cffunction name="ds" access="private" returntype="string" output="false">
		<cfreturn variables.databaseService.getDatasource() />
	</cffunction>

	<cffunction name="count" access="public" returntype="numeric" output="false">
		<cfset q = queryExecute( "SELECT COUNT(*) AS cnt FROM companies", {}, { datasource: ds() } ) />
		<cfset colName = listFirst( q.columnList ) />
		<cfreturn val( q[ colName ][ 1 ] ) />
	</cffunction>

	<cffunction name="list" access="public" returntype="array" output="false">
		<cfargument name="sortBy" type="string" required="false" default="name" />
		<cfargument name="sortDir" type="string" required="false" default="asc" />
		<cfset sb = lCase( trim( arguments.sortBy ) ) />
		<cfset sd = lCase( trim( arguments.sortDir ) ) />
		<cfif sd NEQ "desc"><cfset sd = "asc" /></cfif>
		<cfif listFindNoCase( "name,careers_source,score,job_count,created_at", sb ) EQ 0><cfset sb = "name" /></cfif>
		<!--- Use real expressions for ORDER BY (SQLite does not always accept SELECT alias in ORDER BY the same way across engines) --->
		<cfset orderExpr = "lower(c.name)" />
		<cfif sb EQ "careers_source"><cfset orderExpr = "lower(c.careers_source)" /></cfif>
		<cfif sb EQ "score"><cfset orderExpr = "c.cf_likelihood_score" /></cfif>
		<cfif sb EQ "job_count"><cfset orderExpr = "(SELECT COUNT(*) FROM jobs j WHERE j.company_id = c.id)" /></cfif>
		<cfif sb EQ "created_at"><cfset orderExpr = "datetime(c.created_at)" /></cfif>
		<cfset q = queryExecute(
			"SELECT c.id, c.name, c.website, c.careers_url, c.careers_source, c.ats_config, c.cf_likelihood_score AS score,
			        (SELECT COUNT(*) FROM jobs j WHERE j.company_id = c.id) AS job_count,
			        c.created_at, c.updated_at
			 FROM companies c
			 ORDER BY " & orderExpr & " " & sd,
			{},
			{ datasource: ds() }
		) />
		<cfset rows = variables.databaseService.queryToArray( q ) />
		<cfloop array="#rows#" index="rowItem">
			<cfset rowItem.ats_config = parseJsonColumn( rowItem.ats_config ) />
			<cfset rowItem.score = val( rowItem.score ) />
			<cfset rowItem.job_count = val( rowItem.job_count ) />
		</cfloop>
		<cfreturn rows />
	</cffunction>

	<cffunction name="getAllQuery" access="public" returntype="query" output="false">
		<cfreturn queryExecute(
			"SELECT id, name, website, careers_url, careers_source, ats_config, cf_likelihood_score
			 FROM companies
			 WHERE careers_source <> 'external_feed'
			   AND careers_source <> 'cf_global_watcher'
			 ORDER BY CASE careers_source
					WHEN 'cf_global_watcher' THEN -1
					WHEN 'remotive_feed' THEN 0
					WHEN 'arbeitnow_feed' THEN 0
					WHEN 'getcfmljobs_feed' THEN 0
					WHEN 'adzuna_feed' THEN 0
					WHEN 'google_cse_feed' THEN 0
					WHEN 'cutshort_scan' THEN 0
					WHEN 'linkedin_public' THEN 0
					WHEN 'foundit_scan' THEN 0
					WHEN 'shine_scan' THEN 0
				WHEN 'weekday_scan' THEN 0
				WHEN 'jooble_feed' THEN 0
				WHEN 'expertini_scan' THEN 0
				WHEN 'indeed_scan' THEN 0
				WHEN 'instahyre_scan' THEN 0
				WHEN 'remoteok_feed' THEN 0
				WHEN 'jobicy_feed' THEN 0
				WHEN 'remote_rss_feed' THEN 0
				WHEN 'reddit_feed' THEN 0
				WHEN 'usajobs_feed' THEN 0
				WHEN 'greenhouse' THEN 1
					ELSE 2
				END,
				id",
			{},
			{ datasource: ds() }
		) />
	</cffunction>

	<cffunction name="getFeedAtsConfigJson" access="public" returntype="string" output="false">
		<cfargument name="careersSource" type="string" required="true" />
		<cfset q = queryExecute(
			"SELECT ats_config FROM companies WHERE careers_source = ? LIMIT 1",
			[ { value: trim( arguments.careersSource ), cfsqltype: "cf_sql_varchar" } ],
			{ datasource: ds() }
		) />
		<cfif q.recordCount EQ 0><cfreturn "" /></cfif>
		<cfreturn toString( q.ats_config[ 1 ] ) />
	</cffunction>

	<cffunction name="getById" access="public" returntype="struct" output="false">
		<cfargument name="id" type="numeric" required="true" />
		<cfset q = queryExecute(
			"SELECT id, name, website, careers_url, careers_source, ats_config, cf_likelihood_score AS score
			 FROM companies WHERE id = ?",
			[ { value: arguments.id, cfsqltype: "cf_sql_integer" } ],
			{ datasource: ds() }
		) />
		<cfif q.recordCount EQ 0>
			<cfreturn {} />
		</cfif>
		<cfset rowItem = variables.databaseService.queryToArray( q )[ 1 ] />
		<cfset rowItem.ats_config = parseJsonColumn( rowItem.ats_config ) />
		<cfset rowItem.score = val( rowItem.score ) />
		<cfreturn rowItem />
	</cffunction>

	<cffunction name="seedIfEmpty" access="public" returntype="void" output="false">
		<cfif NOT fileExists( variables.seedJsonPath )>
			<cfthrow message="Seed file missing: #variables.seedJsonPath#" />
		</cfif>
		<cfset rawText = fileRead( variables.seedJsonPath ) />
		<cfset rows = deserializeJSON( rawText ) />
		<cfif NOT isArray( rows )>
			<cfthrow message="Seed file must contain a JSON array of companies." />
		</cfif>
		<cfloop array="#rows#" index="rowItem">
			<cfset upsertCompanyFromSeed( rowItem ) />
		</cfloop>
	</cffunction>

	<cffunction name="ensureFeedSources" access="public" returntype="void" output="false">
	<cfset upsertFeedSource(
		name = "CF Global Watcher",
		careersUrl = "https://www.bing.com/search?format=rss",
		careersSource = "cf_global_watcher",
		atsConfig = {
			"max_runs_per_day": 2,
			"min_interval_minutes": 720,
			"max_queries_per_run": 20,
			"max_url_fetches_per_query": 25,
			"fetch_sleep_ms": 450,
			"brave_api_key": "",
			"global_watcher_queries": [
				"""coldfusion"" developer job",
				"""cfml"" developer hiring",
				"""lucee"" developer job",
				"""coldbox"" developer job posting",
				"full stack developer coldfusion backend job",
				"fullstack cfml developer hiring",
				"coldfusion developer remote",
				"cfml developer Europe job",
				"coldfusion developer Australia hiring",
				"coldfusion developer Canada job",
				"cfml developer United Kingdom",
				"coldfusion developer Singapore job",
				"coldfusion site:boards.greenhouse.io",
				"cfml site:jobs.lever.co",
				"coldfusion site:myworkdayjobs.com",
				"cfml site:jobs.ashbyhq.com",
				"coldfusion site:boards.greenhouse.io embed job",
				"coldfusion site:linkedin.com/jobs",
				"cfml site:indeed.com viewjob",
				"coldfusion site:glassdoor.com job",
				"lucee site:stackoverflow.com/jobs",
				"coldfusion site:smartrecruiters.com",
				"cfml site:jobvite.com",
				"coldfusion site:icims.com jobs",
				"coldfusion developer site:remoteok.com",
				"cfml site:weworkremotely.com",
				"coldfusion site:jobicy.com",
				"coldfusion site:arbeitnow.com",
				"cfml developer site:remotive.com",
				"coldfusion site:wellfound.com jobs",
				"coldfusion site:simplyhired.com",
				"cfml site:monster.com job",
				"coldfusion site:careerbuilder.com",
				"coldfusion developer site:ziprecruiter.com",
				"cfml developer site:seek.com.au",
				"coldfusion site:totaljobs.com",
				"cfml developer site:stepstone.de",
				"coldfusion developer site:naukri.com",
				"cfml developer site:foundit.in",
				"coldfusion site:instahyre.com",
				"mura cms developer job hiring",
				"adobe coldfusion developer job worldwide"
			]
		}
	) />
	<cfset upsertFeedSource(
		name = "Remotive Feed",
			careersUrl = "https://remotive.com/api/remote-jobs",
			careersSource = "remotive_feed",
			atsConfig = {}
		) />
		<cfset upsertFeedSource(
			name = "ArbeitNow Feed",
			careersUrl = "https://www.arbeitnow.com/api/job-board-api",
			careersSource = "arbeitnow_feed",
			atsConfig = {}
		) />
		<cfset upsertFeedSource(
			name = "GetCFMLJobs Feed",
			careersUrl = "https://www.getcfmljobs.com/",
			careersSource = "getcfmljobs_feed",
			atsConfig = { "max_job_details": 40 }
		) />
		<cfset upsertFeedSource(
			name = "Adzuna Feed",
			careersUrl = "https://api.adzuna.com/v1/api/jobs/in/search/1",
			careersSource = "adzuna_feed",
			atsConfig = { "countries": [ "us", "gb", "ca", "au", "de", "in" ], "country": "in" }
		) />
		<cfset upsertFeedSource(
			name = "Google Programmable Search (CFML)",
			careersUrl = "https://www.googleapis.com/customsearch/v1",
			careersSource = "google_cse_feed",
		atsConfig = {
			"num": 10,
			"queries": [
				"(coldfusion OR cfml OR lucee OR coldbox) site:linkedin.com/jobs",
				"(coldfusion OR cfml OR lucee) site:instahyre.com",
				"(coldfusion OR cfml OR lucee) site:cutshort.io/job",
				"full stack coldfusion developer India site:linkedin.com/jobs",
				"fullstack coldfusion backend developer site:naukri.com",
				"Liventus coldfusion developer India",
				"Stridely Solutions coldfusion developer India",
				"TELUS Digital coldfusion Noida developer",
				"Infoane Technologies coldfusion Hyderabad",
				"Neologix coldfusion developer Trivandrum",
				"Akkodis coldfusion developer Bengaluru",
				"coldfusion developer India site:glassdoor.co.in",
				"coldfusion developer jobs India site:indeed.co.in",
				"CFML developer India site:instahyre.com",
				"coldfusion developer India site:trabajo.org",
				"coldfusion developer Accenture India hiring",
				"(coldfusion OR cfml OR lucee) site:remoteok.com",
				"(coldfusion OR cfml) site:weworkremotely.com",
				"coldfusion developer site:remote.co",
				"cfml developer site:jobspresso.co",
				"coldfusion remote site:workingnomads.com",
				"full stack coldfusion site:justremote.co",
				"coldfusion developer site:flexjobs.com",
				"cfml developer site:wellfound.com",
				"coldfusion developer site:upwork.com",
				"coldfusion developer site:simplyhired.com",
				"coldfusion developer site:toptal.com",
				"coldfusion developer site:jobicy.com",
				"ZOLL emsCharts coldfusion developer",
				"site:emscharts.com coldfusion",
				"companies using coldfusion .cfm worldwide",
				"builtwith coldfusion companies USA"
			]
		}
		) />
		<cfset upsertFeedSource(
			name = "LinkedIn Public (CFML India + Remote)",
			careersUrl = "https://www.linkedin.com/jobs/search?keywords=coldfusion&location=India",
			careersSource = "linkedin_public",
		atsConfig = {
			"search_urls": [
				"https://www.linkedin.com/jobs/search?keywords=coldfusion&location=India&f_TPR=r2592000&position=1&pageNum=0",
				"https://www.linkedin.com/jobs/search?keywords=cfml+OR+lucee&location=India&f_TPR=r2592000&position=1&pageNum=0",
				"https://www.linkedin.com/jobs/search?keywords=coldfusion&f_WT=2&f_TPR=r2592000&position=1&pageNum=0",
				"https://www.linkedin.com/jobs/search?keywords=coldfusion+OR+cfml+OR+lucee&f_TPR=r2592000&position=1&pageNum=0",
				"https://www.linkedin.com/jobs/search?keywords=full+stack+coldfusion&location=India&f_TPR=r2592000&position=1&pageNum=0",
				"https://www.linkedin.com/jobs/search?keywords=fullstack+coldfusion&f_WT=2&f_TPR=r2592000&position=1&pageNum=0",
				"https://www.linkedin.com/jobs/search?keywords=coldfusion&location=Bengaluru%2C+Karnataka%2C+India&f_TPR=r2592000&position=1&pageNum=0",
				"https://www.linkedin.com/jobs/search?keywords=coldfusion&location=Hyderabad%2C+Telangana%2C+India&f_TPR=r2592000&position=1&pageNum=0",
				"https://www.linkedin.com/jobs/search?keywords=coldfusion&location=Pune%2C+Maharashtra%2C+India&f_TPR=r2592000&position=1&pageNum=0",
				"https://www.linkedin.com/jobs/search?keywords=coldfusion&location=Chennai%2C+Tamil+Nadu%2C+India&f_TPR=r2592000&position=1&pageNum=0",
				"https://www.linkedin.com/jobs/search?keywords=CFML&location=India&f_TPR=r2592000&position=1&pageNum=0",
				"https://www.linkedin.com/jobs/search?keywords=coldfusion&location=India&f_WT=2&f_TPR=r2592000&position=1&pageNum=0"
			]
		}
		) />
		<cfset upsertFeedSource(
			name = "Cutshort (CFML search)",
			careersUrl = "https://cutshort.io/jobs?q=coldfusion",
			careersSource = "cutshort_scan",
			atsConfig = {
				"max_job_details": 18,
				"listing_urls": [
					"https://cutshort.io/jobs?q=coldfusion",
					"https://cutshort.io/jobs?q=lucee",
					"https://cutshort.io/jobs?q=cfml",
					"https://cutshort.io/jobs?q=full+stack+coldfusion"
				]
			}
		) />
		<cfset upsertFeedSource(
			name = "Foundit.in (CFML India)",
			careersUrl = "https://www.foundit.in/search/coldfusion-jobs",
			careersSource = "foundit_scan",
			atsConfig = {
				"max_job_details": 20,
				"listing_urls": [
					"https://www.foundit.in/search/coldfusion-jobs",
					"https://www.foundit.in/search/cfml-jobs",
					"https://www.foundit.in/search/lucee-jobs"
				]
			}
		) />
		<cfset upsertFeedSource(
			name = "Shine.com (CFML India)",
			careersUrl = "https://www.shine.com/job-search/coldfusion-jobs",
			careersSource = "shine_scan",
			atsConfig = {
				"max_job_details": 20,
				"listing_urls": [
					"https://www.shine.com/job-search/coldfusion-jobs",
					"https://www.shine.com/job-search/cfml-jobs",
					"https://www.shine.com/job-search/lucee-jobs"
				]
			}
		) />
	<cfset upsertFeedSource(
		name = "Weekday.works (CFML India)",
		careersUrl = "https://jobs.weekday.works",
		careersSource = "weekday_scan",
		atsConfig = {
			"max_job_details": 15,
			"listing_urls": [
				"https://jobs.weekday.works/?q=coldfusion",
				"https://jobs.weekday.works/?q=cfml"
			]
		}
	) />
	<cfset upsertFeedSource(
		name = "Jooble (CFML Global)",
		careersUrl = "https://jooble.org/api/",
		careersSource = "jooble_feed",
		atsConfig = {
			"keywords": [ "ColdFusion", "CFML", "Lucee", "full stack coldfusion" ],
			"locations": [ "Remote", "United States", "United Kingdom", "Canada", "Australia", "Germany", "India" ]
		}
	) />
	<cfset upsertFeedSource(
		name = "Expertini India (CFML)",
		careersUrl = "https://in.expertini.com/jobs/search/coldfusion-jobs-india/",
		careersSource = "expertini_scan",
		atsConfig = {
			"max_job_details": 25,
			"listing_urls": [
				"https://in.expertini.com/jobs/search/coldfusion-jobs-india/",
				"https://in.expertini.com/jobs/search/cfml-jobs-india/",
				"https://in.expertini.com/jobs/search/lucee-jobs-india/"
			]
		}
	) />
	<cfset upsertFeedSource(
		name = "Indeed India (CFML)",
		careersUrl = "https://in.indeed.com/jobs?q=coldfusion&l=India",
		careersSource = "indeed_scan",
		atsConfig = {
			"max_job_details": 25,
			"listing_urls": [
				"https://in.indeed.com/jobs?q=coldfusion&l=India",
				"https://in.indeed.com/jobs?q=CFML+developer&l=India",
				"https://in.indeed.com/jobs?q=lucee+developer&l=India",
				"https://in.indeed.com/jobs?q=coldfusion&l="
			]
		}
	) />
	<cfset upsertFeedSource(
		name = "Instahyre (CFML India)",
		careersUrl = "https://www.instahyre.com/search-jobs/",
		careersSource = "instahyre_scan",
		atsConfig = {
			"max_job_details": 15,
			"listing_urls": [
				"https://www.instahyre.com/search-jobs/?designation=coldfusion",
				"https://www.instahyre.com/search-jobs/?designation=cfml",
				"https://www.instahyre.com/search-jobs/?designation=lucee"
			]
		}
	) />
	<cfset upsertFeedSource(
		name = "Remote OK",
		careersUrl = "https://remoteok.com/api",
		careersSource = "remoteok_feed",
		atsConfig = { "api_url": "https://remoteok.com/api" }
	) />
	<cfset upsertFeedSource(
		name = "Jobicy Remote Jobs",
		careersUrl = "https://jobicy.com/api/v2/remote-jobs",
		careersSource = "jobicy_feed",
		atsConfig = { "count": 50 }
	) />
	<cfset upsertFeedSource(
		name = "We Work Remotely (RSS)",
		careersUrl = "https://weworkremotely.com/remote-jobs.rss",
		careersSource = "remote_rss_feed",
		atsConfig = {
			"raw_source": "weworkremotely",
			"rss_urls": [
				"https://weworkremotely.com/remote-jobs.rss",
				"https://weworkremotely.com/categories/remote-full-stack-programming-jobs.rss",
				"https://weworkremotely.com/categories/remote-back-end-programming-jobs.rss"
			]
		}
	) />
	<cfset upsertFeedSource(
		name = "Reddit (CF hiring)",
		careersUrl = "https://www.reddit.com/r/coldfusion/new.json",
		careersSource = "reddit_feed",
		atsConfig = {
			"max_posts_per_listing": 100,
			"request_sleep_ms": 2500,
			"user_agent": "web:coldfusion-job-finder:v1.0 (job aggregator)",
			"listing_urls": [
				"https://www.reddit.com/r/coldfusion/new.json?limit=100",
				"https://www.reddit.com/r/forhire/search.json?q=coldfusion+OR+cfml+OR+lucee&restrict_sr=1&sort=new&limit=100",
				"https://www.reddit.com/r/jobbit/search.json?q=coldfusion+OR+cfml&restrict_sr=1&sort=new&limit=100",
				"https://www.reddit.com/r/remotejs/search.json?q=coldfusion+OR+cfml&restrict_sr=1&sort=new&limit=50",
				"https://www.reddit.com/search.json?q=coldfusion+hiring+OR+%22coldfusion+developer%22&sort=new&limit=100"
			]
		}
	) />
	<cfset upsertFeedSource(
		name = "USAJOBS.gov (CF)",
		careersUrl = "https://data.usajobs.gov/api/search",
		careersSource = "usajobs_feed",
		atsConfig = {
			"api_key": "",
			"user_agent": "",
			"results_per_page": 50,
			"keywords": [ "ColdFusion", "CFML", "Lucee" ]
		}
	) />
	</cffunction>

	<!--- Removes the "Unknown Company" external_feed placeholder when no jobs reference it. Returns count removed. --->
	<cffunction name="purgeEmptyUnknownCompany" access="public" returntype="numeric" output="false">
		<cfset q = queryExecute(
			"SELECT c.id FROM companies c
			 WHERE c.name = 'Unknown Company' AND c.careers_source = 'external_feed'
			   AND NOT EXISTS ( SELECT 1 FROM jobs j WHERE j.company_id = c.id )",
			{},
			{ datasource: ds() }
		) />
		<cfset removed = 0 />
		<cfloop query="q">
			<cfset queryExecute(
				"DELETE FROM companies WHERE id = ?",
				[ { value: val( q.id ), cfsqltype: "cf_sql_integer" } ],
				{ datasource: ds() }
			) />
			<cfset removed = removed + 1 />
		</cfloop>
		<cfreturn removed />
	</cffunction>

	<cffunction name="getOrCreateExternalCompany" access="public" returntype="numeric" output="false">
		<cfargument name="name" type="string" required="true" />
		<cfargument name="website" type="string" required="false" default="" />
		<cfset cleanName = trim( arguments.name ) />
		<cfif NOT len( cleanName )>
			<cfset cleanName = "Unknown Company" />
		</cfif>
		<cfset q = queryExecute(
			"SELECT id FROM companies WHERE name = ? AND careers_source = 'external_feed' ORDER BY id LIMIT 1",
			[ { value: cleanName, cfsqltype: "cf_sql_varchar" } ],
			{ datasource: ds() }
		) />
		<cfif q.recordCount GT 0>
			<cfreturn val( q.id[ 1 ] ) />
		</cfif>
		<cfset queryExecute(
			"INSERT INTO companies (name, website, careers_url, careers_source, ats_config, updated_at)
			 VALUES (?, ?, ?, 'external_feed', '{}', datetime('now'))",
			[
				{ value: cleanName, cfsqltype: "cf_sql_varchar" },
				{ value: arguments.website, cfsqltype: "cf_sql_varchar" },
				{ value: "", cfsqltype: "cf_sql_varchar" }
			],
			{ datasource: ds() }
		) />
		<cfset q2 = queryExecute( "SELECT last_insert_rowid() AS rid", {}, { datasource: ds() } ) />
		<cfset ridCol = listFirst( q2.columnList ) />
		<cfreturn val( q2[ ridCol ][ 1 ] ) />
	</cffunction>

	<cffunction name="upsertDiscoveredCompany" access="public" returntype="numeric" output="false">
		<cfargument name="name" type="string" required="true" />
		<cfargument name="website" type="string" required="false" default="" />
		<cfargument name="careersUrl" type="string" required="false" default="" />
		<cfargument name="discoverySource" type="string" required="false" default="" />

		<cfset cleanName = trim( arguments.name ) />
		<cfif NOT len( cleanName )><cfset cleanName = "Unknown Company" /></cfif>
		<cfset websiteValue = trim( arguments.website ) />
		<cfset careersUrlValue = trim( arguments.careersUrl ) />
		<cfif NOT len( careersUrlValue )><cfset careersUrlValue = websiteValue /></cfif>

		<cfset baseAts = {
			max_runs_per_day: 1,
			min_interval_minutes: 1440,
			keywords: [ "coldfusion", "cfml", "lucee", "adobe coldfusion" ],
			discovery_source: arguments.discoverySource
		} />

		<cfset q = queryExecute(
			"SELECT id FROM companies
			 WHERE careers_source = 'career_page_scan'
			   AND (
			     (website = ? AND website <> '')
			     OR (name = ?)
			   )
			 ORDER BY id
			 LIMIT 1",
			[
				{ value: websiteValue, cfsqltype: "cf_sql_varchar" },
				{ value: cleanName, cfsqltype: "cf_sql_varchar" }
			],
			{ datasource: ds() }
		) />

		<cfif q.recordCount EQ 0>
			<cfset queryExecute(
				"INSERT INTO companies (name, website, careers_url, careers_source, ats_config, updated_at)
				 VALUES (?, ?, ?, 'career_page_scan', ?, datetime('now'))",
				[
					{ value: cleanName, cfsqltype: "cf_sql_varchar" },
					{ value: websiteValue, cfsqltype: "cf_sql_varchar" },
					{ value: careersUrlValue, cfsqltype: "cf_sql_varchar" },
					{ value: serializeJSON( baseAts ), cfsqltype: "cf_sql_longvarchar" }
				],
				{ datasource: ds() }
			) />
			<cfset q2 = queryExecute( "SELECT last_insert_rowid() AS rid", {}, { datasource: ds() } ) />
			<cfset ridCol = listFirst( q2.columnList ) />
			<cfreturn val( q2[ ridCol ][ 1 ] ) />
		</cfif>

		<cfset existingId = val( q.id[ 1 ] ) />
		<cfset queryExecute(
			"UPDATE companies
			 SET website = CASE WHEN ? <> '' THEN ? ELSE website END,
			     careers_url = CASE WHEN ? <> '' THEN ? ELSE careers_url END,
			     updated_at = datetime('now')
			 WHERE id = ?",
			[
				{ value: websiteValue, cfsqltype: "cf_sql_varchar" },
				{ value: websiteValue, cfsqltype: "cf_sql_varchar" },
				{ value: careersUrlValue, cfsqltype: "cf_sql_varchar" },
				{ value: careersUrlValue, cfsqltype: "cf_sql_varchar" },
				{ value: existingId, cfsqltype: "cf_sql_integer" }
			],
			{ datasource: ds() }
		) />
		<cfreturn existingId />
	</cffunction>

	<cffunction name="insertCompany" access="private" returntype="void" output="false">
		<cfargument name="row" type="struct" required="true" />
		<cfif structKeyExists( arguments.row, "ats_config" )>
			<cfset atsJson = serializeJSON( arguments.row.ats_config ) />
		<cfelse>
			<cfset atsJson = "{}" />
		</cfif>
		<cfif structKeyExists( arguments.row, "website" )>
			<cfset websiteValue = arguments.row.website />
		<cfelse>
			<cfset websiteValue = "" />
		</cfif>
		<cfset queryExecute(
			"INSERT INTO companies (name, website, careers_url, careers_source, ats_config, updated_at)
			 VALUES (?, ?, ?, ?, ?, datetime('now'))",
			[
				{ value: arguments.row.name, cfsqltype: "cf_sql_varchar" },
				{ value: websiteValue, cfsqltype: "cf_sql_varchar" },
				{ value: arguments.row.careers_url, cfsqltype: "cf_sql_varchar" },
				{ value: arguments.row.careers_source, cfsqltype: "cf_sql_varchar" },
				{ value: atsJson, cfsqltype: "cf_sql_longvarchar" }
			],
			{ datasource: ds() }
		) />
	</cffunction>

	<cffunction name="upsertCompanyFromSeed" access="private" returntype="void" output="false">
		<cfargument name="row" type="struct" required="true" />
		<cfif NOT structKeyExists( arguments.row, "name" ) OR NOT structKeyExists( arguments.row, "careers_source" )>
			<cfreturn />
		</cfif>
		<cfset q = queryExecute(
			"SELECT id FROM companies WHERE name = ? AND careers_source = ? LIMIT 1",
			[
				{ value: arguments.row.name, cfsqltype: "cf_sql_varchar" },
				{ value: arguments.row.careers_source, cfsqltype: "cf_sql_varchar" }
			],
			{ datasource: ds() }
		) />
		<cfif q.recordCount EQ 0>
			<cfset insertCompany( arguments.row ) />
			<cfreturn />
		</cfif>
		<cfset existingId = val( q.id[ 1 ] ) />
		<cfif structKeyExists( arguments.row, "ats_config" )><cfset atsJson = serializeJSON( arguments.row.ats_config ) /><cfelse><cfset atsJson = "{}" /></cfif>
		<cfif structKeyExists( arguments.row, "website" )><cfset websiteValue = arguments.row.website /><cfelse><cfset websiteValue = "" /></cfif>
		<cfif structKeyExists( arguments.row, "careers_url" )><cfset careersUrlValue = arguments.row.careers_url /><cfelse><cfset careersUrlValue = "" /></cfif>
		<cfset queryExecute(
			"UPDATE companies
			 SET website = ?, careers_url = ?, ats_config = ?, updated_at = datetime('now')
			 WHERE id = ?",
			[
				{ value: websiteValue, cfsqltype: "cf_sql_varchar" },
				{ value: careersUrlValue, cfsqltype: "cf_sql_varchar" },
				{ value: atsJson, cfsqltype: "cf_sql_longvarchar" },
				{ value: existingId, cfsqltype: "cf_sql_integer" }
			],
			{ datasource: ds() }
		) />
	</cffunction>

	<cffunction name="upsertFeedSource" access="private" returntype="void" output="false">
		<cfargument name="name" type="string" required="true" />
		<cfargument name="careersUrl" type="string" required="true" />
		<cfargument name="careersSource" type="string" required="true" />
		<cfargument name="atsConfig" type="struct" required="true" />
		<cfset q = queryExecute(
			"SELECT id FROM companies WHERE name = ? AND careers_source = ? LIMIT 1",
			[
				{ value: arguments.name, cfsqltype: "cf_sql_varchar" },
				{ value: arguments.careersSource, cfsqltype: "cf_sql_varchar" }
			],
			{ datasource: ds() }
		) />
		<cfif q.recordCount EQ 0>
			<cfset queryExecute(
				"INSERT INTO companies (name, website, careers_url, careers_source, ats_config, updated_at)
				 VALUES (?, '', ?, ?, ?, datetime('now'))",
				[
					{ value: arguments.name, cfsqltype: "cf_sql_varchar" },
					{ value: arguments.careersUrl, cfsqltype: "cf_sql_varchar" },
					{ value: arguments.careersSource, cfsqltype: "cf_sql_varchar" },
					{ value: serializeJSON( arguments.atsConfig ), cfsqltype: "cf_sql_longvarchar" }
				],
				{ datasource: ds() }
			) />
		</cfif>
	</cffunction>

	<cffunction name="parseJsonColumn" access="private" returntype="any" output="false">
		<cfargument name="value" type="any" required="true" />
		<cfif isSimpleValue( arguments.value ) AND len( trim( arguments.value ) )>
			<cftry>
				<cfreturn deserializeJSON( arguments.value ) />
				<cfcatch type="any">
					<cfreturn {} />
				</cfcatch>
			</cftry>
		</cfif>
		<cfreturn {} />
	</cffunction>
</cfcomponent>
