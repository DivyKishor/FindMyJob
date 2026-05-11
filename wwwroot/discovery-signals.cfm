<cfsetting showdebugoutput="false" />

<cfparam name="url.signals_sort_by" default="created_at" />
<cfparam name="url.signals_sort_dir" default="desc" />

<cfset signalsSortBy = lCase( url.signals_sort_by ) />
<cfset signalsSortDir = lCase( url.signals_sort_dir ) />
<cfset pageError = "" />
<cfset discoverySignals = [] />

<cfset appBasePath = getDirectoryFromPath( cgi.script_name ) />
<cfif left( appBasePath, 1 ) NEQ "/"><cfset appBasePath = "/" & appBasePath /></cfif>
<cfif right( appBasePath, 1 ) NEQ "/"><cfset appBasePath = appBasePath & "/" /></cfif>
<cfset indexUrl = appBasePath & "index.cfm" />
<cfset signalsPageUrl = appBasePath & "discovery-signals.cfm" />

<cftry>
	<cfset discoverySignals = application.discoveryService.listRecentSignals( 100, signalsSortBy, signalsSortDir ) />
	<cfcatch type="any">
		<cfset discoverySignals = [] />
		<cfset pageError = cfcatch.message />
	</cfcatch>
</cftry>

<cfset signalsSortPrefix = "#signalsPageUrl#?" />

<cfset sigDirWhen = "asc" /><cfif signalsSortBy EQ "created_at" AND signalsSortDir EQ "asc"><cfset sigDirWhen = "desc" /></cfif>
<cfset sigDirScore = "asc" /><cfif signalsSortBy EQ "confidence_score" AND signalsSortDir EQ "asc"><cfset sigDirScore = "desc" /></cfif>
<cfset sigDirDomain = "asc" /><cfif signalsSortBy EQ "company_domain" AND signalsSortDir EQ "asc"><cfset sigDirDomain = "desc" /></cfif>
<cfset sigDirType = "asc" /><cfif signalsSortBy EQ "signal_type" AND signalsSortDir EQ "asc"><cfset sigDirType = "desc" /></cfif>
<cfset sigDirQuery = "asc" /><cfif signalsSortBy EQ "query_text" AND signalsSortDir EQ "asc"><cfset sigDirQuery = "desc" /></cfif>

<cfoutput>
<!DOCTYPE html>
<html lang="en">
<head>
	<meta charset="utf-8" />
	<meta name="viewport" content="width=device-width, initial-scale=1" />
	<title>CF / Lucee discovery signals</title>
	<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet" />
</head>
<body class="bg-light">
	<div class="container py-4">
		<div class="d-flex justify-content-between align-items-center flex-wrap gap-2 mb-3">
			<div>
				<h1 class="h4 mb-1">CF / Lucee discovery signals (Bing RSS)</h1>
				<div class="small text-secondary">Heuristic web leads from discovery runs — not the same as confirmed job postings. Refresh with <a href="#appBasePath#tasks/runDiscovery.cfm?force=1">runDiscovery?force=1</a>.</div>
			</div>
			<div>
				<a class="btn btn-sm btn-outline-secondary" href="#indexUrl#">Back to dashboard</a>
			</div>
		</div>

		<cfif len( pageError )>
			<div class="alert alert-danger">#encodeForHTML( pageError )#</div>
		</cfif>

		<div class="card shadow-sm">
			<div class="table-responsive">
				<table class="table table-sm table-striped mb-0">
					<thead class="table-light">
						<tr>
							<th><a class="text-decoration-none" href="#signalsSortPrefix#signals_sort_by=signal_type&amp;signals_sort_dir=#sigDirType#">Type</a></th>
							<th><a class="text-decoration-none" href="#signalsSortPrefix#signals_sort_by=company_domain&amp;signals_sort_dir=#sigDirDomain#">Domain</a></th>
							<th><a class="text-decoration-none" href="#signalsSortPrefix#signals_sort_by=query_text&amp;signals_sort_dir=#sigDirQuery#">Query</a></th>
							<th class="small">Evidence</th>
							<th><a class="text-decoration-none" href="#signalsSortPrefix#signals_sort_by=confidence_score&amp;signals_sort_dir=#sigDirScore#">Score</a></th>
							<th>Link</th>
							<th><a class="text-decoration-none" href="#signalsSortPrefix#signals_sort_by=created_at&amp;signals_sort_dir=#sigDirWhen#">When</a></th>
						</tr>
					</thead>
					<tbody>
						<cfif arrayLen( discoverySignals ) EQ 0>
							<tr><td colspan="7" class="text-secondary">No signals yet.</td></tr>
						<cfelse>
							<cfloop array="#discoverySignals#" index="sig">
								<tr>
									<td>#encodeForHTML( sig.signal_type )#</td>
									<td>#encodeForHTML( sig.company_domain )#</td>
									<td class="small">#encodeForHTML( left( sig.query_text, 48 ) )#</td>
									<td class="small">#encodeForHTML( left( sig.evidence_text, 120 ) )#</td>
									<td>#val( sig.confidence_score )#</td>
									<td>
										<cfif len( trim( sig.target_url ) )>
											<cfset sigHref = trim( sig.target_url ) />
											<cfif reFindNoCase( "^https?://", sigHref ) EQ 0 AND reFindNoCase( "^//", sigHref ) EQ 0><cfset sigHref = "https://" & sigHref /></cfif>
											<cfif left( sigHref, 2 ) EQ "//"><cfset sigHref = "https:" & sigHref /></cfif>
											<a href="#encodeForHTMLAttribute( sigHref )#" target="_blank" rel="noopener noreferrer">open</a>
										<cfelse>&mdash;</cfif>
									</td>
									<td class="small">#encodeForHTML( sig.created_at )#</td>
								</tr>
							</cfloop>
						</cfif>
					</tbody>
				</table>
			</div>
		</div>
	</div>
</body>
</html>
</cfoutput>
