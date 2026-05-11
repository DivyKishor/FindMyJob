<cfcomponent output="false" accessors="true">
	<cfproperty name="companyService" type="any" />
	<cfproperty name="jobService" type="any" />
	<cfproperty name="httpClientService" type="any" />
	<cfproperty name="greenhouseParser" type="any" />
	<cfproperty name="loggerService" type="any" />
	<cfproperty name="sourceQuotaService" type="any" />
	<cfproperty name="scoringService" type="any" />

	<cffunction name="init" access="public" returntype="any" output="false">
		<cfargument name="companyService" type="any" required="true" />
		<cfargument name="jobService" type="any" required="true" />
		<cfargument name="httpClientService" type="any" required="true" />
		<cfargument name="greenhouseParser" type="any" required="true" />
		<cfargument name="loggerService" type="any" required="true" />
		<cfargument name="sourceQuotaService" type="any" required="true" />
		<cfargument name="scoringService" type="any" required="true" />
		<cfset variables.companyService = arguments.companyService />
		<cfset variables.jobService = arguments.jobService />
		<cfset variables.httpClientService = arguments.httpClientService />
		<cfset variables.greenhouseParser = arguments.greenhouseParser />
		<cfset variables.loggerService = arguments.loggerService />
		<cfset variables.sourceQuotaService = arguments.sourceQuotaService />
		<cfset variables.scoringService = arguments.scoringService />
		<cfreturn this />
	</cffunction>

	<cffunction name="runAll" access="public" returntype="struct" output="false">
		<cfset summary = { companiesProcessed: 0, jobsUpserted: 0, errors: [], quotaGuardSkips: 0, scanBudgetSkips: 0, sourceHealth: {}, errorClasses: {} } />
		<!--- Many seeded employers use career_page_scan; cap only guards runaway time (each scan may fetch sub-pages) --->
		<cfset maxCareerScanPerRun = 120 />
		<cfset careerScanProcessed = 0 />
		<cfset companiesQ = variables.companyService.getAllQuery() />
		<cfloop from="1" to="#companiesQ.recordCount#" index="i">
			<cfset companyId = val( companiesQ.id[ i ] ) />
			<cfset companyName = companiesQ.name[ i ] />
			<cfif structKeyExists( companiesQ, "careers_source" )><cfset source = lCase( trim( companiesQ.careers_source[ i ] ) ) /><cfelse><cfset source = "" /></cfif>
			<cfset cfg = parseConfig( companiesQ.ats_config[ i ] ) />
			<cfif listFindNoCase( "greenhouse,remotive_feed,arbeitnow_feed,adzuna_feed,getcfmljobs_feed,google_cse_feed,cutshort_scan,linkedin_public,foundit_scan,shine_scan,weekday_scan,jooble_feed,expertini_scan,indeed_scan,instahyre_scan,career_page_scan", source ) EQ 0>
				<cfset arrayAppend( summary.errors, "Skipped (unsupported source '#source#') for company #companyId# (#companyName#)" ) />
				<cfset variables.loggerService.warn( "Skipped unsupported careers_source=#source# for company #companyId# (#companyName#)" ) />
				<cfset incrementSourceHealth( summary.sourceHealth, source, "skipped", 0 ) />
				<cfset incrementErrorClass( summary.errorClasses, "unsupported_source" ) />
				<cfcontinue />
			</cfif>
			<cfset sourceKey = buildSourceKey( source, companyId ) />
			<cfset maxRunsPerDay = getNumericCfg( cfg, "max_runs_per_day", defaultMaxRunsFor( source ) ) />
			<cfset minIntervalMinutes = getNumericCfg( cfg, "min_interval_minutes", defaultMinIntervalFor( source ) ) />
			<cfif source EQ "career_page_scan" AND careerScanProcessed GTE maxCareerScanPerRun>
				<cfset summary.scanBudgetSkips = val( summary.scanBudgetSkips ) + 1 />
				<cfset variables.loggerService.info( "Scan budget skip for #companyName# (career_page_scan): max per run reached" ) />
				<cfset incrementSourceHealth( summary.sourceHealth, source, "skipped", 0 ) />
				<cfset incrementErrorClass( summary.errorClasses, "scan_budget_skip" ) />
				<cfcontinue />
			</cfif>
			<cfset quota = variables.sourceQuotaService.canRun( sourceKey, maxRunsPerDay, minIntervalMinutes ) />

			<cfif NOT quota.allowed>
				<cfset summary.quotaGuardSkips = val( summary.quotaGuardSkips ) + 1 />
				<cfset variables.loggerService.warn( "Quota guard skip #companyName# (#source#): #quota.reason# sourceKey=#sourceKey#" ) />
				<cfset incrementSourceHealth( summary.sourceHealth, source, "skipped", 0 ) />
				<cfset incrementErrorClass( summary.errorClasses, "quota_guard_skip" ) />
				<cfcontinue />
			</cfif>

			<cftry>
				<cfset n = 0 />
				<cfif source EQ "greenhouse">
					<cfset n = ingestGreenhouse( companyId, companiesQ.ats_config[ i ] ) />
				<cfelseif source EQ "remotive_feed">
					<cfset n = ingestRemotive() />
				<cfelseif source EQ "arbeitnow_feed">
					<cfset n = ingestArbeitnow() />
				<cfelseif source EQ "getcfmljobs_feed">
					<cfset n = ingestGetCfmlJobs( companiesQ.careers_url[ i ], companiesQ.ats_config[ i ] ) />
				<cfelseif source EQ "adzuna_feed">
					<cfset n = ingestAdzuna( companiesQ.ats_config[ i ] ) />
				<cfelseif source EQ "google_cse_feed">
					<cfset n = ingestGoogleCse( companiesQ.ats_config[ i ] ) />
				<cfelseif source EQ "cutshort_scan">
					<cfset n = ingestCutshortScan( companiesQ.careers_url[ i ], companiesQ.ats_config[ i ] ) />
			<cfelseif source EQ "linkedin_public">
				<cfset n = ingestLinkedInPublic( companiesQ.ats_config[ i ] ) />
			<cfelseif source EQ "foundit_scan">
				<cfset n = ingestFounditScan( companiesQ.ats_config[ i ] ) />
			<cfelseif source EQ "shine_scan">
				<cfset n = ingestShineScan( companiesQ.ats_config[ i ] ) />
			<cfelseif source EQ "weekday_scan">
				<cfset n = ingestWeekdayScan( companiesQ.ats_config[ i ] ) />
			<cfelseif source EQ "jooble_feed">
				<cfset n = ingestJoobleFeed( companiesQ.ats_config[ i ] ) />
			<cfelseif source EQ "expertini_scan">
				<cfset n = ingestExpertiniScan( companiesQ.ats_config[ i ] ) />
			<cfelseif source EQ "indeed_scan">
				<cfset n = ingestIndeedScan( companiesQ.ats_config[ i ] ) />
			<cfelseif source EQ "instahyre_scan">
				<cfset n = ingestInstahyreScan( companiesQ.ats_config[ i ] ) />
			<cfelseif source EQ "career_page_scan">
					<cfset n = ingestCareerPageScan( companyId, companiesQ.careers_url[ i ], companiesQ.ats_config[ i ] ) />
					<cfset careerScanProcessed = careerScanProcessed + 1 />
				</cfif>
				<cfset variables.sourceQuotaService.markRun( sourceKey ) />
				<cfset summary.jobsUpserted = summary.jobsUpserted + n />
				<cfset summary.companiesProcessed = summary.companiesProcessed + 1 />
				<cfset incrementSourceHealth( summary.sourceHealth, source, "success", n ) />
				<cfcatch type="any">
					<cfset msg = "Company #companyId# (#companyName#): #cfcatch.message#" />
					<cfset arrayAppend( summary.errors, msg ) />
					<cfset variables.loggerService.error( msg, cfcatch ) />
					<cfset incrementSourceHealth( summary.sourceHealth, source, "failed", 0 ) />
					<cfset incrementErrorClass( summary.errorClasses, classifyErrorLabel( cfcatch.message ) ) />
				</cfcatch>
			</cftry>
			<cfset sleepMs( 350 ) />
		</cfloop>
		<cfset variables.loggerService.info( "Scrape finished: companies=#summary.companiesProcessed# jobsUpserted=#summary.jobsUpserted#" ) />
		<cfset variables.loggerService.info( "Source health: #serializeJSON( summary.sourceHealth )#" ) />
		<cfset variables.loggerService.info( "Error classes: #serializeJSON( summary.errorClasses )#" ) />
		<cfreturn summary />
	</cffunction>

	<!--- Remove legacy career_page_scan rows that pre-date URL gate (homepage / docs mistaken for jobs) --->
	<cffunction name="pruneCareerScanNonPostingJobs" access="public" returntype="numeric" output="false">
		<cfset pruneQ = variables.jobService.getCareerPageScanJobsForPrune() />
		<cfset removed = 0 />
		<cfloop from="1" to="#pruneQ.recordCount#" index="rowNum">
			<cfif NOT isProbableJobPostingUrl( trim( pruneQ.link[ rowNum ] ), trim( pruneQ.careers_url[ rowNum ] ) )>
				<cfset variables.jobService.deleteJobById( val( pruneQ.id[ rowNum ] ) ) />
				<cfset removed = removed + 1 />
			</cfif>
		</cfloop>
		<cfif removed GT 0>
			<cfset variables.loggerService.info( "Pruned #removed# career_page_scan job(s) with non-posting URLs." ) />
		</cfif>
		<cfreturn removed />
	</cffunction>

	<cffunction name="ingestGreenhouse" access="private" returntype="numeric" output="false">
		<cfargument name="companyId" type="numeric" required="true" />
		<cfargument name="atsConfigJson" type="string" required="true" />
		<cfset cfg = parseConfig( arguments.atsConfigJson ) />
		<cfif NOT structKeyExists( cfg, "board_token" ) OR NOT len( trim( cfg.board_token ) )>
			<cfthrow message="Missing ats_config.board_token for Greenhouse company." />
		</cfif>
		<!--- content=true returns full post HTML so CF/CFML/Lucee can be matched in body (list-only has no description) --->
		<cfset requestUrl = "https://boards-api.greenhouse.io/v1/boards/" & trim( cfg.board_token ) & "/jobs?content=true" />
		<cfset body = variables.httpClientService.getText( requestUrl, 120 ) />
		<cfset jobs = variables.greenhouseParser.parseJobs( body ) />
		<cfset n = 0 />
		<cfloop array="#jobs#" index="jobItem">
			<cfif NOT len( trim( jobItem.link ) ) OR NOT len( trim( jobItem.externalId ) )><cfcontinue /></cfif>
			<cfif NOT variables.scoringService.shouldPersistJob( jobItem.title, jobItem.description )><cfcontinue /></cfif>
			<cfset variables.jobService.upsertJob(
				companyId = arguments.companyId,
				externalId = jobItem.externalId,
				title = jobItem.title,
				description = jobItem.description,
				location = jobItem.location,
				link = jobItem.link,
				rawSource = "greenhouse"
			) />
			<cfset n = n + 1 />
		</cfloop>
		<cfreturn n />
	</cffunction>

	<cffunction name="ingestCareerPageScan" access="private" returntype="numeric" output="false">
		<cfargument name="companyId" type="numeric" required="true" />
		<cfargument name="careersUrl" type="string" required="true" />
		<cfargument name="atsConfigJson" type="string" required="true" />
		<cfif NOT len( trim( arguments.careersUrl ) )><cfreturn 0 /></cfif>
		<cfset cfg = parseConfig( arguments.atsConfigJson ) />
		<cfif structKeyExists( cfg, "keywords" ) AND isArray( cfg.keywords )>
			<cfset keywords = cfg.keywords />
		<cfelse>
			<cfset keywords = [ "coldfusion", "cfml", "lucee", "adobe coldfusion" ] />
		</cfif>
		<!--- Main careers landing page (soft-fail: bad TLS, 403/404, or timeouts should not fail the whole scrape run) --->
		<cftry>
			<cfset htmlMain = variables.httpClientService.getText( arguments.careersUrl, 28 ) />
			<cfcatch type="any">
				<cfset variables.loggerService.warn( "Career scan: primary fetch failed companyId=#arguments.companyId# url=#arguments.careersUrl#: #cfcatch.message#" ) />
				<cfreturn 0 />
			</cfcatch>
		</cftry>
		<cfset plainMain = htmlBodyToPlain( htmlMain ) />
		<!--- Follow same-site links that look like job detail pages, merge text for CF + hiring context --->
		<cfset candidateUrls = collectSameHostJobLikeUrls( htmlMain, arguments.careersUrl, 22 ) />
		<!--- Some companies expose only external ATS links (Workday/SuccessFactors/etc.) from careers landing pages. --->
		<cfset externalAtsUrls = collectExternalAtsUrls( htmlMain, arguments.careersUrl, 20 ) />
		<cfset aggregatedPlain = plainMain />
		<cfset maxSubFetch = 10 />
		<cfset fetched = 0 />
		<cfloop array="#candidateUrls#" index="subUrl">
			<cfif fetched GTE maxSubFetch><cfbreak /></cfif>
			<cfif normalizeUrlForCompare( subUrl ) EQ normalizeUrlForCompare( arguments.careersUrl )><cfcontinue /></cfif>
			<cftry>
				<cfset subHtml = variables.httpClientService.getText( trim( subUrl ), 14 ) />
				<cfset aggregatedPlain = aggregatedPlain & " " & htmlBodyToPlain( subHtml ) />
				<cfset fetched = fetched + 1 />
				<cfcatch type="any">
				</cfcatch>
			</cftry>
		</cfloop>
		<cfset lcAgg = lCase( aggregatedPlain ) />
		<!--- Require hiring/job language somewhere on careers + listing pages (filters marketing-only mentions) --->
		<cfif NOT careerTextHasHiringLanguage( lcAgg )>
			<cfset variables.loggerService.info( "Career scan: no hiring/job language on careers pages companyId=#arguments.companyId#" ) />
			<cfreturn 0 />
		</cfif>
		<cfset matched = "" />
		<cfloop array="#keywords#" index="kw">
			<cfif findNoCase( kw, lcAgg ) GT 0>
				<cfset matched = kw />
				<cfbreak />
			</cfif>
		</cfloop>
		<cfif NOT len( matched )><cfreturn 0 /></cfif>
		<cfset pos = findNoCase( matched, lcAgg ) />
		<cfif pos LT 1><cfset pos = 1 /></cfif>
		<cfset startAt = pos - 120 />
		<cfif startAt LT 1><cfset startAt = 1 /></cfif>
		<cfset snippet = mid( aggregatedPlain, startAt, 480 ) />
		<cfset finalTitle = "Career posting: " & matched />
		<cfif NOT variables.scoringService.shouldPersistJob( finalTitle, left( aggregatedPlain, 60000 ) )><cfreturn 0 /></cfif>
		<cfset bestLink = findBestJobLink( htmlMain, arguments.careersUrl, keywords ) />
		<cfset finalLink = pickCareerJobPostingUrl( bestLink, candidateUrls, arguments.careersUrl ) />
		<cfif NOT len( trim( finalLink ) )>
			<cfset finalLink = firstProbableJobUrlFromArray( externalAtsUrls, arguments.careersUrl ) />
		</cfif>
		<cfif NOT len( trim( finalLink ) )>
			<cfset variables.loggerService.info( "Career scan: CF+hiring text found but no ATS/job-detail URL companyId=#arguments.companyId#" ) />
			<cfreturn 0 />
		</cfif>
		<cfif NOT isProbableJobPostingUrl( finalLink, arguments.careersUrl )>
			<cfset variables.loggerService.info( "Career scan: resolved link is not a job posting URL companyId=#arguments.companyId# link=#finalLink#" ) />
			<cfreturn 0 />
		</cfif>
		<cfif structKeyExists( bestLink, "link" ) AND len( trim( bestLink.link ) ) AND normalizeUrlForCompare( bestLink.link ) EQ normalizeUrlForCompare( finalLink ) AND structKeyExists( bestLink, "title" ) AND len( trim( bestLink.title ) )>
			<cfset finalTitle = "Career posting: " & left( bestLink.title, 120 ) />
		</cfif>
		<cfset extId = "scan-" & hash( arguments.companyId & "|" & finalLink ) />
		<cfset variables.jobService.upsertJob(
			companyId = arguments.companyId,
			externalId = extId,
			title = finalTitle,
			description = snippet,
			location = "",
			link = finalLink,
			rawSource = "career_page_scan"
		) />
		<cfreturn 1 />
	</cffunction>

	<cffunction name="htmlBodyToPlain" access="private" returntype="string" output="false">
		<cfargument name="htmlBody" type="string" required="true" />
		<cfset p = reReplace( arguments.htmlBody, "(?si)<script[^>]*>.*?</script>", " ", "all" ) />
		<cfset p = reReplace( p, "(?si)<style[^>]*>.*?</style>", " ", "all" ) />
		<cfset p = reReplace( p, "(?si)<noscript[^>]*>.*?</noscript>", " ", "all" ) />
		<cfset p = reReplace( p, "(?si)<head[^>]*>.*?</head>", " ", "all" ) />
		<cfset p = reReplace( p, "<[^>]+>", " ", "all" ) />
		<cfreturn trim( reReplace( p, "\s+", " ", "all" ) ) />
	</cffunction>

	<cffunction name="careerTextHasHiringLanguage" access="private" returntype="boolean" output="false">
		<cfargument name="lcPlain" type="string" required="true" />
		<cfset t = arguments.lcPlain />
		<cfif find( "job", t ) OR find( "hiring", t ) OR find( "career", t ) OR find( "position", t ) OR find( "opening", t ) OR find( "vacancy", t ) OR find( "requisition", t ) OR find( "/apply", t ) OR find( "opportunit", t ) OR find( "join our", t ) OR find( "we are hiring", t ) OR find( "employment", t ) OR find( "role ", t ) OR find( " roles", t )>
			<cfreturn true />
		</cfif>
		<cfreturn false />
	</cffunction>

	<cffunction name="sameSiteHostCareer" access="private" returntype="boolean" output="false">
		<cfargument name="urlA" type="string" required="true" />
		<cfargument name="urlB" type="string" required="true" />
		<cftry>
			<cfset ua = createObject( "java", "java.net.URL" ).init( trim( arguments.urlA ) ) />
			<cfset ub = createObject( "java", "java.net.URL" ).init( trim( arguments.urlB ) ) />
			<cfset ha = lCase( ua.getHost() ) />
			<cfset hb = lCase( ub.getHost() ) />
			<cfif left( ha, 4 ) EQ "www."><cfset ha = mid( ha, 5, len( ha ) ) /></cfif>
			<cfif left( hb, 4 ) EQ "www."><cfset hb = mid( hb, 5, len( hb ) ) /></cfif>
			<cfreturn ha EQ hb />
			<cfcatch type="any">
				<cfreturn false />
			</cfcatch>
		</cftry>
	</cffunction>

	<cffunction name="hrefLooksLikeJobListingPath" access="private" returntype="boolean" output="false">
		<cfargument name="fullUrl" type="string" required="true" />
		<cfset u = lCase( trim( arguments.fullUrl ) ) />
		<cfif findNoCase( "gh_jid", u ) GT 0 OR findNoCase( "?job=", u ) GT 0 OR findNoCase( "&job=", u ) GT 0 OR findNoCase( "myworkdayjobs.com", u ) GT 0 OR findNoCase( "lever.co", u ) GT 0 OR findNoCase( "boards.greenhouse.io", u ) GT 0 OR findNoCase( "job-boards.greenhouse.io", u ) GT 0 OR findNoCase( "smartrecruiters.com", u ) GT 0 OR findNoCase( "ashbyhq.com", u ) GT 0 OR findNoCase( "icims.com", u ) GT 0 OR findNoCase( "successfactors.com", u ) GT 0 OR findNoCase( "taleo.net", u ) GT 0 OR findNoCase( "bamboohr.com", u ) GT 0 OR findNoCase( "darwinbox", u ) GT 0 OR findNoCase( "cutshort.io", u ) GT 0 OR findNoCase( "/job/", u ) GT 0 OR findNoCase( "/jobs/", u ) GT 0 OR findNoCase( "/jobs/search", u ) GT 0 OR findNoCase( "/job-search", u ) GT 0 OR findNoCase( "/position", u ) GT 0 OR findNoCase( "/opening", u ) GT 0 OR findNoCase( "/vacancy", u ) GT 0 OR findNoCase( "/requisition", u ) GT 0>
			<cfreturn true />
		</cfif>
		<cfif findNoCase( "/careers/", u ) GT 0 AND listLen( reReplace( listLast( u, "/" ), "[?##].*$", "", "all" ), "-" ) GTE 3>
			<cfreturn true />
		</cfif>
		<cfreturn false />
	</cffunction>

	<cffunction name="collectSameHostJobLikeUrls" access="private" returntype="array" output="false">
		<cfargument name="htmlBody" type="string" required="true" />
		<cfargument name="careersPageUrl" type="string" required="true" />
		<cfargument name="maxLinks" type="numeric" required="true" />
		<cfset out = [] />
		<cfset seen = {} />
		<cfset anchors = reMatchNoCase( "(?is)<a\\b[^>]*href\\s*=\\s*[^>]*>.*?</a>", arguments.htmlBody ) />
		<cfif NOT isArray( anchors )>
			<cfreturn out />
		</cfif>
		<cfloop array="#anchors#" index="anchorHtml">
			<cfset href = extractHref( anchorHtml ) />
			<cfif NOT len( href )><cfcontinue /></cfif>
			<cfif left( lCase( href ), 11 ) EQ "javascript:" OR left( lCase( href ), 7 ) EQ "mailto:" OR left( href, 1 ) EQ chr( 35 )>
				<cfcontinue />
			</cfif>
			<cfset absoluteUrl = absolutizeUrl( arguments.careersPageUrl, href ) />
			<cfif NOT len( absoluteUrl )><cfcontinue /></cfif>
			<cfif NOT sameSiteHostCareer( absoluteUrl, arguments.careersPageUrl )><cfcontinue /></cfif>
			<cfif NOT hrefLooksLikeJobListingPath( absoluteUrl )><cfcontinue /></cfif>
			<cfif structKeyExists( seen, absoluteUrl )><cfcontinue /></cfif>
			<cfset seen[ absoluteUrl ] = true />
			<cfset arrayAppend( out, absoluteUrl ) />
			<cfif arrayLen( out ) GTE arguments.maxLinks>
				<cfbreak />
			</cfif>
		</cfloop>
		<cfreturn out />
	</cffunction>

	<cffunction name="collectExternalAtsUrls" access="private" returntype="array" output="false">
		<cfargument name="htmlBody" type="string" required="true" />
		<cfargument name="careersPageUrl" type="string" required="true" />
		<cfargument name="maxLinks" type="numeric" required="true" />
		<cfset out = [] />
		<cfset seen = {} />
		<cfset anchors = reMatchNoCase( "(?is)<a\\b[^>]*href\\s*=\\s*[^>]*>.*?</a>", arguments.htmlBody ) />
		<cfif NOT isArray( anchors )>
			<cfreturn out />
		</cfif>
		<cfloop array="#anchors#" index="anchorHtml">
			<cfset href = extractHref( anchorHtml ) />
			<cfif NOT len( href )><cfcontinue /></cfif>
			<cfif left( lCase( href ), 11 ) EQ "javascript:" OR left( lCase( href ), 7 ) EQ "mailto:" OR left( href, 1 ) EQ chr( 35 )>
				<cfcontinue />
			</cfif>
			<cfset absoluteUrl = absolutizeUrl( arguments.careersPageUrl, href ) />
			<cfif NOT len( absoluteUrl )><cfcontinue /></cfif>
			<cfif sameSiteHostCareer( absoluteUrl, arguments.careersPageUrl )><cfcontinue /></cfif>
			<cfif NOT hrefLooksLikeJobListingPath( absoluteUrl )><cfcontinue /></cfif>
			<cfif structKeyExists( seen, absoluteUrl )><cfcontinue /></cfif>
			<cfset seen[ absoluteUrl ] = true />
			<cfset arrayAppend( out, absoluteUrl ) />
			<cfif arrayLen( out ) GTE arguments.maxLinks><cfbreak /></cfif>
		</cfloop>
		<cfreturn out />
	</cffunction>

	<cffunction name="pickCareerJobPostingUrl" access="private" returntype="string" output="false">
		<cfargument name="bestLinkStruct" type="struct" required="true" />
		<cfargument name="candidateUrls" type="array" required="true" />
		<cfargument name="careersUrl" type="string" required="true" />
		<cfif structKeyExists( arguments.bestLinkStruct, "link" ) AND len( trim( arguments.bestLinkStruct.link ) )>
			<cfset u = trim( arguments.bestLinkStruct.link ) />
			<cfif isProbableJobPostingUrl( u, arguments.careersUrl )>
				<cfreturn u />
			</cfif>
		</cfif>
		<cfloop array="#arguments.candidateUrls#" index="cand">
			<cfif isProbableJobPostingUrl( cand, arguments.careersUrl )>
				<cfreturn cand />
			</cfif>
		</cfloop>
		<cfreturn "" />
	</cffunction>

	<cffunction name="firstProbableJobUrlFromArray" access="private" returntype="string" output="false">
		<cfargument name="candidateUrls" type="array" required="true" />
		<cfargument name="careersUrl" type="string" required="true" />
		<cfloop array="#arguments.candidateUrls#" index="cand">
			<cfif isProbableJobPostingUrl( cand, arguments.careersUrl )>
				<cfreturn cand />
			</cfif>
		</cfloop>
		<cfreturn "" />
	</cffunction>

	<cffunction name="findBestJobLink" access="private" returntype="struct" output="false">
		<cfargument name="htmlBody" type="string" required="true" />
		<cfargument name="baseUrl" type="string" required="true" />
		<cfargument name="keywords" type="array" required="true" />
		<cfset result = { link: "", title: "" } />
		<cfset anchors = reMatchNoCase( "(?is)<a\\b[^>]*href\\s*=\\s*[^>]*>.*?</a>", arguments.htmlBody ) />
		<cfif NOT isArray( anchors )>
			<cfreturn result />
		</cfif>
		<cfset fallback = { link: "", title: "" } />
		<cfloop array="#anchors#" index="anchorHtml">
			<cfset href = extractHref( anchorHtml ) />
			<cfif NOT len( href )><cfcontinue /></cfif>
			<cfif left( lCase( href ), 11 ) EQ "javascript:" OR left( lCase( href ), 7 ) EQ "mailto:" OR left( href, 1 ) EQ chr(35)>
				<cfcontinue />
			</cfif>
			<cfset absoluteUrl = absolutizeUrl( arguments.baseUrl, href ) />
			<cfif NOT len( absoluteUrl )><cfcontinue /></cfif>
			<cfset linkText = href />
			<cfset linkEvidence = lCase( anchorHtml & " " & absoluteUrl ) />
			<cfif find( "job", linkEvidence ) EQ 0 AND find( "career", linkEvidence ) EQ 0 AND find( "position", linkEvidence ) EQ 0>
				<cfcontinue />
			</cfif>
			<cfif NOT len( fallback.link )>
				<cfset fallback.link = absoluteUrl />
				<cfset fallback.title = linkText />
			</cfif>
			<cfif containsKeyword( linkEvidence, arguments.keywords )>
				<cfset result.link = absoluteUrl />
				<cfset result.title = linkText />
				<cfreturn result />
			</cfif>
		</cfloop>
		<cfif len( fallback.link )>
			<cfreturn fallback />
		</cfif>
		<cfreturn result />
	</cffunction>

	<cffunction name="extractHref" access="private" returntype="string" output="false">
		<cfargument name="anchorHtml" type="string" required="true" />
		<cfset hrefPos = findNoCase( "href", arguments.anchorHtml ) />
		<cfif hrefPos LTE 0><cfreturn "" /></cfif>
		<cfset eqPos = find( "=", arguments.anchorHtml, hrefPos ) />
		<cfif eqPos LTE 0><cfreturn "" /></cfif>
		<cfset rawValue = trim( mid( arguments.anchorHtml, eqPos + 1, len( arguments.anchorHtml ) - eqPos ) ) />
		<cfif NOT len( rawValue )><cfreturn "" /></cfif>
		<cfset firstChar = left( rawValue, 1 ) />
		<cfif firstChar EQ chr(34) OR firstChar EQ chr(39)>
			<cfset endPos = find( firstChar, rawValue, 2 ) />
			<cfif endPos GT 2>
				<cfreturn trim( mid( rawValue, 2, endPos - 2 ) ) />
			</cfif>
		<cfelse>
			<cfset endSpace = find( " ", rawValue ) />
			<cfset endTag = find( ">", rawValue ) />
			<cfif endSpace GT 0 AND endTag GT 0>
				<cfset endPos = min( endSpace, endTag ) />
			<cfelseif endSpace GT 0>
				<cfset endPos = endSpace />
			<cfelseif endTag GT 0>
				<cfset endPos = endTag />
			<cfelse>
				<cfset endPos = 0 />
			</cfif>
			<cfif endPos GT 1>
				<cfreturn trim( left( rawValue, endPos - 1 ) ) />
			</cfif>
		</cfif>
		<cfreturn "" />
	</cffunction>

	<cffunction name="absolutizeUrl" access="private" returntype="string" output="false">
		<cfargument name="baseUrl" type="string" required="true" />
		<cfargument name="targetUrl" type="string" required="true" />
		<cftry>
			<cfset baseObj = createObject( "java", "java.net.URL" ).init( arguments.baseUrl ) />
			<cfset resolvedObj = createObject( "java", "java.net.URL" ).init( baseObj, arguments.targetUrl ) />
			<cfreturn toString( resolvedObj.toString() ) />
			<cfcatch type="any">
				<cfif left( arguments.targetUrl, 4 ) EQ "http">
					<cfreturn arguments.targetUrl />
				</cfif>
				<cfreturn "" />
			</cfcatch>
		</cftry>
	</cffunction>

	<cffunction name="containsKeyword" access="private" returntype="boolean" output="false">
		<cfargument name="textValue" type="string" required="true" />
		<cfargument name="keywords" type="array" required="true" />
		<cfloop array="#arguments.keywords#" index="kw">
			<cfif len( trim( kw ) ) AND findNoCase( kw, arguments.textValue ) GT 0>
				<cfreturn true />
			</cfif>
		</cfloop>
		<cfreturn false />
	</cffunction>

	<cffunction name="ingestRemotive" access="private" returntype="numeric" output="false">
		<cfset body = variables.httpClientService.getText( "https://remotive.com/api/remote-jobs" ) />
		<cfset payload = deserializeJSON( body ) />
		<cfif NOT structKeyExists( payload, "jobs" ) OR NOT isArray( payload.jobs )><cfreturn 0 /></cfif>
		<cfset n = 0 />
		<cfloop array="#payload.jobs#" index="jobItem">
			<cfif NOT structKeyExists( jobItem, "id" ) OR NOT structKeyExists( jobItem, "title" )><cfcontinue /></cfif>
			<cfif structKeyExists( jobItem, "company_name" )><cfset companyName = trim( jobItem.company_name ) /><cfelse><cfset companyName = "Unknown Company" /></cfif>
			<cfif structKeyExists( jobItem, "company_website" )><cfset companyWebsite = trim( jobItem.company_website ) /><cfelse><cfset companyWebsite = "" /></cfif>
			<cfset companyId = variables.companyService.getOrCreateExternalCompany( companyName, companyWebsite ) />
			<cfset externalId = "remotive-" & toString( jobItem.id ) />
			<cfif structKeyExists( jobItem, "description" )><cfset desc = toString( jobItem.description ) /><cfelse><cfset desc = "" /></cfif>
			<cfif structKeyExists( jobItem, "candidate_required_location" )><cfset location = toString( jobItem.candidate_required_location ) /><cfelse><cfset location = "" /></cfif>
			<cfif structKeyExists( jobItem, "url" )><cfset link = toString( jobItem.url ) /><cfelse><cfset link = "" /></cfif>
			<cfif NOT len( trim( link ) )><cfcontinue /></cfif>
			<cfif NOT variables.scoringService.shouldPersistJob( toString( jobItem.title ), desc )><cfcontinue /></cfif>
			<cfset variables.jobService.upsertJob(companyId=companyId, externalId=externalId, title=jobItem.title, description=desc, location=location, link=link, rawSource="remotive") />
			<cfset n = n + 1 />
		</cfloop>
		<cfreturn n />
	</cffunction>

	<cffunction name="ingestArbeitnow" access="private" returntype="numeric" output="false">
		<cfset body = variables.httpClientService.getText( "https://www.arbeitnow.com/api/job-board-api" ) />
		<cfset payload = deserializeJSON( body ) />
		<cfif structKeyExists( payload, "data" ) AND isArray( payload.data )><cfset jobRows = payload.data /><cfelseif structKeyExists( payload, "jobs" ) AND isArray( payload.jobs )><cfset jobRows = payload.jobs /><cfelse><cfset jobRows = [] /></cfif>
		<cfset n = 0 />
		<cfloop array="#jobRows#" index="jobItem">
			<cfif NOT structKeyExists( jobItem, "title" )><cfcontinue /></cfif>
			<cfif structKeyExists( jobItem, "company_name" )><cfset companyName = trim( jobItem.company_name ) /><cfelse><cfset companyName = "Unknown Company" /></cfif>
			<cfset companyId = variables.companyService.getOrCreateExternalCompany( companyName, "" ) />
			<cfif structKeyExists( jobItem, "slug" )><cfset externalId = "arbeitnow-" & toString( jobItem.slug ) /><cfelse><cfset externalId = "arbeitnow-" & hash( companyName & "|" & jobItem.title ) /></cfif>
			<cfif structKeyExists( jobItem, "description" )><cfset desc = toString( jobItem.description ) /><cfelse><cfset desc = "" /></cfif>
			<cfif structKeyExists( jobItem, "location" )><cfset location = toString( jobItem.location ) /><cfelse><cfset location = "" /></cfif>
			<cfif structKeyExists( jobItem, "url" )><cfset link = toString( jobItem.url ) /><cfelse><cfset link = "" /></cfif>
			<cfif NOT len( trim( link ) ) AND structKeyExists( jobItem, "slug" )><cfset link = "https://www.arbeitnow.com/jobs/" & toString( jobItem.slug ) /></cfif>
			<cfif NOT len( trim( link ) )><cfcontinue /></cfif>
			<cfif NOT variables.scoringService.shouldPersistJob( toString( jobItem.title ), desc )><cfcontinue /></cfif>
			<cfset variables.jobService.upsertJob(companyId=companyId, externalId=externalId, title=jobItem.title, description=desc, location=location, link=link, rawSource="arbeitnow") />
			<cfset n = n + 1 />
		</cfloop>
		<cfreturn n />
	</cffunction>

	<!--- https://www.getcfmljobs.com/ — CFML community job board (HTML only; respect rate limits) --->
	<cffunction name="ingestGetCfmlJobs" access="private" returntype="numeric" output="false">
		<cfargument name="listingUrl" type="string" required="true" />
		<cfargument name="atsConfigJson" type="string" required="false" default="" />
		<cfset cfg = parseConfig( arguments.atsConfigJson ) />
		<cfset maxDetails = getNumericCfg( cfg, "max_job_details", 40 ) />
		<cfset listUrl = len( trim( arguments.listingUrl ) ) ? trim( arguments.listingUrl ) : "https://www.getcfmljobs.com/" />
		<cfset basePage = "https://www.getcfmljobs.com/index.cfm" />
		<cftry>
			<cfset htmlList = variables.httpClientService.getText( listUrl, 35 ) />
			<cfcatch type="any">
				<cfset variables.loggerService.warn( "GetCFMLJobs listing fetch failed: #cfcatch.message#" ) />
				<cfreturn 0 />
			</cfcatch>
		</cftry>
		<cfset relPaths = [] />
		<cfset m1 = reMatchNoCase( "/jobs/index\.cfm/[^\s""'<>]+", htmlList ) />
		<cfif isArray( m1 )>
			<cfloop array="#m1#" index="rp">
				<cfset arrayAppend( relPaths, rp ) />
			</cfloop>
		</cfif>
		<cfset m2 = reMatchNoCase( "\.\./viewjob\.cfm\?jobid=\d+", htmlList ) />
		<cfif isArray( m2 )>
			<cfloop array="#m2#" index="rp">
				<cfset arrayAppend( relPaths, rp ) />
			</cfloop>
		</cfif>
		<cfset m3 = reMatchNoCase( "/viewjob\.cfm\?jobid=\d+", htmlList ) />
		<cfif isArray( m3 )>
			<cfloop array="#m3#" index="rp">
				<cfset arrayAppend( relPaths, rp ) />
			</cfloop>
		</cfif>
		<cfset byId = {} />
		<cfloop array="#relPaths#" index="rel">
			<cfset absU = absolutizeUrl( basePage, rel ) />
			<cfif NOT len( absU )><cfcontinue /></cfif>
			<cfset absU = replace( absU, "http://www.getcfmljobs.com", "https://www.getcfmljobs.com", "all" ) />
			<cfset absU = replace( absU, "http://getcfmljobs.com", "https://www.getcfmljobs.com", "all" ) />
			<cfset jid = getCfmlJobsJobKey( absU ) />
			<cfif NOT len( jid )><cfcontinue /></cfif>
			<cfif NOT structKeyExists( byId, jid )>
				<cfset byId[ jid ] = absU />
			</cfif>
		</cfloop>
		<cfset n = 0 />
		<cfset fetched = 0 />
		<cfset idKeys = structKeyList( byId ) />
		<cfloop list="#idKeys#" index="jidKey">
			<cfif fetched GTE maxDetails><cfbreak /></cfif>
			<cfset jobUrl = byId[ jidKey ] />
			<cftry>
				<cfset jobHtml = variables.httpClientService.getText( jobUrl, 25 ) />
				<cfcatch type="any">
					<cfset variables.loggerService.warn( "GetCFMLJobs job fetch failed jobId=#jidKey#: #cfcatch.message#" ) />
					<cfcontinue />
				</cfcatch>
			</cftry>
			<cfset parsed = parseGetCfmlJobsJobHtml( jobHtml ) />
			<cfif NOT len( trim( parsed.title ) )>
				<cfset parsed.title = "ColdFusion job (GetCFMLJobs)" />
			</cfif>
			<cfset companyName = len( trim( parsed.companyName ) ) ? trim( parsed.companyName ) : "Unknown Company" />
			<cfset companyId = variables.companyService.getOrCreateExternalCompany( companyName, parsed.companyWebsite ) />
			<cfset externalId = "getcfmljobs-" & jidKey />
			<cfif NOT variables.scoringService.shouldPersistJob( parsed.title, parsed.description )>
				<cfset fetched = fetched + 1 />
				<cfset sleepMs( 400 ) />
				<cfcontinue />
			</cfif>
			<cfset variables.jobService.upsertJob(
				companyId = companyId,
				externalId = externalId,
				title = parsed.title,
				description = parsed.description,
				location = parsed.location,
				link = jobUrl,
				rawSource = "getcfmljobs"
			) />
			<cfset n = n + 1 />
			<cfset fetched = fetched + 1 />
			<cfset sleepMs( 450 ) />
		</cfloop>
		<cfif n GT 0>
			<cfset variables.loggerService.info( "GetCFMLJobs ingest: upserted #n# job(s) from #listUrl#" ) />
		</cfif>
		<cfreturn n />
	</cffunction>

	<cffunction name="getCfmlJobsJobKey" access="private" returntype="string" output="false">
		<cfargument name="absoluteUrl" type="string" required="true" />
		<cfset u = trim( arguments.absoluteUrl ) />
		<cfif findNoCase( "jobid=", u )>
			<cfreturn listLast( u, "=" ) />
		</cfif>
		<cfset tail = listLast( u, "/" ) />
		<cfif len( tail ) AND isNumeric( tail )>
			<cfreturn tail />
		</cfif>
		<cfreturn "" />
	</cffunction>

	<cffunction name="parseGetCfmlJobsJobHtml" access="private" returntype="struct" output="false">
		<cfargument name="htmlBody" type="string" required="true" />
		<cfset s = arguments.htmlBody />
		<cfset out = { title: "", companyName: "", companyWebsite: "", location: "", description: "" } />
		<cfset hp = findNoCase( "<h2>", s ) />
		<cfif hp GT 0>
			<cfset he = find( "</h2>", s, hp ) />
			<cfif he GT hp>
				<cfset out.title = trim( mid( s, hp + 4, he - hp - 4 ) ) />
			</cfif>
		</cfif>
		<cfset cp = findNoCase( "<strong>Company:</strong>", s ) />
		<cfif cp GT 0>
			<cfset seg = mid( s, cp, 600 ) />
			<cfset segPlain = trim( reReplace( reReplace( seg, "<[^>]+>", " ", "all" ), "\s+", " ", "all" ) ) />
			<cfset cnPos = findNoCase( "company:", segPlain ) />
			<cfif cnPos GT 0>
				<cfset tail = trim( mid( segPlain, cnPos + 8, 220 ) ) />
				<cfset jb = findNoCase( "job type", tail ) />
				<cfif jb GT 0>
					<cfset out.companyName = trim( left( tail, jb - 1 ) ) />
				<cfelse>
					<cfset out.companyName = trim( tail ) />
				</cfif>
			</cfif>
		</cfif>
		<cfset cv = findNoCase( "Click to view company website", s ) />
		<cfif cv GT 0>
			<cfset win = mid( s, cv - 260, 260 ) />
			<cfset hrefArr = reMatchNoCase( "href\s*=\s*""[^""]+""", win ) />
			<cfif isArray( hrefArr ) AND arrayLen( hrefArr ) GT 0>
				<cfset hi = arrayLen( hrefArr ) />
				<cfloop condition="hi GTE 1">
					<cfset rawHref = hrefArr[ hi ] />
					<cfset candUrl = trim( reReplaceNoCase( rawHref, "(?i)^href\s*=\s*""|""$", "", "all" ) ) />
					<cfset hi = hi - 1 />
					<cfif findNoCase( "getcfmljobs.com", candUrl ) GT 0><cfcontinue /></cfif>
					<cfif left( candUrl, 7 ) EQ "http://" OR left( candUrl, 8 ) EQ "https://" >
						<cfset out.companyWebsite = candUrl />
						<cfbreak />
					</cfif>
				</cfloop>
			</cfif>
		</cfif>
		<cfset lp = findNoCase( "<strong>Location:</strong>", s ) />
		<cfif lp GT 0>
			<cfset segL = mid( s, lp, 700 ) />
			<cfset segLPlain = trim( reReplace( reReplace( reReplace( segL, "&nbsp;", " ", "all" ), "<[^>]+>", " ", "all" ), "\s+", " ", "all" ) ) />
			<cfset locPos = findNoCase( "location:", segLPlain ) />
			<cfif locPos GT 0>
				<cfset tailL = trim( mid( segLPlain, locPos + 10, 200 ) ) />
				<cfset jd = findNoCase( "job description", tailL ) />
				<cfif jd GT 0>
					<cfset out.location = trim( left( tailL, jd - 1 ) ) />
				<cfelse>
					<cfset out.location = trim( tailL ) />
				</cfif>
			</cfif>
		</cfif>
		<cfset jdPos = findNoCase( "<legend>Job Description</legend>", s ) />
		<cfif jdPos GT 0>
			<cfset chunk = mid( s, jdPos, 25000 ) />
			<cfset hrp = findNoCase( "<hr", chunk ) />
			<cfif hrp GT 0>
				<cfset chunk = left( chunk, hrp ) />
			</cfif>
			<cfset out.description = trim( reReplace( reReplace( reReplace( chunk, "<[^>]+>", " ", "all" ), "&nbsp;", " ", "all" ), "\s+", " ", "all" ) ) />
			<cfset out.description = trim( reReplaceNoCase( out.description, "^.*?job description", "", "all" ) ) />
		</cfif>
		<cfreturn out />
	</cffunction>

	<cffunction name="ingestAdzuna" access="private" returntype="numeric" output="false">
		<cfargument name="atsConfigJson" type="string" required="true" />
		<cfset cfg = parseConfig( arguments.atsConfigJson ) />
		<cfif NOT structKeyExists( cfg, "app_id" ) OR NOT structKeyExists( cfg, "app_key" ) OR NOT len( trim( cfg.app_id ) ) OR NOT len( trim( cfg.app_key ) )>
			<cfset variables.loggerService.warn( "Adzuna skipped: missing app_id/app_key in ats_config." ) />
			<cfreturn 0 />
		</cfif>
		<cfif structKeyExists( cfg, "country" )><cfset country = lCase( cfg.country ) /><cfelse><cfset country = "gb" /></cfif>
		<cfset n = 0 />
		<cfset queries = [ "coldfusion", "cfml", "lucee", "coldbox" ] />
		<cfloop array="#queries#" index="term">
			<cfset endpoint = "https://api.adzuna.com/v1/api/jobs/" & country & "/search/1?app_id=" & urlEncodedFormat( cfg.app_id ) & "&app_key=" & urlEncodedFormat( cfg.app_key ) & "&results_per_page=50&what=" & urlEncodedFormat( term ) />
			<cfset body = variables.httpClientService.getText( endpoint ) />
			<cfset payload = deserializeJSON( body ) />
			<cfif NOT structKeyExists( payload, "results" ) OR NOT isArray( payload.results )><cfcontinue /></cfif>
			<cfloop array="#payload.results#" index="jobItem">
				<cfif NOT structKeyExists( jobItem, "title" )><cfcontinue /></cfif>
				<cfset companyName = "Unknown Company" />
				<cfif structKeyExists( jobItem, "company" ) AND isStruct( jobItem.company ) AND structKeyExists( jobItem.company, "display_name" )><cfset companyName = toString( jobItem.company.display_name ) /></cfif>
				<cfset companyId = variables.companyService.getOrCreateExternalCompany( companyName, "" ) />
				<cfif structKeyExists( jobItem, "id" )><cfset externalId = "adzuna-" & toString( jobItem.id ) /><cfelse><cfset externalId = "adzuna-" & hash( companyName & "|" & jobItem.title ) /></cfif>
				<cfif structKeyExists( jobItem, "description" )><cfset desc = toString( jobItem.description ) /><cfelse><cfset desc = "" /></cfif>
				<cfset location = "" />
				<cfif structKeyExists( jobItem, "location" ) AND isStruct( jobItem.location ) AND structKeyExists( jobItem.location, "display_name" )><cfset location = toString( jobItem.location.display_name ) /></cfif>
				<cfif structKeyExists( jobItem, "redirect_url" )><cfset link = toString( jobItem.redirect_url ) /><cfelse><cfset link = "" /></cfif>
				<cfif NOT len( trim( link ) )><cfcontinue /></cfif>
				<cfif NOT variables.scoringService.shouldPersistJob( toString( jobItem.title ), desc )><cfcontinue /></cfif>
				<cfset variables.jobService.upsertJob(companyId=companyId, externalId=externalId, title=jobItem.title, description=desc, location=location, link=link, rawSource="adzuna") />
				<cfset n = n + 1 />
			</cfloop>
		</cfloop>
		<cfreturn n />
	</cffunction>

	<!--- Google Programmable Search Engine (Custom Search JSON API). Use for web + site-scoped queries (e.g. LinkedIn jobs, Instahyre) when api_key + cx are set. --->
	<cffunction name="ingestGoogleCse" access="private" returntype="numeric" output="false">
		<cfargument name="atsConfigJson" type="string" required="true" />
		<cfset cfg = parseConfig( arguments.atsConfigJson ) />
		<cfif NOT structKeyExists( cfg, "api_key" ) OR NOT structKeyExists( cfg, "cx" ) OR NOT len( trim( cfg.api_key ) ) OR NOT len( trim( cfg.cx ) )>
			<cfset variables.loggerService.warn( "Google CSE skipped: set ats_config.api_key and ats_config.cx (Programmable Search Engine)." ) />
			<cfreturn 0 />
		</cfif>
		<cfset numPerQuery = getNumericCfg( cfg, "num", 10 ) />
		<cfif numPerQuery LT 1><cfset numPerQuery = 1 /></cfif>
		<cfif numPerQuery GT 10><cfset numPerQuery = 10 /></cfif>
		<cfif structKeyExists( cfg, "queries" ) AND isArray( cfg.queries ) AND arrayLen( cfg.queries ) GT 0>
			<cfset queries = cfg.queries />
		<cfelse>
			<cfset queries = [
				"(coldfusion OR cfml OR lucee OR coldbox) site:linkedin.com/jobs",
				"(coldfusion OR cfml OR lucee) site:instahyre.com",
				"(coldfusion OR cfml OR lucee) site:cutshort.io/job"
			] />
		</cfif>
		<cfset n = 0 />
		<cfloop array="#queries#" index="qText">
			<cfset qTrim = trim( toString( qText ) ) />
			<cfif NOT len( qTrim )><cfcontinue /></cfif>
			<cfset endpoint = "https://www.googleapis.com/customsearch/v1?key=" & urlEncodedFormat( trim( cfg.api_key ) ) & "&cx=" & urlEncodedFormat( trim( cfg.cx ) ) & "&q=" & urlEncodedFormat( qTrim ) & "&num=" & numPerQuery />
			<cftry>
				<cfset body = variables.httpClientService.getText( endpoint, 25 ) />
				<cfset payload = deserializeJSON( body ) />
				<cfcatch type="any">
					<cfset variables.loggerService.warn( "Google CSE request failed for query=#left( qTrim, 120 )#: #cfcatch.message#" ) />
					<cfcontinue />
				</cfcatch>
			</cftry>
			<cfif structKeyExists( payload, "error" )>
				<cfset variables.loggerService.warn( "Google CSE API error for query=#left( qTrim, 80 )#: #serializeJSON( payload.error )#" ) />
				<cfcontinue />
			</cfif>
			<cfif NOT structKeyExists( payload, "items" ) OR NOT isArray( payload.items )><cfcontinue /></cfif>
			<cfloop array="#payload.items#" index="item">
				<cfif NOT isStruct( item )><cfcontinue /></cfif>
				<cfif NOT structKeyExists( item, "link" ) OR NOT len( trim( toString( item.link ) ) )><cfcontinue /></cfif>
				<cfset link = trim( toString( item.link ) ) />
				<cfset jt = structKeyExists( item, "title" ) ? trim( toString( item.title ) ) : "" />
				<cfset sn = structKeyExists( item, "snippet" ) ? trim( toString( item.snippet ) ) : "" />
				<cfif NOT variables.scoringService.shouldPersistJob( jt, sn )><cfcontinue /></cfif>
				<cfset companyName = googleCseCompanyLabel( link, jt, sn ) />
				<cfset companyId = variables.companyService.getOrCreateExternalCompany( companyName, "" ) />
				<cfset externalId = "gcs-" & hash( lCase( link ) ) />
				<cfset variables.jobService.upsertJob( companyId = companyId, externalId = externalId, title = len( jt ) ? jt : "Job (Google search)", description = sn, location = "", link = link, rawSource = "google_cse" ) />
				<cfset n = n + 1 />
			</cfloop>
			<cfset sleepMs( 400 ) />
		</cfloop>
		<cfif n GT 0>
			<cfset variables.loggerService.info( "Google CSE ingest: upserted #n# job(s)." ) />
		</cfif>
		<cfreturn n />
	</cffunction>

	<cffunction name="googleCseCompanyLabel" access="private" returntype="string" output="false">
		<cfargument name="link" type="string" required="true" />
		<cfargument name="title" type="string" required="true" />
		<cfargument name="snippet" type="string" required="true" />
		<cftry>
			<cfset ju = createObject( "java", "java.net.URL" ).init( trim( arguments.link ) ) />
			<cfset h = lCase( ju.getHost() ) />
			<cfcatch type="any">
				<cfreturn "Job listing" />
			</cfcatch>
		</cftry>
		<cfif left( h, 4 ) EQ "www."><cfset h = mid( h, 5, len( h ) ) /></cfif>
		<cfif findNoCase( "linkedin.", h )><cfreturn "LinkedIn" /></cfif>
		<cfif findNoCase( "instahyre.", h )><cfreturn "Instahyre" /></cfif>
		<cfif findNoCase( "cutshort.", h )><cfreturn "Cutshort" /></cfif>
		<cfif findNoCase( "google.", h )><cfreturn "Google" /></cfif>
		<cfreturn h />
	</cffunction>

	<!--- Cutshort listing pages include absolute /job/... links; fetch each detail page and keep rows that pass CF keyword scoring. --->
	<cffunction name="ingestCutshortScan" access="private" returntype="numeric" output="false">
		<cfargument name="careersUrl" type="string" required="true" />
		<cfargument name="atsConfigJson" type="string" required="true" />
		<cfset cfg = parseConfig( arguments.atsConfigJson ) />
		<cfset maxDetails = getNumericCfg( cfg, "max_job_details", 18 ) />
		<cfif structKeyExists( cfg, "listing_urls" ) AND isArray( cfg.listing_urls ) AND arrayLen( cfg.listing_urls ) GT 0>
			<cfset listingUrls = cfg.listing_urls />
		<cfelse>
			<cfset listingUrls = [ len( trim( arguments.careersUrl ) ) ? trim( arguments.careersUrl ) : "https://cutshort.io/jobs?q=coldfusion" ] />
		</cfif>
		<cfset seenUrls = {} />
		<cfset jobUrls = [] />
		<cfloop array="#listingUrls#" index="lu">
			<cfset listU = trim( toString( lu ) ) />
			<cfif NOT len( listU )><cfcontinue /></cfif>
			<cftry>
				<cfset htmlList = variables.httpClientService.getText( listU, 28 ) />
				<cfcatch type="any">
					<cfset variables.loggerService.warn( "Cutshort listing fetch failed url=#listU#: #cfcatch.message#" ) />
					<cfcontinue />
				</cfcatch>
			</cftry>
			<cfset found = reMatchNoCase( "https://cutshort\.io/job/[^""'\s<>]+", htmlList ) />
			<cfif isArray( found )>
				<cfloop array="#found#" index="ju">
					<cfset ju = trim( ju ) />
					<cfif NOT len( ju ) OR structKeyExists( seenUrls, ju )><cfcontinue /></cfif>
					<cfset seenUrls[ ju ] = true />
					<cfset arrayAppend( jobUrls, ju ) />
				</cfloop>
			</cfif>
			<cfset sleepMs( 350 ) />
		</cfloop>
		<cfset n = 0 />
		<cfset fetched = 0 />
		<cfloop array="#jobUrls#" index="jobUrl">
			<cfif fetched GTE maxDetails><cfbreak /></cfif>
			<cftry>
				<cfset jobHtml = variables.httpClientService.getText( jobUrl, 22 ) />
				<cfcatch type="any">
					<cfset variables.loggerService.warn( "Cutshort job fetch failed url=#jobUrl#: #cfcatch.message#" ) />
					<cfcontinue />
				</cfcatch>
			</cftry>
			<cfset parsed = parseCutshortJobHtml( jobHtml ) />
			<cfif NOT variables.scoringService.shouldPersistJob( parsed.title, parsed.description )>
				<cfset fetched = fetched + 1 />
				<cfset sleepMs( 300 ) />
				<cfcontinue />
			</cfif>
			<cfset companyName = len( trim( parsed.companyName ) ) ? trim( parsed.companyName ) : "Cutshort employer" />
			<cfset companyId = variables.companyService.getOrCreateExternalCompany( companyName, parsed.companyWebsite ) />
			<cfset extKey = listLast( jobUrl, "/" ) />
			<cfset externalId = "cutshort-" & ( len( extKey ) ? extKey : hash( jobUrl ) ) />
			<cfset variables.jobService.upsertJob( companyId = companyId, externalId = externalId, title = parsed.title, description = parsed.description, location = parsed.location, link = jobUrl, rawSource = "cutshort" ) />
			<cfset n = n + 1 />
			<cfset fetched = fetched + 1 />
			<cfset sleepMs( 400 ) />
		</cfloop>
		<cfif n GT 0>
			<cfset variables.loggerService.info( "Cutshort ingest: upserted #n# job(s)." ) />
		</cfif>
		<cfreturn n />
	</cffunction>

	<!--- LinkedIn public job search (no auth, returns SSR HTML with job cards). Respects rate limits. --->
	<cffunction name="ingestLinkedInPublic" access="private" returntype="numeric" output="false">
		<cfargument name="atsConfigJson" type="string" required="true" />
		<cfset cfg = parseConfig( arguments.atsConfigJson ) />
		<cfif structKeyExists( cfg, "search_urls" ) AND isArray( cfg.search_urls ) AND arrayLen( cfg.search_urls ) GT 0>
			<cfset searchUrls = cfg.search_urls />
		<cfelse>
			<cfset searchUrls = [
				"https://www.linkedin.com/jobs/search?keywords=coldfusion&location=India&f_TPR=r2592000&position=1&pageNum=0",
				"https://www.linkedin.com/jobs/search?keywords=coldfusion+OR+cfml+OR+lucee&f_WT=2&f_TPR=r2592000&position=1&pageNum=0"
			] />
		</cfif>
		<cfset seenLinks = {} />
		<cfset n = 0 />
		<cfloop array="#searchUrls#" index="su">
			<cfset searchUrl = trim( toString( su ) ) />
			<cfif NOT len( searchUrl )><cfcontinue /></cfif>
			<cftry>
				<cfset htmlPage = variables.httpClientService.getText( searchUrl, 30 ) />
				<cfcatch type="any">
					<cfset variables.loggerService.warn( "LinkedIn public fetch failed url=#left( searchUrl, 120 )#: #cfcatch.message#" ) />
					<cfcontinue />
				</cfcatch>
			</cftry>
			<cfset titles = reMatchNoCase( "base-search-card__title[^>]*>[^<]+<", htmlPage ) />
			<cfset links = reMatchNoCase( "https://[a-z]+\.linkedin\.com/jobs/view/[^""\?\s]+", htmlPage ) />
			<cfset locations = reMatchNoCase( "job-search-card__location[^>]*>[^<]+<", htmlPage ) />
			<cfif NOT isArray( titles )><cfset titles = [] /></cfif>
			<cfif NOT isArray( links )><cfset links = [] /></cfif>
			<cfif NOT isArray( locations )><cfset locations = [] /></cfif>
			<cfset uniqueLinks = [] />
			<cfloop array="#links#" index="rawLink">
				<cfset cleanLink = trim( rawLink ) />
				<cfif NOT structKeyExists( seenLinks, cleanLink )>
					<cfset seenLinks[ cleanLink ] = true />
					<cfset arrayAppend( uniqueLinks, cleanLink ) />
				</cfif>
			</cfloop>
			<cfloop from="1" to="#arrayLen( titles )#" index="idx">
				<cfset rawTitle = trim( titles[ idx ] ) />
				<cfset rawTitle = reReplace( rawTitle, "^[^>]+>", "", "all" ) />
				<cfset rawTitle = reReplace( rawTitle, "<$", "", "all" ) />
				<cfset rawTitle = trim( rawTitle ) />
				<cfif NOT len( rawTitle )><cfcontinue /></cfif>
				<cfset jobLink = "" />
				<cfif idx LTE arrayLen( uniqueLinks )><cfset jobLink = uniqueLinks[ idx ] /></cfif>
				<cfif NOT len( jobLink )><cfcontinue /></cfif>
				<cfset loc = "" />
				<cfif idx LTE arrayLen( locations )>
					<cfset loc = trim( locations[ idx ] ) />
					<cfset loc = reReplace( loc, "^[^>]+>", "", "all" ) />
					<cfset loc = reReplace( loc, "<$", "", "all" ) />
					<cfset loc = trim( loc ) />
				</cfif>
				<cfif NOT variables.scoringService.shouldPersistJob( rawTitle, "" )><cfcontinue /></cfif>
				<cfset companyId = variables.companyService.getOrCreateExternalCompany( "LinkedIn", "" ) />
				<cfset externalId = "linkedin-" & hash( lCase( jobLink ) ) />
				<cfset variables.jobService.upsertJob( companyId = companyId, externalId = externalId, title = rawTitle, description = "", location = loc, link = jobLink, rawSource = "linkedin" ) />
				<cfset n = n + 1 />
			</cfloop>
			<cfset sleepMs( 1500 ) />
		</cfloop>
		<cfif n GT 0>
			<cfset variables.loggerService.info( "LinkedIn public ingest: upserted #n# job(s)." ) />
		</cfif>
		<cfreturn n />
	</cffunction>

	<!--- Foundit.in (formerly Monster India) listing scan --->
	<cffunction name="ingestFounditScan" access="private" returntype="numeric" output="false">
		<cfargument name="atsConfigJson" type="string" required="true" />
		<cfset cfg = parseConfig( arguments.atsConfigJson ) />
		<cfset maxDetails = getNumericCfg( cfg, "max_job_details", 20 ) />
		<cfif structKeyExists( cfg, "listing_urls" ) AND isArray( cfg.listing_urls ) AND arrayLen( cfg.listing_urls ) GT 0>
			<cfset listingUrls = cfg.listing_urls />
		<cfelse>
			<cfset listingUrls = [
				"https://www.foundit.in/search/coldfusion-jobs",
				"https://www.foundit.in/search/cfml-jobs",
				"https://www.foundit.in/search/lucee-jobs"
			] />
		</cfif>
		<cfset seenUrls = {} />
		<cfset jobUrls = [] />
		<cfloop array="#listingUrls#" index="lu">
			<cfset listU = trim( toString( lu ) ) />
			<cfif NOT len( listU )><cfcontinue /></cfif>
			<cftry>
				<cfset htmlList = variables.httpClientService.getText( listU, 28 ) />
				<cfcatch type="any">
					<cfset variables.loggerService.warn( "Foundit listing fetch failed url=#listU#: #cfcatch.message#" ) />
					<cfcontinue />
				</cfcatch>
			</cftry>
			<cfset found = reMatchNoCase( "https://www\.foundit\.in/job/[^""'\s<>]+", htmlList ) />
			<cfif isArray( found )>
				<cfloop array="#found#" index="ju">
					<cfset ju = trim( ju ) />
					<cfif NOT len( ju ) OR structKeyExists( seenUrls, ju )><cfcontinue /></cfif>
					<cfset seenUrls[ ju ] = true />
					<cfset arrayAppend( jobUrls, ju ) />
				</cfloop>
			</cfif>
			<cfset sleepMs( 350 ) />
		</cfloop>
		<cfset n = 0 />
		<cfset fetched = 0 />
		<cfloop array="#jobUrls#" index="jobUrl">
			<cfif fetched GTE maxDetails><cfbreak /></cfif>
			<cftry>
				<cfset jobHtml = variables.httpClientService.getText( jobUrl, 22 ) />
				<cfcatch type="any">
					<cfset variables.loggerService.warn( "Foundit job fetch failed url=#jobUrl#: #cfcatch.message#" ) />
					<cfcontinue />
				</cfcatch>
			</cftry>
			<cfset parsed = parseGenericJobHtml( jobHtml, "Foundit employer" ) />
			<cfif NOT variables.scoringService.shouldPersistJob( parsed.title, parsed.description )>
				<cfset fetched = fetched + 1 />
				<cfset sleepMs( 350 ) />
				<cfcontinue />
			</cfif>
			<cfset companyName = len( trim( parsed.companyName ) ) ? trim( parsed.companyName ) : "Foundit employer" />
			<cfset companyId = variables.companyService.getOrCreateExternalCompany( companyName, "" ) />
			<cfset extKey = listLast( jobUrl, "/" ) />
			<cfset externalId = "foundit-" & ( len( extKey ) ? extKey : hash( jobUrl ) ) />
			<cfset variables.jobService.upsertJob( companyId = companyId, externalId = externalId, title = parsed.title, description = parsed.description, location = parsed.location, link = jobUrl, rawSource = "foundit" ) />
			<cfset n = n + 1 />
			<cfset fetched = fetched + 1 />
			<cfset sleepMs( 350 ) />
		</cfloop>
		<cfif n GT 0>
			<cfset variables.loggerService.info( "Foundit ingest: upserted #n# job(s)." ) />
		</cfif>
		<cfreturn n />
	</cffunction>

	<!--- Shine.com job listing scan --->
	<cffunction name="ingestShineScan" access="private" returntype="numeric" output="false">
		<cfargument name="atsConfigJson" type="string" required="true" />
		<cfset cfg = parseConfig( arguments.atsConfigJson ) />
		<cfset maxDetails = getNumericCfg( cfg, "max_job_details", 20 ) />
		<cfif structKeyExists( cfg, "listing_urls" ) AND isArray( cfg.listing_urls ) AND arrayLen( cfg.listing_urls ) GT 0>
			<cfset listingUrls = cfg.listing_urls />
		<cfelse>
			<cfset listingUrls = [
				"https://www.shine.com/job-search/coldfusion-jobs"
			] />
		</cfif>
		<cfset seenUrls = {} />
		<cfset jobUrls = [] />
		<cfloop array="#listingUrls#" index="lu">
			<cfset listU = trim( toString( lu ) ) />
			<cfif NOT len( listU )><cfcontinue /></cfif>
			<cftry>
				<cfset htmlList = variables.httpClientService.getText( listU, 28 ) />
				<cfcatch type="any">
					<cfset variables.loggerService.warn( "Shine listing fetch failed url=#listU#: #cfcatch.message#" ) />
					<cfcontinue />
				</cfcatch>
			</cftry>
			<cfset found = reMatchNoCase( "https://www\.shine\.com/jobs/[^""'\s<>]+", htmlList ) />
			<cfif isArray( found )>
				<cfloop array="#found#" index="ju">
					<cfset ju = trim( ju ) />
					<cfif NOT len( ju ) OR structKeyExists( seenUrls, ju )><cfcontinue /></cfif>
					<cfset seenUrls[ ju ] = true />
					<cfset arrayAppend( jobUrls, ju ) />
				</cfloop>
			</cfif>
			<cfset sleepMs( 350 ) />
		</cfloop>
		<cfset n = 0 />
		<cfset fetched = 0 />
		<cfloop array="#jobUrls#" index="jobUrl">
			<cfif fetched GTE maxDetails><cfbreak /></cfif>
			<cftry>
				<cfset jobHtml = variables.httpClientService.getText( jobUrl, 22 ) />
				<cfcatch type="any">
					<cfset variables.loggerService.warn( "Shine job fetch failed url=#jobUrl#: #cfcatch.message#" ) />
					<cfcontinue />
				</cfcatch>
			</cftry>
			<cfset parsed = parseGenericJobHtml( jobHtml, "Shine employer" ) />
			<cfif NOT variables.scoringService.shouldPersistJob( parsed.title, parsed.description )>
				<cfset fetched = fetched + 1 />
				<cfset sleepMs( 350 ) />
				<cfcontinue />
			</cfif>
			<cfset companyName = len( trim( parsed.companyName ) ) ? trim( parsed.companyName ) : "Shine employer" />
			<cfset companyId = variables.companyService.getOrCreateExternalCompany( companyName, "" ) />
			<cfset extKey = listLast( jobUrl, "/" ) />
			<cfset externalId = "shine-" & ( len( extKey ) ? extKey : hash( jobUrl ) ) />
			<cfset variables.jobService.upsertJob( companyId = companyId, externalId = externalId, title = parsed.title, description = parsed.description, location = parsed.location, link = jobUrl, rawSource = "shine" ) />
			<cfset n = n + 1 />
			<cfset fetched = fetched + 1 />
			<cfset sleepMs( 350 ) />
		</cfloop>
		<cfif n GT 0>
			<cfset variables.loggerService.info( "Shine ingest: upserted #n# job(s)." ) />
		</cfif>
		<cfreturn n />
	</cffunction>

	<!--- Weekday.works job listing scan --->
	<cffunction name="ingestWeekdayScan" access="private" returntype="numeric" output="false">
		<cfargument name="atsConfigJson" type="string" required="true" />
		<cfset cfg = parseConfig( arguments.atsConfigJson ) />
		<cfset maxDetails = getNumericCfg( cfg, "max_job_details", 15 ) />
		<cfif structKeyExists( cfg, "listing_urls" ) AND isArray( cfg.listing_urls ) AND arrayLen( cfg.listing_urls ) GT 0>
			<cfset listingUrls = cfg.listing_urls />
		<cfelse>
			<cfset listingUrls = [
				"https://jobs.weekday.works"
			] />
		</cfif>
		<cfset seenUrls = {} />
		<cfset jobUrls = [] />
		<cfloop array="#listingUrls#" index="lu">
			<cfset listU = trim( toString( lu ) ) />
			<cfif NOT len( listU )><cfcontinue /></cfif>
			<cftry>
				<cfset htmlList = variables.httpClientService.getText( listU, 28 ) />
				<cfcatch type="any">
					<cfset variables.loggerService.warn( "Weekday listing fetch failed url=#listU#: #cfcatch.message#" ) />
					<cfcontinue />
				</cfcatch>
			</cftry>
			<cfset found = reMatchNoCase( "https://jobs\.weekday\.works/[^""'\s<>]+coldfusion[^""'\s<>]*", htmlList ) />
			<cfif isArray( found )>
				<cfloop array="#found#" index="ju">
					<cfset ju = trim( ju ) />
					<cfif NOT len( ju ) OR structKeyExists( seenUrls, ju )><cfcontinue /></cfif>
					<cfset seenUrls[ ju ] = true />
					<cfset arrayAppend( jobUrls, ju ) />
				</cfloop>
			</cfif>
			<cfset sleepMs( 350 ) />
		</cfloop>
		<cfset n = 0 />
		<cfset fetched = 0 />
		<cfloop array="#jobUrls#" index="jobUrl">
			<cfif fetched GTE maxDetails><cfbreak /></cfif>
			<cftry>
				<cfset jobHtml = variables.httpClientService.getText( jobUrl, 22 ) />
				<cfcatch type="any">
					<cfset variables.loggerService.warn( "Weekday job fetch failed url=#jobUrl#: #cfcatch.message#" ) />
					<cfcontinue />
				</cfcatch>
			</cftry>
			<cfset parsed = parseGenericJobHtml( jobHtml, "Weekday employer" ) />
			<cfif NOT variables.scoringService.shouldPersistJob( parsed.title, parsed.description )>
				<cfset fetched = fetched + 1 />
				<cfset sleepMs( 350 ) />
				<cfcontinue />
			</cfif>
			<cfset companyName = len( trim( parsed.companyName ) ) ? trim( parsed.companyName ) : "Weekday employer" />
			<cfset companyId = variables.companyService.getOrCreateExternalCompany( companyName, "" ) />
			<cfset extKey = listLast( jobUrl, "/" ) />
			<cfset externalId = "weekday-" & ( len( extKey ) ? extKey : hash( jobUrl ) ) />
			<cfset variables.jobService.upsertJob( companyId = companyId, externalId = externalId, title = parsed.title, description = parsed.description, location = parsed.location, link = jobUrl, rawSource = "weekday" ) />
			<cfset n = n + 1 />
			<cfset fetched = fetched + 1 />
			<cfset sleepMs( 350 ) />
		</cfloop>
		<cfif n GT 0>
			<cfset variables.loggerService.info( "Weekday ingest: upserted #n# job(s)." ) />
		</cfif>
		<cfreturn n />
	</cffunction>

	<!--- Jooble free REST API (POST-based JSON, covers India) --->
	<cffunction name="ingestJoobleFeed" access="private" returntype="numeric" output="false">
		<cfargument name="atsConfigJson" type="string" required="true" />
		<cfset cfg = parseConfig( arguments.atsConfigJson ) />
		<cfset apiKey = "" />
		<cfif structKeyExists( cfg, "api_key" ) AND len( trim( cfg.api_key ) )>
			<cfset apiKey = trim( cfg.api_key ) />
		</cfif>
		<cfif NOT len( apiKey )>
			<cfset variables.loggerService.warn( "Jooble: no api_key configured, skipping." ) />
			<cfreturn 0 />
		</cfif>
		<cfset loc = structKeyExists( cfg, "location" ) ? cfg.location : "India" />
		<cfset keywords = [ "ColdFusion", "CFML", "Lucee", "full stack coldfusion" ] />
		<cfif structKeyExists( cfg, "keywords" ) AND isArray( cfg.keywords )>
			<cfset keywords = cfg.keywords />
		</cfif>
		<cfset n = 0 />
		<cfset seenLinks = {} />
		<cfloop array="#keywords#" index="kw">
			<cfset body = serializeJSON( { "keywords": kw, "location": loc, "page": "1" } ) />
			<cftry>
				<cfhttp url="https://jooble.org/api/#apiKey#" method="POST" result="httpRes" timeout="30">
					<cfhttpparam type="header" name="Content-Type" value="application/json" />
					<cfhttpparam type="body" value="#body#" />
				</cfhttp>
				<cfif NOT structKeyExists( httpRes, "statusCode" ) OR val( listFirst( httpRes.statusCode, " " ) ) GTE 300>
					<cfset variables.loggerService.warn( "Jooble API failed for keyword=#kw#: #structKeyExists( httpRes, 'statusCode' ) ? httpRes.statusCode : 'no status'#" ) />
					<cfcontinue />
				</cfif>
				<cfset data = deserializeJSON( httpRes.fileContent ) />
				<cfif NOT isStruct( data ) OR NOT structKeyExists( data, "jobs" ) OR NOT isArray( data.jobs )>
					<cfcontinue />
				</cfif>
				<cfloop array="#data.jobs#" index="jb">
					<cfset jTitle = structKeyExists( jb, "title" ) ? trim( jb.title ) : "" />
					<cfset jCompany = structKeyExists( jb, "company" ) ? trim( jb.company ) : "" />
					<cfset jLocation = structKeyExists( jb, "location" ) ? trim( jb.location ) : "" />
					<cfset jLink = structKeyExists( jb, "link" ) ? trim( jb.link ) : "" />
					<cfset jSnippet = structKeyExists( jb, "snippet" ) ? trim( jb.snippet ) : "" />
					<cfif NOT len( jLink ) OR structKeyExists( seenLinks, jLink )><cfcontinue /></cfif>
					<cfset seenLinks[ jLink ] = true />
					<cfif NOT variables.scoringService.shouldPersistJob( jTitle, jSnippet )><cfcontinue /></cfif>
					<cfset companyName = len( jCompany ) ? jCompany : "Jooble employer" />
					<cfset companyId = variables.companyService.getOrCreateExternalCompany( companyName, "" ) />
					<cfset externalId = "jooble-" & hash( jLink ) />
					<cfset desc = reReplace( jSnippet, "<[^>]+>", " ", "all" ) />
					<cfset desc = trim( reReplace( desc, "\s+", " ", "all" ) ) />
					<cfset variables.jobService.upsertJob( companyId = companyId, externalId = externalId, title = jTitle, description = desc, location = jLocation, link = jLink, rawSource = "jooble" ) />
					<cfset n = n + 1 />
				</cfloop>
				<cfcatch type="any">
					<cfset variables.loggerService.warn( "Jooble API error for keyword=#kw#: #cfcatch.message#" ) />
				</cfcatch>
			</cftry>
			<cfset sleepMs( 500 ) />
		</cfloop>
		<cfif n GT 0><cfset variables.loggerService.info( "Jooble ingest: upserted #n# job(s)." ) /></cfif>
		<cfreturn n />
	</cffunction>

	<!--- Expertini India job listing scan (72+ CF jobs in India) --->
	<cffunction name="ingestExpertiniScan" access="private" returntype="numeric" output="false">
		<cfargument name="atsConfigJson" type="string" required="true" />
		<cfset cfg = parseConfig( arguments.atsConfigJson ) />
		<cfset maxDetails = getNumericCfg( cfg, "max_job_details", 25 ) />
		<cfif structKeyExists( cfg, "listing_urls" ) AND isArray( cfg.listing_urls ) AND arrayLen( cfg.listing_urls ) GT 0>
			<cfset listingUrls = cfg.listing_urls />
		<cfelse>
			<cfset listingUrls = [ "https://in.expertini.com/jobs/search/coldfusion-jobs-india/" ] />
		</cfif>
		<cfset seenUrls = {} />
		<cfset jobUrls = [] />
		<cfloop array="#listingUrls#" index="lu">
			<cfset listU = trim( toString( lu ) ) />
			<cfif NOT len( listU )><cfcontinue /></cfif>
			<cftry>
				<cfset htmlList = variables.httpClientService.getText( listU, 30 ) />
				<cfcatch type="any">
					<cfset variables.loggerService.warn( "Expertini listing fetch failed url=#listU#: #cfcatch.message#" ) />
					<cfcontinue />
				</cfcatch>
			</cftry>
			<cfset found = reMatchNoCase( "https://in\.expertini\.com/jobs/job/[^""'\s<>]+/", htmlList ) />
			<cfif isArray( found )>
				<cfloop array="#found#" index="ju">
					<cfset ju = trim( ju ) />
					<cfif NOT len( ju ) OR structKeyExists( seenUrls, ju )><cfcontinue /></cfif>
					<cfset seenUrls[ ju ] = true />
					<cfset arrayAppend( jobUrls, ju ) />
				</cfloop>
			</cfif>
			<cfset sleepMs( 400 ) />
		</cfloop>
		<cfset n = 0 />
		<cfset fetched = 0 />
		<cfloop array="#jobUrls#" index="jobUrl">
			<cfif fetched GTE maxDetails><cfbreak /></cfif>
			<cftry>
				<cfset jobHtml = variables.httpClientService.getText( jobUrl, 22 ) />
				<cfcatch type="any">
					<cfset variables.loggerService.warn( "Expertini job fetch failed url=#jobUrl#: #cfcatch.message#" ) />
					<cfcontinue />
				</cfcatch>
			</cftry>
			<cfset parsed = parseGenericJobHtml( jobHtml, "Expertini employer" ) />
			<cfif NOT variables.scoringService.shouldPersistJob( parsed.title, parsed.description )>
				<cfset fetched = fetched + 1 />
				<cfset sleepMs( 400 ) />
				<cfcontinue />
			</cfif>
			<cfset companyName = len( trim( parsed.companyName ) ) ? trim( parsed.companyName ) : "Expertini employer" />
			<cfset companyId = variables.companyService.getOrCreateExternalCompany( companyName, "" ) />
			<cfset slug = listLast( reReplace( jobUrl, "/$", "" ), "/" ) />
			<cfset externalId = "expertini-" & ( len( slug ) ? slug : hash( jobUrl ) ) />
			<cfset variables.jobService.upsertJob( companyId = companyId, externalId = externalId, title = parsed.title, description = parsed.description, location = parsed.location, link = jobUrl, rawSource = "expertini" ) />
			<cfset n = n + 1 />
			<cfset fetched = fetched + 1 />
			<cfset sleepMs( 400 ) />
		</cfloop>
		<cfif n GT 0><cfset variables.loggerService.info( "Expertini ingest: upserted #n# job(s)." ) /></cfif>
		<cfreturn n />
	</cffunction>

	<!--- Indeed India job listing scan --->
	<cffunction name="ingestIndeedScan" access="private" returntype="numeric" output="false">
		<cfargument name="atsConfigJson" type="string" required="true" />
		<cfset cfg = parseConfig( arguments.atsConfigJson ) />
		<cfset maxDetails = getNumericCfg( cfg, "max_job_details", 25 ) />
		<cfif structKeyExists( cfg, "listing_urls" ) AND isArray( cfg.listing_urls ) AND arrayLen( cfg.listing_urls ) GT 0>
			<cfset listingUrls = cfg.listing_urls />
		<cfelse>
			<cfset listingUrls = [ "https://in.indeed.com/jobs?q=coldfusion&l=India" ] />
		</cfif>
		<cfset seenUrls = {} />
		<cfset jobUrls = [] />
		<cfloop array="#listingUrls#" index="lu">
			<cfset listU = trim( toString( lu ) ) />
			<cfif NOT len( listU )><cfcontinue /></cfif>
			<cftry>
				<cfset htmlList = variables.httpClientService.getText( listU, 30 ) />
				<cfcatch type="any">
					<cfset variables.loggerService.warn( "Indeed listing fetch failed url=#listU#: #cfcatch.message#" ) />
					<cfcontinue />
				</cfcatch>
			</cftry>
			<cfset found = reMatchNoCase( "https://in\.indeed\.com/(?:rc/clk|viewjob)[^""'\s<>]+", htmlList ) />
			<cfif isArray( found )>
				<cfloop array="#found#" index="ju">
					<cfset ju = trim( ju ) />
					<cfif NOT len( ju ) OR structKeyExists( seenUrls, ju )><cfcontinue /></cfif>
					<cfset seenUrls[ ju ] = true />
					<cfset arrayAppend( jobUrls, ju ) />
				</cfloop>
			</cfif>
			<cfset foundAlt = reMatchNoCase( '/rc/clk\?jk=[^""''\s<>]+', htmlList ) />
			<cfif isArray( foundAlt )>
				<cfloop array="#foundAlt#" index="relUrl">
					<cfset absUrl = "https://in.indeed.com" & trim( relUrl ) />
					<cfif structKeyExists( seenUrls, absUrl )><cfcontinue /></cfif>
					<cfset seenUrls[ absUrl ] = true />
					<cfset arrayAppend( jobUrls, absUrl ) />
				</cfloop>
			</cfif>
			<cfset sleepMs( 500 ) />
		</cfloop>
		<cfset n = 0 />
		<cfset fetched = 0 />
		<cfloop array="#jobUrls#" index="jobUrl">
			<cfif fetched GTE maxDetails><cfbreak /></cfif>
			<cftry>
				<cfset jobHtml = variables.httpClientService.getText( jobUrl, 22 ) />
				<cfcatch type="any">
					<cfset variables.loggerService.warn( "Indeed job fetch failed url=#jobUrl#: #cfcatch.message#" ) />
					<cfcontinue />
				</cfcatch>
			</cftry>
			<cfset parsed = parseGenericJobHtml( jobHtml, "Indeed employer" ) />
			<cfif NOT variables.scoringService.shouldPersistJob( parsed.title, parsed.description )>
				<cfset fetched = fetched + 1 />
				<cfset sleepMs( 500 ) />
				<cfcontinue />
			</cfif>
			<cfset companyName = len( trim( parsed.companyName ) ) ? trim( parsed.companyName ) : "Indeed employer" />
			<cfset companyId = variables.companyService.getOrCreateExternalCompany( companyName, "" ) />
			<cfset jkMatch = reFindNoCase( "jk=([a-f0-9]+)", jobUrl, 1, true ) />
			<cfif isArray( jkMatch.pos ) AND arrayLen( jkMatch.pos ) GTE 2 AND jkMatch.pos[ 2 ] GT 0>
				<cfset externalId = "indeed-" & mid( jobUrl, jkMatch.pos[ 2 ], jkMatch.len[ 2 ] ) />
			<cfelse>
				<cfset externalId = "indeed-" & hash( jobUrl ) />
			</cfif>
			<cfset variables.jobService.upsertJob( companyId = companyId, externalId = externalId, title = parsed.title, description = parsed.description, location = parsed.location, link = jobUrl, rawSource = "indeed" ) />
			<cfset n = n + 1 />
			<cfset fetched = fetched + 1 />
			<cfset sleepMs( 500 ) />
		</cfloop>
		<cfif n GT 0><cfset variables.loggerService.info( "Indeed India ingest: upserted #n# job(s)." ) /></cfif>
		<cfreturn n />
	</cffunction>

	<!--- Instahyre India job listing scan --->
	<cffunction name="ingestInstahyreScan" access="private" returntype="numeric" output="false">
		<cfargument name="atsConfigJson" type="string" required="true" />
		<cfset cfg = parseConfig( arguments.atsConfigJson ) />
		<cfset maxDetails = getNumericCfg( cfg, "max_job_details", 15 ) />
		<cfif structKeyExists( cfg, "listing_urls" ) AND isArray( cfg.listing_urls ) AND arrayLen( cfg.listing_urls ) GT 0>
			<cfset listingUrls = cfg.listing_urls />
		<cfelse>
			<cfset listingUrls = [ "https://www.instahyre.com/search-jobs/?designation=coldfusion" ] />
		</cfif>
		<cfset seenUrls = {} />
		<cfset jobUrls = [] />
		<cfloop array="#listingUrls#" index="lu">
			<cfset listU = trim( toString( lu ) ) />
			<cfif NOT len( listU )><cfcontinue /></cfif>
			<cftry>
				<cfset htmlList = variables.httpClientService.getText( listU, 28 ) />
				<cfcatch type="any">
					<cfset variables.loggerService.warn( "Instahyre listing fetch failed url=#listU#: #cfcatch.message#" ) />
					<cfcontinue />
				</cfcatch>
			</cftry>
			<cfset found = reMatchNoCase( "https://www\.instahyre\.com/job/[^""'\s<>]+", htmlList ) />
			<cfif isArray( found )>
				<cfloop array="#found#" index="ju">
					<cfset ju = trim( ju ) />
					<cfif NOT len( ju ) OR structKeyExists( seenUrls, ju )><cfcontinue /></cfif>
					<cfset seenUrls[ ju ] = true />
					<cfset arrayAppend( jobUrls, ju ) />
				</cfloop>
			</cfif>
			<cfset sleepMs( 400 ) />
		</cfloop>
		<cfset n = 0 />
		<cfset fetched = 0 />
		<cfloop array="#jobUrls#" index="jobUrl">
			<cfif fetched GTE maxDetails><cfbreak /></cfif>
			<cftry>
				<cfset jobHtml = variables.httpClientService.getText( jobUrl, 22 ) />
				<cfcatch type="any">
					<cfset variables.loggerService.warn( "Instahyre job fetch failed url=#jobUrl#: #cfcatch.message#" ) />
					<cfcontinue />
				</cfcatch>
			</cftry>
			<cfset parsed = parseGenericJobHtml( jobHtml, "Instahyre employer" ) />
			<cfif NOT variables.scoringService.shouldPersistJob( parsed.title, parsed.description )>
				<cfset fetched = fetched + 1 />
				<cfset sleepMs( 400 ) />
				<cfcontinue />
			</cfif>
			<cfset companyName = len( trim( parsed.companyName ) ) ? trim( parsed.companyName ) : "Instahyre employer" />
			<cfset companyId = variables.companyService.getOrCreateExternalCompany( companyName, "" ) />
			<cfset slug = listLast( reReplace( jobUrl, "/$", "" ), "/" ) />
			<cfset externalId = "instahyre-" & ( len( slug ) ? slug : hash( jobUrl ) ) />
			<cfset variables.jobService.upsertJob( companyId = companyId, externalId = externalId, title = parsed.title, description = parsed.description, location = parsed.location, link = jobUrl, rawSource = "instahyre" ) />
			<cfset n = n + 1 />
			<cfset fetched = fetched + 1 />
			<cfset sleepMs( 400 ) />
		</cfloop>
		<cfif n GT 0><cfset variables.loggerService.info( "Instahyre ingest: upserted #n# job(s)." ) /></cfif>
		<cfreturn n />
	</cffunction>

	<!--- Generic HTML title parser shared by Foundit, Shine, and Weekday scrapers --->
	<cffunction name="parseGenericJobHtml" access="private" returntype="struct" output="false">
		<cfargument name="htmlBody" type="string" required="true" />
		<cfargument name="fallbackTitle" type="string" required="false" default="Job listing" />
		<cfset out = { title: "", companyName: "", description: "", location: "" } />
		<cfset s = arguments.htmlBody />

		<!--- Try JSON-LD first (Shine.com, Foundit.in, etc. provide clean structured data) --->
		<cfset ldBlocks = reMatchNoCase( '(?s)<script[^>]*type\s*=\s*"application/ld\+json"[^>]*>(.*?)</script>', s ) />
		<cfif isArray( ldBlocks )>
			<cfloop array="#ldBlocks#" index="ldBlock">
				<cfset ldJson = reReplaceNoCase( ldBlock, '(?s)<script[^>]*>', '', 'one' ) />
				<cfset ldJson = reReplaceNoCase( ldJson, '(?s)</script>', '', 'one' ) />
				<cfset ldJson = trim( ldJson ) />
				<cfif NOT len( ldJson )><cfcontinue /></cfif>
				<cftry>
					<cfset ld = deserializeJSON( ldJson ) />
					<cfif isStruct( ld ) AND structKeyExists( ld, "@type" ) AND findNoCase( "JobPosting", ld["@type"] ) GT 0>
						<cfif structKeyExists( ld, "title" ) AND len( trim( ld.title ) )>
							<cfset out.title = trim( ld.title ) />
						</cfif>
						<cfif structKeyExists( ld, "hiringOrganization" ) AND isStruct( ld.hiringOrganization ) AND structKeyExists( ld.hiringOrganization, "name" )>
							<cfset out.companyName = trim( ld.hiringOrganization.name ) />
						</cfif>
						<cfif structKeyExists( ld, "description" ) AND len( trim( ld.description ) )>
							<cfset rawDesc = ld.description />
							<cfset rawDesc = reReplace( rawDesc, "<[^>]+>", " ", "all" ) />
							<cfset rawDesc = replace( rawDesc, "\n", " ", "all" ) />
							<cfset out.description = left( trim( reReplace( rawDesc, "\s+", " ", "all" ) ), 12000 ) />
						</cfif>
						<cfif structKeyExists( ld, "jobLocation" ) AND isArray( ld.jobLocation ) AND arrayLen( ld.jobLocation ) GT 0>
							<cfset jl = ld.jobLocation[ 1 ] />
							<cfif isStruct( jl ) AND structKeyExists( jl, "address" ) AND isStruct( jl.address )>
								<cfset addr = jl.address />
								<cfset locParts = [] />
								<cfif structKeyExists( addr, "addressLocality" ) AND len( trim( addr.addressLocality ) )>
									<cfset arrayAppend( locParts, trim( addr.addressLocality ) ) />
								</cfif>
								<cfif structKeyExists( addr, "addressCountry" ) AND len( trim( addr.addressCountry ) )>
									<cfset arrayAppend( locParts, trim( addr.addressCountry ) ) />
								</cfif>
								<cfif arrayLen( locParts ) GT 0>
									<cfset out.location = arrayToList( locParts, ", " ) />
								</cfif>
							</cfif>
						</cfif>
						<cfbreak />
					</cfif>
					<cfcatch type="any"></cfcatch>
				</cftry>
			</cfloop>
		</cfif>

		<!--- Fallback to <title> tag parsing if JSON-LD didn't yield a title --->
		<cfif NOT len( trim( out.title ) )>
			<cfset tTag = findNoCase( "<title", s ) />
			<cfif tTag GT 0>
				<cfset gt = find( ">", s, tTag ) />
				<cfset tClose = findNoCase( "</title>", s, tTag ) />
				<cfif gt GT 0 AND tClose GT gt>
					<cfset fullTitle = trim( mid( s, gt + 1, tClose - gt - 1 ) ) />
					<!--- Strip trailing site suffixes like " - Shine.com", " - Foundit.in", " - Monster.com" --->
					<cfset fullTitle = reReplaceNoCase( fullTitle, "\s+-\s+(Shine\.com|Foundit\.in|Monster\.\w+|Weekday\.works)\s*$", "" ) />
					<!--- Try "TITLE Job in COMPANY at LOCATION" pattern (Shine.com / Foundit.in format) --->
					<cfset jobInMatch = reFindNoCase( "^(.+?)\s+Job in\s+(.+?)\s+at\s+(.+)$", fullTitle, 1, true ) />
					<cfif isArray( jobInMatch.pos ) AND arrayLen( jobInMatch.pos ) GTE 4 AND jobInMatch.pos[ 2 ] GT 0>
						<cfset out.title = trim( mid( fullTitle, jobInMatch.pos[ 2 ], jobInMatch.len[ 2 ] ) ) />
						<cfif NOT len( trim( out.companyName ) )>
							<cfset out.companyName = trim( mid( fullTitle, jobInMatch.pos[ 3 ], jobInMatch.len[ 3 ] ) ) />
						</cfif>
						<cfif NOT len( trim( out.location ) )>
							<cfset out.location = trim( mid( fullTitle, jobInMatch.pos[ 4 ], jobInMatch.len[ 4 ] ) ) />
						</cfif>
					<cfelse>
						<cfset pipePos = findNoCase( "|", fullTitle ) />
						<cfset dashPos = findNoCase( " - ", fullTitle ) />
						<cfif pipePos GT 0>
							<cfset part1 = trim( left( fullTitle, pipePos - 1 ) ) />
							<cfset part2 = trim( mid( fullTitle, pipePos + 1, len( fullTitle ) ) ) />
							<cfset p2match = reFindNoCase( "^(.+?)\s+Job in\s+(.+?)\s+at\s+(.+)$", part2, 1, true ) />
							<cfif isArray( p2match.pos ) AND arrayLen( p2match.pos ) GTE 4 AND p2match.pos[ 2 ] GT 0>
								<cfset out.title = part1 />
								<cfif NOT len( trim( out.companyName ) )><cfset out.companyName = trim( mid( part2, p2match.pos[ 3 ], p2match.len[ 3 ] ) ) /></cfif>
								<cfif NOT len( trim( out.location ) )><cfset out.location = trim( mid( part2, p2match.pos[ 4 ], p2match.len[ 4 ] ) ) /></cfif>
							<cfelse>
								<cfset out.title = part1 />
								<cfif NOT len( trim( out.companyName ) ) AND len( part2 )><cfset out.companyName = part2 /></cfif>
							</cfif>
						<cfelseif dashPos GT 0>
							<cfset out.title = trim( left( fullTitle, dashPos - 1 ) ) />
							<cfset remainder = trim( mid( fullTitle, dashPos + 3, len( fullTitle ) ) ) />
							<cfif NOT len( trim( out.companyName ) ) AND len( remainder )><cfset out.companyName = remainder /></cfif>
						<cfelse>
							<cfset out.title = fullTitle />
						</cfif>
					</cfif>
				</cfif>
			</cfif>
		</cfif>

		<!--- Extract location from HTML if not already parsed --->
		<cfif NOT len( trim( out.location ) )>
			<cfset locMatch = reMatchNoCase( "(Bengaluru|Bangalore|Mumbai|Delhi|Hyderabad|Chennai|Pune|Kolkata|Noida|Gurgaon|Gurugram|Remote|India|United States|USA)[^<""]*", s ) />
			<cfif isArray( locMatch ) AND arrayLen( locMatch ) GT 0>
				<cfset out.location = trim( left( locMatch[ 1 ], 120 ) ) />
			</cfif>
		</cfif>
		<!--- Use htmlBodyToPlain only if JSON-LD didn't provide a description --->
		<cfif NOT len( trim( out.description ) )>
			<cfset out.description = left( htmlBodyToPlain( s ), 12000 ) />
		</cfif>
		<cfif NOT len( trim( out.title ) )>
			<cfset out.title = arguments.fallbackTitle />
		</cfif>
		<cfreturn out />
	</cffunction>

	<cffunction name="parseCutshortJobHtml" access="private" returntype="struct" output="false">
		<cfargument name="htmlBody" type="string" required="true" />
		<cfset out = { title: "", companyName: "", companyWebsite: "", description: "", location: "" } />
		<cfset s = arguments.htmlBody />
		<cfset tTag = findNoCase( "<title", s ) />
		<cfif tTag GT 0>
			<cfset gt = find( ">", s, tTag ) />
			<cfset tClose = findNoCase( "</title>", s, tTag ) />
			<cfif gt GT 0 AND tClose GT gt>
				<cfset fullTitle = trim( mid( s, gt + 1, tClose - gt - 1 ) ) />
				<cfset pipePos = findNoCase( "|", fullTitle ) />
				<cfif pipePos GT 0>
					<cfset coreTitle = trim( left( fullTitle, pipePos - 1 ) ) />
				<cfelse>
					<cfset coreTitle = fullTitle />
				</cfif>
				<cfset hireAt = findNoCase( " is hiring ", coreTitle ) />
				<cfset jobInAt = findNoCase( " job in ", coreTitle ) />
				<cfif hireAt GT 0 AND jobInAt GT hireAt>
					<cfset out.companyName = trim( left( coreTitle, hireAt - 1 ) ) />
					<cfset out.title = trim( mid( coreTitle, hireAt + 12, jobInAt - hireAt - 12 ) ) />
					<cfset locPart = trim( mid( coreTitle, jobInAt + 8, len( coreTitle ) ) ) />
					<cfset parenPos = find( "(", locPart ) />
					<cfif parenPos GT 0>
						<cfset out.location = trim( left( locPart, parenPos - 1 ) ) />
					<cfelse>
						<cfset out.location = locPart />
					</cfif>
				<cfelse>
					<cfset out.title = coreTitle />
				</cfif>
			</cfif>
		</cfif>
		<cfset out.description = left( htmlBodyToPlain( s ), 12000 ) />
		<cfif NOT len( trim( out.title ) )>
			<cfset out.title = "Cutshort job" />
		</cfif>
		<cfreturn out />
	</cffunction>

	<cffunction name="parseConfig" access="private" returntype="struct" output="false">
		<cfargument name="jsonText" type="string" required="true" />
		<cfif len( trim( arguments.jsonText ) )>
			<cftry><cfreturn deserializeJSON( arguments.jsonText ) /><cfcatch type="any"><cfreturn {} /></cfcatch></cftry>
		</cfif>
		<cfreturn {} />
	</cffunction>

	<cffunction name="getNumericCfg" access="private" returntype="numeric" output="false">
		<cfargument name="cfg" type="struct" required="true" />
		<cfargument name="keyName" type="string" required="true" />
		<cfargument name="defaultValue" type="numeric" required="true" />
		<cfif structKeyExists( arguments.cfg, arguments.keyName )>
			<cfreturn val( arguments.cfg[ arguments.keyName ] ) />
		</cfif>
		<cfreturn arguments.defaultValue />
	</cffunction>

	<cffunction name="defaultMaxRunsFor" access="private" returntype="numeric" output="false">
		<cfargument name="source" type="string" required="true" />
		<cfif arguments.source EQ "adzuna_feed"><cfreturn 1 /></cfif>
		<cfif arguments.source EQ "remotive_feed" OR arguments.source EQ "arbeitnow_feed" OR arguments.source EQ "getcfmljobs_feed" OR arguments.source EQ "google_cse_feed" OR arguments.source EQ "cutshort_scan" OR arguments.source EQ "linkedin_public" OR arguments.source EQ "foundit_scan" OR arguments.source EQ "shine_scan" OR arguments.source EQ "weekday_scan" OR arguments.source EQ "jooble_feed" OR arguments.source EQ "expertini_scan" OR arguments.source EQ "indeed_scan" OR arguments.source EQ "instahyre_scan"><cfreturn 2 /></cfif>
		<cfreturn 1 />
	</cffunction>

	<cffunction name="defaultMinIntervalFor" access="private" returntype="numeric" output="false">
		<cfargument name="source" type="string" required="true" />
		<cfif arguments.source EQ "adzuna_feed"><cfreturn 1440 /></cfif>
		<cfif arguments.source EQ "remotive_feed" OR arguments.source EQ "arbeitnow_feed" OR arguments.source EQ "getcfmljobs_feed"><cfreturn 360 /></cfif>
		<cfif arguments.source EQ "google_cse_feed" OR arguments.source EQ "cutshort_scan" OR arguments.source EQ "linkedin_public" OR arguments.source EQ "foundit_scan" OR arguments.source EQ "shine_scan" OR arguments.source EQ "weekday_scan" OR arguments.source EQ "jooble_feed" OR arguments.source EQ "expertini_scan" OR arguments.source EQ "indeed_scan" OR arguments.source EQ "instahyre_scan"><cfreturn 720 /></cfif>
		<cfreturn 1440 />
	</cffunction>

	<cffunction name="buildSourceKey" access="private" returntype="string" output="false">
		<cfargument name="source" type="string" required="true" />
		<cfargument name="companyId" type="numeric" required="true" />
		<cfif arguments.source EQ "remotive_feed" OR arguments.source EQ "arbeitnow_feed" OR arguments.source EQ "adzuna_feed" OR arguments.source EQ "getcfmljobs_feed" OR arguments.source EQ "google_cse_feed" OR arguments.source EQ "cutshort_scan" OR arguments.source EQ "linkedin_public" OR arguments.source EQ "foundit_scan" OR arguments.source EQ "shine_scan" OR arguments.source EQ "weekday_scan" OR arguments.source EQ "jooble_feed" OR arguments.source EQ "expertini_scan" OR arguments.source EQ "indeed_scan" OR arguments.source EQ "instahyre_scan">
			<cfreturn arguments.source />
		</cfif>
		<cfreturn arguments.source & ":" & arguments.companyId />
	</cffunction>

	<cffunction name="incrementSourceHealth" access="private" returntype="void" output="false">
		<cfargument name="bucket" type="struct" required="true" />
		<cfargument name="source" type="string" required="true" />
		<cfargument name="state" type="string" required="true" />
		<cfargument name="jobsUpserted" type="numeric" required="false" default="0" />
		<cfset src = len( trim( arguments.source ) ) ? lCase( trim( arguments.source ) ) : "unknown" />
		<cfif NOT structKeyExists( arguments.bucket, src )>
			<cfset arguments.bucket[ src ] = { success: 0, failed: 0, skipped: 0, jobsUpserted: 0 } />
		</cfif>
		<cfset stateKey = lCase( trim( arguments.state ) ) />
		<cfif NOT structKeyExists( arguments.bucket[ src ], stateKey )>
			<cfset arguments.bucket[ src ][ stateKey ] = 0 />
		</cfif>
		<cfset arguments.bucket[ src ][ stateKey ] = val( arguments.bucket[ src ][ stateKey ] ) + 1 />
		<cfset arguments.bucket[ src ].jobsUpserted = val( arguments.bucket[ src ].jobsUpserted ) + val( arguments.jobsUpserted ) />
	</cffunction>

	<cffunction name="incrementErrorClass" access="private" returntype="void" output="false">
		<cfargument name="bucket" type="struct" required="true" />
		<cfargument name="className" type="string" required="true" />
		<cfset key = len( trim( arguments.className ) ) ? lCase( trim( arguments.className ) ) : "unknown_error" />
		<cfif NOT structKeyExists( arguments.bucket, key )>
			<cfset arguments.bucket[ key ] = 0 />
		</cfif>
		<cfset arguments.bucket[ key ] = val( arguments.bucket[ key ] ) + 1 />
	</cffunction>

	<cffunction name="classifyErrorLabel" access="private" returntype="string" output="false">
		<cfargument name="messageText" type="string" required="true" />
		<cfset m = lCase( trim( arguments.messageText ) ) />
		<cfif find( " 401 ", m )><cfreturn "http_401" /></cfif>
		<cfif find( " 403 ", m ) OR find( "forbidden", m )><cfreturn "http_403" /></cfif>
		<cfif find( " 404 ", m ) OR find( "not found", m )><cfreturn "http_404" /></cfif>
		<cfif find( " 408 ", m ) OR find( "time-out", m ) OR find( "timeout", m )><cfreturn "http_timeout" /></cfif>
		<cfif find( " 429 ", m )><cfreturn "http_429" /></cfif>
		<cfif find( " 503 ", m )><cfreturn "http_503" /></cfif>
		<cfif find( "connection failure", m )><cfreturn "connection_failure" /></cfif>
		<cfreturn "other_error" />
	</cffunction>

	<cffunction name="sleepMs" access="private" returntype="void" output="false">
		<cfargument name="ms" type="numeric" required="true" />
		<cfset createObject( "java", "java.lang.Thread" ).sleep( javacast( "int", arguments.ms ) ) />
	</cffunction>

	<!--- Avoid turning marketing/docs pages into fake "jobs" (e.g. product site mentions ColdFusion but no ATS URL) --->
	<cffunction name="normalizeUrlForCompare" access="private" returntype="string" output="false">
		<cfargument name="u" type="string" required="true" />
		<cfset s = trim( arguments.u ) />
		<cfif NOT len( s )><cfreturn "" /></cfif>
		<cfset s = lCase( s ) />
		<cfif right( s, 1 ) EQ "/">
			<cfset s = left( s, len( s ) - 1 ) />
		</cfif>
		<cfreturn s />
	</cffunction>

	<cffunction name="isProbableJobPostingUrl" access="private" returntype="boolean" output="false">
		<cfargument name="jobUrl" type="string" required="true" />
		<cfargument name="careersUrl" type="string" required="true" />
		<cfif NOT len( trim( arguments.jobUrl ) ) OR NOT len( trim( arguments.careersUrl ) )>
			<cfreturn false />
		</cfif>
		<cftry>
			<cfset ju = createObject( "java", "java.net.URL" ).init( trim( arguments.jobUrl ) ) />
			<cfset jc = createObject( "java", "java.net.URL" ).init( trim( arguments.careersUrl ) ) />
			<cfcatch type="any">
				<cfreturn false />
			</cfcatch>
		</cftry>
		<cfif normalizeUrlForCompare( ju.toString() ) EQ normalizeUrlForCompare( jc.toString() )>
			<cfreturn false />
		</cfif>
		<cfset u = lCase( trim( arguments.jobUrl ) ) />
		<cfif findNoCase( "/job", u ) GT 0 OR findNoCase( "/jobs/", u ) GT 0 OR findNoCase( "/jobs/search", u ) GT 0 OR findNoCase( "/job-search", u ) GT 0 OR findNoCase( "gh_jid", u ) GT 0 OR findNoCase( "?job=", u ) GT 0 OR findNoCase( "&job=", u ) GT 0 OR findNoCase( "requisition", u ) GT 0 OR findNoCase( "myworkdayjobs.com", u ) GT 0 OR findNoCase( "lever.co", u ) GT 0 OR findNoCase( "boards.greenhouse.io", u ) GT 0 OR findNoCase( "job-boards.greenhouse.io", u ) GT 0 OR findNoCase( "greenhouse.io/embed", u ) GT 0 OR findNoCase( "smartrecruiters.com", u ) GT 0 OR findNoCase( "ashbyhq.com", u ) GT 0 OR findNoCase( "icims.com", u ) GT 0 OR findNoCase( "taleo", u ) GT 0 OR findNoCase( "brassring", u ) GT 0 OR findNoCase( "successfactors", u ) GT 0 OR findNoCase( "jobvite.com", u ) GT 0 OR findNoCase( "bamboohr.com", u ) GT 0 OR findNoCase( "rippling.com", u ) GT 0 OR findNoCase( "darwinbox", u ) GT 0 OR findNoCase( "cutshort.io", u ) GT 0 OR findNoCase( "/position/", u ) GT 0 OR findNoCase( "/opening/", u ) GT 0 OR findNoCase( "/vacancy", u ) GT 0 OR findNoCase( "/opportunit", u ) GT 0 OR findNoCase( "/apply", u ) GT 0>
			<cfreturn true />
		</cfif>
		<cfif ju.getHost() EQ jc.getHost()>
			<cfset p = lCase( ju.getPath() ) />
			<cfset pClean = reReplace( p, "^/+", "", "all" ) />
			<cfif len( pClean ) AND listLen( pClean, "/" ) GTE 3 AND ( find( "career", pClean ) OR find( "job", pClean ) )>
				<cfreturn true />
			</cfif>
		</cfif>
		<cfreturn false />
	</cffunction>
</cfcomponent>
