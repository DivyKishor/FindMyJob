<cfsetting showdebugoutput="false" />

<cfparam name="url.signals_sort_by" default="created_at" />
<cfparam name="url.signals_sort_dir" default="desc" />

<cfset signalsSortBy = lCase( url.signals_sort_by ) />
<cfset signalsSortDir = lCase( url.signals_sort_dir ) />
<cfset pageError = "" />
<cfset discoverySignals = [] />

<cfinclude template="includes/pathUtil.cfm" />
<cfset signalsPageUrl = appBasePath & "discovery-signals.cfm" />

<cftry>
	<cfset discoverySignals = application.discoveryService.listRecentSignals( 100, signalsSortBy, signalsSortDir ) />
	<cfcatch type="any">
		<cfset discoverySignals = [] />
		<cfset pageError = cfcatch.message />
	</cfcatch>
</cftry>

<cfset signalsSortPrefix = signalsPageUrl & "?" />
<cfset sigDirWhen = signalsSortBy EQ "created_at" AND signalsSortDir EQ "asc" ? "desc" : "asc" />
<cfset sigDirScore = signalsSortBy EQ "confidence_score" AND signalsSortDir EQ "asc" ? "desc" : "asc" />
<cfset sigDirDomain = signalsSortBy EQ "company_domain" AND signalsSortDir EQ "asc" ? "desc" : "asc" />
<cfset sigDirType = signalsSortBy EQ "signal_type" AND signalsSortDir EQ "asc" ? "desc" : "asc" />
<cfset sigDirQuery = signalsSortBy EQ "query_text" AND signalsSortDir EQ "asc" ? "desc" : "asc" />

<cfset activeSection = "network" />
<cfset pageTitle = "CF/OBSERVER | Discovery Network" />
<cfset searchKeyword = "" />
<cfset locationKeyword = "" />
<cfset minScore = 0 />
<cfset rawSourceFilter = "" />
<cfset companyId = 0 />
<cfset jobsAnchorQuery = "jobs_page=1" & "##jobs" />
<cfset healthAnchorQuery = "jobs_page=1" & "##pipeline" />
<cfset companiesAnchorQuery = "companies_page=1" & "##companies" />

<cfinclude template="includes/layoutHead.cfm" />
<cfinclude template="includes/layoutSidebar.cfm" />

<main class="flex-1 flex flex-col min-w-0 bg-background relative overflow-hidden">
<cfinclude template="includes/layoutTopbar.cfm" />

<cfoutput>
<div class="flex-1 overflow-y-auto custom-scrollbar px-4 md:px-margin-desktop py-6 md:py-8 flex flex-col gap-6">

<section class="bento-card p-6">
<h1 class="text-xl text-on-surface font-bold mb-2">Discovery Network</h1>
<p class="text-outline text-sm max-w-3xl">Heuristic CF/Lucee web leads from Bing RSS discovery — <strong class="text-on-surface">not</strong> the same as confirmed job postings in the Job Feed. Refresh with <a class="text-primary" href="#appBasePath#tasks/runDiscovery.cfm?force=1">Run Discovery (force)</a> or the daily pipeline.</p>
</section>

<cfif len( pageError )>
<div class="bento-card p-4 border-l-4 border-l-red-400 text-red-300 text-sm">#encodeForHTML( pageError )#</div>
</cfif>

<div class="bento-card overflow-x-auto">
<table class="w-full text-left border-collapse min-w-[800px]">
<thead>
<tr class="bg-surface-container-low/50 text-outline text-[11px] uppercase tracking-widest border-b border-outline-variant/20">
<th class="px-4 py-3"><a class="text-primary hover:underline" href="#signalsSortPrefix#signals_sort_by=signal_type&amp;signals_sort_dir=#sigDirType#">Type</a></th>
<th class="px-4 py-3"><a class="text-primary hover:underline" href="#signalsSortPrefix#signals_sort_by=company_domain&amp;signals_sort_dir=#sigDirDomain#">Domain</a></th>
<th class="px-4 py-3"><a class="text-primary hover:underline" href="#signalsSortPrefix#signals_sort_by=query_text&amp;signals_sort_dir=#sigDirQuery#">Query</a></th>
<th class="px-4 py-3">Evidence</th>
<th class="px-4 py-3"><a class="text-primary hover:underline" href="#signalsSortPrefix#signals_sort_by=confidence_score&amp;signals_sort_dir=#sigDirScore#">Score</a></th>
<th class="px-4 py-3">Link</th>
<th class="px-4 py-3"><a class="text-primary hover:underline" href="#signalsSortPrefix#signals_sort_by=created_at&amp;signals_sort_dir=#sigDirWhen#">When</a></th>
</tr>
</thead>
<tbody class="text-sm divide-y divide-outline-variant/10">
<cfif arrayLen( discoverySignals ) EQ 0>
<tr><td colspan="7" class="px-4 py-6 text-outline">No signals yet. Run discovery from Operator tools.</td></tr>
<cfelse>
<cfloop array="#discoverySignals#" index="sig">
<cfset sigHref = len( trim( sig.target_url ) ) ? trim( sig.target_url ) : "" />
<cfif len( sigHref ) AND reFindNoCase( "^https?://", sigHref ) EQ 0><cfset sigHref = "https://" & sigHref /></cfif>
<tr class="hover:bg-surface-container-high/30">
<td class="px-4 py-3 text-on-surface">#encodeForHTML( sig.signal_type )#</td>
<td class="px-4 py-3">#encodeForHTML( sig.company_domain )#</td>
<td class="px-4 py-3 text-xs text-outline">#encodeForHTML( left( sig.query_text, 48 ) )#</td>
<td class="px-4 py-3 text-xs text-outline">#encodeForHTML( left( sig.evidence_text, 120 ) )#</td>
<td class="px-4 py-3 numerical">#val( sig.confidence_score )#</td>
<td class="px-4 py-3">
<cfif len( sigHref )><a class="text-primary text-xs font-semibold" href="#encodeForHTMLAttribute( sigHref )#" target="_blank" rel="noopener">View source</a><cfelse>&mdash;</cfif>
</td>
<td class="px-4 py-3 text-xs text-outline numerical">#encodeForHTML( sig.created_at )#</td>
</tr>
</cfloop>
</cfif>
</tbody>
</table>
</div>

</div>
</cfoutput>
</main>

<cfinclude template="includes/layoutFoot.cfm" />
