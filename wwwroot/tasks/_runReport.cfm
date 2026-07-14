<!--- Shared renderer: expects variables.summary (a pipeline runDaily struct) and emits an
      HTML report. Surfaces failures/attention first so a broken source is easy to spot.
      Included by runDailyScrape.cfm (live) and lastRunReport.cfm (reads last stored run). --->
<cfscript>
	s = isStruct( variables.summary ) ? variables.summary : {};
	function g( st, key, def ) { return ( isStruct( st ) AND structKeyExists( st, key ) ) ? st[ key ] : def; }

	scrape  = g( s, "scrape", {} );
	disc    = g( s, "discovery", {} );
	score   = g( s, "score", {} );
	alerts  = g( s, "alerts", {} );
	watcher = g( s, "cfGlobalWatcher", {} );
	sh      = g( scrape, "sourceHealth", {} );

	// per-source rollup + failure detection
	perSource = [];
	failedSources = [];
	for ( src in sh ) {
		row = sh[ src ];
		f  = val( g( row, "FAILED", 0 ) );
		ok = val( g( row, "SUCCESS", 0 ) );
		sk = val( g( row, "SKIPPED", 0 ) );
		up = val( g( row, "JOBSUPSERTED", 0 ) );
		arrayAppend( perSource, { src: src, ok: ok, failed: f, skipped: sk, up: up } );
		if ( f GT 0 ) { arrayAppend( failedSources, src & " &mdash; " & f & " failed" ); }
	}
	arraySort( perSource, function( a, b ) { return b.up - a.up; } );

	// classify scrape errors
	scrapeErrs = isArray( g( scrape, "errors", [] ) ) ? scrape.errors : [];
	unsupported = [];
	otherScrapeErrs = [];
	for ( e in scrapeErrs ) {
		if ( findNoCase( "unsupported source", e ) GT 0 ) {
			arrayAppend( unsupported, reReplaceNoCase( e, "^Skipped \(unsupported source '[^']*'\) for company ", "" ) );
		} else {
			arrayAppend( otherScrapeErrs, e );
		}
	}
	discErrs = isArray( g( disc, "errors", [] ) ) ? disc.errors : [];

	// alerts delivered
	ch = isArray( g( alerts, "channelResults", [] ) ) ? alerts.channelResults : [];
	sentCount = 0;
	for ( c in ch ) { if ( isStruct( c ) AND g( c, "SENT", false ) ) { sentCount++; } }

	hardFailCount = arrayLen( failedSources ) + arrayLen( otherScrapeErrs ) + arrayLen( discErrs );
	attnClass = ( hardFailCount GT 0 OR arrayLen( unsupported ) GT 0 ) ? "attn" : "ok";
</cfscript>
<cfoutput>
<!doctype html><html lang="en"><head><meta charset="utf-8" />
<title>CF/OBSERVER &mdash; run report</title>
<style>
 body{font-family:system-ui,Segoe UI,Arial,sans-serif;margin:24px;color:##1a1a1a;max-width:900px}
 h1{font-size:20px;margin:0 0 2px} h2{font-size:14px;text-transform:uppercase;letter-spacing:.04em;margin:24px 0 8px;border-bottom:1px solid ##e2e2e2;padding-bottom:4px}
 small{color:##666} pre{background:##f6f8fa;padding:12px 14px;border-radius:6px;overflow:auto;font-size:13px;line-height:1.5}
 .attn{color:##b00020} .ok{color:##1a7f37} ul{margin:6px 0 0 0;padding-left:20px} li{margin:2px 0;font-size:13px}
</style></head><body>
<h1>CF/OBSERVER &mdash; Daily Run Report</h1>
<small>Run at #encodeForHtml( g( s, "runAt", "?" ) )# &middot; scoring #encodeForHtml( g( score, "ruleVersion", "n/a" ) )#</small>

<h2>Headline</h2>
<pre>#lJustify( "Jobs upserted (scrape)", 26 )# #val( g( scrape, "jobsUpserted", 0 ) )#
#lJustify( "Jobs scored", 26 )# #val( g( score, "jobsScored", 0 ) )#
#lJustify( "Companies processed", 26 )# #val( g( scrape, "companiesProcessed", 0 ) )#
#lJustify( "New companies discovered", 26 )# #val( g( disc, "companiesUpserted", 0 ) )#   (signals #val( g( disc, "signalsStored", 0 ) )# &middot; queries #val( g( disc, "queriesTried", 0 ) )#)
#lJustify( "Alerts created", 26 )# #val( g( alerts, "alertsCreated", 0 ) )#   (threshold #val( g( alerts, "threshold", 0 ) )# &middot; #sentCount# delivered)
#lJustify( "CF global watcher", 26 )# #val( g( watcher, "jobsUpserted", 0 ) )#</pre>

<h2 class="#attnClass#">Needs attention</h2>
<cfif hardFailCount EQ 0 AND arrayLen( unsupported ) EQ 0>
	<p class="ok">No failures &mdash; every source ran clean. &##9989;</p>
<cfelse>
	<cfif arrayLen( failedSources ) GT 0>
		<p class="attn"><strong>Sources that FAILED (fix these):</strong></p>
		<ul><cfloop array="#failedSources#" index="fs"><li class="attn">#encodeForHtml( fs )#</li></cfloop></ul>
	</cfif>
	<cfif arrayLen( otherScrapeErrs ) GT 0>
		<p class="attn"><strong>Scrape errors:</strong></p>
		<ul><cfloop array="#otherScrapeErrs#" index="oe"><li>#encodeForHtml( oe )#</li></cfloop></ul>
	</cfif>
	<cfif arrayLen( discErrs ) GT 0>
		<p class="attn"><strong>Discovery errors:</strong></p>
		<ul><cfloop array="#discErrs#" index="de"><li>#encodeForHtml( de )#</li></cfloop></ul>
	</cfif>
	<cfif arrayLen( unsupported ) GT 0>
		<p><strong>#arrayLen( unsupported )# companies skipped &mdash; unsupported <code>careers_source</code></strong> (assign each a real source, or remove the seed):</p>
		<ul><cfloop array="#unsupported#" index="us"><li>#encodeForHtml( us )#</li></cfloop></ul>
	</cfif>
</cfif>

<h2>Throttled (normal &mdash; not errors)</h2>
<pre>#lJustify( "quota_guard_skip", 20 )# #val( g( scrape, "quotaGuardSkips", 0 ) )#   (source already ran within its interval)
#lJustify( "scan_budget_skip", 20 )# #val( g( scrape, "scanBudgetSkips", 0 ) )#   (per-run career-scan cap reached)</pre>

<h2>Per-source</h2>
<pre>#lJustify( "source", 24 )##rJustify( "success", 9 )##rJustify( "failed", 8 )##rJustify( "skipped", 9 )##rJustify( "upserted", 10 )#
#repeatString( "-", 60 )#
<cfloop array="#perSource#" index="r">#lJustify( left( r.src, 23 ), 24 )##rJustify( "#r.ok#", 9 )##rJustify( "#r.failed#", 8 )##rJustify( "#r.skipped#", 9 )##rJustify( "#r.up#", 10 )#
</cfloop></pre>
</b