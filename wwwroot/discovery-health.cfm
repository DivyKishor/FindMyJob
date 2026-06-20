<cfsetting showdebugoutput="false" />
<!--- Discovery Engine Health — how well the autonomous discovery is working. --->
<cfset gw = application.dataGateway />

<cfset totalSignals = val( gw.scalar( "SELECT COUNT(*) FROM discovery_signals", [], 0 ) ) />
<cfset signals7d    = val( gw.scalar( "SELECT COUNT(*) FROM discovery_signals WHERE created_at >= datetime('now','-7 days')", [], 0 ) ) />
<cfset signals24h   = val( gw.scalar( "SELECT COUNT(*) FROM discovery_signals WHERE created_at >= datetime('now','-1 day')", [], 0 ) ) />
<cfset byType       = gw.queryArray( "SELECT signal_type, COUNT(*) AS c FROM discovery_signals GROUP BY signal_type ORDER BY c DESC" ) />

<cfset totalCompanies      = val( gw.scalar( "SELECT COUNT(*) FROM companies", [], 0 ) ) />
<cfset discoveredCompanies = val( gw.scalar( "SELECT COUNT(*) FROM companies WHERE careers_source = 'career_page_scan'", [], 0 ) ) />
<cfset jobsFromDiscovered  = val( gw.scalar( "SELECT COUNT(*) FROM jobs j INNER JOIN companies c ON c.id = j.company_id WHERE c.careers_source = 'career_page_scan'", [], 0 ) ) />

<cfset sourcesByStatus = gw.queryArray( "SELECT status, COUNT(*) AS c FROM sources GROUP BY status ORDER BY c DESC" ) />
<cfset totalEdges      = val( gw.scalar( "SELECT COUNT(*) FROM source_edges", [], 0 ) ) />

<cfset recentSignals = gw.queryArray(
	"SELECT signal_type, company_name, company_domain, confidence_score, created_at, target_url
	 FROM discovery_signals ORDER BY created_at DESC LIMIT 15" ) />

<!--- Latest discovery sub-summary from pipeline_runs. --->
<cfset lastRun = gw.queryRow( "SELECT run_at, status, summary_json FROM pipeline_runs ORDER BY run_at DESC LIMIT 1" ) />
<cfset disc = { QUERIESTRIED: "-", SIGNALSSTORED: "-", COMPANIESUPSERTED: "-" } />
<cfset lastRunAt = "" />
<cfif NOT structIsEmpty( lastRun )>
	<cfset lastRunAt = lastRun.run_at />
	<cftry>
		<cfset parsed = deserializeJSON( lastRun.summary_json ) />
		<cfif isStruct( parsed ) AND structKeyExists( parsed, "DISCOVERY" )><cfset disc = parsed.DISCOVERY /></cfif>
		<cfcatch type="any"></cfcatch>
	</cftry>
</cfif>

<cfset signalToCompany = ( totalSignals GT 0 ) ? numberFormat( ( discoveredCompanies / totalSignals ) * 100, "9.9" ) : "0" />

<cfoutput>
<!DOCTYPE html>
<html lang="en">
<head>
	<meta charset="utf-8" />
	<meta name="viewport" content="width=device-width, initial-scale=1" />
	<title>Discovery Engine Health — CF/OBSERVER</title>
	<style>
		body { background:##0b0f14; color:##e6edf3; font-family:'Segoe UI',system-ui,sans-serif; margin:0; padding:24px; }
		a { color:##6fb3ff; } h1 { font-size:20px; margin:0 0 2px; } h2 { font-size:14px; color:##9fb0c0; margin:26px 0 10px; text-transform:uppercase; letter-spacing:.04em; }
		.sub { color:##7d8da0; font-size:13px; margin-bottom:18px; }
		.stats { display:flex; gap:14px; flex-wrap:wrap; }
		.stat { background:##131a22; border:1px solid ##223040; border-radius:10px; padding:16px 18px; min-width:150px; }
		.stat .n { font-size:26px; font-weight:700; } .stat .l { font-size:11px; color:##8aa0b4; text-transform:uppercase; letter-spacing:.04em; margin-top:4px; }
		.funnel { display:flex; align-items:center; gap:10px; flex-wrap:wrap; margin-top:6px; }
		.fstep { background:##131a22; border:1px solid ##223040; border-radius:10px; padding:14px 18px; text-align:center; }
		.fstep .n { font-size:22px; font-weight:700; } .fstep .l { font-size:11px; color:##8aa0b4; }
		.arrow { color:##40526a; font-size:22px; }
		.bar { height:9px; border-radius:5px; background:##1f6feb; }
		.bartrack { background:##17222e; border-radius:5px; overflow:hidden; flex:1; }
		.row { display:flex; align-items:center; gap:10px; margin:6px 0; font-size:13px; }
		.row .k { width:140px; color:##cdd9e5; } .row .v { width:60px; text-align:right; color:##9fb0c0; }
		table { border-collapse:collapse; width:100%; margin-top:8px; font-size:12.5px; }
		th,td { text-align:left; padding:7px 10px; border-bottom:1px solid ##1c2733; }
		th { color:##9fb0c0; } .pill { font-size:10px; padding:2px 7px; border-radius:9px; background:##17222e; border:1px solid ##2a3a4a; color:##9fb0c0; }
		.on { background:##0f3a25; color:##5be39b; border:1px solid ##1d6b46; }
	</style>
</head>
<body>
	<h1>Discovery Engine Health</h1>
	<div class="sub">How well the autonomous discovery is finding CF/Lucee companies &amp; signals. <a href="index.cfm">&larr; Dashboard</a> &middot; <a href="discovery-signals.cfm">Signals feed</a></div>

	<h2>Signals discovered</h2>
	<div class="stats">
		<div class="stat"><div class="n">#numberFormat( totalSignals, ',' )#</div><div class="l">Total signals</div></div>
		<div class="stat"><div class="n">#numberFormat( signals7d, ',' )#</div><div class="l">Last 7 days</div></div>
		<div class="stat"><div class="n">#numberFormat( signals24h, ',' )#</div><div class="l">Last 24 hours</div></div>
		<div class="stat"><div class="n">#numberFormat( discoveredCompanies, ',' )#</div><div class="l">Companies discovered</div></div>
	</div>

	<h2>Discovery funnel</h2>
	<div class="funnel">
		<div class="fstep"><div class="n">#numberFormat( totalSignals, ',' )#</div><div class="l">web signals</div></div>
		<div class="arrow">&rarr;</div>
		<div class="fstep"><div class="n">#numberFormat( discoveredCompanies, ',' )#</div><div class="l">career pages found</div></div>
		<div class="arrow">&rarr;</div>
		<div class="fstep"><div class="n">#numberFormat( jobsFromDiscovered, ',' )#</div><div class="l">jobs from them</div></div>
	</div>
	<div class="sub" style="margin-top:8px;">Signal&rarr;company conversion: #signalToCompany#% &middot; #numberFormat( discoveredCompanies, ',' )# of #numberFormat( totalCompanies, ',' )# total companies were auto-discovered.</div>

	<h2>Signals by type</h2>
	<cfset maxType = 1 />
	<cfloop array="#byType#" index="bt"><cfif val( bt.c ) GT maxType><cfset maxType = val( bt.c ) /></cfif></cfloop>
	<cfloop array="#byType#" index="bt">
		<div class="row">
			<div class="k">#encodeForHTML( bt.signal_type )#</div>
			<div class="bartrack"><div class="bar" style="width:#int( ( val( bt.c ) / maxType ) * 100 )#%;"></div></div>
			<div class="v">#numberFormat( val( bt.c ), ',' )#</div>
		</div>
	</cfloop>

	<h2>Source graph &amp; last run</h2>
	<div class="stats">
		<cfloop array="#sourcesByStatus#" index="ss">
			<div class="stat"><div class="n">#val( ss.c )#</div><div class="l">sources: #encodeForHTML( ss.status )#</div></div>
		</cfloop>
		<div class="stat"><div class="n">#numberFormat( totalEdges, ',' )#</div><div class="l">provenance edges</div></div>
	</div>
	<div class="sub" style="margin-top:10px;">
		Last pipeline discovery (#encodeForHTML( lastRunAt )#):
		queries tried <b>#disc.QUERIESTRIED#</b> &middot; signals stored <b>#disc.SIGNALSSTORED#</b> &middot; companies upserted <b>#disc.COMPANIESUPSERTED#</b>.
		<cfif isNumeric( disc.QUERIESTRIED ) AND val( disc.QUERIESTRIED ) EQ 0><br/><span style="color:##e3a55b;">Note: discovery was quota-throttled this run (SourceQuotaService) — expected on a cost-tuned cadence.</span></cfif>
	</div>

	<h2>Most recent signals</h2>
	<table>
		<tr><th>Type</th><th>Company / domain</th><th>Confidence</th><th>Found</th></tr>
		<cfif arrayLen( recentSignals ) EQ 0><tr><td colspan="4" style="color:##7d8da0">No signals yet — run <a href="tasks/runDiscovery.cfm?force=1">discovery</a>.</td></tr></cfif>
		<cfloop array="#recentSignals#" index="sg">
			<tr>
				<td><span class="pill">#encodeForHTML( sg.signal_type )#</span></td>
				<td>#encodeForHTML( len( trim( sg.company_name ) ) ? sg.company_name : sg.company_domain )#</td>
				<td>#val( sg.confidence_score )#</td>
				<td>#encodeForHTML( sg.created_at )#</td>
			</tr>
		</cfloop>
	</table>
</body>
</html>
</cfoutput>
