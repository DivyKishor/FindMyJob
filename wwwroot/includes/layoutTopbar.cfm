<cfparam name="searchKeyword" default="" />
<header class="flex justify-between items-center w-full px-4 md:px-margin-desktop h-16 glass-header sticky top-0 z-50 border-b border-outline-variant/30 shadow-[0_0_30px_0_rgba(0,174,239,0.05)]">
<div class="flex items-center gap-4 md:gap-8 min-w-0">
<span class="font-headline-md text-lg font-bold text-primary tracking-tighter whitespace-nowrap">CF/OBSERVER</span>
<div class="hidden lg:flex items-center gap-6">
<cfoutput>
<a class="text-primary font-semibold border-b-2 border-primary pb-2 text-sm" href="#indexUrl#">Dashboard</a>
<a class="text-outline hover:text-on-surface transition-colors text-sm" href="#indexUrl#?#healthAnchorQuery#">Pipeline</a>
<a class="text-outline hover:text-on-surface transition-colors text-sm" href="#discoveryUrl#">Discovery</a>
</cfoutput>
</div>
</div>
<cfoutput>
<form method="get" action="#indexUrl#" class="flex items-center gap-2 flex-1 max-w-md mx-2 md:mx-8">
<input type="hidden" name="location" value="#encodeForHTMLAttribute( locationKeyword )#"/>
<input type="hidden" name="min_score" value="#minScore#"/>
<input type="hidden" name="source" value="#encodeForHTMLAttribute( rawSourceFilter )#"/>
<input type="hidden" name="company_id" value="#companyId#"/>
<div class="relative w-full">
<span class="material-symbols-outlined absolute left-3 top-1/2 -translate-y-1/2 text-outline text-[20px]">search</span>
<input class="w-full bg-surface-container-lowest border border-outline-variant/40 rounded-lg pl-10 pr-4 py-1.5 text-sm text-on-surface focus:outline-none focus:border-primary transition-colors" name="keyword" placeholder="Search CF / CFML / Lucee jobs..." type="text" value="#encodeForHTMLAttribute( searchKeyword )#"/>
</div>
<button type="submit" class="hidden md:inline-flex text-primary text-sm px-2">Go</button>
</form>
</cfoutput>
<div class="flex items-center gap-2">
<div class="h-8 w-8 rounded-full border border-primary/30 flex items-center justify-center text-primary text-xs font-bold numerical" title="CF/OBSERVER">CF</div>
</div>
</header>
