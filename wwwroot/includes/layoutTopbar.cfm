<cfparam name="searchKeyword" default="" />
<cfparam name="activeSection" default="today" />
<cfparam name="unreadAlerts" default="0" />

<cfparam name="isLocal" default="false" />
<cfset navLinks = [
	{ id: "today", label: "Today", href: indexUrl },
	{ id: "board", label: "Board", href: indexUrl & "##board" },
	{ id: "companies", label: "Companies", href: indexUrl & "##companies" },
	{ id: "alerts", label: "Alerts", href: indexUrl & "##alerts" }
] />
<cfif isLocal>
	<cfset arrayAppend( navLinks, { id: "pipeline", label: "Pipeline", href: indexUrl & "##pipeline" } ) />
	<cfset arrayAppend( navLinks, { id: "network", label: "Network", href: discoveryUrl } ) />
</cfif>

<cfoutput>
<header class="fp-nav">
<div class="fp-wrap fp-nav-row">
	<a class="fp-reset fp-disp" style="font-size:20px;color:var(--fp-ink);text-decoration:none;" href="#indexUrl#">CF<span style="color:var(--fp-accent2)">/</span>OBSERVER</a>

	<nav class="fp-nav-links">
	<cfloop array="#navLinks#" index="navLink">
		<a class="fp-link<cfif activeSection EQ navLink.id> fp-link--on</cfif>" href="#navLink.href#">#navLink.label#<cfif navLink.id EQ "alerts" AND val( unreadAlerts ) GT 0><span class="fp-nav-dot"></span></cfif></a>
	</cfloop>
	</nav>

	<div class="fp-filterbar-spacer"></div>

	<form method="get" action="#indexUrl#" class="fp-nav-search">
		<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="var(--fp-mute)" stroke-width="2"><circle cx="11" cy="11" r="7"/><path d="M21 21l-4-4"/></svg>
		<input class="fp-in" name="keyword" placeholder="Search&hellip;" value="#encodeForHTMLAttribute( searchKeyword )#"/>
	</form>

	<a class="fp-reset fp-save fp-save--wide" id="nav-saved-link" href="##" title="Saved roles">
		<svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="var(--fp-ink)" stroke-width="2.2" stroke-linejoin="round"><path d="M12 21s-7.5-4.9-10-9.3C.6 9 1.7 5.6 5 4.7c2-.5 3.9.4 5 2 1.1-1.6 3-2.5 5-2 3.3.9 4.4 4.3 3 7C19.5 16.1 12 21 12 21z"/></svg>
		<span class="fp-disp" style="font-size:15px;" id="nav-saved-count">0</span>
	</a>

	<a class="fp-btn fp-btn--ink fp-btn--sm fp-nav-getalerts" href="#indexUrl###alerts">Get alerts</a>

	<button type="button" class="fp-reset fp-nav-burger" id="fp-nav-burger" aria-label="Menu">
		<svg width="18" height="18" viewBox="0 0 18 18" stroke="var(--fp-ink)" stroke-width="2"><path d="M2 4h14M2 9h14M2 14h14"/></svg>
	</button>
</div>

<div class="fp-wrap fp-nav-menu" id="fp-nav-menu">
	<form method="get" action="#indexUrl#">
		<input class="fp-in" name="keyword" placeholder="Search CF / Lucee&hellip;" value="#encodeForHTMLAttribute( searchKeyword )#"/>
	</form>
	<cfloop array="#navLinks#" index="navLink">
		<a class="fp-link<cfif activeSection EQ navLink.id> fp-link--on</cfif>" href="#navLink.href#">#navLink.label#<cfif navLink.id EQ "alerts" AND val( unreadAlerts ) GT 0><span class="fp-nav-dot"></span></cfif></a>
	</cfloop>
	<a class="fp-btn fp-btn--ink fp-btn--sm" href="#indexUrl###alerts">Get alerts</a>
</div>
</header>
</cfoutput>
