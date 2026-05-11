<cfsetting showdebugoutput="false" />

<cfparam name="url.keyword" default="" />
<cfparam name="url.location" default="" />
<cfparam name="url.min_score" default="0" />
<cfparam name="url.company_id" default="0" />
<cfparam name="url.jobs_page" default="1" />
<cfparam name="url.jobs_page_size" default="25" />
<cfparam name="url.jobs_sort_by" default="fetched_at" />
<cfparam name="url.jobs_sort_dir" default="desc" />
<cfparam name="url.alerts_page" default="1" />
<cfparam name="url.alerts_page_size" default="25" />
<cfparam name="url.alerts_sort_by" default="sent_at" />
<cfparam name="url.alerts_sort_dir" default="desc" />
<cfparam name="url.companies_sort_by" default="score" />
<cfparam name="url.companies_sort_dir" default="desc" />

<cfset keyword = trim( url.keyword ) />
<cfset locationKeyword = trim( url.location ) />
<cfset minScore = val( url.min_score ) />
<cfset companyId = val( url.company_id ) />
<cfset jobsPage = val( url.jobs_page ) />
<cfset jobsPageSize = val( url.jobs_page_size ) />
<cfset jobsSortBy = lCase( url.jobs_sort_by ) />
<cfset jobsSortDir = lCase( url.jobs_sort_dir ) />
<cfset alertsPage = val( url.alerts_page ) />
<cfset alertsPageSize = val( url.alerts_page_size ) />
<cfset alertsSortBy = lCase( url.alerts_sort_by ) />
<cfset alertsSortDir = lCase( url.alerts_sort_dir ) />
<cfset companiesSortBy = lCase( url.companies_sort_by ) />
<cfset companiesSortDir = lCase( url.companies_sort_dir ) />

<cfif jobsPage LT 1><cfset jobsPage = 1 /></cfif>
<cfif alertsPage LT 1><cfset alertsPage = 1 /></cfif>
<cfif jobsPageSize LT 1><cfset jobsPageSize = 25 /></cfif>
<cfif alertsPageSize LT 1><cfset alertsPageSize = 25 /></cfif>

<cfset runInfo = {} />
<cfset pageError = "" />
<!--- Web path for same-origin links (tasks, APIs). Leading slash when app lives at container root. --->
<cfset appBasePath = getDirectoryFromPath( cgi.script_name ) />
<cfif left( appBasePath, 1 ) NEQ "/"><cfset appBasePath = "/" & appBasePath /></cfif>
<cfif right( appBasePath, 1 ) NEQ "/"><cfset appBasePath = appBasePath & "/" /></cfif>
<cfset indexUrl = appBasePath & "index.cfm" />

<cftry>
	<cfset companies = application.companyService.list( companiesSortBy, companiesSortDir ) />
	<cfset jobsData = application.jobService.listPaged( companyId, keyword, minScore, jobsPage, jobsPageSize, jobsSortBy, jobsSortDir, locationKeyword ) />
	<cfset alertsData = application.alertService.listAlertsPaged( alertsPage, alertsPageSize, alertsSortBy, alertsSortDir ) />
	<cfset runInfo = application.runStatusService.getLatestRun() />
	<cfset totalCompanies = arrayLen( companies ) />
	<cfset totalJobs = jobsData.totalRows />
	<cfset totalAlerts = alertsData.totalRows />
	<cfcatch type="any">
		<cfset companies = [] />
		<cfset jobsData = { rows: [], totalRows: 0, page: 1, pageSize: 25, totalPages: 1, sortBy: "fetched_at", sortDir: "desc" } />
		<cfset alertsData = { rows: [], totalRows: 0, page: 1, pageSize: 25, totalPages: 1, sortBy: "sent_at", sortDir: "desc" } />
		<cfset totalCompanies = 0 />
		<cfset totalJobs = 0 />
		<cfset totalAlerts = 0 />
		<cfset pageError = cfcatch.message />
	</cfcatch>
</cftry>

	<!--- Core filter + each sort dimension once. Sort header URLs omit their own pair so the clicked values are the only copy (duplicate query keys broke sort on Lucee). --->
<cfset filterCoreNoLocation = "keyword=#urlEncodedFormat( keyword )#&min_score=#minScore#&company_id=#companyId#&jobs_page_size=#jobsData.pageSize#&alerts_page_size=#alertsData.pageSize#" />
<cfset filterLocation = "location=#urlEncodedFormat( locationKeyword )#" />
<cfset filterCore = "#filterCoreNoLocation#&#filterLocation#" />
<cfset filterJobsSort = "jobs_sort_by=#urlEncodedFormat( jobsData.sortBy )#&jobs_sort_dir=#urlEncodedFormat( jobsData.sortDir )#" />
<cfset filterAlertsSort = "alerts_sort_by=#urlEncodedFormat( alertsData.sortBy )#&alerts_sort_dir=#urlEncodedFormat( alertsData.sortDir )#" />
<cfset filterCompaniesSort = "companies_sort_by=#urlEncodedFormat( companiesSortBy )#&companies_sort_dir=#urlEncodedFormat( companiesSortDir )#" />
<cfset baseFilter = "#filterCore#&#filterJobsSort#&#filterAlertsSort#&#filterCompaniesSort#" />
<cfset baseFilterNoLocation = "#filterCoreNoLocation#&#filterJobsSort#&#filterAlertsSort#&#filterCompaniesSort#" />
<cfset filterCoreNoKeyword = "min_score=#minScore#&company_id=#companyId#&jobs_page_size=#jobsData.pageSize#&alerts_page_size=#alertsData.pageSize#" />
<cfset baseFilterNoKeyword = "#filterCoreNoKeyword#&#filterLocation#&#filterJobsSort#&#filterAlertsSort#&#filterCompaniesSort#" />
<cfset jobsSortPrefix = "#indexUrl#?#filterCore#&#filterCompaniesSort#&#filterAlertsSort#&jobs_page=1&alerts_page=#val( alertsData.page )#" />
<cfset alertsSortPrefix = "#indexUrl#?#filterCore#&#filterJobsSort#&#filterCompaniesSort#&jobs_page=#val( jobsData.page )#&alerts_page=1" />
<cfset companiesSortPrefix = "#indexUrl#?#filterCore#&#filterJobsSort#&#filterAlertsSort#&jobs_page=#val( jobsData.page )#&alerts_page=#val( alertsData.page )#" />

<cfset jobsDirCompany = "asc" /><cfif jobsData.sortBy EQ "company_name" AND jobsData.sortDir EQ "asc"><cfset jobsDirCompany = "desc" /></cfif>
<cfset jobsDirTitle = "asc" /><cfif jobsData.sortBy EQ "title" AND jobsData.sortDir EQ "asc"><cfset jobsDirTitle = "desc" /></cfif>
<cfset jobsDirLocation = "asc" /><cfif jobsData.sortBy EQ "location" AND jobsData.sortDir EQ "asc"><cfset jobsDirLocation = "desc" /></cfif>
<cfset jobsDirScore = "asc" /><cfif jobsData.sortBy EQ "score" AND jobsData.sortDir EQ "asc"><cfset jobsDirScore = "desc" /></cfif>
<cfset jobsDirFetched = "asc" /><cfif jobsData.sortBy EQ "fetched_at" AND jobsData.sortDir EQ "asc"><cfset jobsDirFetched = "desc" /></cfif>

<cfset alertsDirSent = "asc" /><cfif alertsData.sortBy EQ "sent_at" AND alertsData.sortDir EQ "asc"><cfset alertsDirSent = "desc" /></cfif>
<cfset alertsDirChannel = "asc" /><cfif alertsData.sortBy EQ "channel" AND alertsData.sortDir EQ "asc"><cfset alertsDirChannel = "desc" /></cfif>
<cfset alertsDirCompany = "asc" /><cfif alertsData.sortBy EQ "company_name" AND alertsData.sortDir EQ "asc"><cfset alertsDirCompany = "desc" /></cfif>
<cfset alertsDirTitle = "asc" /><cfif alertsData.sortBy EQ "title" AND alertsData.sortDir EQ "asc"><cfset alertsDirTitle = "desc" /></cfif>
<cfset alertsDirScore = "asc" /><cfif alertsData.sortBy EQ "score" AND alertsData.sortDir EQ "asc"><cfset alertsDirScore = "desc" /></cfif>

<cfset coDirName = "asc" /><cfif companiesSortBy EQ "name" AND companiesSortDir EQ "asc"><cfset coDirName = "desc" /></cfif>
<cfset coDirSource = "asc" /><cfif companiesSortBy EQ "careers_source" AND companiesSortDir EQ "asc"><cfset coDirSource = "desc" /></cfif>
<cfset coDirScore = "asc" /><cfif companiesSortBy EQ "score" AND companiesSortDir EQ "asc"><cfset coDirScore = "desc" /></cfif>
<cfset coDirJobs = "asc" /><cfif companiesSortBy EQ "job_count" AND companiesSortDir EQ "asc"><cfset coDirJobs = "desc" /></cfif>
<cfset coDirCreated = "asc" /><cfif companiesSortBy EQ "created_at" AND companiesSortDir EQ "asc"><cfset coDirCreated = "desc" /></cfif>
<cfset coSortIcon = "v" /><cfif companiesSortDir EQ "asc"><cfset coSortIcon = "^" /></cfif>

<cfoutput>
<!DOCTYPE html>
<html lang="en">
<head>
	<meta charset="utf-8" />
	<meta name="viewport" content="width=device-width, initial-scale=1" />
	<title>ColdFusion Job Finder - India &amp; Remote</title>
	<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet" />
</head>
<body class="bg-light">
	<div class="container py-4">
		<div class="d-flex justify-content-between align-items-center mb-3">
			<div>
				<h1 class="h3 mb-1">ColdFusion Job Finder <span class="badge bg-success">India &amp; Remote</span></h1>
				<div class="text-secondary">ColdFusion / CFML / Lucee <strong>&amp; Full-Stack (CF backend)</strong> jobs from LinkedIn, Cutshort, GetCFMLJobs, Adzuna India, Remotive, ArbeitNow, Greenhouse ATS, and career page scans. <strong>Score 80+</strong> = India-based or truly remote. Score 50 = CF match but US/location-restricted. <a href="#appBasePath#discovery-signals.cfm" target="_blank" rel="noopener">Discovery signals</a></div>
			</div>
			<div class="text-end">
				<a class="btn btn-sm btn-outline-primary me-1" href="#appBasePath#tasks/seed.cfm">Seed</a>
				<a class="btn btn-sm btn-outline-secondary me-1" href="#appBasePath#tasks/runDiscovery.cfm">Run Discovery</a>
				<a class="btn btn-sm btn-outline-secondary me-1" href="#appBasePath#tasks/pruneIrrelevantJobs.cfm">Prune non-CF jobs</a>
				<a class="btn btn-sm btn-primary me-1" href="#appBasePath#tasks/runDailyScrape.cfm">Run Daily Pipeline</a>
			</div>
		</div>

		<cfif len( pageError )>
			<div class="alert alert-danger">#encodeForHTML( pageError )#</div>
		</cfif>

		<div class="alert alert-info small mb-3">
			<span class="fw-semibold">Scoring (v3):</span> Jobs are scored 0-100. <strong>100</strong> = CF keyword + India location or global-remote confirmed. <strong>80</strong> = CF + likely remote-friendly. <strong>50</strong> = CF match but location unclear. <strong>20</strong> = CF match but US work auth / clearance required. <strong>Full-stack</strong> postings with ColdFusion/CFML as backend are also captured. Use <strong>Score 70+</strong> filter to see only India-eligible postings. Sources: LinkedIn (India + remote), Cutshort, GetCFMLJobs, Adzuna India, Remotive, ArbeitNow, Greenhouse, career page scans.
		</div>

		<div class="card shadow-sm mb-3">
			<div class="card-body py-2">
				<div class="d-flex justify-content-between align-items-start flex-wrap">
					<div>
						<div class="small text-secondary">Last Pipeline Run</div>
						<cfif structIsEmpty( runInfo )>
							<div class="text-muted">No runs recorded yet.</div>
						<cfelse>
							<div class="fw-semibold">#encodeForHTML( runInfo.status )# at #encodeForHTML( runInfo.run_at )#</div>
							<div class="small text-secondary">
								Upserted: #val( runInfo.jobs_upserted )# |
								Scored: #val( runInfo.jobs_scored )# |
								Alerts: #val( runInfo.alerts_created )# |
								Errors: #val( runInfo.error_count )#
							</div>
							<cfif structKeyExists( runInfo, "errors" ) AND arrayLen( runInfo.errors ) GT 0>
								<div class="small text-danger mt-1">#encodeForHTML( runInfo.errors[ 1 ] )#</div>
							</cfif>
						</cfif>
					</div>
					<div class="small">
						<a href="#appBasePath#api/companies.cfm">companies API</a> |
						<a href="#appBasePath#api/jobs.cfm">jobs API</a> |
						<a href="#appBasePath#api/alerts.cfm">alerts API</a> |
						<a href="#appBasePath#discovery-signals.cfm" target="_blank" rel="noopener">discovery signals</a>
					</div>
				</div>
			</div>
		</div>

		<div class="row g-3 mb-4">
			<div class="col-md-4"><div class="card shadow-sm"><div class="card-body"><div class="text-secondary small">Companies</div><div class="fs-4 fw-semibold">#totalCompanies#</div></div></div></div>
			<div class="col-md-4"><div class="card shadow-sm"><div class="card-body"><div class="text-secondary small">Jobs (CF-related filter)</div><div class="fs-4 fw-semibold">#totalJobs#</div></div></div></div>
			<div class="col-md-4"><div class="card shadow-sm"><div class="card-body"><div class="text-secondary small">Alerts</div><div class="fs-4 fw-semibold">#totalAlerts#</div></div></div></div>
		</div>

		<div class="card shadow-sm mb-4">
			<div class="card-header">Filters</div>
			<div class="card-body">
				<form method="get" action="#indexUrl#" class="row g-3">
					<input type="hidden" name="jobs_sort_by" value="#encodeForHTMLAttribute( jobsData.sortBy )#" />
					<input type="hidden" name="jobs_sort_dir" value="#encodeForHTMLAttribute( jobsData.sortDir )#" />
					<input type="hidden" name="alerts_sort_by" value="#encodeForHTMLAttribute( alertsData.sortBy )#" />
					<input type="hidden" name="alerts_sort_dir" value="#encodeForHTMLAttribute( alertsData.sortDir )#" />
					<input type="hidden" name="companies_sort_by" value="#encodeForHTMLAttribute( companiesSortBy )#" />
					<input type="hidden" name="companies_sort_dir" value="#encodeForHTMLAttribute( companiesSortDir )#" />
					<div class="col-md-3">
						<label class="form-label">Keyword</label>
						<input class="form-control" type="text" name="keyword" value="#encodeForHTMLAttribute( keyword )#" />
					</div>
					<div class="col-md-2">
						<label class="form-label">Location</label>
						<input class="form-control" type="text" name="location" value="#encodeForHTMLAttribute( locationKeyword )#" placeholder="India / Bengaluru" />
					</div>
					<div class="col-md-2">
						<label class="form-label">Min job score</label>
						<input class="form-control" type="number" name="min_score" value="#minScore#" min="0" max="100" />
						<div class="form-text">Only ColdFusion, CFML, and Lucee mentions are stored at ingest. Use 100 to require a scored keyword hit (after Run Daily Pipeline).</div>
					</div>
					<div class="col-md-2">
						<label class="form-label">Company</label>
						<select class="form-select" name="company_id">
							<option value="0">All Companies</option>
							<cfloop array="#companies#" index="companyRow">
								<option value="#companyRow.id#"<cfif companyId EQ val( companyRow.id )> selected</cfif>>#encodeForHTML( companyRow.name )#</option>
							</cfloop>
						</select>
					</div>
					<div class="col-md-1"><label class="form-label">Jobs/page</label><input class="form-control" type="number" name="jobs_page_size" value="#jobsData.pageSize#" min="5" max="200" /></div>
					<div class="col-md-1"><label class="form-label">Alerts/page</label><input class="form-control" type="number" name="alerts_page_size" value="#alertsData.pageSize#" min="5" max="200" /></div>
					<div class="col-md-1 d-flex align-items-end"><button class="btn btn-primary w-100" type="submit">Apply</button></div>
				</form>
				<div class="small mt-2">
					<strong>Quick filters:</strong>
					<a href="#indexUrl#?#baseFilterNoLocation#&min_score=70&location=&jobs_page=1" class="btn btn-sm btn-success">India-eligible (score 70+)</a>
					<a href="#indexUrl#?#baseFilterNoLocation#&min_score=80&location=&jobs_page=1" class="btn btn-sm btn-outline-success">Best matches (80+)</a> |
					<a href="#indexUrl#?#baseFilterNoLocation#&location=#urlEncodedFormat( "India" )#&jobs_page=1">India</a> |
					<a href="#indexUrl#?#baseFilterNoLocation#&location=#urlEncodedFormat( "Bengaluru" )#&jobs_page=1">Bengaluru</a> |
					<a href="#indexUrl#?#baseFilterNoLocation#&location=#urlEncodedFormat( "Hyderabad" )#&jobs_page=1">Hyderabad</a> |
					<a href="#indexUrl#?#baseFilterNoLocation#&location=#urlEncodedFormat( "remote" )#&jobs_page=1">Remote</a> |
					<a href="#indexUrl#?#baseFilterNoKeyword#&keyword=#urlEncodedFormat( "full stack" )#&jobs_page=1">Full Stack</a> |
					<a href="#indexUrl#?#baseFilterNoLocation#&location=&min_score=0&jobs_page=1">Clear all</a>
				</div>
			</div>
		</div>

		<div class="card shadow-sm mb-4">
			<div class="card-header d-flex justify-content-between">
				<span>Jobs</span>
				<span class="small text-secondary">Page #jobsData.page# / #jobsData.totalPages#</span>
			</div>
			<div class="table-responsive">
				<table class="table table-sm table-hover mb-0">
					<thead class="table-light">
						<tr>
							<th><a class="text-decoration-none" href="#jobsSortPrefix#&jobs_sort_by=company_name&jobs_sort_dir=#jobsDirCompany#">Company</a></th>
							<th><a class="text-decoration-none" href="#jobsSortPrefix#&jobs_sort_by=title&jobs_sort_dir=#jobsDirTitle#">Title</a></th>
							<th>Description preview</th>
							<th><a class="text-decoration-none" href="#jobsSortPrefix#&jobs_sort_by=location&jobs_sort_dir=#jobsDirLocation#">Location</a></th>
							<th><a class="text-decoration-none" href="#jobsSortPrefix#&jobs_sort_by=score&jobs_sort_dir=#jobsDirScore#">Score</a></th>
							<th><a class="text-decoration-none" href="#jobsSortPrefix#&jobs_sort_by=fetched_at&jobs_sort_dir=#jobsDirFetched#">Fetched</a></th>
							<th>Source / link</th>
						</tr>
					</thead>
					<tbody>
						<cfif arrayLen( jobsData.rows ) EQ 0>
							<tr><td colspan="7" class="text-secondary">No jobs match current filters.</td></tr>
						<cfelse>
							<cfloop array="#jobsData.rows#" index="jobRow">
								<cfset descPreview = "" />
								<cfif structKeyExists( jobRow, "description" ) AND len( trim( jobRow.description ) )>
									<cfset descPreview = reReplace( jobRow.description, "(?si)<script[^>]*>.*?</script>", " ", "all" ) />
									<cfset descPreview = reReplace( descPreview, "(?si)<style[^>]*>.*?</style>", " ", "all" ) />
									<cfset descPreview = reReplace( descPreview, "(?si)<noscript[^>]*>.*?</noscript>", " ", "all" ) />
									<cfset descPreview = reReplace( descPreview, "(?si)<head[^>]*>.*?</head>", " ", "all" ) />
									<cfset descPreview = trim( reReplace( descPreview, "<[^>]+>", " ", "all" ) ) />
									<cfset descPreview = trim( reReplace( descPreview, "\s+", " ", "all" ) ) />
									<cfset descPreview = left( descPreview, 220 ) />
								</cfif>
								<cfset jobHref = "" />
								<cfif structKeyExists( jobRow, "link" )><cfset jobHref = trim( jobRow.link ) /></cfif>
								<cfif len( jobHref )>
									<cfif reFindNoCase( "^https?://", jobHref ) EQ 0 AND reFindNoCase( "^//", jobHref ) EQ 0><cfset jobHref = "https://" & jobHref /></cfif>
									<cfif left( jobHref, 2 ) EQ "//"><cfset jobHref = "https:" & jobHref /></cfif>
								</cfif>
								<tr>
									<td>#encodeForHTML( jobRow.company_name )#</td>
									<td>#encodeForHTML( jobRow.title )#</td>
									<td class="small text-secondary"><cfif len( descPreview )>#encodeForHTML( descPreview )#<cfelse>&mdash;</cfif></td>
									<td>#encodeForHTML( jobRow.location )#</td>
									<td>#val( jobRow.score )#</td>
									<td>#encodeForHTML( jobRow.fetched_at )#</td>
									<td class="small">
										<cfif structKeyExists( jobRow, "raw_source" ) AND len( trim( jobRow.raw_source ) )><span class="text-secondary">#encodeForHTML( jobRow.raw_source )#</span><br /></cfif>
										<cfif len( jobHref )>
											<a href="#encodeForHTMLAttribute( jobHref )#" target="_blank" rel="noopener noreferrer">open posting</a>
										<cfelse>&mdash;</cfif>
									</td>
								</tr>
							</cfloop>
						</cfif>
					</tbody>
				</table>
			</div>
			<div class="card-footer d-flex justify-content-between">
				<cfif jobsData.page GT 1>
					<a class="btn btn-sm btn-outline-secondary" href="#indexUrl#?#baseFilter#&jobs_page=#jobsData.page-1#&alerts_page=#alertsData.page#">Previous</a>
				<cfelse><span></span></cfif>
				<cfif jobsData.page LT jobsData.totalPages>
					<a class="btn btn-sm btn-outline-secondary" href="#indexUrl#?#baseFilter#&jobs_page=#jobsData.page+1#&alerts_page=#alertsData.page#">Next</a>
				</cfif>
			</div>
		</div>

		<div class="card shadow-sm mb-4">
			<div class="card-header">Companies</div>
			<div class="table-responsive">
				<table class="table table-sm table-striped mb-0">
					<thead class="table-light">
						<tr>
							<th><a class="text-decoration-none" href="#companiesSortPrefix#&companies_sort_by=name&companies_sort_dir=#coDirName#">Name<cfif companiesSortBy EQ "name"><span class="small text-secondary"> #coSortIcon#</span></cfif></a></th>
							<th><a class="text-decoration-none" href="#companiesSortPrefix#&companies_sort_by=careers_source&companies_sort_dir=#coDirSource#">Source<cfif companiesSortBy EQ "careers_source"><span class="small text-secondary"> #coSortIcon#</span></cfif></a></th>
							<th><a class="text-decoration-none" href="#companiesSortPrefix#&companies_sort_by=score&companies_sort_dir=#coDirScore#">Score<cfif companiesSortBy EQ "score"><span class="small text-secondary"> #coSortIcon#</span></cfif></a></th>
							<th><a class="text-decoration-none" href="#companiesSortPrefix#&companies_sort_by=job_count&companies_sort_dir=#coDirJobs#">Jobs<cfif companiesSortBy EQ "job_count"><span class="small text-secondary"> #coSortIcon#</span></cfif></a></th>
							<th>Website</th>
							<th>Careers</th>
							<th><a class="text-decoration-none" href="#companiesSortPrefix#&companies_sort_by=created_at&companies_sort_dir=#coDirCreated#">Added<cfif companiesSortBy EQ "created_at"><span class="small text-secondary"> #coSortIcon#</span></cfif></a></th>
						</tr>
					</thead>
					<tbody>
						<cfif arrayLen( companies ) EQ 0>
							<tr><td colspan="7" class="text-secondary">No companies found.</td></tr>
						<cfelse>
							<cfloop array="#companies#" index="companyRow">
								<tr>
									<td>#encodeForHTML( companyRow.name )#</td>
									<td>#encodeForHTML( companyRow.careers_source )#</td>
									<td>#val( companyRow.score )#</td>
									<td>#val( companyRow.job_count )#</td>
									<td>
										<cfif len( trim( companyRow.website ) )>
											<cfset coWeb = trim( companyRow.website ) />
											<cfif reFindNoCase( "^https?://", coWeb ) EQ 0 AND reFindNoCase( "^//", coWeb ) EQ 0><cfset coWeb = "https://" & coWeb /></cfif>
											<cfif left( coWeb, 2 ) EQ "//"><cfset coWeb = "https:" & coWeb /></cfif>
											<a href="#encodeForHTMLAttribute( coWeb )#" target="_blank" rel="noopener noreferrer">site</a>
										<cfelse>&mdash;</cfif>
									</td>
									<td>
										<cfif len( trim( companyRow.careers_url ) )>
											<cfset coCareer = trim( companyRow.careers_url ) />
											<cfif reFindNoCase( "^https?://", coCareer ) EQ 0 AND reFindNoCase( "^//", coCareer ) EQ 0><cfset coCareer = "https://" & coCareer /></cfif>
											<cfif left( coCareer, 2 ) EQ "//"><cfset coCareer = "https:" & coCareer /></cfif>
											<a href="#encodeForHTMLAttribute( coCareer )#" target="_blank" rel="noopener noreferrer">careers</a>
										<cfelse>&mdash;</cfif>
									</td>
									<td class="small">#encodeForHTML( companyRow.created_at )#</td>
								</tr>
							</cfloop>
						</cfif>
					</tbody>
				</table>
			</div>
		</div>

		<div class="card shadow-sm mb-4">
			<div class="card-header d-flex justify-content-between">
				<span>Alerts</span>
				<span class="small text-secondary">Page #alertsData.page# / #alertsData.totalPages#</span>
			</div>
			<div class="table-responsive">
				<table class="table table-sm table-striped mb-0">
					<thead class="table-light">
						<tr>
							<th><a class="text-decoration-none" href="#alertsSortPrefix#&alerts_sort_by=sent_at&alerts_sort_dir=#alertsDirSent#">Sent At</a></th>
							<th><a class="text-decoration-none" href="#alertsSortPrefix#&alerts_sort_by=channel&alerts_sort_dir=#alertsDirChannel#">Channel</a></th>
							<th><a class="text-decoration-none" href="#alertsSortPrefix#&alerts_sort_by=company_name&alerts_sort_dir=#alertsDirCompany#">Company</a></th>
							<th><a class="text-decoration-none" href="#alertsSortPrefix#&alerts_sort_by=title&alerts_sort_dir=#alertsDirTitle#">Title</a></th>
							<th><a class="text-decoration-none" href="#alertsSortPrefix#&alerts_sort_by=score&alerts_sort_dir=#alertsDirScore#">Score</a></th>
						</tr>
					</thead>
					<tbody>
						<cfif arrayLen( alertsData.rows ) EQ 0>
							<tr><td colspan="5" class="text-secondary">No alerts yet. Run daily pipeline first.</td></tr>
						<cfelse>
							<cfloop array="#alertsData.rows#" index="alertRow">
								<cfif structKeyExists( alertRow, "payload" )>
									<cfset payload = alertRow.payload />
								<cfelse>
									<cfset payload = {} />
								</cfif>
								<tr>
									<td>#encodeForHTML( alertRow.sent_at )#</td>
									<td>#encodeForHTML( alertRow.channel )#</td>
									<td><cfif structKeyExists( payload, "company_name" )>#encodeForHTML( payload.company_name )#</cfif></td>
									<td><cfif structKeyExists( payload, "title" )>#encodeForHTML( payload.title )#</cfif></td>
									<td><cfif structKeyExists( payload, "score" )>#val( payload.score )#</cfif></td>
								</tr>
							</cfloop>
						</cfif>
					</tbody>
				</table>
			</div>
			<div class="card-footer d-flex justify-content-between">
				<cfif alertsData.page GT 1>
					<a class="btn btn-sm btn-outline-secondary" href="#indexUrl#?#baseFilter#&alerts_page=#alertsData.page-1#&jobs_page=#jobsData.page#">Previous</a>
				<cfelse><span></span></cfif>
				<cfif alertsData.page LT alertsData.totalPages>
					<a class="btn btn-sm btn-outline-secondary" href="#indexUrl#?#baseFilter#&alerts_page=#alertsData.page+1#&jobs_page=#jobsData.page#">Next</a>
				</cfif>
			</div>
		</div>
	</div>
</body>
</html>
</cfoutput>
