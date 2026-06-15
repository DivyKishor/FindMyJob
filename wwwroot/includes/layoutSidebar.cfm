<cfparam name="activeSection" default="overview" />
<cfset navBase = "flex items-center gap-3 px-3 py-2 rounded transition-transform active:scale-95" />
<cfset navIdle = navBase & " text-outline hover:text-on-surface hover:bg-surface-container-high" />
<cfset navActive = navBase & " nav-link-active" />
<aside class="hidden md:flex flex-col h-full w-64 sticky left-0 glass-header border-r border-outline-variant/20 py-6 px-4 gap-4 z-50">
<div class="flex flex-col gap-1 mb-6 px-2">
<span class="font-label-mono text-on-surface-variant text-sm">CF Intelligence</span>
<span class="text-[10px] uppercase tracking-widest text-outline numerical">India &amp; Remote</span>
</div>
<nav class="flex flex-col gap-1 flex-1">
<cfoutput>
<a class="#activeSection EQ 'overview' ? navActive : navIdle#" href="#indexUrl#">
<span class="material-symbols-outlined text-[20px]">dashboard</span>
<span class="font-body-md text-sm">Overview</span>
</a>
<a class="#activeSection EQ 'jobs' ? navActive : navIdle#" href="#indexUrl#?#jobsAnchorQuery#">
<span class="material-symbols-outlined text-[20px]">list_alt</span>
<span class="font-body-md text-sm">Job Feed</span>
</a>
<a class="#activeSection EQ 'health' ? navActive : navIdle#" href="#indexUrl#?#healthAnchorQuery#">
<span class="material-symbols-outlined text-[20px]">analytics</span>
<span class="font-body-md text-sm">Health</span>
</a>
<a class="#activeSection EQ 'network' ? navActive : navIdle#" href="#discoveryUrl#">
<span class="material-symbols-outlined text-[20px]">hub</span>
<span class="font-body-md text-sm">Network</span>
</a>
<a class="#activeSection EQ 'companies' ? navActive : navIdle#" href="#indexUrl#?#companiesAnchorQuery#">
<span class="material-symbols-outlined text-[20px]">domain</span>
<span class="font-body-md text-sm">Companies</span>
</a>
</cfoutput>
</nav>
<div class="mt-auto flex flex-col gap-4">
<cfoutput>
<a class="w-full bg-primary-container text-on-primary-container font-semibold py-2 px-4 rounded-lg flex items-center justify-center gap-2 hover:brightness-110 transition-all" href="#appBasePath#tasks/runDailyScrape.cfm">
<span class="material-symbols-outlined text-[18px]">play_circle</span>
<span>Run Daily Pipeline</span>
</a>
</cfoutput>
<details class="border-t border-outline-variant/20 pt-4 text-sm">
<summary class="text-outline cursor-pointer px-3 py-1 hover:text-on-surface">Operator tools</summary>
<div class="flex flex-col gap-1 mt-2 px-1">
<cfoutput>
<a class="px-3 py-1 text-outline hover:text-primary" href="#appBasePath#tasks/seed.cfm">Seed</a>
<a class="px-3 py-1 text-outline hover:text-primary" href="#appBasePath#tasks/runDiscovery.cfm">Run Discovery</a>
<a class="px-3 py-1 text-outline hover:text-primary" href="#appBasePath#tasks/checkJobExpiry.cfm">Check expiry</a>
<a class="px-3 py-1 text-outline hover:text-primary" href="#appBasePath#tasks/setupSchedule.cfm" title="Registers Lucee scheduled tasks">Setup schedule</a>
<a class="px-3 py-1 text-outline hover:text-primary" href="#appBasePath#tasks/pruneIrrelevantJobs.cfm">Prune non-CF</a>
<a class="px-3 py-1 text-outline hover:text-primary" href="#appBasePath#tasks/enrichCompanyLinks.cfm">Enrich links</a>
<a class="px-3 py-1 text-outline hover:text-primary" href="#appBasePath#tasks/promoteDevJobsScannerEmployers.cfm">Promote employers</a>
<a class="px-3 py-1 text-outline hover:text-primary" href="#appBasePath#tasks/backfillJobCompanies.cfm">Backfill companies</a>
<a class="px-3 py-1 text-outline hover:text-primary" href="#appBasePath#api/jobs.cfm" title="Returns JSON">Jobs API</a>
<a class="px-3 py-1 text-outline hover:text-primary" href="#appBasePath#api/companies.cfm" title="Returns JSON">Companies API</a>
<a class="px-3 py-1 text-outline hover:text-primary" href="#appBasePath#api/alerts.cfm" title="Returns JSON">Alerts API</a>
</cfoutput>
</div>
</details>
</div>
</aside>
