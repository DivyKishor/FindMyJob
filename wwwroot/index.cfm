<cfsetting showdebugoutput="false" />

<cfparam name="url.keyword" default="" />
<cfparam name="url.location" default="" />
<cfparam name="url.min_score" default="0" />
<cfparam name="url.source" default="" />
<cfparam name="url.company_id" default="0" />
<cfparam name="url.jobs_page" default="1" />
<cfparam name="url.jobs_page_size" default="25" />
<cfparam name="url.jobs_sort_by" default="fetched_at" />
<cfparam name="url.jobs_sort_dir" default="desc" />
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

<cfinclude template="includes/pathUtil.cfm" />

<cfset runInfo = {} />
<cfset pageError = "" />
<cfset pipelinePhases = [] />
<cfset companiesForFilter = [] />

<cftry>
	<cfset companiesData = application.companyService.listPaged( companiesSortBy, companiesSortDir, companiesPage, companiesPageSize ) />
	<cfset companies = companiesData.rows />
	<cfset companiesForFilter = application.companyService.listWithJobsForFilter() />
	<cfset jobsData = application.jobService.listPaged( companyId, keyword, minScore, jobsPage, jobsPageSize, jobsSortBy, jobsSortDir, locationKeyword, rawSourceFilter ) />
	<cfset alertsData = application.alertService.listAlertsPaged( alertsPage, alertsPageSize, alertsSortBy, alertsSortDir ) />
	<cfset runInfo = application.runStatusService.getLatestRun() />
	<cfset pipelinePhases = application.runStatusService.getPipelinePhaseRows( runInfo ) />
	<cfset totalCompanies = companiesData.totalRows />
	<cfset totalJobs = jobsData.totalRows />
	<cfset totalJobsInDb = application.jobService.countAll() />
	<cfset filtersActive = len( keyword ) OR len( locationKeyword ) OR minScore GT 0 OR len( rawSourceFilter ) OR companyId GT 0 />
	<cfset totalAlerts = alertsData.totalRows />
	<cfset scrapeCompaniesProcessed = application.runStatusService.getPipelineMetric( runInfo, "scrape", "companiesProcessed", 0 ) />
	<cfset companyLinksEnriched = application.runStatusService.getPipelineMetric( runInfo, "scrape", "companyLinksEnriched", 0 ) />
	<cfcatch type="any">
		<cfset companiesData = { rows: [], totalRows: 0, page: 1, pageSize: 25, totalPages: 1, sortBy: "job_count", sortDir: "desc" } />
		<cfset companies = [] />
		<cfset companiesForFilter = [] />
		<cfset jobsData = { rows: [], totalRows: 0, page: 1, pageSize: 25, totalPages: 1, sortBy: "fetched_at", sortDir: "desc" } />
		<cfset alertsData = { rows: [], totalRows: 0, page: 1, pageSize: 25, totalPages: 1, sortBy: "sent_at", sortDir: "desc" } />
		<cfset totalCompanies = 0 />
		<cfset totalJobs = 0 />
		<cfset totalJobsInDb = 0 />
		<cfset filtersActive = false />
		<cfset totalAlerts = 0 />
		<cfset scrapeCompaniesProcessed = 0 />
		<cfset companyLinksEnriched = 0 />
		<cfset pageError = cfcatch.message />
	</cfcatch>
</cftry>

<cfset filterCoreNoLocation = "keyword=#urlEncodedFormat( keyword )#&min_score=#minScore#&source=#urlEncodedFormat( rawSourceFilter )#&company_id=#companyId#&jobs_page_size=#jobsData.pageSize#&alerts_page_size=#alertsData.pageSize#&companies_page_size=#companiesData.pageSize#" />
<cfset filterLocation = "location=#urlEncodedFormat( locationKeyword )#" />
<cfset filterCore = "#filterCoreNoLocation#&#filterLocation#" />
<cfset filterJobsSort = "jobs_sort_by=#urlEncodedFormat( jobsData.sortBy )#&jobs_sort_dir=#urlEncodedFormat( jobsData.sortDir )#" />
<cfset filterAlertsSort = "alerts_sort_by=#urlEncodedFormat( alertsData.sortBy )#&alerts_sort_dir=#urlEncodedFormat( alertsData.sortDir )#" />
<cfset filterCompaniesSort = "companies_sort_by=#urlEncodedFormat( companiesData.sortBy )#&companies_sort_dir=#urlEncodedFormat( companiesData.sortDir )#" />
<cfset baseFilter = "#filterCore#&#filterJobsSort#&#filterAlertsSort#&#filterCompaniesSort#&companies_page=#companiesData.page#" />
<cfset baseFilterNoLocation = "#filterCoreNoLocation#&#filterJobsSort#&#filterAlertsSort#&#filterCompaniesSort#&companies_page=#companiesData.page#" />
<cfset filterCoreNoKeyword = "min_score=#minScore#&source=#urlEncodedFormat( rawSourceFilter )#&company_id=#companyId#&jobs_page_size=#jobsData.pageSize#&alerts_page_size=#alertsData.pageSize#&companies_page_size=#companiesData.pageSize#" />
<cfset baseFilterNoKeyword = "#filterCoreNoKeyword#&#filterLocation#&#filterJobsSort#&#filterAlertsSort#&#filterCompaniesSort#&companies_page=#companiesData.page#" />
<cfset jobsAnchorQuery = baseFilter & "&jobs_page=1&alerts_page=" & val( alertsData.page ) & "##jobs" />
<cfset healthAnchorQuery = baseFilter & "&jobs_page=" & val( jobsData.page ) & "&alerts_page=" & val( alertsData.page ) & "##pipeline" />
<cfset companiesAnchorQuery = baseFilter & "&jobs_page=" & val( jobsData.page ) & "&alerts_page=" & val( alertsData.page ) & "##companies" />

<cfset activeSection = "overview" />
<cfset pageTitle = "CF/OBSERVER | Dashboard" />
<cfset searchKeyword = keyword />

<cfinclude template="includes/layoutHead.cfm" />
<cfinclude template="includes/layoutSidebar.cfm" />

<main class="flex-1 flex flex-col min-w-0 bg-background relative overflow-hidden">
<cfinclude template="includes/layoutTopbar.cfm" />

<cfoutput>
<div class="flex-1 overflow-y-auto custom-scrollbar px-4 md:px-margin-desktop py-6 md:py-8 flex flex-col gap-8">

<cfif len( pageError )>
<div class="bento-card p-4 border-l-4 border-l-red-400 text-red-300 text-sm">#encodeForHTML( pageError )#</div>
</cfif>

<!--- USP strip --->
<section class="bento-card p-5 md:p-6">
<h2 class="text-primary text-xs font-bold uppercase tracking-[0.2em] mb-3">ColdFusion job intelligence</h2>
<p class="text-outline text-sm mb-4 max-w-4xl">One dashboard for <strong class="text-on-surface">ColdFusion, CFML, Lucee</strong> and full-stack CF-backend roles — scored for India eligibility and global remote.</p>
<div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 text-sm">
<div class="flex gap-2"><span class="material-symbols-outlined text-primary text-[18px]">hub</span><span><strong class="text-on-surface">20+ sources</strong><br/><span class="text-outline text-xs">Watcher, Adzuna, DevJobsScanner, boards, career scans</span></span></div>
<div class="flex gap-2"><span class="material-symbols-outlined text-primary text-[18px]">grade</span><span><strong class="text-on-surface">India-first scoring</strong><br/><span class="text-outline text-xs">v3 score 0–100; 70+ = India-eligible / global remote</span></span></div>
<div class="flex gap-2"><span class="material-symbols-outlined text-primary text-[18px]">layers</span><span><strong class="text-on-surface">Full-stack CF</strong><br/><span class="text-outline text-xs">Captures CFML/Lucee backend roles, not title-only noise</span></span></div>
<div class="flex gap-2"><span class="material-symbols-outlined text-primary text-[18px]">sync</span><span><strong class="text-on-surface">Daily pipeline</strong><br/><span class="text-outline text-xs">Ingest, dedupe, score, and alert automatically</span></span></div>
</div>
<button type="button" id="scoring-toggle" class="mt-4 text-primary text-xs font-semibold flex items-center gap-1 hover:underline">
<span class="material-symbols-outlined text-[14px]">info</span> How scoring works
</button>
<div id="scoring-panel" class="hidden mt-3 text-xs text-outline leading-relaxed border-t border-outline-variant/20 pt-3">
<strong class="text-on-surface">100</strong> = CF keyword + India or confirmed global remote.
<strong class="text-on-surface">80</strong> = CF + likely remote-friendly.
<strong class="text-on-surface">50</strong> = CF match, location unclear.
<strong class="text-on-surface">20</strong> = US work-auth / clearance signals.
Use <a class="text-primary" href="#indexUrl#?#baseFilterNoLocation#&min_score=70&location=&jobs_page=1">India-eligible (70+)</a> quick filter.
</div>
</section>

<!--- Bento stats --->
<section class="grid grid-cols-1 md:grid-cols-12 gap-6">
<div class="bento-card md:col-span-6 p-6 flex flex-col justify-between">
<div>
<h3 class="text-outline text-xs uppercase tracking-wider mb-1">Jobs matching filters</h3>
<div class="flex items-baseline gap-3">
<span class="text-[40px] text-on-surface numerical font-bold">#numberFormat( totalJobs, "," )#</span>
<cfif filtersActive OR totalJobs NEQ totalJobsInDb>
<span class="text-primary font-label-mono text-sm numerical">#numberFormat( totalJobsInDb, "," )# total indexed</span>
</cfif>
</div>
</div>
<div class="mt-4 text-outline-variant text-[11px] font-label-mono border-t border-outline-variant/10 pt-4 numerical">
<cfif structIsEmpty( runInfo )>NO PIPELINE RUN YET<cfelse>LAST SYNC: #encodeForHTML( runInfo.run_at )#</cfif>
</div>
</div>
<div class="bento-card md:col-span-3 p-6 flex flex-col justify-between">
<div>
<h3 class="text-outline text-xs uppercase tracking-wider mb-1">Tracked sources</h3>
<div class="flex items-center gap-3">
<span class="text-3xl text-on-surface numerical font-bold">#numberFormat( totalCompanies, "," )#</span>
<cfif NOT structIsEmpty( runInfo ) AND lCase( runInfo.status ) EQ "success">
<div class="h-3 w-3 rounded-full bg-primary glow-blue-pulse"></div>
</cfif>
</div>
</div>
<p class="text-outline text-xs mt-2 numerical">Companies in watch list</p>
</div>
<div class="bento-card md:col-span-3 p-6 flex flex-col justify-between">
<div>
<h3 class="text-outline text-xs uppercase tracking-wider mb-1">Alerts &amp; scrape</h3>
<div class="font-label-mono text-2xl text-on-surface numerical">#numberFormat( totalAlerts, "," )# <span class="text-outline text-sm">alerts</span></div>
</div>
<p class="text-outline text-xs mt-2 numerical">Last scrape: #val( scrapeCompaniesProcessed )# cos. | #val( companyLinksEnriched )# links enriched</p>
</div>
</section>

<!--- Pipeline health --->
<section id="pipeline" class="flex flex-col gap-4">
<div class="flex justify-between items-center flex-wrap gap-2">
<h2 class="font-headline-md text-lg text-on-surface tracking-tight">Pipeline Health</h2>
<a class="text-primary text-xs font-semibold flex items-center gap-1 hover:underline" href="#appBasePath#tasks/runDailyScrape.cfm">
VIEW RUN OUTPUT <span class="material-symbols-outlined text-[14px]">arrow_forward</span>
</a>
</div>
<div class="bento-card overflow-hidden">
<table class="w-full text-left border-collapse">
<thead>
<tr class="bg-surface-container-low/50 text-outline text-[11px] uppercase tracking-widest border-b border-outline-variant/20">
<th class="px-6 py-3 font-medium">Pipeline phase</th>
<th class="px-6 py-3 font-medium">Last sync</th>
<th class="px-6 py-3 font-medium">Status</th>
<th class="px-6 py-3 font-medium">Volume</th>
</tr>
</thead>
<tbody class="text-sm font-label-mono divide-y divide-outline-variant/10">
<cfif arrayLen( pipelinePhases ) EQ 0>
<tr><td colspan="4" class="px-6 py-4 text-outline">No pipeline runs recorded yet. Use <strong>Run Daily Pipeline</strong> in the sidebar.</td></tr>
<cfelse>
<cfloop array="#pipelinePhases#" index="phaseRow">
<cfset statusClass = "status-success" />
<cfif phaseRow.status EQ "WARN"><cfset statusClass = "status-warn" /></cfif>
<cfif phaseRow.status EQ "FAILED"><cfset statusClass = "status-failed" /></cfif>
<tr class="hover:bg-surface-container-high/30 transition-colors">
<td class="px-6 py-4 text-on-surface">#encodeForHTML( phaseRow.label )#</td>
<td class="px-6 py-4 text-outline-variant numerical">#encodeForHTML( left( phaseRow.lastSync, 19 ) )#</td>
<td class="px-6 py-4">
<span class="inline-flex items-center gap-1.5 px-2 py-0.5 rounded-full text-[10px] font-bold #statusClass#">
<span class="h-1 w-1 rounded-full bg-current"></span> #encodeForHTML( phaseRow.status )#
</span>
</td>
<td class="px-6 py-4 text-outline numerical">#numberFormat( val( phaseRow.volume ), "," )#</td>
</tr>
</cfloop>
</cfif>
</tbody>
</table>
</div>
</section>

<!--- Filters --->
<form method="get" action="#indexUrl#" id="filters" class="flex flex-wrap items-center gap-3 bg-surface-container-lowest border border-outline-variant/20 p-3 rounded-lg">
<input type="hidden" name="jobs_sort_by" value="#encodeForHTMLAttribute( jobsData.sortBy )#"/>
<input type="hidden" name="jobs_sort_dir" value="#encodeForHTMLAttribute( jobsData.sortDir )#"/>
<input type="hidden" name="alerts_sort_by" value="#encodeForHTMLAttribute( alertsData.sortBy )#"/>
<input type="hidden" name="alerts_sort_dir" value="#encodeForHTMLAttribute( alertsData.sortDir )#"/>
<input type="hidden" name="companies_sort_by" value="#encodeForHTMLAttribute( companiesData.sortBy )#"/>
<input type="hidden" name="companies_sort_dir" value="#encodeForHTMLAttribute( companiesData.sortDir )#"/>
<div class="flex items-center gap-2 px-2 border-r border-outline-variant/20">
<span class="material-symbols-outlined text-[18px] text-outline">filter_list</span>
<span class="text-[11px] font-bold uppercase text-outline">Filters</span>
</div>
<input class="bg-transparent border border-outline-variant/30 rounded px-3 py-1.5 text-sm text-on-surface min-w-[120px]" type="text" name="keyword" value="#encodeForHTMLAttribute( keyword )#" placeholder="Keyword"/>
<input class="bg-transparent border border-outline-variant/30 rounded px-3 py-1.5 text-sm text-on-surface min-w-[120px]" type="text" name="location" value="#encodeForHTMLAttribute( locationKeyword )#" placeholder="Location"/>
<input class="bg-transparent border border-outline-variant/30 rounded px-3 py-1.5 text-sm text-on-surface w-20 numerical" type="number" name="min_score" value="#minScore#" min="0" max="100" title="Min score"/>
<select class="bg-surface-container-lowest border border-outline-variant/30 rounded px-2 py-1.5 text-sm text-on-surface max-w-[180px]" name="company_id">
<option value="0">All companies</option>
<cfloop array="#companiesForFilter#" index="coFilter">
<option value="#coFilter.id#"<cfif companyId EQ val( coFilter.id )> selected</cfif>>#encodeForHTML( coFilter.name )# (#val( coFilter.job_count )#)</option>
</cfloop>
</select>
<input type="hidden" name="source" value="#encodeForHTMLAttribute( rawSourceFilter )#"/>
<button type="submit" class="bg-primary/20 text-primary px-4 py-1.5 rounded text-sm font-semibold hover:bg-primary/30">Apply</button>
<div class="ml-auto flex items-center gap-3">
<span class="text-xs text-outline">India-eligible (70+)</span>
<button type="button" id="toggle-india-eligible" class="w-8 h-4 rounded-full relative transition-colors #minScore GTE 70 ? 'bg-primary/30' : 'bg-outline-variant/30'#" aria-checked="#minScore GTE 70 ? 'true' : 'false'#" data-on-url="#indexUrl#?#baseFilterNoLocation#&min_score=70&location=&jobs_page=1" data-off-url="#indexUrl#?#baseFilterNoLocation#&min_score=0&location=&jobs_page=1">
<div class="absolute top-0.5 w-3 h-3 bg-primary rounded-full transition-all #minScore GTE 70 ? 'translate-x-4' : 'translate-x-0.5'#" style="left:0"></div>
</button>
</div>
</form>

<div class="flex flex-wrap gap-2 text-xs">
<a class="px-2 py-1 rounded bg-primary/10 text-primary" href="#indexUrl#?#baseFilterNoLocation#&min_score=70&location=&jobs_page=1">India-eligible</a>
<a class="px-2 py-1 rounded border border-outline-variant/30 text-outline hover:text-primary" href="#indexUrl#?#baseFilterNoLocation#&location=#urlEncodedFormat( 'India' )#&jobs_page=1">India</a>
<a class="px-2 py-1 rounded border border-outline-variant/30 text-outline hover:text-primary" href="#indexUrl#?#baseFilterNoLocation#&location=#urlEncodedFormat( 'remote' )#&jobs_page=1">Remote</a>
<a class="px-2 py-1 rounded border border-outline-variant/30 text-outline hover:text-primary" href="#indexUrl#?keyword=&location=&min_score=0&source=#urlEncodedFormat( 'cf_global_watcher' )#&company_id=0&jobs_page=1">Global CF</a>
<a class="px-2 py-1 rounded border border-outline-variant/30 text-outline hover:text-primary" href="#indexUrl#?keyword=&location=&min_score=0&source=&company_id=0&jobs_page=1">Clear all</a>
</div>

<cfif totalJobs EQ 0 AND totalJobsInDb GT 0>
<div class="bento-card p-4 border-l-4 border-l-tertiary text-sm text-outline">
<strong class="text-on-surface">#totalJobsInDb# job(s)</strong> in the database do not match current filters.
<a class="text-primary" href="#indexUrl#?keyword=&location=&min_score=0&source=&company_id=0&jobs_page=1">Clear filters</a>
</div>
</cfif>

<!--- Master-detail job feed --->
<section id="jobs" class="grid grid-cols-1 lg:grid-cols-12 gap-6 min-h-[480px]">
<div class="lg:col-span-5 flex flex-col gap-3 max-h-[700px] overflow-y-auto custom-scrollbar pr-1">
<div class="flex justify-between items-center mb-1">
<span class="text-sm text-outline">Job feed</span>
<span class="text-xs text-outline numerical">Page #jobsData.page# / #jobsData.totalPages#</span>
</div>
<cfif arrayLen( jobsData.rows ) EQ 0>
<div class="bento-card p-6 text-outline text-sm">No jobs match current filters.</div>
<cfelse>
<cfset firstJob = jobsData.rows[ 1 ] />
<cfset firstDesc = "" />
<cfif structKeyExists( firstJob, "description" ) AND len( trim( firstJob.description ) )>
<cfset firstDesc = trim( reReplace( reReplace( reReplace( firstJob.description, "(?si)<script[^>]*>.*?</script>", " ", "all" ), "<[^>]+>", " ", "all" ), "\s+", " ", "all" ) ) />
</cfif>
<cfset firstHref = structKeyExists( firstJob, "link" ) ? trim( firstJob.link ) : "" />
<cfif len( firstHref ) AND reFindNoCase( "^https?://", firstHref ) EQ 0><cfset firstHref = "https://" & firstHref /></cfif>
<cfset firstScore = val( firstJob.score ) />
<cfset firstInsight = "Score " & firstScore & "/100." />
<cfif firstScore GTE 70>
<cfset firstInsight = firstInsight & " India-eligible or global-remote signals detected." />
<cfelseif firstScore GTE 50>
<cfset firstInsight = firstInsight & " CF match; verify location eligibility." />
</cfif>
<cfloop from="1" to="#arrayLen( jobsData.rows )#" index="jobIdx">
<cfset jobRow = jobsData.rows[ jobIdx ] />
<cfset descPlain = "" />
<cfif structKeyExists( jobRow, "description" ) AND len( trim( jobRow.description ) )>
<cfset descPlain = reReplace( jobRow.description, "(?si)<script[^>]*>.*?</script>", " ", "all" ) />
<cfset descPlain = trim( reReplace( reReplace( descPlain, "<[^>]+>", " ", "all" ), "\s+", " ", "all" ) ) />
</cfif>
<cfset jobHref = "" />
<cfif structKeyExists( jobRow, "link" )><cfset jobHref = trim( jobRow.link ) /></cfif>
<cfif len( jobHref )>
<cfif reFindNoCase( "^https?://", jobHref ) EQ 0 AND reFindNoCase( "^//", jobHref ) EQ 0><cfset jobHref = "https://" & jobHref /></cfif>
<cfif left( jobHref, 2 ) EQ "//"><cfset jobHref = "https:" & jobHref /></cfif>
</cfif>
<cfset jobScore = val( jobRow.score ) />
<cfset radialOffset = 251.2 * ( 1 - ( jobScore / 100 ) ) />
<cfset stackText = lCase( jobRow.title & " " & descPlain ) />
<cfset cardActive = jobIdx EQ 1 ? " active" : "" />
<cfset metaLine = encodeForHTMLAttribute( jobRow.company_name ) & " | " & encodeForHTMLAttribute( len( trim( jobRow.location ) ) ? jobRow.location : "Location n/a" ) />
<cfif structKeyExists( jobRow, "raw_source" ) AND len( trim( jobRow.raw_source ) )><cfset metaLine = metaLine & " | " & encodeForHTMLAttribute( jobRow.raw_source ) /></cfif>
<cfset insightText = "Score " & jobScore & "/100." />
<cfif jobScore GTE 70>
<cfset insightText = insightText & " India-eligible or global-remote signals detected." />
<cfelseif jobScore GTE 50>
<cfset insightText = insightText & " CF match; verify location eligibility." />
</cfif>
<div class="bento-card p-4 border-l-4 border-l-transparent job-card#cardActive# cursor-pointer" data-job-id="#jobRow.id#" data-title="#encodeForHTMLAttribute( jobRow.title )#" data-meta="#metaLine#" data-description="#encodeForHTMLAttribute( left( descPlain, 4000 ) )#" data-insight="#encodeForHTMLAttribute( insightText )#" data-link="#encodeForHTMLAttribute( jobHref )#" data-score="#jobScore#">
<div class="flex justify-between items-start mb-2 gap-2">
<div class="min-w-0">
<h4 class="text-on-surface font-semibold leading-tight truncate">#encodeForHTML( jobRow.title )#</h4>
<p class="text-outline text-sm truncate">#encodeForHTML( jobRow.company_name )#<cfif len( trim( jobRow.location ) )> &bull; #encodeForHTML( jobRow.location )#</cfif></p>
</div>
<div class="relative h-12 w-12 flex-shrink-0 flex items-center justify-center">
<svg class="radial-progress-svg absolute h-full w-full" viewBox="0 0 100 100">
<circle class="radial-progress-bg" cx="50" cy="50" r="40" stroke-width="8"></circle>
<circle class="radial-progress-val" cx="50" cy="50" r="40" stroke="url(##scoreGrad)" stroke-dasharray="251.2" stroke-dashoffset="#radialOffset#" stroke-width="8"></circle>
</svg>
<span class="font-label-mono text-[11px] font-bold text-primary numerical">#jobScore#</span>
</div>
</div>
<div class="flex flex-wrap gap-2 mt-2">
<cfif findNoCase( "coldfusion", stackText ) OR findNoCase( "cfml", stackText )><span class="text-[10px] font-label-mono px-2 py-0.5 bg-surface-container-highest text-outline">CFML</span></cfif>
<cfif findNoCase( "lucee", stackText )><span class="text-[10px] font-label-mono px-2 py-0.5 bg-surface-container-highest text-outline">LUCEE</span></cfif>
<cfif findNoCase( "full stack", stackText ) OR findNoCase( "fullstack", stackText )><span class="text-[10px] font-label-mono px-2 py-0.5 bg-surface-container-highest text-outline">FULL STACK</span></cfif>
<cfif findNoCase( "remote", stackText )><span class="text-[10px] font-label-mono px-2 py-0.5 bg-surface-container-highest text-outline">REMOTE</span></cfif>
</div>
</div>
</cfloop>
</cfif>
<div class="flex justify-between pt-2">
<cfif jobsData.page GT 1><a class="text-sm text-primary" href="#indexUrl#?#baseFilter#&jobs_page=#jobsData.page-1#&alerts_page=#alertsData.page#&companies_page=#companiesData.page#">Previous</a><cfelse><span></span></cfif>
<cfif jobsData.page LT jobsData.totalPages><a class="text-sm text-primary" href="#indexUrl#?#baseFilter#&jobs_page=#jobsData.page+1#&alerts_page=#alertsData.page#&companies_page=#companiesData.page#">Next</a></cfif>
</div>
</div>

<div class="lg:col-span-7 bento-card flex flex-col min-h-[480px]" id="detail-pane">
<header class="p-6 md:p-8 border-b border-outline-variant/20 flex flex-col sm:flex-row justify-between items-start gap-4 bg-surface-container-lowest/30">
<div class="min-w-0">
<span class="text-primary text-[10px] font-bold uppercase tracking-[0.2em] block mb-2">NOW VIEWING</span>
<h2 class="text-xl md:text-2xl text-on-surface font-bold" id="detail-title"><cfif arrayLen( jobsData.rows )>#encodeForHTML( jobsData.rows[1].title )#<cfelse>Select a job</cfif></h2>
<p class="text-outline text-sm mt-1" id="detail-meta"><cfif arrayLen( jobsData.rows )>#encodeForHTML( jobsData.rows[1].company_name )#<cfelse>No job selected</cfif></p>
</div>
<a id="detail-apply" class="bg-primary-container text-on-primary-container font-bold px-6 py-3 rounded-lg hover:brightness-110 transition-all flex items-center gap-2 whitespace-nowrap<cfif arrayLen( jobsData.rows ) EQ 0 OR NOT len( firstHref )> opacity-50 pointer-events-none</cfif>" href="<cfif arrayLen( jobsData.rows ) AND len( firstHref )>#encodeForHTMLAttribute( firstHref )#<cfelse>##</cfif>" target="_blank" rel="noopener noreferrer">
APPLY NOW <span class="material-symbols-outlined">bolt</span>
</a>
</header>
<div class="p-6 md:p-8 overflow-y-auto custom-scrollbar flex-1 space-y-6">
<section>
<h3 class="text-on-surface font-semibold mb-3">Job Description</h3>
<p class="text-outline text-sm leading-relaxed" id="detail-description"><cfif arrayLen( jobsData.rows ) AND len( firstDesc )>#encodeForHTML( left( firstDesc, 2000 ) )#<cfelse>No description available.</cfif></p>
</section>
<div class="p-5 bg-surface-container-low rounded-lg border border-primary/20">
<h4 class="text-primary font-bold mb-2 flex items-center gap-2 text-sm">
<span class="material-symbols-outlined text-[20px]">psychology</span> Scoring insight
</h4>
<p class="text-sm text-outline" id="detail-insight"><cfif arrayLen( jobsData.rows )>#encodeForHTML( firstInsight )#<cfelse>Run the daily pipeline to score jobs.</cfif></p>
</div>
</div>
</div>
</section>

<!--- Companies --->
<section id="companies" class="flex flex-col gap-4">
<div class="flex justify-between items-center">
<h2 class="text-lg text-on-surface font-semibold">Companies</h2>
<span class="text-xs text-outline numerical">Page #companiesData.page# / #companiesData.totalPages#</span>
</div>
<div class="bento-card overflow-x-auto">
<table class="w-full text-left border-collapse min-w-[640px]">
<thead>
<tr class="bg-surface-container-low/50 text-outline text-[11px] uppercase tracking-widest border-b border-outline-variant/20">
<th class="px-4 py-3">Name</th>
<th class="px-4 py-3">Source</th>
<th class="px-4 py-3">Score</th>
<th class="px-4 py-3">Jobs</th>
<th class="px-4 py-3">Links</th>
</tr>
</thead>
<tbody class="text-sm divide-y divide-outline-variant/10">
<cfif arrayLen( companies ) EQ 0>
<tr><td colspan="5" class="px-4 py-4 text-outline">No companies found.</td></tr>
<cfelse>
<cfloop array="#companies#" index="companyRow">
<cfset coWeb = trim( companyRow.website ) />
<cfif len( coWeb ) AND reFindNoCase( "^https?://", coWeb ) EQ 0><cfset coWeb = "https://" & coWeb /></cfif>
<cfset coCareer = trim( companyRow.careers_url ) />
<cfif len( coCareer ) AND reFindNoCase( "^https?://", coCareer ) EQ 0><cfset coCareer = "https://" & coCareer /></cfif>
<tr class="hover:bg-surface-container-high/30">
<td class="px-4 py-3 text-on-surface">#encodeForHTML( companyRow.name )#</td>
<td class="px-4 py-3 text-outline text-xs">#encodeForHTML( companyRow.careers_source )#</td>
<td class="px-4 py-3 numerical">#val( companyRow.score )#</td>
<td class="px-4 py-3 numerical">#val( companyRow.job_count )#</td>
<td class="px-4 py-3 text-xs">
<cfif len( coWeb )><a class="text-primary" href="#encodeForHTMLAttribute( coWeb )#" target="_blank" rel="noopener">site</a></cfif>
<cfif len( coCareer )> <a class="text-primary" href="#encodeForHTMLAttribute( coCareer )#" target="_blank" rel="noopener">careers</a></cfif>
</td>
</tr>
</cfloop>
</cfif>
</tbody>
</table>
</div>
<div class="flex justify-between text-sm">
<cfif companiesData.page GT 1><a class="text-primary" href="#indexUrl#?#baseFilter#&companies_page=#companiesData.page-1#&jobs_page=#jobsData.page#&alerts_page=#alertsData.page#">Previous</a><cfelse><span></span></cfif>
<cfif companiesData.page LT companiesData.totalPages><a class="text-primary" href="#indexUrl#?#baseFilter#&companies_page=#companiesData.page+1#&jobs_page=#jobsData.page#&alerts_page=#alertsData.page#">Next</a></cfif>
</div>
</section>

<!--- Alerts --->
<section id="alerts" class="flex flex-col gap-4 pb-8">
<div class="flex justify-between items-center">
<h2 class="text-lg text-on-surface font-semibold">Alerts</h2>
<span class="text-xs text-outline numerical">Page #alertsData.page# / #alertsData.totalPages#</span>
</div>
<div class="bento-card overflow-x-auto">
<table class="w-full text-left border-collapse min-w-[560px]">
<thead>
<tr class="bg-surface-container-low/50 text-outline text-[11px] uppercase tracking-widest border-b border-outline-variant/20">
<th class="px-4 py-3">Sent</th>
<th class="px-4 py-3">Channel</th>
<th class="px-4 py-3">Company</th>
<th class="px-4 py-3">Title</th>
<th class="px-4 py-3">Score</th>
</tr>
</thead>
<tbody class="text-sm divide-y divide-outline-variant/10">
<cfif arrayLen( alertsData.rows ) EQ 0>
<tr><td colspan="5" class="px-4 py-4 text-outline">No alerts yet. Run daily pipeline first.</td></tr>
<cfelse>
<cfloop array="#alertsData.rows#" index="alertRow">
<cfset payload = structKeyExists( alertRow, "payload" ) ? alertRow.payload : {} />
<tr class="hover:bg-surface-container-high/30">
<td class="px-4 py-3 text-outline text-xs numerical">#encodeForHTML( alertRow.sent_at )#</td>
<td class="px-4 py-3">#encodeForHTML( alertRow.channel )#</td>
<td class="px-4 py-3">#encodeForHTML( structKeyExists( payload, "company_name" ) ? payload.company_name : "" )#</td>
<td class="px-4 py-3">#encodeForHTML( structKeyExists( payload, "title" ) ? payload.title : "" )#</td>
<td class="px-4 py-3 numerical">#structKeyExists( payload, "score" ) ? val( payload.score ) : ""#</td>
</tr>
</cfloop>
</cfif>
</tbody>
</table>
</div>
<div class="flex justify-between text-sm">
<cfif alertsData.page GT 1><a class="text-primary" href="#indexUrl#?#baseFilter#&alerts_page=#alertsData.page-1#&jobs_page=#jobsData.page#&companies_page=#companiesData.page#">Previous</a><cfelse><span></span></cfif>
<cfif alertsData.page LT alertsData.totalPages><a class="text-primary" href="#indexUrl#?#baseFilter#&alerts_page=#alertsData.page+1#&jobs_page=#jobsData.page#&companies_page=#companiesData.page#">Next</a></cfif>
</div>
</section>

</div>
</cfoutput>
</main>

<svg width="0" height="0" class="absolute">
<defs>
<linearGradient id="scoreGrad" x1="0%" x2="100%" y1="0%" y2="100%">
<stop offset="0%" stop-color="#82cfff"></stop>
<stop offset="100%" stop-color="#00aeef"></stop>
</linearGradient>
</defs>
</svg>

<cfinclude template="includes/layoutFoot.cfm" />
