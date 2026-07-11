<cfsetting showdebugoutput="false" />
<!--- Local-only report hub. Guarded in Application.cfc onRequestStart (localOnlyPages),
      so it (and everything it links to) is reachable from the box itself, never publicly. --->
<cfoutput>
<!DOCTYPE html>
<html lang="en">
<head>
	<meta charset="utf-8" />
	<meta name="viewport" content="width=device-width, initial-scale=1" />
	<title>Reports &mdash; CF/OBSERVER</title>
	<style>
		body { background:##0b0f14; color:##e6edf3; font-family:'Segoe UI',system-ui,sans-serif; margin:0; padding:24px; }
		a { color:##6fb3ff; text-decoration:none; } a:hover { text-decoration:underline; }
		h1 { font-size:20px; margin:0 0 2px; } h2 { font-size:13px; color:##9fb0c0; margin:26px 0 10px; text-transform:uppercase; letter-spacing:.04em; }
		.sub { color:##7d8da0; font-size:13px; margin-bottom:6px; }
		.badge { display:inline-block; font-size:10px; padding:2px 8px; border-radius:9px; background:##17222e; border:1px solid ##2a3a4a; color:##9fb0c0; margin-left:6px; }
		.local { background:##0f3a25; color:##5be39b; border:1px solid ##1d6b46; }
		.grid { display:grid; grid-template-columns:repeat(auto-fill,minmax(260px,1fr)); gap:12px; }
		.card { background:##131a22; border:1px solid ##223040; border-radius:10px; padding:16px 18px; }
		.card a.t { font-size:15px; font-weight:700; color:##e6edf3; }
		.card .d { font-size:12px; color:##8aa0b4; margin-top:5px; line-height:1.45; }
		.warn { color:##e3a55b; }
	</style>
</head>
<body>
	<h1>CF/OBSERVER &mdash; Reports<span class="badge local">local only</span></h1>
	<div class="sub">Everything here is restricted to the server itself &mdash; not reachable from the public site. <a href="index.cfm">&larr; Dashboard</a></div>

	<h2>Views (read-only)</h2>
	<div class="grid">
		<div class="card">
			<a class="t" href="tasks/lastRunReport.cfm">Last pipeline run report</a>
			<div class="d">The most recent daily run, formatted &mdash; failures and attention items first. Does not re-scrape.</div>
		</div>
		<div class="card">
			<a class="t" href="discovery-health.cfm">Discovery engine health</a>
			<div class="d">Signal counts, discovery funnel, signals-by-type, source graph, and last-run discovery stats.</div>
		</div>
		<div class="card">
			<a class="t" href="discovered-companies.cfm">Discovered companies</a>
			<div class="d">Companies the engine surfaced, newest first, grouped by the day they were discovered.</div>
		</div>
		<div class="card">
			<a class="t" href="discovery-signals.cfm">Signals feed</a>
			<div class="d">Raw discovery signals (evidence) with confidence scores and source URLs.</div>
		</div>
	</div>

	<h2>Actions (trigger a run)</h2>
	<div class="sub warn">These kick off real work. Harvest LinkedIn posts starts a <b>paid</b> Apify run.</div>
	<div class="grid">
		<div class="card">
			<a class="t" href="tasks/runDailyScrape.cfm">Run daily pipeline now</a>
			<div class="d">Full cycle: discovery &rarr; scrape &rarr; score &rarr; alerts. Renders the report when done.</div>
		</div>
		<div class="card">
			<a class="t" href="tasks/runDiscovery.cfm?force=1">Run discovery now</a>
			<div class="d">Force a discovery pass (ignores the per-query throttle).</div>
		</div>
		<div class="card">
			<a class="t" href="tasks/harvestApifyPosts.cfm">Harvest LinkedIn posts</a>
			<div class="d">Pull fresh CF hiring posts via Apify (&le;7 days). <span class="warn">Paid.</span></div>
		</div>
		<div class="card">
			<a class="t" href="tasks/harvestGithub.cfm?max=60">Harvest GitHub companies</a>
			<div class="d">Discover employers via the CFML developer graph (careers-gated).</div>
		</div>
	</div>
</body>
</html>
</cfoutput>
