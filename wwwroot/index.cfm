<cfsetting showdebugoutput="false" />

<cfparam name="url.keyword" default="" />
<cfparam name="url.location" default="" />
<cfparam name="url.min_score" default="0" />
<cfparam name="url.source" default="" />
<cfparam name="url.company_id" default="0" />
<cfparam name="url.jobs_page" default="1" />
<cfparam name="url.jobs_page_size" default="25" />
<cfparam name="url.jobs_sort_by" default="first_seen" />
<cfparam name="url.jobs_sort_dir" default="desc" />
<cfparam name="url.new_since" default="24" />
<cfparam name="url.sponsorship" default="0" />
<cfparam name="url.new_today" default="0" />
<cfparam name="url.work_type" default="" />
<cfparam name="url.alerts_page" default="1" />
<cfparam name="url.alerts_page_size" default="25" />
<cfparam name="url.alerts_sort_by" default="sent_at" />
<cfparam name="url.alerts_sort_dir" default="desc" />
<cfparam name="url.companies_page" default="1" />
<cfparam name="url.companies_page_size" default="25" />
<cfparam name="url.companies_sort_by" default="job_count" />
<cfparam name="url.companies_sort_dir" default="desc" />

<cfset keyword = trim( url.keyword ) />
<cfset locationKeyword = trim( url.location ) />
<cfset minScore = val( url.min_score ) />
<cfset rawSourceFilter = trim( url.source ) />
<cfset companyId = val( url.company_id ) />
<cfset jobsPage = val( url.jobs_page ) />
<cfset jobsPageSize = val( url.jobs_page_size ) />
<cfset jobsSortBy = lCase( url.jobs_sort_by ) />
<cfset jobsSortDir = lCase( url.jobs_sort_dir ) />
<cfset newSince = val( url.new_since ) />
<cfif NOT listFind( "6,24,48,168", newSince )><cfset newSince = 24 /></cfif>
<cfset workTypeFilter = lCase( trim( url.work_type ) ) />
<cfif NOT listFind( ",remote,hybrid,onsite,unknown", workTypeFilter )><cfset workTypeFilter = "" /></cfif>
<cfset sponsorshipOnly = ( val( url.sponsorship ) EQ 1 ) />
<cfset newTodayHours = ( val( url.new_today ) EQ 1 ) ? 24 : 0 />
<!--- The "new today" view is about recency, so order by most-recently-found. --->
<cfif newTodayHours GT 0>
	<cfset jobsSortBy = "first_seen" />
	<cfset jobsSortDir = "desc" />
</cfif>
<cfset alertsPage = val( url.alerts_page ) />
<cfset alertsPageSize = val( url.alerts_page_size ) />
<cfset alertsSortBy = lCase( url.alerts_sort_by ) />
<cfset alertsSortDir = lCase( url.alerts_sort_dir ) />
<cfset companiesPage = val( url.companies_page ) />
<cfset companiesPageSize = val( url.companies_page_size ) />
<cfset companiesSortBy = lCase( url.companies_sort_by ) />
<cfset companiesSortDir = lCase( url.companies_sort_dir ) />

<cfif jobsPage LT 1><cfset jobsPage = 1 /></cfif>
<cfif alertsPage LT 1><cfset alertsPage = 1 /></cfif>
<cfif companiesPage LT 1><cfset companiesPage = 1 /></cfif>
<cfif jobsPageSize LT 1><cfset jobsPageSize = 25 /></cfif>
<cfif alertsPageSize LT 1><cfset alertsPageSize = 25 /></cfif>
<cfif companiesPageSize LT 1><cfset companiesPageSize = 25 /></cfif>

<!--- Admin visibility: only show admin controls (Run now, Pipeline nav) when accessing directly from localhost.
     Ngrok forwards via localhost so REMOTE_ADDR is 127.0.0.1 even for public visitors — check X-Forwarded-For to detect proxy. --->
<cfset isLocal = (
    ( CGI.REMOTE_ADDR EQ "127.0.0.1" OR CGI.REMOTE_ADDR EQ "::1" OR CGI.REMOTE_ADDR EQ "0:0:0:0:0:0:0:1" )
    AND NOT len( trim( CGI.HTTP_X_FORWARDED_FOR ) )
) />

<cfinclude template="includes/pathUtil.cfm" />

<cfset runInfo = {} />
<cfset pageError = "" />
<cfset pipelinePhases = [] />
<cfset companiesForFilter = [] />

<cftry>
	<cfset companiesData = application.companyService.listPaged( companiesSortBy, companiesSortDir, companiesPage, companiesPageSize ) />
	<cfset companies = companiesData.rows />
	<cfset companiesForFilter = application.companyService.listWithJobsForFilter() />
	<cfset jobsData = application.jobService.listPaged( companyId, keyword, minScore, jobsPage, jobsPageSize, jobsSortBy, jobsSortDir, locationKeyword, rawSourceFilter, workTypeFilter, sponsorshipOnly, newTodayHours ) />
	<cfset alertsData = application.alertService.listAlertsPaged( alertsPage, alertsPageSize, alertsSortBy, alertsSortDir ) />
	<cfset runInfo = application.runStatusService.getLatestRun() />
	<cfset pipelinePhases = application.runStatusService.getPipelinePhaseRows( runInfo ) />
	<cfset totalCompanies = companiesData.totalRows />
	<cfset totalJobs = jobsData.totalRows />
	<cfset totalJobsInDb = application.jobService.countAll() />
	<cfset filtersActive = len( keyword ) OR len( locationKeyword ) OR minScore GT 0 OR len( rawSourceFilter ) OR companyId GT 0 OR len( workTypeFilter ) />
	<cfset totalAlerts = alertsData.totalRows />
	<cfset scrapeCompaniesProcessed = application.runStatusService.getPipelineMetric( runInfo, "scrape", "companiesProcessed", 0 ) />
	<cfset companyLinksEnriched = application.runStatusService.getPipelineMetric( runInfo, "scrape", "companyLinksEnriched", 0 ) />
	<cfset newJobsCount = application.jobService.countNew( 24 ) />
	<cfset briefingData = application.jobService.listPaged( 0, "", 0, 1, 7, "score", "desc" ) />
	<cfset eligibleData = application.jobService.listPaged( 0, "", 70, 1, 1, "score", "desc" ) />
	<cfset eligibleCount = eligibleData.totalRows />
	<cfset sourceHealthStruct = application.runStatusService.getPipelineMetric( runInfo, "scrape", "sourceHealth", {} ) />
	<cfset sourceNames = [] />
	<cfif isStruct( sourceHealthStruct )>
		<cfloop collection="#sourceHealthStruct#" item="srcKey">
			<cfset arrayAppend( sourceNames, srcKey ) />
		</cfloop>
	</cfif>
	<cfset liveSourcesCount = arrayLen( sourceNames ) />
	<cfcatch type="any">
		<cfset companiesData = { rows: [], totalRows: 0, page: 1, pageSize: 25, totalPages: 1, sortBy: "job_count", sortDir: "desc" } />
		<cfset companies = [] />
		<cfset companiesForFilter = [] />
		<cfset jobsData = { rows: [], totalRows: 0, page: 1, pageSize: 25, totalPages: 1, sortBy: "score", sortDir: "desc" } />
		<cfset alertsData = { rows: [], totalRows: 0, page: 1, pageSize: 25, totalPages: 1, sortBy: "sent_at", sortDir: "desc" } />
		<cfset totalCompanies = 0 />
		<cfset totalJobs = 0 />
		<cfset totalJobsInDb = 0 />
		<cfset filtersActive = false />
		<cfset totalAlerts = 0 />
		<cfset scrapeCompaniesProcessed = 0 />
		<cfset companyLinksEnriched = 0 />
		<cfset newJobsCount = 0 />
		<cfset briefingData = { rows: [] } />
		<cfset eligibleCount = 0 />
		<cfset sourceNames = [] />
		<cfset liveSourcesCount = 0 />
		<cfset pageError = cfcatch.message />
	</cfcatch>
</cftry>

<cfset activeSection = "today" />
<cfset unreadAlerts = 0 />
<cfset pageTitle = "CF/OBSERVER | Today" />
<cfset searchKeyword = keyword />
<cfset bodyClass = "fp-root" />

<!--- ===================== helpers ===================== --->

<cffunction name="relAge" access="public" returntype="string" output="false">
	<cfargument name="ts" type="string" required="true" />
	<cfif NOT len( trim( arguments.ts ) ) ><cfreturn "" /></cfif>
	<cftry>
		<cfset var dt = parseDateTime( arguments.ts ) />
		<cfcatch type="any"><cfreturn "" /></cfcatch>
	</cftry>
	<cfset var mins = dateDiff( "n", dt, now() ) />
	<cfif mins LT 1><cfreturn "just now" /></cfif>
	<cfif mins LT 60><cfreturn mins & "m ago" /></cfif>
	<cfset var hrs = dateDiff( "h", dt, now() ) />
	<cfif hrs LT 24><cfreturn hrs & "h ago" /></cfif>
	<cfset var days = dateDiff( "d", dt, now() ) />
	<cfreturn days & "d ago" />
</cffunction>

<cffunction name="plainSummary" access="public" returntype="string" output="false">
	<cfargument name="html" type="string" required="true" />
	<cfargument name="maxLen" type="numeric" required="false" default="150" />
	<cfif NOT len( trim( arguments.html ) ) ><cfreturn "" /></cfif>
	<cfset var out = reReplace( arguments.html, "(?si)<script[^>]*>.*?</script>", " ", "all" ) />
	<cfset out = trim( reReplace( reReplace( out, "<[^>]+>", " ", "all" ), "\s+", " ", "all" ) ) />
	<cfif len( out ) GT arguments.maxLen><cfset out = left( out, arguments.maxLen ) & "…" /></cfif>
	<cfreturn out />
</cffunction>

<cffunction name="scoreToneClass" access="public" returntype="string" output="false">
	<cfargument name="score" type="numeric" required="true" />
	<cfif arguments.score GTE 90><cfreturn "fp-badge--top" /></cfif>
	<cfif arguments.score GTE 70><cfreturn "fp-badge--good" /></cfif>
	<cfif arguments.score GTE 50><cfreturn "fp-badge--mid" /></cfif>
	<cfreturn "fp-badge--low" />
</cffunction>

<cffunction name="jobHref" access="public" returntype="string" output="false">
	<cfargument name="link" type="string" required="true" />
	<cfset var href = trim( arguments.link ) />
	<cfif NOT len( href ) ><cfreturn "" /></cfif>
	<cfif left( href, 2 ) EQ "//"><cfreturn "https:" & href /></cfif>
	<cfif reFindNoCase( "^https?://", href ) EQ 0><cfreturn "https://" & href /></cfif>
	<cfreturn href />
</cffunction>

<!--- Build a Board URL with the given filter state, anchored to #board. --->
<cffunction name="boardUrl" access="public" returntype="string" output="false">
	<cfargument name="base" type="string" required="true" />
	<cfargument name="kw" type="string" required="true" />
	<cfargument name="loc" type="string" required="true" />
	<cfargument name="ms" type="numeric" required="true" />
	<cfargument name="src" type="string" required="true" />
	<cfargument name="cid" type="numeric" required="true" />
	<cfargument name="wt" type="string" required="true" />
	<cfargument name="sb" type="string" required="true" />
	<cfargument name="sd" type="string" required="true" />
		<cfargument name="spOverride" type="string" required="false" default="" />
		<cfargument name="ntOverride" type="string" required="false" default="" />
		<cfset var spOn = false />
		<cfif arguments.spOverride EQ "1"><cfset spOn = true />
		<cfelseif arguments.spOverride EQ "0"><cfset spOn = false />
		<cfelse><cfset spOn = ( structKeyExists( variables, "sponsorshipOnly" ) AND variables.sponsorshipOnly ) /></cfif>
		<cfset var ntOn = false />
		<cfif arguments.ntOverride EQ "1"><cfset ntOn = true />
		<cfelseif arguments.ntOverride EQ "0"><cfset ntOn = false />
		<cfelse><cfset ntOn = ( structKeyExists( variables, "newTodayHours" ) AND variables.newTodayHours GT 0 ) /></cfif>
		<cfset var extra = "" />
		<cfif spOn><cfset extra = extra & "&sponsorship=1" /></cfif>
		<cfif ntOn><cfset extra = extra & "&new_today=1" /></cfif>
	<cfreturn arguments.base & "?keyword=" & urlEncodedFormat( arguments.kw ) & "&location=" & urlEncodedFormat( arguments.loc )
		& "&min_score=" & arguments.ms & "&source=" & urlEncodedFormat( arguments.src ) & "&company_id=" & arguments.cid
		& "&work_type=" & urlEncodedFormat( arguments.wt ) & "&jobs_sort_by=" & urlEncodedFormat( arguments.sb )
		& "&jobs_sort_dir=" & urlEncodedFormat( arguments.sd ) & "&jobs_page=1" & extra & "##board" />
</cffunction>

<!--- Renders a single job card (Briefing + Board use this). --->
<cffunction name="renderJobCard" access="public" returntype="string" output="false">
	<cfargument name="job" type="struct" required="true" />
	<cfargument name="big" type="boolean" required="false" default="false" />
	<cfset var j = arguments.job />
	<cfset var score = val( j.score ) />
	<cfset var work = structKeyExists( j, "work_type" ) ? lCase( j.work_type ) : "unknown" />
	<cfset var workLabel = work EQ "unknown" ? "unclassified" : work />
	<cfset var href = jobHref( j.link ) />
	<cfset var summary = structKeyExists( j, "description" ) ? plainSummary( j.description, 150 ) : "" />
	<cfset var ageStr = structKeyExists( j, "first_seen_at" ) ? relAge( j.first_seen_at ) : ( structKeyExists( j, "fetched_at" ) ? relAge( j.fetched_at ) : "" ) />
	<cfset var loc = len( trim( j.location ) ) ? j.location : "Location n/a" />
	<cfset var badgePx = arguments.big ? 60 : 50 />
	<cfset var expired = structKeyExists( j, "is_active" ) AND NOT val( j.is_active ) />
	<cfsavecontent variable="out">
	<cfoutput>
	<a class="fp-card fp-click fp-job-card<cfif arguments.big> fp-job-card--big</cfif>" style="text-decoration:none;color:inherit;"<cfif len( href )> href="#encodeForHTMLAttribute( href )#" target="_blank" rel="noopener noreferrer"<cfelse> href="##" onclick="return false;"</cfif>>
		<div class="fp-job-card-top">
			<cfif work NEQ "unknown"><span class="fp-kick fp-work-pill<cfif work EQ 'remote'> fp-work-pill--remote</cfif>">#encodeForHTML( workLabel )#</span><cfelse><span></span></cfif>
			<cfif structKeyExists( j, "has_sponsorship" ) AND j.has_sponsorship>
				<span class="fp-kick" style="background:##0f3a25;color:##5be39b;border:1px solid ##1d6b46;margin-left:6px;">SPONSORSHIP</span>
			</cfif>
			<div class="fp-badge #scoreToneClass( score )#" style="width:#badgePx#px;height:#badgePx#px;">
				<span class="fp-badge-num" style="font-size:#( arguments.big ? 22 : 18 )#px;">#score#</span>
				<span class="fp-badge-lbl" style="font-size:#( arguments.big ? 8 : 7 )#px;">MATCH</span>
			</div>
		</div>
		<h3 class="fp-disp">#encodeForHTML( j.title )#</h3>
			<cfif structKeyExists( j, "reasons" ) AND isArray( j.reasons ) AND arrayLen( j.reasons )>
				<cfset var rsnStr = lCase( arrayToList( j.reasons, "|" ) ) />
				<cfif findNoCase( "india_eligible", rsnStr ) OR findNoCase( "remote_fit", rsnStr )>
					<div style="margin-top:3px;line-height:1;">
						<cfif findNoCase( "india_eligible", rsnStr )><span class="fp-kick" style="font-size:9px;margin-right:5px;">INDIA</span></cfif>
						<cfif findNoCase( "remote_fit", rsnStr )><span class="fp-kick" style="font-size:9px;">REMOTE</span></cfif>
					</div>
				</cfif>
			</cfif>
		<cfif arguments.big AND len( summary )><p class="fp-summary">#encodeForHTML( summary )#</p></cfif>
		<div class="fp-job-card-bottom">
			<div style="min-width:0;">
				<div class="fp-job-card-company">#encodeForHTML( j.company_name )#</div>
				<div class="fp-job-card-meta">#encodeForHTML( loc )#<cfif len( ageStr )> &middot; #ageStr#</cfif><cfif expired> &middot; expired</cfif></div>
			</div>
			<button type="button" class="fp-reset fp-save fp-save-toggle" data-job-id="#val( j.id )#" title="Save role" onclick="event.preventDefault();event.stopPropagation();">
				<svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="var(--fp-ink)" stroke-width="2.2" stroke-linejoin="round"><path d="M12 21s-7.5-4.9-10-9.3C.6 9 1.7 5.6 5 4.7c2-.5 3.9.4 5 2 1.1-1.6 3-2.5 5-2 3.3.9 4.4 4.3 3 7C19.5 16.1 12 21 12 21z"/></svg>
			</button>
		</div>
	</a>
	</cfoutput>
	</cfsavecontent>
	<cfreturn out />
</cffunction>

<cfinclude template="includes/layoutHead.cfm" />
<cfinclude template="includes/layoutTopbar.cfm" />

<cfoutput>

<cfif len( pageError )>
<div class="fp-wrap" style="padding-top:20px;">
	<div class="fp-card" style="padding:16px 20px;border-color:var(--fp-accent2);color:var(--fp-accent2);font-size:13px;">#encodeForHTML( pageError )#</div>
</div>
</cfif>

<!--- ===================== Briefing (Today) ===================== --->
<cfset topJob = arrayLen( briefingData.rows ) ? briefingData.rows[ 1 ] : {} />
<cfset boardGrid = [] />
<cfloop from="2" to="#arrayLen( briefingData.rows )#" index="bgIdx">
	<cfset arrayAppend( boardGrid, briefingData.rows[ bgIdx ] ) />
</cfloop>

<section class="fp-hero">
	<div class="fp-wrap fp-hero-inner">
		<div class="fp-hero-top">
			<div class="fp-hero-head">
				<div class="fp-kick fp-hero-kick">The daily ColdFusion frontpage &middot; #dateFormat( now(), 'd mmm yyyy' )#</div>
				<h1 class="fp-disp">#newJobsCount# fresh<br/>CF roles<br/><span class="fp-accent">worth a look<span class="fp-accent2">.</span></span></h1>
				<p class="fp-hero-sub">Scored across #liveSourcesCount# source<cfif liveSourcesCount NEQ 1>s</cfif>, filtered to the #eligibleCount# that are India-eligible or genuinely remote. No title-only noise.</p>
			</div>
			<div class="fp-seal-wrap">
				<svg class="fp-seal" viewBox="0 0 132 132" width="132" height="132">
					<defs><path id="fpcircle" d="M66,66 m-50,0 a50,50 0 1,1 100,0 a50,50 0 1,1 -100,0" /></defs>
					<text fill="var(--fp-accent)" style="font-size:11px;font-weight:700;letter-spacing:3px;font-family:Archivo,sans-serif;">
						<textPath href="##fpcircle">INDIA-ELIGIBLE &middot; GLOBAL REMOTE &middot; CFML &middot; LUCEE &middot; </textPath>
					</text>
				</svg>
				<div class="fp-seal-center"><span class="fp-disp" style="font-size:22px;">NEW</span></div>
			</div>
		</div>

		<cfif NOT structIsEmpty( topJob )>
		<cfset topHref = jobHref( topJob.link ) />
		<a class="fp-card fp-click fp-top-match" style="text-decoration:none;"<cfif len( topHref )> href="#encodeForHTMLAttribute( topHref )#" target="_blank" rel="noopener noreferrer"<cfelse> href="##" onclick="return false;"</cfif>>
			<div class="fp-badge fp-badge--ondark #scoreToneClass( val( topJob.score ) )#" style="width:78px;height:78px;">
				<span class="fp-badge-num" style="font-size:28px;">#val( topJob.score )#</span>
				<span class="fp-badge-lbl" style="font-size:10px;">MATCH</span>
			</div>
			<div class="fp-top-match-body">
				<div class="fp-kick fp-top-match-kick">Top match today</div>
				<div class="fp-disp fp-top-match-title">#encodeForHTML( topJob.title )#</div>
				<div class="fp-top-match-meta">#encodeForHTML( topJob.company_name )#<cfif len( trim( topJob.location ) )> &middot; #encodeForHTML( topJob.location )#</cfif></div>
			</div>
			<cfif len( topHref )>
			<span class="fp-btn fp-btn--accent">Apply now &rarr;</span>
			<cfelse>
			<span class="fp-btn" aria-disabled="true">No link yet</span>
			</cfif>
		</a>
		</cfif>
	</div>
</section>

<cfif arrayLen( boardGrid )>
<section class="fp-wrap" style="padding:30px 28px 16px;">
	<div class="fp-section-head">
		<span class="fp-disp" style="font-size:22px;">More on the board</span>
		<span class="fp-section-rule"></span>
		<a class="fp-reset fp-kick fp-link" style="color:var(--fp-mute);white-space:nowrap;" href="##board">See all &rarr;</a>
	</div>
	<div class="fp-grid-3">
	<cfloop from="1" to="#arrayLen( boardGrid )#" index="bgIdx">
		#renderJobCard( boardGrid[ bgIdx ], bgIdx EQ 1 )#
	</cfloop>
	</div>
</section>
</cfif>

<!--- by the numbers --->
<section class="fp-wrap" style="padding:24px 28px 12px;">
	<div class="fp-stats-strip">
		<div class="fp-stat-cell">
			<div class="fp-stat-val">#numberFormat( totalJobsInDb, ',' )#</div>
			<div class="fp-kick fp-stat-lbl">Indexed</div>
		</div>
		<div class="fp-stat-cell fp-stat-cell--accent">
			<div class="fp-stat-val">+#numberFormat( newJobsCount, ',' )#</div>
			<div class="fp-kick fp-stat-lbl">New today</div>
		</div>
		<div class="fp-stat-cell">
			<div class="fp-stat-val">#numberFormat( eligibleCount, ',' )#</div>
			<div class="fp-kick fp-stat-lbl">Eligible 70+</div>
		</div>
		<div class="fp-stat-cell">
			<div class="fp-stat-val">#numberFormat( liveSourcesCount, ',' )#</div>
			<div class="fp-kick fp-stat-lbl">Live sources</div>
		</div>
	</div>
</section>

<!--- sources strip --->
<cfif arrayLen( sourceNames )>
<section class="fp-wrap" style="padding:20px 28px 48px;">
	<div class="fp-kick" style="color:var(--fp-mute);margin-bottom:12px;">Reading from #liveSourcesCount# source<cfif liveSourcesCount NEQ 1>s</cfif></div>
	<div class="fp-sources-strip">
	<cfloop array="#sourceNames#" index="srcName">
		<span class="fp-kick fp-source-chip">#encodeForHTML( srcName )#</span>
	</cfloop>
	</div>
</section>
</cfif>

<!--- ===================== Board ===================== --->
<cfset eligibleOn = ( minScore GTE 70 AND lCase( trim( locationKeyword ) ) EQ "india-eligible" ) />
<cfset activeCompanyName = "" />
<cfif companyId GT 0>
	<cfloop array="#companiesForFilter#" index="coF">
		<cfif val( coF.id ) EQ companyId><cfset activeCompanyName = coF.name /></cfif>
	</cfloop>
</cfif>

<div id="board" style="position:relative;top:-64px;"></div>
<div class="fp-filterbar">
	<div class="fp-wrap fp-filterbar-row">
		<a class="fp-chip<cfif NOT len( workTypeFilter )> fp-chip--on</cfif>" href="#boardUrl( indexUrl, keyword, locationKeyword, minScore, rawSourceFilter, companyId, '', jobsData.sortBy, jobsData.sortDir )#">All</a>
		<a class="fp-chip<cfif workTypeFilter EQ 'remote'> fp-chip--on</cfif>" href="#boardUrl( indexUrl, keyword, locationKeyword, minScore, rawSourceFilter, companyId, 'remote', jobsData.sortBy, jobsData.sortDir )#">Remote</a>
		<a class="fp-chip<cfif workTypeFilter EQ 'hybrid'> fp-chip--on</cfif>" href="#boardUrl( indexUrl, keyword, locationKeyword, minScore, rawSourceFilter, companyId, 'hybrid', jobsData.sortBy, jobsData.sortDir )#">Hybrid</a>
		<a class="fp-chip<cfif workTypeFilter EQ 'onsite'> fp-chip--on</cfif>" href="#boardUrl( indexUrl, keyword, locationKeyword, minScore, rawSourceFilter, companyId, 'onsite', jobsData.sortBy, jobsData.sortDir )#">Onsite</a>

		<span class="fp-filterbar-divider"></span>

		<a class="fp-chip<cfif minScore EQ 0> fp-chip--on</cfif>" href="#boardUrl( indexUrl, keyword, locationKeyword, 0, rawSourceFilter, companyId, workTypeFilter, jobsData.sortBy, jobsData.sortDir )#">Any score</a>
		<a class="fp-chip<cfif minScore EQ 70> fp-chip--on</cfif>" href="#boardUrl( indexUrl, keyword, locationKeyword, 70, rawSourceFilter, companyId, workTypeFilter, jobsData.sortBy, jobsData.sortDir )#">70+</a>
		<a class="fp-chip<cfif minScore EQ 85> fp-chip--on</cfif>" href="#boardUrl( indexUrl, keyword, locationKeyword, 85, rawSourceFilter, companyId, workTypeFilter, jobsData.sortBy, jobsData.sortDir )#">85+</a>

		<cfif eligibleOn>
		<a class="fp-chip fp-chip--on" href="#boardUrl( indexUrl, keyword, '', 0, rawSourceFilter, companyId, workTypeFilter, jobsData.sortBy, jobsData.sortDir )#">India-eligible &##10003;</a>
		<cfelse>
		<a class="fp-chip" href="#boardUrl( indexUrl, keyword, 'india-eligible', 70, rawSourceFilter, companyId, workTypeFilter, jobsData.sortBy, jobsData.sortDir )#">India-eligible &##10003;</a>
		</cfif>

		<span class="fp-filterbar-divider"></span>

		<!--- Sponsorship toggle — boardUrl injects the flag into the query (preserves New-today). --->
		<cfif sponsorshipOnly>
		<a class="fp-chip fp-chip--on" href="#boardUrl( indexUrl, keyword, locationKeyword, minScore, rawSourceFilter, companyId, workTypeFilter, jobsData.sortBy, jobsData.sortDir, '0' )#">Sponsorship &##10003;</a>
		<cfelse>
		<a class="fp-chip" href="#boardUrl( indexUrl, keyword, locationKeyword, minScore, rawSourceFilter, companyId, workTypeFilter, jobsData.sortBy, jobsData.sortDir, '1' )#">Sponsorship</a>
		</cfif>
		<!--- New-today toggle (preserves an active Sponsorship flag via the inherit default). --->
		<cfif newTodayHours GT 0>
		<a class="fp-chip fp-chip--on" href="#boardUrl( indexUrl, keyword, locationKeyword, minScore, rawSourceFilter, companyId, workTypeFilter, jobsData.sortBy, jobsData.sortDir, '', '0' )#">New today &##10003;</a>
		<cfelse>
		<a class="fp-chip" href="#boardUrl( indexUrl, keyword, locationKeyword, minScore, rawSourceFilter, companyId, workTypeFilter, jobsData.sortBy, jobsData.sortDir, '', '1' )#">New today</a>
		</cfif>

		<div class="fp-filterbar-spacer"></div>
		<span class="fp-kick" style="color:var(--fp-mute);">#numberFormat( jobsData.totalRows, ',' )# of #numberFormat( totalJobsInDb, ',' )#</span>
		<select class="fp-in" style="width:auto;padding:9px 12px;font-weight:700;text-transform:uppercase;letter-spacing:.06em;font-size:11px;" onchange="location.href=this.value;">
			<option value="#boardUrl( indexUrl, keyword, locationKeyword, minScore, rawSourceFilter, companyId, workTypeFilter, 'score', 'desc' )#"<cfif jobsData.sortBy EQ 'score'> selected</cfif>>Sort: match score</option>
			<option value="#boardUrl( indexUrl, keyword, locationKeyword, minScore, rawSourceFilter, companyId, workTypeFilter, 'first_seen', 'desc' )#"<cfif jobsData.sortBy EQ 'first_seen'> selected</cfif>>Sort: newest</option>
		</select>
	</div>
</div>

<div class="fp-wrap" style="padding:26px 28px 56px;">
	<cfif companyId GT 0 AND len( activeCompanyName )>
	<div style="display:flex;align-items:center;gap:12px;margin-bottom:18px;">
		<span class="fp-kick" style="color:var(--fp-mute);">Filtered to</span>
		<a class="fp-chip fp-chip--on" style="text-decoration:none;" href="#boardUrl( indexUrl, keyword, locationKeyword, minScore, rawSourceFilter, 0, workTypeFilter, jobsData.sortBy, jobsData.sortDir )#">#encodeForHTML( activeCompanyName )# &##10005;</a>
	</div>
	</cfif>

	<cfif arrayLen( jobsData.rows ) EQ 0>
	<div class="fp-card fp-empty">
		<div class="fp-empty-icon">
			<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="var(--fp-ink)" stroke-width="2"><circle cx="11" cy="11" r="7"/><path d="M21 21l-4-4"/></svg>
		</div>
		<h3 class="fp-disp">No roles match those filters</h3>
		<p>Loosen the score or work-type filters, or clear your search.</p>
		<a class="fp-btn fp-btn--accent" style="margin-top:6px;" href="#indexUrl#?keyword=&location=&min_score=0&source=&company_id=0&work_type=&jobs_page=1##board">Reset filters</a>
	</div>
	<cfelse>
	<div class="fp-grid-3">
	<cfloop from="1" to="#arrayLen( jobsData.rows )#" index="jobIdx">
		#renderJobCard( jobsData.rows[ jobIdx ], ( jobIdx - 1 ) MOD 7 EQ 0 )#
	</cfloop>
	</div>
	<div style="display:flex;justify-content:space-between;margin-top:24px;">
		<cfif jobsData.page GT 1>
		<a class="fp-btn fp-btn--ghost fp-btn--sm" href="#indexUrl#?#boardUrl( '', keyword, locationKeyword, minScore, rawSourceFilter, companyId, workTypeFilter, jobsData.sortBy, jobsData.sortDir )#&jobs_page=#jobsData.page-1###board">&larr; Previous</a>
		<cfelse><span></span></cfif>
		<span class="fp-kick" style="color:var(--fp-mute);align-self:center;">Page #jobsData.page# / #jobsData.totalPages#</span>
		<cfif jobsData.page LT jobsData.totalPages>
		<a class="fp-btn fp-btn--ghost fp-btn--sm" href="#indexUrl#?#boardUrl( '', keyword, locationKeyword, minScore, rawSourceFilter, companyId, workTypeFilter, jobsData.sortBy, jobsData.sortDir )#&jobs_page=#jobsData.page+1###board">Next &rarr;</a>
		<cfelse><span></span></cfif>
	</div>
	</cfif>
</div>

<!--- ===================== Companies ===================== --->
<div id="companies" style="position:relative;top:-64px;"></div>
<div class="fp-wrap fp-page">
	<div style="margin-bottom:24px;display:flex;justify-content:space-between;align-items:flex-end;flex-wrap:wrap;gap:8px;">
		<div>
			<h1 class="fp-disp fp-page-title">Companies hiring CF</h1>
			<div class="fp-kick fp-page-sub">#numberFormat( totalCompanies, ',' )# employers &middot; page #companiesData.page# / #companiesData.totalPages#</div>
		</div>
	</div>
	<cfif arrayLen( companies ) EQ 0>
	<div class="fp-card" style="padding:24px;color:var(--fp-mute);font-size:13.5px;">No companies found.</div>
	<cfelse>
	<div class="fp-grid-3">
	<cfloop array="#companies#" index="companyRow">
		<cfset coWeb = trim( companyRow.website ) />
		<cfif len( coWeb ) AND reFindNoCase( "^https?://", coWeb ) EQ 0><cfset coWeb = "https://" & coWeb /></cfif>
		<cfset coCareer = trim( companyRow.careers_url ) />
		<cfif len( coCareer ) AND reFindNoCase( "^https?://", coCareer ) EQ 0><cfset coCareer = "https://" & coCareer /></cfif>
		<cfset coInitial = len( trim( companyRow.name ) ) ? uCase( left( trim( companyRow.name ), 1 ) ) : "?" />
		<a class="fp-card fp-click" style="padding:22px;display:flex;flex-direction:column;gap:14px;height:100%;text-decoration:none;color:inherit;" href="#boardUrl( indexUrl, '', '', 0, '', val( companyRow.id ), '', 'score', 'desc' )#">
			<div style="display:flex;justify-content:space-between;align-items:flex-start;">
				<div class="fp-disp" style="width:46px;height:46px;border:2px solid var(--fp-ink);border-radius:50%;display:flex;align-items:center;justify-content:center;">#encodeForHTML( coInitial )#</div>
				<div class="fp-badge #scoreToneClass( val( companyRow.score ) )#" style="width:46px;height:46px;">
					<span class="fp-badge-num" style="font-size:16px;">#val( companyRow.score )#</span>
				</div>
			</div>
			<div>
				<h3 class="fp-disp" style="font-size:22px;margin:0;">#encodeForHTML( companyRow.name )#</h3>
				<div style="font-size:12.5px;color:var(--fp-mute);margin-top:4px;">#encodeForHTML( len( trim( companyRow.careers_source ) ) ? companyRow.careers_source : "unknown source" )#</div>
			</div>
			<div style="display:flex;align-items:center;justify-content:space-between;margin-top:auto;padding-top:6px;">
				<span class="fp-kick">#val( companyRow.job_count )# open #( val( companyRow.job_count ) EQ 1 ? "role" : "roles" )#</span>
				<span class="fp-kick fp-link" style="color:var(--fp-mute);">View &rarr;</span>
			</div>
		</a>
	</cfloop>
	</div>
	<div style="display:flex;justify-content:space-between;margin-top:24px;">
		<cfif companiesData.page GT 1>
		<a class="fp-btn fp-btn--ghost fp-btn--sm" href="#indexUrl#?keyword=#urlEncodedFormat( keyword )#&location=#urlEncodedFormat( locationKeyword )#&min_score=#minScore#&source=#urlEncodedFormat( rawSourceFilter )#&company_id=#companyId#&work_type=#urlEncodedFormat( workTypeFilter )#&jobs_sort_by=#urlEncodedFormat( jobsData.sortBy )#&jobs_sort_dir=#urlEncodedFormat( jobsData.sortDir )#&companies_page=#companiesData.page-1###companies">&larr; Previous</a>
		<cfelse><span></span></cfif>
		<cfif companiesData.page LT companiesData.totalPages>
		<a class="fp-btn fp-btn--ghost fp-btn--sm" href="#indexUrl#?keyword=#urlEncodedFormat( keyword )#&location=#urlEncodedFormat( locationKeyword )#&min_score=#minScore#&source=#urlEncodedFormat( rawSourceFilter )#&company_id=#companyId#&work_type=#urlEncodedFormat( workTypeFilter )#&jobs_sort_by=#urlEncodedFormat( jobsData.sortBy )#&jobs_sort_dir=#urlEncodedFormat( jobsData.sortDir )#&companies_page=#companiesData.page+1###companies">Next &rarr;</a>
		<cfelse><span></span></cfif>
	</div>
	</cfif>
</div>

<!--- ===================== Alerts ===================== --->
<div id="alerts" style="position:relative;top:-64px;"></div>
<div class="fp-wrap fp-page">
	<div style="margin-bottom:24px;">
		<h1 class="fp-disp fp-page-title">Your alerts</h1>
		<div class="fp-kick fp-page-sub">#numberFormat( totalAlerts, ',' )# matches pushed &middot; page #alertsData.page# / #alertsData.totalPages#</div>
	</div>
	<cfif arrayLen( alertsData.rows ) EQ 0>
	<div class="fp-card" style="padding:24px;color:var(--fp-mute);font-size:13.5px;">No alerts yet. Run the daily pipeline first.</div>
	<cfelse>
	<div style="display:flex;flex-direction:column;gap:12px;">
	<cfloop array="#alertsData.rows#" index="alertRow">
		<cfset payload = structKeyExists( alertRow, "payload" ) ? alertRow.payload : {} />
		<cfset alertScore = structKeyExists( payload, "score" ) ? val( payload.score ) : 0 />
		<div class="fp-card" style="padding:18px;display:flex;align-items:center;gap:16px;flex-wrap:wrap;">
			<div class="fp-badge #scoreToneClass( alertScore )#" style="width:48px;height:48px;">
				<span class="fp-badge-num" style="font-size:16px;">#alertScore#</span>
			</div>
			<div style="flex:1;min-width:0;">
				<div class="fp-disp" style="font-size:18px;">#encodeForHTML( structKeyExists( payload, "title" ) ? payload.title : "Untitled role" )#</div>
				<div style="font-size:12.5px;color:var(--fp-mute);margin-top:3px;">#encodeForHTML( structKeyExists( payload, "company_name" ) ? payload.company_name : "" )#</div>
			</div>
			<div style="text-align:right;flex:0 0 auto;">
				<div class="fp-kick">#encodeForHTML( alertRow.channel )#</div>
				<div style="font-size:11.5px;color:var(--fp-mute);margin-top:4px;">#encodeForHTML( left( alertRow.sent_at, 16 ) )#</div>
			</div>
		</div>
	</cfloop>
	</div>
	<div style="display:flex;justify-content:space-between;margin-top:24px;">
		<cfif alertsData.page GT 1>
		<a class="fp-btn fp-btn--ghost fp-btn--sm" href="#indexUrl#?keyword=#urlEncodedFormat( keyword )#&location=#urlEncodedFormat( locationKeyword )#&min_score=#minScore#&source=#urlEncodedFormat( rawSourceFilter )#&company_id=#companyId#&work_type=#urlEncodedFormat( workTypeFilter )#&jobs_sort_by=#urlEncodedFormat( jobsData.sortBy )#&jobs_sort_dir=#urlEncodedFormat( jobsData.sortDir )#&alerts_page=#alertsData.page-1###alerts">&larr; Previous</a>
		<cfelse><span></span></cfif>
		<cfif alertsData.page LT alertsData.totalPages>
		<a class="fp-btn fp-btn--ghost fp-btn--sm" href="#indexUrl#?keyword=#urlEncodedFormat( keyword )#&location=#urlEncodedFormat( locationKeyword )#&min_score=#minScore#&source=#urlEncodedFormat( rawSourceFilter )#&company_id=#companyId#&work_type=#urlEncodedFormat( workTypeFilter )#&jobs_sort_by=#urlEncodedFormat( jobsData.sortBy )#&jobs_sort_dir=#urlEncodedFormat( jobsData.sortDir )#&alerts_page=#alertsData.page+1###alerts">Next &rarr;</a>
		<cfelse><span></span></cfif>
	</div>
	</cfif>
</div>

<!--- ===================== Pipeline ===================== --->
<div id="pipeline" style="position:relative;top:-64px;"></div>
<div class="fp-wrap fp-page">
	<div style="margin-bottom:24px;">
		<h1 class="fp-disp fp-page-title">Pipeline health</h1>
		<div class="fp-kick fp-page-sub">Daily ingest &middot; dedupe &middot; score &middot; alert</div>
	</div>

	<div class="fp-card" style="background:var(--fp-deep);color:var(--fp-cream);padding:24px;display:flex;align-items:center;justify-content:space-between;flex-wrap:wrap;gap:16px;margin-bottom:24px;">
		<div style="display:flex;align-items:center;gap:14px;">
			<span style="width:12px;height:12px;border-radius:50%;background:var(--fp-accent);flex:0 0 auto;"></span>
			<div>
				<div class="fp-disp" style="font-size:20px;">
				<cfif structIsEmpty( runInfo )>No pipeline run yet<cfelseif lCase( runInfo.status ) EQ "success">Pipeline healthy<cfelse>Pipeline needs attention</cfif>
				</div>
				<div style="font-size:13px;color:rgba(243,239,228,0.7);margin-top:4px;">
				<cfif NOT structIsEmpty( runInfo )>Last run #encodeForHTML( left( runInfo.run_at, 19 ) )#<cfelse>Use Run Daily Pipeline to start the first run.</cfif>
				</div>
			</div>
		</div>
		<cfif isLocal><a class="fp-btn fp-btn--accent" href="#appBasePath#tasks/runDailyScrape.cfm">Run now &rarr;</a></cfif>
	</div>

	<cfif arrayLen( pipelinePhases ) EQ 0>
	<div class="fp-card" style="padding:24px;color:var(--fp-mute);font-size:13.5px;">No pipeline runs recorded yet.</div>
	<cfelse>
	<div class="fp-grid-3 fp-phases" style="grid-template-columns:repeat(5,1fr);">
	<cfloop array="#pipelinePhases#" index="phaseRow">
		<cfset statusClass = "fp-status-pill--ok" />
		<cfif phaseRow.status EQ "WARN"><cfset statusClass = "fp-status-pill--warn" /></cfif>
		<cfif phaseRow.status EQ "FAILED"><cfset statusClass = "fp-status-pill--failed" /></cfif>
		<div class="fp-card" style="padding:18px;display:flex;flex-direction:column;gap:8px;">
			<div class="fp-kick" style="color:var(--fp-mute);">#encodeForHTML( phaseRow.label )#</div>
			<span class="fp-status-pill #statusClass#"><span class="fp-dot"></span> #encodeForHTML( phaseRow.status )#</span>
			<div class="fp-disp" style="font-size:28px;">#numberFormat( val( phaseRow.volume ), ',' )#</div>
			<div style="font-size:11px;color:var(--fp-mute);">#encodeForHTML( left( phaseRow.lastSync, 16 ) )#</div>
		</div>
	</cfloop>
	</div>
	</cfif>

	<div style="margin-top:24px;">
		<a class="fp-link fp-kick" style="color:var(--fp-mute);" href="#discoveryUrl#">View discovery network &rarr;</a>
	</div>
</div>

</cfoutput>

<cfinclude template="includes/layoutFoot.cfm" />
