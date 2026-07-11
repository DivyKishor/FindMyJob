<cfsetting showdebugoutput="false" />
<!--- Discovered companies feed: everything the autonomous discovery engine has surfaced,
      newest first, grouped by the day it was discovered (companies.created_at). --->
<cfset gw = application.dataGateway />

<cfparam name="url.limit" default="300" />
<cfset viewLimit = min( max( val( url.limit ), 20 ), 2000 ) />

<!--- Discovered = career_page_scan rows whose ats_config carries a discovery_source
      (that key is only written by DiscoveryService.upsertDiscoveredCompany). --->
<cfset rows = gw.queryArray(
	"SELECT c.id, c.name, c.website, c.careers_url, c.ats_config, c.created_at,
	        (SELECT COUNT(*) FROM jobs j WHERE j.company_id = c.id) AS job_count
	 FROM companies c
	 WHERE c.careers_source = 'career_page_scan'
	   AND c.ats_config LIKE '%""discovery_source"":""_%'
	 ORDER BY c.created_at DESC, c.id DESC
	 LIMIT " & viewLimit ) />

<cfset totalDiscovered = val( gw.scalar(
	"SELECT COUNT(*) FROM companies
	 WHERE careers_source = 'career_page_scan' AND ats_config LIKE '%""discovery_source"":""_%'", [], 0 ) ) />
<cfset new7d = val( gw.scalar(
	"SELECT COUNT(*) FROM companies
	 WHERE careers_source = 'career_page_scan' AND ats_config LIKE '%""discovery_source"":""_%'
	   AND created_at >= datetime('now','-7 days')", [], 0 ) ) />
<cfset new24h = val( gw.scalar(
	"SELECT COUNT(*) FROM companies
	 WHERE careers_source = 'career_page_scan' AND ats_config LIKE '%""discovery_source"":""_%'
	   AND created_at >= datetime('now','-1 day')", [], 0 ) ) />

<!--- Last time discovery ran, from the pipeline summary. --->
<cfset lastRun = gw.queryRow( "SELECT run_at, summary_json FROM pipeline_runs ORDER BY run_at DESC LIMIT 1" ) />
<cfset lastRunAt = structIsEmpty( lastRun ) ? "" : lastRun.run_at />

<cffunction name="discSource" access="private" returntype="string" output="false">
	<cfargument name="atsConfig" type="string" required="true" />
	<cftry>
		<cfset var cfg = deserializeJSON( arguments.atsConfig ) />
		<cfif isStruct( cfg ) AND structKeyExists( cfg, "discovery_source" ) AND len( trim( cfg.discovery_source ) )>
			<cfreturn trim( cfg.discovery_source ) />
		</cfif>
		<cfcatch type="any"></cfcatch>
	</cftry>
	<cfreturn "discovered" />
</cffunction>

<cfoutput>
<!DOCTYPE html>
<html lang="en">
<head>
	<meta charset="utf-8" />
	<meta name="viewport" content="width=device-width, initial-scale=1" />
	<title>Discovered Companies &mdash; CF/OBSERVER</title>
	<style>
		body { background:##0b0f14; color:##e6edf3; font-family:'Segoe UI',system-ui,sans-serif; margin:0; padding:24px; }
		a { color:##6fb3ff; text-decoration:none; } a:hover { text-decoration:underline; }
		h1 { font-size:20px; margin:0 0 2px; } h2 { font-size:13px; color:##9fb0c0; margin:24px 0 8px; }
		.sub { color:##7d8da0; font-size:13px; margin-bottom:18px; }
		.stats { display:flex; gap:14px; flex-wrap:wrap; margin-bottom:8px; }
		.stat { background:##131a22; border:1px solid ##223040; border-radius:10px; padding:14px 18px; min-width:140px; }
		.stat .n { font-size:24px; font-weight:700; } .stat .l { font-size:11px; color:##8aa0b4; text-transform:uppercase; letter-spacing:.04em; margin-top:4px; }
		.daygroup { margin-top:18px; }
		.dayhdr { display:flex; align-items:baseline; gap:10px; border-bottom:1px solid ##223040; padding-bottom:6px; margin-bottom:4px; }
		.dayhdr .d { font-size:15px; font-weight:700; color:##cdd9e5; } .dayhdr .c { font-size:12px; color:##7d8da0; }
		table { border-collapse:collapse; width:100%; font-size:12.5px; }
		th,td { text-align:left; padding:7px 10px; border-bottom:1px solid ##1c2733; vertical-align:top; }
		th { color:##9fb0c0; font-weight:600; }
		.pill { font-size:10px; padding:2px 7px; border-radius:9px; background:##17222e; border:1px solid ##2a3a4a; color:##9fb0c0; white-space:nowrap; }
		.jobs { color:##5be39b; } .nojobs { color:##7d8da0; }
		.muted { color:##7d8da0; }
	</style>
</head>
<body>
	<h1>Discovered Companies</h1>
	<div class="sub">
		Employers the discovery engine surfaced, newest first, grouped by discovery day.
		<a href="index.cfm">&larr; Dashboard</a> &middot; <a href="discovery-health.cfm">Engine health</a> &middot; <a href="discovery-signals.cfm">Signals feed</a>
	</div>

	<div class="stats">
		<div class="stat"><div class="n">#numberFormat( totalDiscovered, ',' )#</div><div class="l">Total discovered</div></div>
		<div class="stat"><div class="n">#numberFormat( new7d, ',' )#</div><div class="l">Last 7 days</div></div>
		<div class="stat"><div class="n">#numberFormat( new24h, ',' )#</div><div class="l">Last 24 hours</div></div>
	</div>
	<div class="sub">Last discovery run: <b>#encodeForHTML( len( lastRunAt ) ? lastRunAt : "unknown" )#</b> &middot; showing newest #numberFormat( arrayLen( rows ), ',' )#.</div>

	<cfif arrayLen( rows ) EQ 0>
		<p class="muted">No engine-discovered companies yet. Run <a href="tasks/runDiscovery.cfm?force=1">discovery</a>, then refresh.</p>
	<cfelse>
		<cfset currentDay = "" />
		<cfset dayCount = 0 />
		<cfset openTable = false />
		<cfloop array="#rows#" index="c">
			<cfset dayKey = left( trim( c.created_at ), 10 ) />
			<cfif dayKey NEQ currentDay>
				<cfif openTable></table></div><cfset openTable = false /></cfif>
				<!--- count for this day --->
				<cfset dayCount = val( gw.scalar(
					"SELECT COUNT(*) FROM companies
					 WHERE careers_source = 'career_page_scan' AND ats_config LIKE '%""discovery_source"":""_%'
					   AND date(created_at) = ?", [ dayKey ], 0 ) ) />
				<div class="daygroup">
					<div class="dayhdr"><span class="d">#encodeForHTML( dayKey )#</span><span class="c">#dayCount# discovered</span></div>
					<table>
						<tr><th>Company</th><th>Source</th><th>Jobs</th><th>Careers URL</th><th>Discovered</th></tr>
				<cfset openTable = true />
				<cfset currentDay = dayKey />
			</cfif>
			<cfset jc = val( c.job_count ) />
			<tr>
				<td>#encodeForHTML( c.name )#</td>
				<td><span class="pill">#encodeForHTML( discSource( c.ats_config ) )#</span></td>
				<td class="#( jc GT 0 ) ? 'jobs' : 'nojobs'#">#jc#</td>
				<td><cfif len( trim( c.careers_url ) )><a href="#encodeForHTMLAttribute( c.careers_url )#" target="_blank" rel="noopener">#encodeForHTML( left( c.careers_url, 60 ) )#</a><cfelse><span class="muted">&mdash;</span></cfif></td>
				<td class="muted">#encodeForHTML( c.created_at )#</td>
			</tr>
		</cfloop>
		<cfif openTable></table></div></cfif>
	</cfif>
</body>
</html>
</cfoutput>
