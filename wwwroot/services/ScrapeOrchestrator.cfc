<cfcomponent output="false" accessors="true">
	<cfproperty name="companyService" type="any" />
	<cfproperty name="jobService" type="any" />
	<cfproperty name="httpClientService" type="any" />
	<cfproperty name="greenhouseParser" type="any" />
	<cfproperty name="loggerService" type="any" />
	<cfproperty name="sourceQuotaService" type="any" />
	<cfproperty name="scoringService" type="any" />
	<cfproperty name="atsDetector" type="any" />
	<cfproperty name="careerPageDiscoverer" type="any" />

	<cffunction name="init" access="public" returntype="any" output="false">
		<cfargument name="companyService" type="any" required="true" />
		<cfargument name="jobService" type="any" required="true" />
		<cfargument name="httpClientService" type="any" required="true" />
		<cfargument name="greenhouseParser" type="any" required="true" />
		<cfargument name="loggerService" type="any" required="true" />
		<cfargument name="sourceQuotaService" type="any" required="true" />
		<cfargument name="scoringService" type="any" required="true" />
		<cfargument name="atsDetector" type="any" required="false" default="" />
		<cfargument name="careerPageDiscoverer" type="any" required="false" default="" />
		<cfset variables.companyService = arguments.companyService />
		<cfset variables.jobService = arguments.jobService />
		<cfset variables.httpClientService = arguments.httpClientService />
		<cfset variables.greenhouseParser = arguments.greenhouseParser />
		<cfset variables.loggerService = arguments.loggerService />
		<cfset variables.sourceQuotaService = arguments.sourceQuotaService />
		<cfset variables.scoringService = arguments.scoringService />
		<cfif isObject( arguments.atsDetector )>
			<cfset variables.atsDetector = arguments.atsDetector />
		<cfelse>
			<cfset variables.atsDetector = createObject( "component", "services.AtsDetector" ).init() />
		</cfif>
		<cfif isObject( arguments.careerPageDiscoverer )>
			<cfset variables.careerPageDiscoverer = arguments.careerPageDiscoverer />
		<cfelse>
			<cfset variables.careerPageDiscoverer = createObject( "component", "services.CareerPageDiscoverer" ).init( variables.atsDetector ) />
		</cfif>
		<cfreturn this />
	</cffunction>

	<cffunction name="runAll" access="public" returntype="struct" output="false">
		<cfset var summary = { companiesProcessed: 0, jobsUpserted: 0, errors: [], quotaGuardSkips: 0, scanBudgetSkips: 0, sourceHealth: {}, errorClasses: {}, companyLinksEnriched: 0 } />
		<!--- Many seeded employers use career_page_scan; cap only guards runaway time (each scan may fetch sub-pages) --->
		<cfset maxCareerScanPerRun = 120 />
		<cfset careerScanProcessed = 0 />
		<cfset companiesQ = variables.companyService.getAllQuery() />
		<cfloop from="1" to="#companiesQ.recordCount#" index="i">
			<cfset companyId = val( companiesQ.id[ i ] ) />
			<cfset companyName = companiesQ.name[ i ] />
			<cfif structKeyExists( companiesQ, "careers_source" )><cfset source = lCase( trim( companiesQ.careers_source[ i ] ) ) /><cfelse><cfset source = "" /></cfif>
			<cfset cfg = parseConfig( companiesQ.ats_config[ i ] ) />
			<cfif listFindNoCase( "greenhouse,remotive_feed,arbeitnow_feed,adzuna_feed,getcfmljobs_feed,google_cse_feed,cutshort_scan,linkedin_public,foundit_scan,shine_scan,weekday_scan,jooble_feed,expertini_scan,indeed_scan,instahyre_scan,devjobsscanner_scan,remoteok_feed,jobicy_feed,remote_rss_feed,reddit_feed,usajobs_feed,career_page_scan", source ) EQ 0>
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
			<cfelseif source EQ "devjobsscanner_scan">
				<cfset n = ingestDevJobsScannerScan( companiesQ.ats_config[ i ] ) />
			<cfelseif source EQ "remoteok_feed">
				<cfset n = ingestRemoteOk( companiesQ.ats_config[ i ] ) />
			<cfelseif source EQ "jobicy_feed">
				<cfset n = ingestJobicy( companiesQ.ats_config[ i ] ) />
			<cfelseif source EQ "remote_rss_feed">
				<cfset n = ingestRemoteRssFeed( companiesQ.ats_config[ i ] ) />
			<cfelseif source EQ "reddit_feed">
				<cfset n = ingestReddit( companiesQ.ats_config[ i ] ) />
			<cfelseif source EQ "usajobs_feed">
				<cfset n = ingestUsaJobs( companiesQ.ats_config[ i ] ) />
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

		<!--- Daily enrichment: resolve missing website / careers links for companies in the table. --->
		<cfset enrichKey = "enrich_company_links" />
		<cfset enrichQuota = variables.sourceQuotaService.canRun( enrichKey, 1, 720 ) />
		<cfif enrichQuota.allowed>
			<cftry>
				<cfset enrichResult = enrichCompanyLinks( 15, "" ) />
				<cfset summary.companyLinksEnriched = enrichResult.enriched />
				<cfset variables.sourceQuotaService.markRun( enrichKey ) />
				<cfcatch type="any">
					<cfset arrayAppend( summary.errors, "Company link enrichment: #cfcatch.message#" ) />
					<cfset variables.loggerService.error( "Company link enrichment failed: #cfcatch.message#", cfcatch ) />
				</cfcatch>
			</cftry>
		<cfelse>
			<cfset variables.loggerService.info( "Company link enrich skipped (quota): #enrichQuota.reason#" ) />
		</cfif>

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
		<!--- Known CF product vendors (e.g. ZOLL emsCharts): verify .cfm stack on product site, then track careers even if postings omit "ColdFusion" --->
		<cfif isCfProductStackCompany( cfg )>
			<cfset nProduct = ingestCfProductCompanyCareers( arguments.companyId, arguments.careersUrl, cfg ) />
			<cfif nProduct GT 0><cfreturn nProduct /></cfif>
		</cfif>
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

	<cffunction name="isCfProductStackCompany" access="private" returntype="boolean" output="false">
		<cfargument name="cfg" type="struct" required="true" />
		<cfreturn structKeyExists( arguments.cfg, "cf_product_stack" ) AND ( arguments.cfg.cf_product_stack EQ true OR arguments.cfg.cf_product_stack EQ 1 OR lCase( trim( toString( arguments.cfg.cf_product_stack ) ) ) EQ "true" ) />
	</cffunction>

	<cffunction name="htmlConfirmsColdFusionProduct" access="private" returntype="boolean" output="false">
		<cfargument name="htmlBody" type="string" required="true" />
		<cfset s = lCase( arguments.htmlBody ) />
		<cfif findNoCase( "coldfusion", s ) GT 0 OR findNoCase( "cfml", s ) GT 0 OR findNoCase( "lucee", s ) GT 0><cfreturn true /></cfif>
		<cfif reFindNoCase( "\.cfm\b", s ) GT 0 OR reFindNoCase( "application/ld\+json[^>]*jobposting", s ) GT 0><cfreturn true /></cfif>
		<cfreturn false />
	</cffunction>

	<!--- Companies that ship ColdFusion products (emsCharts, etc.) but rarely say CF in job titles --->
	<cffunction name="ingestCfProductCompanyCareers" access="private" returntype="numeric" output="false">
		<cfargument name="companyId" type="numeric" required="true" />
		<cfargument name="careersUrl" type="string" required="true" />
		<cfargument name="cfg" type="struct" required="true" />
		<cfset productUrls = [] />
		<cfif structKeyExists( arguments.cfg, "product_urls" ) AND isArray( arguments.cfg.product_urls )>
			<cfset productUrls = arguments.cfg.product_urls />
		</cfif>
		<cfset stackConfirmed = false />
		<cfloop array="#productUrls#" index="pu">
			<cfset pUrl = trim( toString( pu ) ) />
			<cfif NOT len( pUrl )><cfcontinue /></cfif>
			<cftry>
				<cfset pHtml = variables.httpClientService.getText( pUrl, 20 ) />
				<cfif htmlConfirmsColdFusionProduct( pHtml )><cfset stackConfirmed = true /><cfbreak /></cfif>
				<cfcatch type="any"></cfcatch>
			</cftry>
		</cfloop>
		<cfif NOT stackConfirmed>
			<cfset variables.loggerService.info( "CF product stack: no CF/.cfm evidence on product_urls companyId=#arguments.companyId#" ) />
			<cfreturn 0 />
		</cfif>
		<cftry>
			<cfset htmlMain = variables.httpClientService.getText( arguments.careersUrl, 28 ) />
			<cfcatch type="any">
				<cfset variables.loggerService.warn( "CF product careers fetch failed companyId=#arguments.companyId#: #cfcatch.message#" ) />
				<cfreturn 0 />
			</cfcatch>
		</cftry>
		<cfif NOT careerTextHasHiringLanguage( lCase( htmlBodyToPlain( htmlMain ) ) )><cfreturn 0 /></cfif>
		<cfset candidateUrls = collectSameHostJobLikeUrls( htmlMain, arguments.careersUrl, 25 ) />
		<cfset externalAtsUrls = collectExternalAtsUrls( htmlMain, arguments.careersUrl, 15 ) />
		<cfset allJobUrls = [] />
		<cfset seenJob = {} />
		<cfloop array="#candidateUrls#" index="ju">
			<cfif structKeyExists( seenJob, ju )><cfcontinue /></cfif>
			<cfset seenJob[ ju ] = true />
			<cfset arrayAppend( allJobUrls, ju ) />
		</cfloop>
		<cfloop array="#externalAtsUrls#" index="eu">
			<cfif NOT structKeyExists( seenJob, eu )><cfset seenJob[ eu ] = true /><cfset arrayAppend( allJobUrls, eu ) /></cfif>
		</cfloop>
		<cfset stackNote = "Company maintains a ColdFusion/CFML product stack (verified on product site). coldfusion cfml" />
		<cfset roleTerms = [ "software", "engineer", "developer", "architect", "programmer", "web", "full stack", "fullstack" ] />
		<cfset n = 0 />
		<cfset maxJobs = getNumericCfg( arguments.cfg, "max_product_career_jobs", 8 ) />
		<cfloop array="#allJobUrls#" index="jobUrl">
			<cfif n GTE maxJobs><cfbreak /></cfif>
			<cfif NOT isProbableJobPostingUrl( jobUrl, arguments.careersUrl )><cfcontinue /></cfif>
			<cftry>
				<cfset jobHtml = variables.httpClientService.getText( jobUrl, 18 ) />
				<cfcatch type="any"><cfcontinue /></cfcatch>
			</cftry>
			<cfset parsed = parseGenericJobHtml( jobHtml, "Open role" ) />
			<cfset title = len( trim( parsed.title ) ) ? trim( parsed.title ) : "Software role (CF product company)" />
			<cfset lcTitle = lCase( title ) />
			<cfset roleMatch = false />
			<cfloop array="#roleTerms#" index="rt">
				<cfif findNoCase( rt, lcTitle ) GT 0><cfset roleMatch = true /><cfbreak /></cfif>
			</cfloop>
			<cfif NOT roleMatch><cfcontinue /></cfif>
			<cfset desc = stackNote & " " & parsed.description />
			<cfif NOT variables.scoringService.shouldPersistJob( title, desc )><cfcontinue /></cfif>
			<cfset extId = "cfproduct-" & hash( arguments.companyId & "|" & jobUrl ) />
			<cfset variables.jobService.upsertJob( companyId = arguments.companyId, externalId = extId, title = title, description = left( desc, 12000 ), location = parsed.location, link = jobUrl, rawSource = "career_page_scan" ) />
			<cfset n = n + 1 />
			<cfset sleepMs( 300 ) />
		</cfloop>
		<cfif n EQ 0>
			<!--- Fallback: one tracked careers entry when listings are JS-rendered but product stack is confirmed --->
			<cfset fallbackLink = arguments.careersUrl />
			<cfif arrayLen( allJobUrls ) GT 0><cfset fallbackLink = allJobUrls[ 1 ] /></cfif>
			<cfset desc = stackNote & " Active careers portal; product built with ColdFusion (.cfm). Check careers for software roles." />
			<cfset title = "CF product company — software hiring (verify careers)" />
			<cfif variables.scoringService.shouldPersistJob( title, desc )>
				<cfset variables.jobService.upsertJob( companyId = arguments.companyId, externalId = "cfproduct-" & hash( arguments.companyId & "|fallback" ), title = title, description = desc, location = "", link = fallbackLink, rawSource = "career_page_scan" ) />
				<cfset n = 1 />
			</cfif>
		</cfif>
		<cfif n GT 0><cfset variables.loggerService.info( "CF product company ingest: #n# job(s) companyId=#arguments.companyId#" ) /></cfif>
		<cfreturn n />
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
		<cfreturn variables.careerPageDiscoverer.hrefLooksLikeJobListingPath( arguments.fullUrl ) />
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
		<cfreturn variables.careerPageDiscoverer.firstProbableJobUrlFromArray( arguments.candidateUrls, arguments.careersUrl ) />
	</cffunction>

	<cffunction name="findBestJobLink" access="private" returntype="struct" output="false">
		<cfargument name="htmlBody" type="string" required="true" />
		<cfargument name="baseUrl" type="string" required="true" />
		<cfargument name="keywords" type="array" required="true" />
		<cfset var result = { link: "", title: "" } />
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
		<cfreturn variables.careerPageDiscoverer.extractHref( arguments.anchorHtml ) />
	</cffunction>

	<cffunction name="absolutizeUrl" access="private" returntype="string" output="false">
		<cfargument name="baseUrl" type="string" required="true" />
		<cfargument name="targetUrl" type="string" required="true" />
		<cfreturn variables.careerPageDiscoverer.absolutizeUrl( arguments.baseUrl, arguments.targetUrl ) />
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

	<!--- Remote OK public JSON API (credit + link back per API terms) --->
	<cffunction name="ingestRemoteOk" access="private" returntype="numeric" output="false">
		<cfargument name="atsConfigJson" type="string" required="false" default="" />
		<cfset cfg = parseConfig( arguments.atsConfigJson ) />
		<cfset apiUrl = "https://remoteok.com/api" />
		<cfif structKeyExists( cfg, "api_url" ) AND len( trim( cfg.api_url ) )>
			<cfset apiUrl = trim( cfg.api_url ) />
		</cfif>
		<cftry>
			<cfset body = variables.httpClientService.getText( apiUrl, 45 ) />
			<cfcatch type="any">
				<cfset variables.loggerService.warn( "Remote OK API fetch failed: #cfcatch.message#" ) />
				<cfreturn 0 />
			</cfcatch>
		</cftry>
		<cftry>
			<cfset rows = deserializeJSON( body ) />
			<cfcatch type="any">
				<cfset variables.loggerService.warn( "Remote OK JSON parse failed: #cfcatch.message#" ) />
				<cfreturn 0 />
			</cfcatch>
		</cftry>
		<cfif NOT isArray( rows )><cfreturn 0 /></cfif>
		<cfset n = 0 />
		<cfloop array="#rows#" index="jobItem">
			<cfif NOT isStruct( jobItem ) OR NOT structKeyExists( jobItem, "position" ) OR NOT structKeyExists( jobItem, "id" )><cfcontinue /></cfif>
			<cfif structKeyExists( jobItem, "company" )><cfset companyName = trim( toString( jobItem.company ) ) /><cfelse><cfset companyName = "Unknown Company" /></cfif>
			<cfset companyId = variables.companyService.getOrCreateExternalCompany( companyName, "" ) />
			<cfset externalId = "remoteok-" & toString( jobItem.id ) />
			<cfif structKeyExists( jobItem, "description" )><cfset desc = toString( jobItem.description ) /><cfelse><cfset desc = "" /></cfif>
			<cfif structKeyExists( jobItem, "location" )><cfset location = toString( jobItem.location ) /><cfelse><cfset location = "" /></cfif>
			<cfif structKeyExists( jobItem, "apply_url" ) AND len( trim( jobItem.apply_url ) )>
				<cfset link = trim( toString( jobItem.apply_url ) ) />
			<cfelseif structKeyExists( jobItem, "url" )>
				<cfset link = trim( toString( jobItem.url ) ) />
			<cfelse>
				<cfset link = "" />
			</cfif>
			<cfif NOT len( link )><cfcontinue /></cfif>
			<cfif NOT variables.scoringService.shouldPersistJob( toString( jobItem.position ), desc )><cfcontinue /></cfif>
			<cfset variables.jobService.upsertJob( companyId = companyId, externalId = externalId, title = jobItem.position, description = desc, location = location, link = link, rawSource = "remoteok" ) />
			<cfset n = n + 1 />
		</cfloop>
		<cfif n GT 0><cfset variables.loggerService.info( "Remote OK ingest: upserted #n# job(s)." ) /></cfif>
		<cfreturn n />
	</cffunction>

	<!--- Jobicy v2 remote jobs API --->
	<cffunction name="ingestJobicy" access="private" returntype="numeric" output="false">
		<cfargument name="atsConfigJson" type="string" required="false" default="" />
		<cfset cfg = parseConfig( arguments.atsConfigJson ) />
		<cfset count = getNumericCfg( cfg, "count", 50 ) />
		<cfset apiUrl = "https://jobicy.com/api/v2/remote-jobs?count=" & count />
		<cfif structKeyExists( cfg, "tag" ) AND len( trim( cfg.tag ) )>
			<cfset apiUrl = apiUrl & "&tag=" & urlEncodedFormat( trim( cfg.tag ) ) />
		</cfif>
		<cftry>
			<cfset body = variables.httpClientService.getText( apiUrl, 35 ) />
			<cfcatch type="any">
				<cfset variables.loggerService.warn( "Jobicy API fetch failed: #cfcatch.message#" ) />
				<cfreturn 0 />
			</cfcatch>
		</cftry>
		<cftry>
			<cfset payload = deserializeJSON( body ) />
			<cfcatch type="any">
				<cfset variables.loggerService.warn( "Jobicy JSON parse failed: #cfcatch.message#" ) />
				<cfreturn 0 />
			</cfcatch>
		</cftry>
		<cfif NOT isStruct( payload ) OR NOT structKeyExists( payload, "jobs" ) OR NOT isArray( payload.jobs )><cfreturn 0 /></cfif>
		<cfset n = 0 />
		<cfloop array="#payload.jobs#" index="jobItem">
			<cfif NOT isStruct( jobItem ) OR NOT structKeyExists( jobItem, "jobTitle" )><cfcontinue /></cfif>
			<cfif structKeyExists( jobItem, "companyName" )><cfset companyName = trim( toString( jobItem.companyName ) ) /><cfelse><cfset companyName = "Unknown Company" /></cfif>
			<cfset companyId = variables.companyService.getOrCreateExternalCompany( companyName, "" ) />
			<cfif structKeyExists( jobItem, "id" )><cfset externalId = "jobicy-" & toString( jobItem.id ) /><cfelse><cfset externalId = "jobicy-" & hash( companyName & jobItem.jobTitle ) /></cfif>
			<cfif structKeyExists( jobItem, "jobDescription" )><cfset desc = toString( jobItem.jobDescription ) /><cfelseif structKeyExists( jobItem, "jobExcerpt" )><cfset desc = toString( jobItem.jobExcerpt ) /><cfelse><cfset desc = "" /></cfif>
			<cfif structKeyExists( jobItem, "jobGeo" )><cfset location = toString( jobItem.jobGeo ) /><cfelse><cfset location = "" /></cfif>
			<cfif structKeyExists( jobItem, "url" )><cfset link = trim( toString( jobItem.url ) ) /><cfelse><cfset link = "" /></cfif>
			<cfif NOT len( link )><cfcontinue /></cfif>
			<cfif NOT variables.scoringService.shouldPersistJob( toString( jobItem.jobTitle ), desc )><cfcontinue /></cfif>
			<cfset variables.jobService.upsertJob( companyId = companyId, externalId = externalId, title = jobItem.jobTitle, description = desc, location = location, link = link, rawSource = "jobicy" ) />
			<cfset n = n + 1 />
		</cfloop>
		<cfif n GT 0><cfset variables.loggerService.info( "Jobicy ingest: upserted #n# job(s)." ) /></cfif>
		<cfreturn n />
	</cffunction>

	<!--- Reddit public JSON (no auth). Reads hiring-oriented subreddits/searches, persists CF posts as jobs. --->
	<cffunction name="ingestReddit" access="private" returntype="numeric" output="false">
		<cfargument name="atsConfigJson" type="string" required="false" default="" />
		<cfset cfg = parseConfig( arguments.atsConfigJson ) />
		<cfset maxPerListing = getNumericCfg( cfg, "max_posts_per_listing", 100 ) />
		<cfif maxPerListing GT 100><cfset maxPerListing = 100 /></cfif>
		<cfset reqSleepMs = getNumericCfg( cfg, "request_sleep_ms", 2500 ) />
		<cfset ua = structKeyExists( cfg, "user_agent" ) AND len( trim( cfg.user_agent ) ) ? trim( cfg.user_agent ) : "web:coldfusion-job-finder:v1.0 (job aggregator; contact: admin)" />
		<cfif structKeyExists( cfg, "listing_urls" ) AND isArray( cfg.listing_urls ) AND arrayLen( cfg.listing_urls ) GT 0>
			<cfset listingUrls = cfg.listing_urls />
		<cfelse>
			<cfset listingUrls = [
				"https://www.reddit.com/r/coldfusion/new.json?limit=100",
				"https://www.reddit.com/r/forhire/search.json?q=coldfusion+OR+cfml+OR+lucee&restrict_sr=1&sort=new&limit=100",
				"https://www.reddit.com/r/jobbit/search.json?q=coldfusion+OR+cfml&restrict_sr=1&sort=new&limit=100",
				"https://www.reddit.com/r/remotejs/search.json?q=coldfusion+OR+cfml&restrict_sr=1&sort=new&limit=50",
				"https://www.reddit.com/search.json?q=coldfusion+hiring+OR+%22coldfusion+developer%22&sort=new&limit=100"
			] />
		</cfif>
		<cfset n = 0 />
		<cfset seenIds = {} />
		<cfloop array="#listingUrls#" index="lu">
			<cfset listU = trim( toString( lu ) ) />
			<cfif NOT len( listU )><cfcontinue /></cfif>
			<cftry>
				<cfset body = variables.httpClientService.getTextWithHeaders( listU, { "User-Agent": ua, "Accept": "application/json" }, 30 ) />
				<cfset payload = deserializeJSON( body ) />
				<cfcatch type="any">
					<cfset variables.loggerService.warn( "Reddit listing fetch/parse failed url=#left( listU, 120 )#: #cfcatch.message#" ) />
					<cfset sleepMs( reqSleepMs ) />
					<cfcontinue />
				</cfcatch>
			</cftry>
			<cfif NOT isStruct( payload ) OR NOT structKeyExists( payload, "data" ) OR NOT isStruct( payload.data ) OR NOT structKeyExists( payload.data, "children" ) OR NOT isArray( payload.data.children )>
				<cfset sleepMs( reqSleepMs ) />
				<cfcontinue />
			</cfif>
			<cfset processed = 0 />
			<cfloop array="#payload.data.children#" index="child">
				<cfif processed GTE maxPerListing><cfbreak /></cfif>
				<cfif NOT isStruct( child ) OR NOT structKeyExists( child, "data" ) OR NOT isStruct( child.data )><cfcontinue /></cfif>
				<cfset post = child.data />
				<cfset postId = structKeyExists( post, "id" ) ? toString( post.id ) : "" />
				<cfif NOT len( postId ) OR structKeyExists( seenIds, postId )><cfcontinue /></cfif>
				<cfset seenIds[ postId ] = true />
				<cfset processed = processed + 1 />
				<cfset postTitle = structKeyExists( post, "title" ) ? trim( toString( post.title ) ) : "" />
				<cfset selfText = structKeyExists( post, "selftext" ) ? trim( toString( post.selftext ) ) : "" />
				<cfif NOT len( postTitle )><cfcontinue /></cfif>
				<!--- Skip [For Hire]/seeking-work posts on r/forhire; keep hiring posts --->
				<cfif findNoCase( "[for hire]", postTitle ) GT 0><cfcontinue /></cfif>
				<cfif NOT variables.scoringService.shouldPersistJob( postTitle, selfText )><cfcontinue /></cfif>
				<cfset permalink = structKeyExists( post, "permalink" ) ? "https://www.reddit.com" & toString( post.permalink ) : "" />
				<cfif structKeyExists( post, "url" ) AND len( trim( toString( post.url ) ) ) AND NOT len( permalink )><cfset permalink = trim( toString( post.url ) ) /></cfif>
				<cfif NOT len( permalink )><cfcontinue /></cfif>
				<cfset subreddit = structKeyExists( post, "subreddit" ) ? toString( post.subreddit ) : "reddit" />
				<cfset companyName = "Reddit r/" & subreddit />
				<cfset companyId = variables.companyService.getOrCreateExternalCompany( companyName, "" ) />
				<cfset externalId = "reddit-" & postId />
				<cfset variables.jobService.upsertJob(
					companyId = companyId,
					externalId = externalId,
					title = postTitle,
					description = len( selfText ) ? selfText : postTitle,
					location = "",
					link = permalink,
					rawSource = "reddit"
				) />
				<cfset n = n + 1 />
			</cfloop>
			<cfset sleepMs( reqSleepMs ) />
		</cfloop>
		<cfif n GT 0><cfset variables.loggerService.info( "Reddit ingest: upserted #n# job(s)." ) /></cfif>
		<cfreturn n />
	</cffunction>

	<!--- USAJOBS.gov official API. Free; requires Authorization-Key + User-Agent (email) per their docs. Heavy legacy-ColdFusion gov employer. --->
	<cffunction name="ingestUsaJobs" access="private" returntype="numeric" output="false">
		<cfargument name="atsConfigJson" type="string" required="false" default="" />
		<cfset cfg = parseConfig( arguments.atsConfigJson ) />
		<cfset apiKey = structKeyExists( cfg, "api_key" ) ? trim( cfg.api_key ) : "" />
		<cfset userAgent = structKeyExists( cfg, "user_agent" ) ? trim( cfg.user_agent ) : "" />
		<cfif NOT len( apiKey ) OR NOT len( userAgent )>
			<cfset variables.loggerService.warn( "USAJOBS skipped: set ats_config.api_key (Authorization-Key) and ats_config.user_agent (registered email)." ) />
			<cfreturn 0 />
		</cfif>
		<cfset keywords = [ "ColdFusion", "CFML", "Lucee" ] />
		<cfif structKeyExists( cfg, "keywords" ) AND isArray( cfg.keywords ) AND arrayLen( cfg.keywords ) GT 0>
			<cfset keywords = cfg.keywords />
		</cfif>
		<cfset perPage = getNumericCfg( cfg, "results_per_page", 50 ) />
		<cfif perPage GT 500><cfset perPage = 500 /></cfif>
		<cfset n = 0 />
		<cfset seenIds = {} />
		<cfloop array="#keywords#" index="kw">
			<cfset kwTrim = trim( toString( kw ) ) />
			<cfif NOT len( kwTrim )><cfcontinue /></cfif>
			<cfset endpoint = "https://data.usajobs.gov/api/search?Keyword=" & urlEncodedFormat( kwTrim ) & "&ResultsPerPage=" & perPage />
			<cftry>
				<cfset body = variables.httpClientService.getTextWithHeaders( endpoint, { "Authorization-Key": apiKey, "User-Agent": userAgent, "Host": "data.usajobs.gov" }, 35 ) />
				<cfset payload = deserializeJSON( body ) />
				<cfcatch type="any">
					<cfset variables.loggerService.warn( "USAJOBS fetch/parse failed keyword=#kwTrim#: #cfcatch.message#" ) />
					<cfset sleepMs( 600 ) />
					<cfcontinue />
				</cfcatch>
			</cftry>
			<cfif NOT isStruct( payload ) OR NOT structKeyExists( payload, "SearchResult" ) OR NOT isStruct( payload.SearchResult ) OR NOT structKeyExists( payload.SearchResult, "SearchResultItems" ) OR NOT isArray( payload.SearchResult.SearchResultItems )>
				<cfset sleepMs( 600 ) />
				<cfcontinue />
			</cfif>
			<cfloop array="#payload.SearchResult.SearchResultItems#" index="item">
				<cfif NOT isStruct( item ) OR NOT structKeyExists( item, "MatchedObjectDescriptor" ) OR NOT isStruct( item.MatchedObjectDescriptor )><cfcontinue /></cfif>
				<cfset d = item.MatchedObjectDescriptor />
				<cfset jobId = structKeyExists( item, "MatchedObjectId" ) ? toString( item.MatchedObjectId ) : "" />
				<cfif NOT len( jobId ) OR structKeyExists( seenIds, jobId )><cfcontinue /></cfif>
				<cfset seenIds[ jobId ] = true />
				<cfset jTitle = structKeyExists( d, "PositionTitle" ) ? trim( toString( d.PositionTitle ) ) : "" />
				<cfif NOT len( jTitle )><cfcontinue /></cfif>
				<cfset companyName = structKeyExists( d, "OrganizationName" ) ? trim( toString( d.OrganizationName ) ) : "US Government" />
				<cfset jLink = structKeyExists( d, "PositionURI" ) ? trim( toString( d.PositionURI ) ) : "" />
				<cfif NOT len( jLink )><cfcontinue /></cfif>
				<cfset jLocation = "" />
				<cfif structKeyExists( d, "PositionLocationDisplay" )><cfset jLocation = trim( toString( d.PositionLocationDisplay ) ) /></cfif>
				<cfset jDesc = "" />
				<cfif structKeyExists( d, "UserArea" ) AND isStruct( d.UserArea ) AND structKeyExists( d.UserArea, "Details" ) AND isStruct( d.UserArea.Details )>
					<cfif structKeyExists( d.UserArea.Details, "JobSummary" )><cfset jDesc = toString( d.UserArea.Details.JobSummary ) /></cfif>
				</cfif>
				<cfif NOT len( jDesc ) AND structKeyExists( d, "QualificationSummary" )><cfset jDesc = toString( d.QualificationSummary ) /></cfif>
				<cfif NOT variables.scoringService.shouldPersistJob( jTitle, jDesc )><cfcontinue /></cfif>
				<cfset companyId = variables.companyService.getOrCreateExternalCompany( companyName, "" ) />
				<cfset externalId = "usajobs-" & jobId />
				<cfset variables.jobService.upsertJob(
					companyId = companyId,
					externalId = externalId,
					title = jTitle,
					description = jDesc,
					location = jLocation,
					link = jLink,
					rawSource = "usajobs"
				) />
				<cfset n = n + 1 />
			</cfloop>
			<cfset sleepMs( 600 ) />
		</cfloop>
		<cfif n GT 0><cfset variables.loggerService.info( "USAJOBS ingest: upserted #n# job(s)." ) /></cfif>
		<cfreturn n />
	</cffunction>

	<!--- Generic RSS ingest for remote job boards (We Work Remotely, etc.) --->
	<cffunction name="ingestRemoteRssFeed" access="private" returntype="numeric" output="false">
		<cfargument name="atsConfigJson" type="string" required="true" />
		<cfset cfg = parseConfig( arguments.atsConfigJson ) />
		<cfset rawSource = "remote_rss" />
		<cfif structKeyExists( cfg, "raw_source" ) AND len( trim( cfg.raw_source ) )>
			<cfset rawSource = lCase( trim( cfg.raw_source ) ) />
		</cfif>
		<cfif structKeyExists( cfg, "rss_urls" ) AND isArray( cfg.rss_urls ) AND arrayLen( cfg.rss_urls ) GT 0>
			<cfset rssUrls = cfg.rss_urls />
		<cfelse>
			<cfset rssUrls = [ "https://weworkremotely.com/remote-jobs.rss" ] />
		</cfif>
		<cfset n = 0 />
		<cfset seenLinks = {} />
		<cfloop array="#rssUrls#" index="feedUrl">
			<cfset feedU = trim( toString( feedUrl ) ) />
			<cfif NOT len( feedU )><cfcontinue /></cfif>
			<cftry>
				<cfset body = variables.httpClientService.getText( feedU, 30 ) />
				<cfcatch type="any">
					<cfset variables.loggerService.warn( "Remote RSS fetch failed url=#feedU#: #cfcatch.message#" ) />
					<cfcontinue />
				</cfcatch>
			</cftry>
			<cftry>
				<cfset xmlDoc = xmlParse( body ) />
				<cfset itemNodes = xmlSearch( xmlDoc, "/rss/channel/item" ) />
				<cfcatch type="any">
					<cfset variables.loggerService.warn( "Remote RSS parse failed url=#feedU#: #cfcatch.message#" ) />
					<cfcontinue />
				</cfcatch>
			</cftry>
			<cfif NOT isArray( itemNodes )><cfcontinue /></cfif>
			<cfloop array="#itemNodes#" index="itemNode">
				<cfset title = getRssXmlText( itemNode, "title" ) />
				<cfset link = getRssXmlText( itemNode, "link" ) />
				<cfset desc = getRssXmlText( itemNode, "description" ) />
				<cfset location = getRssXmlText( itemNode, "region" ) />
				<cfif NOT len( location )><cfset location = getRssXmlText( itemNode, "location" ) /></cfif>
				<cfif NOT len( trim( link ) ) OR structKeyExists( seenLinks, link )><cfcontinue /></cfif>
				<cfset seenLinks[ link ] = true />
				<cfif NOT len( trim( title ) )><cfcontinue /></cfif>
				<cfset descPlain = reReplace( desc, "<[^>]+>", " ", "all" ) />
				<cfset descPlain = trim( reReplace( descPlain, "\s+", " ", "all" ) ) />
				<cfif NOT variables.scoringService.shouldPersistJob( title, descPlain )><cfcontinue /></cfif>
				<cfset companyName = extractCompanyFromRssTitle( title ) />
				<cfset companyId = variables.companyService.getOrCreateExternalCompany( companyName, "" ) />
				<cfset externalId = rawSource & "-" & hash( link ) />
				<cfset variables.jobService.upsertJob( companyId = companyId, externalId = externalId, title = title, description = left( descPlain, 12000 ), location = location, link = link, rawSource = rawSource ) />
				<cfset n = n + 1 />
			</cfloop>
			<cfset sleepMs( 400 ) />
		</cfloop>
		<cfif n GT 0><cfset variables.loggerService.info( "Remote RSS (#rawSource#) ingest: upserted #n# job(s)." ) /></cfif>
		<cfreturn n />
	</cffunction>

	<cffunction name="getRssXmlText" access="private" returntype="string" output="false">
		<cfargument name="itemNode" type="any" required="true" />
		<cfargument name="localName" type="string" required="true" />
		<cfset nodes = xmlSearch( arguments.itemNode, "./#arguments.localName#/text()" ) />
		<cfif isArray( nodes ) AND arrayLen( nodes ) GT 0>
			<cfset v = nodes[ 1 ] />
			<cfif isStruct( v ) AND structKeyExists( v, "xmlText" )><cfreturn trim( toString( v.xmlText ) ) /></cfif>
			<cfif isStruct( v ) AND structKeyExists( v, "xmlValue" )><cfreturn trim( toString( v.xmlValue ) ) /></cfif>
			<cfreturn trim( toString( v ) ) />
		</cfif>
		<cfreturn "" />
	</cffunction>

	<cffunction name="extractCompanyFromRssTitle" access="private" returntype="string" output="false">
		<cfargument name="title" type="string" required="true" />
		<cfset t = trim( arguments.title ) />
		<cfset colonPos = find( ":", t ) />
		<cfif colonPos GT 1>
			<cfreturn trim( left( t, colonPos - 1 ) ) />
		</cfif>
		<cfreturn "Unknown Company" />
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

	<!--- Re-fetches jobs stuck under the "Unknown Company" placeholder and reassigns the real employer parsed from the live page. --->
	<cffunction name="backfillUnknownCompanyJobs" access="public" returntype="struct" output="false">
		<cfset var result = { examined: 0, reassigned: 0, deduped: 0, unresolved: 0, errors: [] } />
		<cfset jobsQ = variables.jobService.getUnknownCompanyJobs() />
		<cfset result.examined = jobsQ.recordCount />
		<cfloop from="1" to="#jobsQ.recordCount#" index="r">
			<cfset jobId = val( jobsQ.id[ r ] ) />
			<cfset jobLink = trim( jobsQ.link[ r ] ) />
			<cfset jobExternalId = trim( jobsQ.external_id[ r ] ) />
			<cfset src = lCase( trim( jobsQ.raw_source[ r ] ) ) />
			<cfif NOT len( jobLink )>
				<cfset result.unresolved = result.unresolved + 1 />
				<cfcontinue />
			</cfif>
			<cftry>
				<cfset pageHtml = variables.httpClientService.getText( jobLink, 25 ) />
				<cfif src EQ "getcfmljobs">
					<cfset parsed = parseGetCfmlJobsJobHtml( pageHtml ) />
				<cfelse>
					<cfset parsed = parseGenericJobHtml( pageHtml, "" ) />
				</cfif>
				<cfset foundName = trim( parsed.companyName ) />
				<cfif len( foundName ) AND foundName NEQ "Unknown Company">
					<cfset newCompanyId = variables.companyService.getOrCreateExternalCompany( foundName, trim( parsed.companyWebsite ) ) />
					<!--- If the same posting already exists under the resolved employer, this Unknown row is a stale duplicate: remove it. --->
					<cfif variables.jobService.duplicateJobExists( newCompanyId, jobExternalId, jobId )>
						<cfset variables.jobService.deleteJobById( jobId ) />
						<cfset result.deduped = result.deduped + 1 />
					<cfelse>
						<cfset variables.jobService.reassignJobCompany( jobId, newCompanyId, trim( parsed.title ) ) />
						<cfset result.reassigned = result.reassigned + 1 />
					</cfif>
				<cfelse>
					<cfset result.unresolved = result.unresolved + 1 />
				</cfif>
				<cfcatch type="any">
					<cfset result.unresolved = result.unresolved + 1 />
					<cfset arrayAppend( result.errors, "Job #jobId#: #cfcatch.message#" ) />
					<cfset variables.loggerService.warn( "Backfill company failed jobId=#jobId# url=#left( jobLink, 120 )#: #cfcatch.message#" ) />
				</cfcatch>
			</cftry>
			<cfset sleepMs( 400 ) />
		</cfloop>
		<!--- Drop the placeholder company once nothing references it anymore. --->
		<cfset result.placeholderRemoved = variables.companyService.purgeEmptyUnknownCompany() />
		<cfif result.reassigned GT 0 OR result.deduped GT 0>
			<cfset variables.loggerService.info( "Backfill: reassigned #result.reassigned#, deduped #result.deduped# of #result.examined# Unknown Company job(s)." ) />
		</cfif>
		<cfreturn result />
	</cffunction>

	<cffunction name="ingestAdzuna" access="private" returntype="numeric" output="false">
		<cfargument name="atsConfigJson" type="string" required="true" />
		<cfset cfg = parseConfig( arguments.atsConfigJson ) />
		<cfif NOT structKeyExists( cfg, "app_id" ) OR NOT structKeyExists( cfg, "app_key" ) OR NOT len( trim( cfg.app_id ) ) OR NOT len( trim( cfg.app_key ) )>
			<cfset variables.loggerService.warn( "Adzuna skipped: missing app_id/app_key in ats_config." ) />
			<cfreturn 0 />
		</cfif>
		<cfif structKeyExists( cfg, "countries" ) AND isArray( cfg.countries ) AND arrayLen( cfg.countries ) GT 0>
			<cfset countries = cfg.countries />
		<cfelseif structKeyExists( cfg, "country" ) AND len( trim( toString( cfg.country ) ) )>
			<cfset countries = [ lCase( trim( toString( cfg.country ) ) ) ] />
		<cfelse>
			<cfset countries = [ "us", "gb", "ca", "au", "de", "in", "fr", "nl", "sg", "nz", "at", "ch", "be", "br", "za", "pl" ] />
		</cfif>
		<cfset n = 0 />
		<cfset queries = [ "coldfusion", "cfml", "lucee", "coldbox" ] />
		<cfloop array="#countries#" index="country">
		<cfloop array="#queries#" index="term">
			<cfset endpoint = "https://api.adzuna.com/v1/api/jobs/" & lCase( trim( toString( country ) ) ) & "/search/1?app_id=" & urlEncodedFormat( cfg.app_id ) & "&app_key=" & urlEncodedFormat( cfg.app_key ) & "&results_per_page=50&what=" & urlEncodedFormat( term ) />
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
		</cfloop>
		<cfreturn n />
	</cffunction>

	<!--- Global CF Job Watcher: Bing RSS meta-search, fetch job pages, persist when CF rules pass. --->
	<cffunction name="runCfGlobalWatcher" access="public" returntype="numeric" output="false">
		<cfset cfgJson = variables.companyService.getFeedAtsConfigJson( "cf_global_watcher" ) />
		<cfif NOT len( trim( cfgJson ) )>
			<cfset variables.loggerService.warn( "CF Global Watcher skipped: no cf_global_watcher feed configured." ) />
			<cfreturn 0 />
		</cfif>
		<cfset cfg = parseConfig( cfgJson ) />
		<cfset maxRunsPerDay = getNumericCfg( cfg, "max_runs_per_day", defaultMaxRunsFor( "cf_global_watcher" ) ) />
		<cfset minIntervalMinutes = getNumericCfg( cfg, "min_interval_minutes", defaultMinIntervalFor( "cf_global_watcher" ) ) />
		<cfset quota = variables.sourceQuotaService.canRun( "cf_global_watcher", maxRunsPerDay, minIntervalMinutes ) />
		<cfif NOT quota.allowed>
			<cfset variables.loggerService.warn( "CF Global Watcher quota skip: #quota.reason#" ) />
			<cfreturn 0 />
		</cfif>
		<cfset n = ingestCfGlobalWatcher( cfgJson ) />
		<cfset variables.sourceQuotaService.markRun( "cf_global_watcher" ) />
		<cfreturn n />
	</cffunction>

	<cffunction name="ingestCfGlobalWatcher" access="private" returntype="numeric" output="false">
		<cfargument name="atsConfigJson" type="string" required="true" />
		<cfset cfg = parseConfig( arguments.atsConfigJson ) />
		<cfset maxQueries = getNumericCfg( cfg, "max_queries_per_run", 20 ) />
		<cfset maxFetchesPerQuery = getNumericCfg( cfg, "max_url_fetches_per_query", 25 ) />
		<cfset fetchSleepMs = getNumericCfg( cfg, "fetch_sleep_ms", 450 ) />
		<cfif structKeyExists( cfg, "global_watcher_queries" ) AND isArray( cfg.global_watcher_queries ) AND arrayLen( cfg.global_watcher_queries ) GT 0>
			<cfset allQueries = cfg.global_watcher_queries />
		<cfelseif structKeyExists( cfg, "queries" ) AND isArray( cfg.queries ) AND arrayLen( cfg.queries ) GT 0>
			<cfset allQueries = cfg.queries />
		<cfelse>
			<cfset allQueries = defaultCfGlobalWatcherQueries() />
		</cfif>
		<cfset braveApiKey = structKeyExists( cfg, "brave_api_key" ) ? trim( toString( cfg.brave_api_key ) ) : "" />
		<cfset startIdx = ( ( dayOfYear( now() ) - 1 ) mod arrayLen( allQueries ) ) + 1 />
		<cfset n = 0 />
		<cfset queriesRun = 0 />
		<cfset seenUrls = {} />
		<cfloop from="0" to="#arrayLen( allQueries ) - 1#" index="offset">
			<cfif queriesRun GTE maxQueries><cfbreak /></cfif>
			<cfset qi = ( ( startIdx - 1 + offset ) mod arrayLen( allQueries ) ) + 1 />
			<cfset qText = trim( toString( allQueries[ qi ] ) ) />
			<cfif NOT len( qText )><cfcontinue /></cfif>
			<cfset queriesRun = queriesRun + 1 />
			<cfset hits = [] />
			<cfset bingFailed = false />
			<cftry>
				<cfset hits = fetchBingRssResults( qText ) />
				<cfcatch type="any">
					<cfset bingFailed = true />
					<cfset variables.loggerService.warn( "CF Global Watcher Bing RSS failed query=#left( qText, 100 )#: #cfcatch.message#" ) />
				</cfcatch>
			</cftry>
			<!--- Brave Search fallback: use when Bing throttles/fails or returns nothing and a key is set --->
			<cfif len( braveApiKey ) AND ( bingFailed OR arrayLen( hits ) EQ 0 )>
				<cftry>
					<cfset braveHits = fetchBraveResults( qText, braveApiKey ) />
					<cfif arrayLen( braveHits ) GT 0>
						<cfset hits = braveHits />
						<cfset variables.loggerService.info( "CF Global Watcher Brave fallback used for query=#left( qText, 80 )# (#arrayLen( braveHits )# hits)." ) />
					</cfif>
					<cfcatch type="any">
						<cfset variables.loggerService.warn( "CF Global Watcher Brave fallback failed query=#left( qText, 80 )#: #cfcatch.message#" ) />
					</cfcatch>
				</cftry>
			</cfif>
			<cfif bingFailed AND arrayLen( hits ) EQ 0><cfcontinue /></cfif>
			<cfset fetchedThisQuery = 0 />
			<cfloop array="#hits#" index="hit">
				<cfif fetchedThisQuery GTE maxFetchesPerQuery><cfbreak /></cfif>
				<cfif NOT isStruct( hit ) OR NOT structKeyExists( hit, "url" )><cfcontinue /></cfif>
				<cfset link = normalizeWatcherUrl( trim( toString( hit.url ) ) ) />
				<cfif NOT len( link ) OR structKeyExists( seenUrls, link )><cfcontinue /></cfif>
				<cfset seenUrls[ link ] = true />
				<cfif NOT isProbableJobPostingUrl( link, "" )><cfcontinue /></cfif>
				<cfset hitTitle = structKeyExists( hit, "title" ) ? trim( toString( hit.title ) ) : "" />
				<cfset hitSnippet = structKeyExists( hit, "snippet" ) ? trim( toString( hit.snippet ) ) : "" />
				<cfset fetchedThisQuery = fetchedThisQuery + 1 />
				<cfif ingestSearchHitAsJob( link, hitTitle, hitSnippet, "cf_global_watcher" )>
					<cfset n = n + 1 />
				</cfif>
				<cfset sleepMs( fetchSleepMs ) />
			</cfloop>
			<cfset sleepMs( 600 ) />
		</cfloop>
		<cfif n GT 0>
			<cfset variables.loggerService.info( "CF Global Watcher: upserted #n# job(s) from #queriesRun# queries." ) />
		</cfif>
		<cfreturn n />
	</cffunction>

	<cffunction name="ingestSearchHitAsJob" access="private" returntype="boolean" output="false">
		<cfargument name="jobUrl" type="string" required="true" />
		<cfargument name="fallbackTitle" type="string" required="false" default="" />
		<cfargument name="fallbackSnippet" type="string" required="false" default="" />
		<cfargument name="rawSource" type="string" required="false" default="cf_global_watcher" />
		<cfset link = normalizeWatcherUrl( trim( arguments.jobUrl ) ) />
		<cfif NOT len( link )><cfreturn false /></cfif>
		<cftry>
			<cfset jobHtml = variables.httpClientService.getText( link, 25 ) />
			<cfcatch type="any">
				<cfset variables.loggerService.warn( "CF watcher job fetch failed url=#left( link, 120 )#: #cfcatch.message#" ) />
				<cfreturn false />
			</cfcatch>
		</cftry>
		<cfset parsed = parseGenericJobHtml( jobHtml, arguments.fallbackTitle ) />
		<cfif NOT len( trim( parsed.title ) ) AND len( trim( arguments.fallbackTitle ) )>
			<cfset parsed.title = trim( arguments.fallbackTitle ) />
		</cfif>
		<cfif NOT len( trim( parsed.description ) ) AND len( trim( arguments.fallbackSnippet ) )>
			<cfset parsed.description = trim( arguments.fallbackSnippet ) />
		</cfif>
		<cfif NOT len( trim( parsed.title ) )><cfreturn false /></cfif>
		<cfif NOT variables.scoringService.shouldPersistJob( parsed.title, parsed.description )><cfreturn false /></cfif>
		<cfset companyName = len( trim( parsed.companyName ) ) ? trim( parsed.companyName ) : googleCseCompanyLabel( link, parsed.title, parsed.description ) />
		<cfset companyId = variables.companyService.getOrCreateExternalCompany( companyName, parsed.companyWebsite ) />
		<cfset externalId = "cfwatch-" & hash( lCase( link ) ) />
		<cfset variables.jobService.upsertJob(
			companyId = companyId,
			externalId = externalId,
			title = parsed.title,
			description = parsed.description,
			location = parsed.location,
			link = link,
			rawSource = arguments.rawSource
		) />
		<cfreturn true />
	</cffunction>

	<cffunction name="fetchBingRssResults" access="private" returntype="array" output="false">
		<cfargument name="queryText" type="string" required="true" />
		<cfset requestUrl = "https://www.bing.com/search?format=rss&q=" & urlEncodedFormat( arguments.queryText ) />
		<cfset body = variables.httpClientService.getText( requestUrl, 15 ) />
		<cfset xmlDoc = xmlParse( body ) />
		<cfset itemNodes = xmlSearch( xmlDoc, "/rss/channel/item" ) />
		<cfset out = [] />
		<cfif isArray( itemNodes )>
			<cfloop array="#itemNodes#" index="itemNode">
				<cfset title = bingRssXmlText( xmlSearch( itemNode, "title/text()" ) ) />
				<cfset link = bingRssXmlText( xmlSearch( itemNode, "link/text()" ) ) />
				<cfset snippet = bingRssXmlText( xmlSearch( itemNode, "description/text()" ) ) />
				<cfif len( trim( link ) )>
					<cfset arrayAppend( out, { title: title, url: link, snippet: snippet } ) />
				</cfif>
			</cfloop>
		</cfif>
		<cfreturn out />
	</cffunction>

	<!--- Brave Search API (free tier ~2k queries/mo). Returns web results as job-URL candidates. --->
	<cffunction name="fetchBraveResults" access="private" returntype="array" output="false">
		<cfargument name="queryText" type="string" required="true" />
		<cfargument name="apiKey" type="string" required="true" />
		<cfset endpoint = "https://api.search.brave.com/res/v1/web/search?count=20&q=" & urlEncodedFormat( arguments.queryText ) />
		<cfset body = variables.httpClientService.getTextWithHeaders(
			endpoint,
			{ "X-Subscription-Token": arguments.apiKey, "Accept": "application/json", "Accept-Encoding": "gzip" },
			20
		) />
		<cfset payload = deserializeJSON( body ) />
		<cfset out = [] />
		<cfif isStruct( payload ) AND structKeyExists( payload, "web" ) AND isStruct( payload.web ) AND structKeyExists( payload.web, "results" ) AND isArray( payload.web.results )>
			<cfloop array="#payload.web.results#" index="r">
				<cfif NOT isStruct( r ) OR NOT structKeyExists( r, "url" )><cfcontinue /></cfif>
				<cfset rUrl = trim( toString( r.url ) ) />
				<cfif NOT len( rUrl )><cfcontinue /></cfif>
				<cfset rTitle = structKeyExists( r, "title" ) ? trim( toString( r.title ) ) : "" />
				<cfset rDesc = structKeyExists( r, "description" ) ? trim( toString( r.description ) ) : "" />
				<cfset arrayAppend( out, { title: rTitle, url: rUrl, snippet: rDesc } ) />
			</cfloop>
		</cfif>
		<cfreturn out />
	</cffunction>

	<cffunction name="bingRssXmlText" access="private" returntype="string" output="false">
		<cfargument name="nodes" type="any" required="true" />
		<cfif isArray( arguments.nodes ) AND arrayLen( arguments.nodes ) GT 0>
			<cfset firstNode = arguments.nodes[ 1 ] />
			<cfif isStruct( firstNode ) AND structKeyExists( firstNode, "xmlText" )>
				<cfset rawValue = toString( firstNode.xmlText ) />
			<cfelseif isStruct( firstNode ) AND structKeyExists( firstNode, "xmlValue" )>
				<cfset rawValue = toString( firstNode.xmlValue ) />
			<cfelse>
				<cfset rawValue = toString( firstNode ) />
			</cfif>
			<cfset rawValue = reReplaceNoCase( rawValue, "(?is)<\?xml[^>]*\?>", "", "all" ) />
			<cfset rawValue = replace( rawValue, "<![CDATA[", "", "all" ) />
			<cfset rawValue = replace( rawValue, "]]>", "", "all" ) />
			<cfreturn trim( rawValue ) />
		</cfif>
		<cfreturn "" />
	</cffunction>

	<cffunction name="normalizeWatcherUrl" access="private" returntype="string" output="false">
		<cfargument name="urlText" type="string" required="true" />
		<cfset u = trim( arguments.urlText ) />
		<cfif NOT len( u )><cfreturn "" /></cfif>
		<cfif findNoCase( "bing.com/aclick", u ) OR findNoCase( "www.bing.com/ck/a", u )>
			<cfset ampPos = find( "&amp;u=", u ) />
			<cfif ampPos EQ 0><cfset ampPos = find( "&u=", u ) /></cfif>
			<cfif ampPos GT 0>
				<cfset startPos = ampPos + ( find( "&amp;u=", u ) GT 0 ? 6 : 3 ) />
				<cfset rest = mid( u, startPos, len( u ) ) />
				<cfset endPos = find( "&", rest ) />
				<cfif endPos GT 0><cfset rest = left( rest, endPos - 1 ) /></cfif>
				<cftry>
					<cfset decoded = urlDecode( rest ) />
					<cfif len( trim( decoded ) ) AND ( left( decoded, 7 ) EQ "http://" OR left( decoded, 8 ) EQ "https://" )>
						<cfset u = decoded />
					</cfif>
					<cfcatch type="any"></cfcatch>
				</cftry>
			</cfif>
		</cfif>
		<cfreturn u />
	</cffunction>

	<cffunction name="defaultCfGlobalWatcherQueries" access="private" returntype="array" output="false">
		<cfreturn [
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
		] />
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
				<cfset useTitle = jt />
				<cfset useDesc = sn />
				<cfset useLocation = "" />
				<cfif isProbableJobPostingUrl( link, "" )>
					<cftry>
						<cfset jobHtml = variables.httpClientService.getText( link, 25 ) />
						<cfset parsed = parseGenericJobHtml( jobHtml, jt ) />
						<cfif len( trim( parsed.title ) )><cfset useTitle = parsed.title /></cfif>
						<cfif len( trim( parsed.description ) )><cfset useDesc = parsed.description /></cfif>
						<cfif len( trim( parsed.location ) )><cfset useLocation = parsed.location /></cfif>
						<cfcatch type="any">
							<cfset variables.loggerService.warn( "Google CSE full-page fetch failed url=#left( link, 100 )#: #cfcatch.message#" ) />
						</cfcatch>
					</cftry>
				</cfif>
				<cfif NOT variables.scoringService.shouldPersistJob( useTitle, useDesc )><cfcontinue /></cfif>
				<cfset companyName = googleCseCompanyLabel( link, useTitle, useDesc ) />
				<cfset companyId = variables.companyService.getOrCreateExternalCompany( companyName, "" ) />
				<cfset externalId = "gcs-" & hash( lCase( link ) ) />
				<cfset variables.jobService.upsertJob( companyId = companyId, externalId = externalId, title = len( useTitle ) ? useTitle : "Job (Google search)", description = useDesc, location = useLocation, link = link, rawSource = "google_cse" ) />
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
			<!--- Collect every job-view link with its byte position in the page. --->
			<cfset linkHits = [] />
			<cfset scanPos = 1 />
			<cfloop condition="true">
				<cfset lm = reFindNoCase( "https://[a-z]+\.linkedin\.com/jobs/view/[^""'\?\s<]+", htmlPage, scanPos, true ) />
				<cfif NOT isArray( lm.pos ) OR lm.pos[1] LTE 0><cfbreak /></cfif>
				<cfset arrayAppend( linkHits, { pos: lm.pos[1], url: mid( htmlPage, lm.pos[1], lm.len[1] ) } ) />
				<cfset scanPos = lm.pos[1] + lm.len[1] />
			</cfloop>

			<!--- Walk each card title and pair it with the job link from its OWN card.
			     LinkedIn lays each card out as <a full-link href=JOB> ... <h3 title>, so the
			     correct link is the nearest /jobs/view/ link occurring BEFORE the title.
			     This replaces the old "zip two page-wide arrays by index" logic, which drifted
			     out of alignment (promoted/extra anchors) and stapled a CF title onto an
			     unrelated posting's URL. --->
			<cfset titlePos = 1 />
			<cfloop condition="true">
				<cfset tm = reFindNoCase( "base-search-card__title[^>]*>[^<]+<", htmlPage, titlePos, true ) />
				<cfif NOT isArray( tm.pos ) OR tm.pos[1] LTE 0><cfbreak /></cfif>
				<cfset tStart = tm.pos[1] />
				<cfset titlePos = tStart + tm.len[1] />
				<cfset rawTitle = mid( htmlPage, tStart, tm.len[1] ) />
				<cfset rawTitle = trim( reReplace( reReplace( rawTitle, "^[^>]+>", "", "all" ), "<$", "", "all" ) ) />
				<cfif NOT len( rawTitle )><cfcontinue /></cfif>

				<!--- nearest job link before this title = the same card's full-link anchor --->
				<cfset jobLink = "" />
				<cfset li = 0 />
				<cfloop from="#arrayLen( linkHits )#" to="1" index="li" step="-1">
					<cfif linkHits[ li ].pos LT tStart>
						<cfset jobLink = linkHits[ li ].url />
						<cfbreak />
					</cfif>
				</cfloop>
				<cfif NOT len( jobLink )><cfcontinue /></cfif>
				<cfif structKeyExists( seenLinks, jobLink )><cfcontinue /></cfif>
				<cfset seenLinks[ jobLink ] = true />

				<!--- location: first location marker at/after the title --->
				<cfset loc = "" />
				<cfset locM = reFindNoCase( "job-search-card__location[^>]*>[^<]+<", htmlPage, tStart, true ) />
				<cfif isArray( locM.pos ) AND locM.pos[1] GT 0>
					<cfset loc = mid( htmlPage, locM.pos[1], locM.len[1] ) />
					<cfset loc = trim( reReplace( reReplace( loc, "^[^>]+>", "", "all" ), "<$", "", "all" ) ) />
				</cfif>

				<!--- Backstop: the public scrape has no job body, so this is a title-only match.
				     Require the link slug to corroborate ColdFusion; otherwise skip. Catches any
				     residual title/link mismatch (e.g. a CF title pointing at a cloud-infra URL). --->
				<cfif NOT linkSlugLooksCF( jobLink )><cfcontinue /></cfif>
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

	<!--- LinkedIn job-view slugs are derived from the posting title, so a CF role reads like
	     /jobs/view/coldfusion-developer-... — require that signal when we have no job body. --->
	<cffunction name="linkSlugLooksCF" access="private" returntype="boolean" output="false">
		<cfargument name="link" type="string" required="true" />
		<cfset var s = lCase( arguments.link ) />
		<cfset var tokens = [ "coldfusion", "cold-fusion", "cfml", "lucee", "coldbox", "fusebox", "wirebox", "commandbox", "adobe-cf", "/cf-" ] />
		<cfset var t = "" />
		<cfloop array="#tokens#" index="t">
			<cfif findNoCase( t, s ) GT 0><cfreturn true /></cfif>
		</cfloop>
		<cfreturn false />
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
		<cfset keywords = [ "ColdFusion", "CFML", "Lucee", "full stack coldfusion" ] />
		<cfif structKeyExists( cfg, "keywords" ) AND isArray( cfg.keywords )>
			<cfset keywords = cfg.keywords />
		</cfif>
		<cfif structKeyExists( cfg, "locations" ) AND isArray( cfg.locations ) AND arrayLen( cfg.locations ) GT 0>
			<cfset locations = cfg.locations />
		<cfelseif structKeyExists( cfg, "location" )>
			<cfset locations = [ cfg.location ] />
		<cfelse>
			<cfset locations = [ "Remote", "United States", "United Kingdom", "Canada", "Australia", "Germany", "India" ] />
		</cfif>
		<cfset n = 0 />
		<cfset seenLinks = {} />
		<cfloop array="#locations#" index="loc">
		<cfloop array="#keywords#" index="kw">
			<cfset body = serializeJSON( { "keywords": kw, "location": trim( toString( loc ) ), "page": "1" } ) />
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

	<!--- DevJobsScanner aggregator scan (devjobsscanner.com).
	      Each job card links straight to the source (LinkedIn / Dice / devitjobs.*); there is no internal detail page,
	      so we read title + apply URL (+ company / location when present) directly from the listing HTML.
	      The CF signal lives in the title, which is enough for shouldPersistJob(). --->
	<cffunction name="ingestDevJobsScannerScan" access="private" returntype="numeric" output="false">
		<cfargument name="atsConfigJson" type="string" required="true" />
		<cfset cfg = parseConfig( arguments.atsConfigJson ) />
		<cfset maxDetails = getNumericCfg( cfg, "max_job_details", 80 ) />
		<cfif structKeyExists( cfg, "listing_urls" ) AND isArray( cfg.listing_urls ) AND arrayLen( cfg.listing_urls ) GT 0>
			<cfset listingUrls = cfg.listing_urls />
		<cfelse>
			<cfset listingUrls = [ "https://www.devjobsscanner.com/coldfusion-jobs/" ] />
		</cfif>
		<!--- Opt-in: resolve newly seen employers to their own careers page and register as career_page_scan targets. --->
		<cfset promoteCompanies = structKeyExists( cfg, "promote_companies" ) AND isBoolean( cfg.promote_companies ) AND cfg.promote_companies />
		<cfset maxPromote = getNumericCfg( cfg, "max_promote_per_run", 8 ) />
		<cfset braveApiKey = structKeyExists( cfg, "brave_api_key" ) ? trim( toString( cfg.brave_api_key ) ) : "" />
		<cfset employerNames = {} />
		<cfset cardPattern = '(?si)<a\s+href="([^"]+)"[^>]*class="jbs-text-hover-link flex self-start"[^>]*>\s*<h2[^>]*>(.*?)</h2>\s*</a>' />
		<cfset n = 0 />
		<cfset processed = 0 />
		<cfset seen = {} />
		<cfloop array="#listingUrls#" index="lu">
			<cfif processed GTE maxDetails><cfbreak /></cfif>
			<cfset listU = trim( toString( lu ) ) />
			<cfif NOT len( listU )><cfcontinue /></cfif>
			<cftry>
				<cfset htmlList = variables.httpClientService.getText( listU, 30 ) />
				<cfcatch type="any">
					<cfset variables.loggerService.warn( "DevJobsScanner listing fetch failed url=#listU#: #cfcatch.message#" ) />
					<cfcontinue />
				</cfcatch>
			</cftry>
			<cfset pos = 1 />
			<cfloop condition="true">
				<cfif processed GTE maxDetails><cfbreak /></cfif>
				<cfset m = reFindNoCase( cardPattern, htmlList, pos, true ) />
				<cfif NOT isArray( m.pos ) OR arrayLen( m.pos ) LT 3 OR m.pos[ 1 ] EQ 0><cfbreak /></cfif>
				<cfset applyUrl = decodeHtmlEntities( mid( htmlList, m.pos[ 2 ], m.len[ 2 ] ) ) />
				<cfset title = cleanListingText( mid( htmlList, m.pos[ 3 ], m.len[ 3 ] ) ) />
				<cfset cardEnd = m.pos[ 1 ] + m.len[ 1 ] />
				<cfset pos = cardEnd />
				<cfif NOT len( trim( applyUrl ) ) OR NOT len( trim( title ) )><cfcontinue /></cfif>

				<!--- company + location live just after the title anchor in the same card --->
				<cfset windowStr = mid( htmlList, cardEnd, 800 ) />
				<cfset companyName = "" />
				<cfset cm = reFindNoCase( 'href="/company/[^"]*"[^>]*>(.*?)</a>', windowStr, 1, true ) />
				<cfif isArray( cm.pos ) AND arrayLen( cm.pos ) GTE 2 AND cm.pos[ 2 ] GT 0>
					<cfset companyName = cleanListingText( mid( windowStr, cm.pos[ 2 ], cm.len[ 2 ] ) ) />
				</cfif>
				<cfset locText = "" />
				<cfset lm = reFindNoCase( 'locationText=([^"&]+)', windowStr, 1, true ) />
				<cfif isArray( lm.pos ) AND arrayLen( lm.pos ) GTE 2 AND lm.pos[ 2 ] GT 0>
					<cftry>
						<cfset locText = trim( urlDecode( mid( windowStr, lm.pos[ 2 ], lm.len[ 2 ] ) ) ) />
						<cfcatch type="any"><cfset locText = "" /></cfcatch>
					</cftry>
				</cfif>

				<!--- stable id from the URL path (drop tracking query) so re-runs dedupe --->
				<cfset urlNoQuery = lCase( reReplace( trim( applyUrl ), "\?.*$", "" ) ) />
				<cfset externalId = "devjobsscanner-" & hash( urlNoQuery ) />
				<cfif structKeyExists( seen, externalId )><cfcontinue /></cfif>
				<cfset seen[ externalId ] = true />

				<cfset descParts = [ title ] />
				<cfif len( trim( companyName ) )><cfset arrayAppend( descParts, "Company: " & trim( companyName ) ) /></cfif>
				<cfif len( trim( locText ) )><cfset arrayAppend( descParts, "Location: " & trim( locText ) ) /></cfif>
				<cfset arrayAppend( descParts, "Aggregated via DevJobsScanner. Apply: " & trim( applyUrl ) ) />
				<cfset description = arrayToList( descParts, " | " ) />

				<cfif NOT variables.scoringService.shouldPersistJob( title, description )>
					<cfset processed = processed + 1 />
					<cfcontinue />
				</cfif>

				<cfset finalCompany = len( trim( companyName ) ) ? trim( companyName ) : "DevJobsScanner employer" />
				<cfset companyId = variables.companyService.getOrCreateExternalCompany( finalCompany, "" ) />
				<cfset variables.jobService.upsertJob( companyId = companyId, externalId = externalId, title = title, description = description, location = locText, link = applyUrl, rawSource = "devjobsscanner" ) />
				<cfif len( trim( companyName ) )><cfset employerNames[ trim( companyName ) ] = true /></cfif>
				<cfset n = n + 1 />
				<cfset processed = processed + 1 />
			</cfloop>
			<cfset sleepMs( 500 ) />
		</cfloop>
		<cfif n GT 0><cfset variables.loggerService.info( "DevJobsScanner ingest: upserted #n# job(s)." ) /></cfif>

		<!--- Promote distinct employers to career_page_scan so their own site is scanned for richer detail. --->
		<cfif promoteCompanies AND maxPromote GT 0>
			<cfset promotedNames = [] />
			<cfset attempted = 0 />
			<cfloop collection="#employerNames#" item="empName">
				<cfif attempted GTE maxPromote><cfbreak /></cfif>
				<cfset attempted = attempted + 1 />
				<cftry>
					<cfif promoteEmployerToCareerScan( empName, braveApiKey )>
						<cfset arrayAppend( promotedNames, empName ) />
					</cfif>
					<cfcatch type="any">
						<cfset variables.loggerService.warn( "DevJobsScanner promote failed for '#empName#': #cfcatch.message#" ) />
					</cfcatch>
				</cftry>
				<cfset sleepMs( 400 ) />
			</cfloop>
			<cfif arrayLen( promotedNames ) GT 0>
				<cfset variables.loggerService.info( "DevJobsScanner promote: registered #arrayLen( promotedNames )# company career page(s): " & arrayToList( promotedNames, "; " ) ) />
			</cfif>
		</cfif>
		<cfreturn n />
	</cffunction>

	<!---
		One-time backfill: promote employers already captured from past devjobsscanner runs
		(external_feed companies that have devjobsscanner jobs) to career_page_scan targets.
		Returns a summary struct. Safe to re-run; companies already promoted are skipped.
	--->
	<cffunction name="backfillDevJobsScannerEmployers" access="public" returntype="struct" output="false">
		<cfargument name="maxPromote" type="numeric" required="false" default="50" />
		<cfargument name="braveApiKey" type="string" required="false" default="" />
		<cfset var summary = { candidates: 0, attempted: 0, promoted: 0, names: [] } />

		<cfset q = variables.companyService.listUnpromotedExternalEmployers( "devjobsscanner" ) />
		<cfset summary.candidates = q.recordCount />

		<cfloop query="q">
			<cfif summary.attempted GTE arguments.maxPromote><cfbreak /></cfif>
			<cfset empName = trim( q.name ) />
			<cfif NOT len( empName )><cfcontinue /></cfif>
			<cfset summary.attempted = summary.attempted + 1 />
			<cftry>
				<cfif promoteEmployerToCareerScan( empName, arguments.braveApiKey )>
					<cfset summary.promoted = summary.promoted + 1 />
					<cfset arrayAppend( summary.names, empName ) />
				</cfif>
				<cfcatch type="any">
					<cfset variables.loggerService.warn( "DevJobsScanner backfill failed for '#empName#': #cfcatch.message#" ) />
				</cfcatch>
			</cftry>
			<cfset sleepMs( 400 ) />
		</cfloop>

		<cfif summary.promoted GT 0>
			<cfset variables.loggerService.info( "DevJobsScanner backfill: promoted #summary.promoted#/#summary.candidates# employer(s): " & arrayToList( summary.names, "; " ) ) />
		</cfif>
		<cfreturn summary />
	</cffunction>

	<!---
		Resolve an employer name to its own careers page via web search, then register it as a
		career_page_scan target. Skips job-board / social / aggregator hosts so we land on the
		company's real site. Returns true when a company was upserted.
	--->
	<cffunction name="promoteEmployerToCareerScan" access="private" returntype="boolean" output="false">
		<cfargument name="employerName" type="string" required="true" />
		<cfargument name="braveApiKey" type="string" required="false" default="" />
		<cfset cleanName = trim( arguments.employerName ) />
		<cfif NOT len( cleanName ) OR findNoCase( "devjobsscanner employer", cleanName ) GT 0><cfreturn false /></cfif>

		<cfset resolved = resolveEmployerCareerLinks( cleanName, arguments.braveApiKey ) />
		<cfif NOT resolved.found><cfreturn false /></cfif>

		<cfset variables.companyService.upsertDiscoveredCompany(
			name = cleanName,
			website = resolved.website,
			careersUrl = resolved.careersUrl,
			discoverySource = "devjobsscanner"
		) />
		<cfreturn true />
	</cffunction>

	<!---
		Resolve an employer name to its own website + careers page via web search. Skips
		job-board / social / aggregator hosts so we land on the company's real site.
		Returns { found:boolean, website:string, careersUrl:string }.
	--->
	<cffunction name="resolveEmployerCareerLinks" access="private" returntype="struct" output="false">
		<cfargument name="employerName" type="string" required="true" />
		<cfargument name="braveApiKey" type="string" required="false" default="" />
		<cfset out = { found: false, website: "", careersUrl: "" } />
		<cfset cleanName = trim( arguments.employerName ) />
		<cfif NOT len( cleanName )><cfreturn out /></cfif>

		<cfset queryText = """" & cleanName & """ careers" />
		<cfset hits = [] />
		<cfset bingFailed = false />
		<cftry>
			<cfset hits = fetchBingRssResults( queryText ) />
			<cfcatch type="any"><cfset bingFailed = true /></cfcatch>
		</cftry>
		<cfif len( arguments.braveApiKey ) AND ( bingFailed OR arrayLen( hits ) EQ 0 )>
			<cftry>
				<cfset hits = fetchBraveResults( queryText, arguments.braveApiKey ) />
				<cfcatch type="any"></cfcatch>
			</cftry>
		</cfif>
		<cfif NOT isArray( hits ) OR arrayLen( hits ) EQ 0><cfreturn out /></cfif>

		<cfloop array="#hits#" index="hit">
			<cfif NOT isStruct( hit ) OR NOT structKeyExists( hit, "url" )><cfcontinue /></cfif>
			<cfset resolvedUrl = normalizeWatcherUrl( toString( hit.url ) ) />
			<cfset host = extractHostFromUrl( resolvedUrl ) />
			<cfif NOT len( host ) OR isJobBoardOrSocialHost( host )><cfcontinue /></cfif>

			<cfset out.website = "https://" & host />
			<cfset out.careersUrl = out.website & "/careers" />
			<cfset out.found = true />
			<cfreturn out />
		</cfloop>
		<cfreturn out />
	</cffunction>

	<!---
		Daily-run phase: fill in missing website / careers_url for companies already in the table.
		Resolves each candidate via web search and updates blank fields only. Bounded per run.
		Returns { candidates, attempted, enriched, names }.
	--->
	<cffunction name="enrichCompanyLinks" access="public" returntype="struct" output="false">
		<cfargument name="maxEnrich" type="numeric" required="false" default="15" />
		<cfargument name="braveApiKey" type="string" required="false" default="" />
		<cfset var summary = { candidates: 0, attempted: 0, enriched: 0, names: [] } />
		<cfif arguments.maxEnrich LTE 0><cfreturn summary /></cfif>

		<cfset q = variables.companyService.listCompaniesMissingLinks( arguments.maxEnrich ) />
		<cfset summary.candidates = q.recordCount />

		<cfloop query="q">
			<cfif summary.attempted GTE arguments.maxEnrich><cfbreak /></cfif>
			<cfset cName = trim( q.name ) />
			<cfif NOT len( cName ) OR cName EQ "Unknown Company" OR cName EQ "DevJobsScanner employer"><cfcontinue /></cfif>
			<cfset summary.attempted = summary.attempted + 1 />
			<cftry>
				<cfset resolved = resolveEmployerCareerLinks( cName, arguments.braveApiKey ) />
				<cfif resolved.found>
					<cfset didUpdate = variables.companyService.fillCompanyLinks( val( q.id ), resolved.website, resolved.careersUrl ) />
					<cfif didUpdate>
						<cfset summary.enriched = summary.enriched + 1 />
						<cfset arrayAppend( summary.names, cName ) />
					<cfelse>
						<cfset variables.companyService.markCompanyChecked( val( q.id ) ) />
					</cfif>
				<cfelse>
					<!--- bump updated_at so unresolved rows rotate to the back of the queue --->
					<cfset variables.companyService.markCompanyChecked( val( q.id ) ) />
				</cfif>
				<cfcatch type="any">
					<cfset variables.loggerService.warn( "Company link enrich failed for '#cName#': #cfcatch.message#" ) />
				</cfcatch>
			</cftry>
			<cfset sleepMs( 400 ) />
		</cfloop>

		<cfif summary.enriched GT 0>
			<cfset variables.loggerService.info( "Company link enrich: filled #summary.enriched#/#summary.candidates# company link(s): " & arrayToList( summary.names, "; " ) ) />
		</cfif>
		<cfreturn summary />
	</cffunction>

	<!--- Lower-cased registrable host from a URL (drops scheme, path, port, leading www.). --->
	<cffunction name="extractHostFromUrl" access="private" returntype="string" output="false">
		<cfargument name="urlText" type="string" required="true" />
		<cfreturn variables.careerPageDiscoverer.extractHostFromUrl( arguments.urlText ) />
	</cffunction>

	<!--- True for hosts that are job boards / aggregators / social — not an employer's own site. --->
	<cffunction name="isJobBoardOrSocialHost" access="private" returntype="boolean" output="false">
		<cfargument name="host" type="string" required="true" />
		<cfreturn variables.careerPageDiscoverer.isJobBoardOrSocialHost( arguments.host ) />
	</cffunction>

	<!--- Strip tags + decode the handful of HTML entities seen in listing titles/company names --->
	<cffunction name="cleanListingText" access="private" returntype="string" output="false">
		<cfargument name="raw" type="string" required="true" />
		<cfset t = reReplace( arguments.raw, "<[^>]+>", " ", "all" ) />
		<cfset t = decodeHtmlEntities( t ) />
		<cfreturn trim( reReplace( t, "\s+", " ", "all" ) ) />
	</cffunction>

	<cffunction name="decodeHtmlEntities" access="private" returntype="string" output="false">
		<cfargument name="raw" type="string" required="true" />
		<cfset t = arguments.raw />
		<cfset t = replace( t, "&amp;", "&", "all" ) />
		<cfset t = replace( t, "&##39;", "'", "all" ) />
		<cfset t = replace( t, "&##039;", "'", "all" ) />
		<cfset t = replace( t, "&apos;", "'", "all" ) />
		<cfset t = replace( t, "&quot;", """", "all" ) />
		<cfset t = replace( t, "&##34;", """", "all" ) />
		<cfset t = replace( t, "&lt;", "<", "all" ) />
		<cfset t = replace( t, "&gt;", ">", "all" ) />
		<cfset t = replace( t, "&nbsp;", " ", "all" ) />
		<cfreturn t />
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
			<cfset locMatch = reMatchNoCase( "\b(Bengaluru|Bangalore|Mumbai|Delhi|Hyderabad|Chennai|Pune|Kolkata|Noida|Gurgaon|Gurugram|Remote|India|United States|USA)\b[^<""]*", s ) />
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
		<cfif arguments.source EQ "cf_global_watcher"><cfreturn 2 /></cfif>
		<cfif arguments.source EQ "remotive_feed" OR arguments.source EQ "arbeitnow_feed" OR arguments.source EQ "getcfmljobs_feed" OR arguments.source EQ "google_cse_feed" OR arguments.source EQ "cutshort_scan" OR arguments.source EQ "linkedin_public" OR arguments.source EQ "foundit_scan" OR arguments.source EQ "shine_scan" OR arguments.source EQ "weekday_scan" OR arguments.source EQ "jooble_feed" OR arguments.source EQ "expertini_scan" OR arguments.source EQ "indeed_scan" OR arguments.source EQ "instahyre_scan" OR arguments.source EQ "devjobsscanner_scan" OR arguments.source EQ "remoteok_feed" OR arguments.source EQ "jobicy_feed" OR arguments.source EQ "remote_rss_feed" OR arguments.source EQ "reddit_feed" OR arguments.source EQ "usajobs_feed"><cfreturn 2 /></cfif>
		<cfreturn 1 />
	</cffunction>

	<cffunction name="defaultMinIntervalFor" access="private" returntype="numeric" output="false">
		<cfargument name="source" type="string" required="true" />
		<cfif arguments.source EQ "adzuna_feed"><cfreturn 1440 /></cfif>
		<cfif arguments.source EQ "remotive_feed" OR arguments.source EQ "arbeitnow_feed" OR arguments.source EQ "getcfmljobs_feed"><cfreturn 360 /></cfif>
		<cfif arguments.source EQ "cf_global_watcher"><cfreturn 720 /></cfif>
		<cfif arguments.source EQ "google_cse_feed" OR arguments.source EQ "cutshort_scan" OR arguments.source EQ "linkedin_public" OR arguments.source EQ "foundit_scan" OR arguments.source EQ "shine_scan" OR arguments.source EQ "weekday_scan" OR arguments.source EQ "jooble_feed" OR arguments.source EQ "expertini_scan" OR arguments.source EQ "indeed_scan" OR arguments.source EQ "instahyre_scan" OR arguments.source EQ "devjobsscanner_scan" OR arguments.source EQ "remoteok_feed" OR arguments.source EQ "jobicy_feed" OR arguments.source EQ "remote_rss_feed" OR arguments.source EQ "reddit_feed" OR arguments.source EQ "usajobs_feed"><cfreturn 720 /></cfif>
		<cfreturn 1440 />
	</cffunction>

	<cffunction name="buildSourceKey" access="private" returntype="string" output="false">
		<cfargument name="source" type="string" required="true" />
		<cfargument name="companyId" type="numeric" required="true" />
		<cfif arguments.source EQ "cf_global_watcher" OR arguments.source EQ "remotive_feed" OR arguments.source EQ "arbeitnow_feed" OR arguments.source EQ "adzuna_feed" OR arguments.source EQ "getcfmljobs_feed" OR arguments.source EQ "google_cse_feed" OR arguments.source EQ "cutshort_scan" OR arguments.source EQ "linkedin_public" OR arguments.source EQ "foundit_scan" OR arguments.source EQ "shine_scan" OR arguments.source EQ "weekday_scan" OR arguments.source EQ "jooble_feed" OR arguments.source EQ "expertini_scan" OR arguments.source EQ "indeed_scan" OR arguments.source EQ "instahyre_scan" OR arguments.source EQ "devjobsscanner_scan" OR arguments.source EQ "remoteok_feed" OR arguments.source EQ "jobicy_feed" OR arguments.source EQ "remote_rss_feed" OR arguments.source EQ "reddit_feed" OR arguments.source EQ "usajobs_feed">
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

	<!--- Delegates to AtsDetector (PR 1.6). The previous inline findNoCase() OR-chain
	     now lives declaratively in AtsRegistry; this shim preserves the call site. --->
	<cffunction name="isProbableJobPostingUrl" access="private" returntype="boolean" output="false">
		<cfargument name="jobUrl" type="string" required="true" />
		<cfargument name="careersUrl" type="string" required="true" />
		<cfreturn variables.atsDetector.isProbableJobPostingUrl( arguments.jobUrl, arguments.careersUrl ) />
	</cffunction>
</cfcomponent>
