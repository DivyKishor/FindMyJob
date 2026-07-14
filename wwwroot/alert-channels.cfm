<cfsetting showdebugoutput="false" />
<cfparam name="url.reinit" default="0" />
<!--- Operator page: alert channel status + test send + recent deliveries (Phase 4). --->
<cfset tg = application.telegramChannel />
<cfset wa = application.whatsappChannel />
<cfset recent = application.alertService.listAlerts( 50 ) />

<cfoutput>
<!DOCTYPE html>
<html lang="en">
<head>
	<meta charset="utf-8" />
	<meta name="viewport" content="width=device-width, initial-scale=1" />
	<title>Alert Channels — CF/OBSERVER</title>
	<style>
		body { background:##0b0f14; color:##e6edf3; font-family:'Segoe UI',system-ui,sans-serif; margin:0; padding:24px; }
		h1 { font-size:20px; margin:0 0 4px; } h2 { font-size:15px; color:##9fb0c0; margin:24px 0 8px; }
		.sub { color:##7d8da0; font-size:13px; margin-bottom:18px; }
		.cards { display:flex; gap:16px; flex-wrap:wrap; }
		.card { background:##131a22; border:1px solid ##223040; border-radius:10px; padding:16px; width:300px; }
		.name { font-weight:600; font-size:15px; text-transform:capitalize; }
		.pill { display:inline-block; font-size:11px; padding:2px 8px; border-radius:10px; margin-left:8px; }
		.on { background:##0f3a25; color:##5be39b; border:1px solid ##1d6b46; }
		.off { background:##3a1f0f; color:##e3a55b; border:1px solid ##6b491d; }
		.meta { color:##8aa0b4; font-size:12px; margin:8px 0 12px; line-height:1.5; }
		button { background:##1f6feb; color:##fff; border:0; border-radius:6px; padding:8px 14px; cursor:pointer; font-size:13px; }
		button:disabled { background:##2a3340; color:##6b7888; cursor:not-allowed; }
		pre { background:##0d141c; border:1px solid ##223040; border-radius:6px; padding:10px; font-size:12px; white-space:pre-wrap; word-break:break-word; margin-top:10px; color:##b9c7d6; }
		table { border-collapse:collapse; width:100%; margin-top:8px; font-size:13px; }
		th,td { text-align:left; padding:7px 10px; border-bottom:1px solid ##1c2733; }
		th { color:##9fb0c0; font-weight:600; }
		.ch { font-size:11px; padding:2px 7px; border-radius:9px; background:##17222e; border:1px solid ##2a3a4a; }
		a { color:##6fb3ff; }
	</style>
</head>
<body>
	<h1>Alert Channels</h1>
	<div class="sub">Phase 4 — Telegram &amp; WhatsApp delivery on the AlertChannel seam. <a href="index.cfm">&larr; Dashboard</a></div>

	<div class="cards">
		<cfset chans = [
			{ key:"telegram", obj: tg, hint:"secrets.telegram_bot_token + secrets.telegram_chat_id" },
			{ key:"whatsapp", obj: wa, hint:"secrets.whatsapp_token + whatsapp_phone_number_id + whatsapp_recipient" }
		] />
		<cfloop array="#chans#" index="c">
			<cfset isOn = c.obj.isEnabled() />
			<div class="card">
				<div class="name">#c.key#
					<span class="pill #( isOn ? 'on' : 'off' )#">#( isOn ? 'CONFIGURED' : 'NOT CONFIGURED' )#</span>
				</div>
				<div class="meta">Needs: #c.hint#<br/>Set via env (CFINTEL_SECRETS_*) or config/app.json, then reinit.</div>
				<button onclick="testChannel('#c.key#', this)" #( isOn ? '' : 'disabled' )#>Send test alert</button>
				<pre id="out-#c.key#" style="display:none"></pre>
			</div>
		</cfloop>

		<div class="card">
			<div class="name">log <span class="pill on">ALWAYS ON</span></div>
			<div class="meta">Default channel — writes to the alerts table + scrape.log. Verified by the daily pipeline / generateAlerts.</div>
		</div>
	</div>

	<h2>Recent deliveries (alerts table)</h2>
	<table>
		<tr><th>Channel</th><th>Title</th><th>Score</th><th>Sent at</th></tr>
		<cfif arrayLen( recent ) EQ 0>
			<tr><td colspan="4" style="color:##7d8da0">No alerts yet. Run <a href="tasks/generateAlerts.cfm">generateAlerts</a> or send a test above.</td></tr>
		</cfif>
		<cfloop array="#recent#" index="a">
			<cfset pl = structKeyExists( a, "payload" ) AND isStruct( a.payload ) ? a.payload : {} />
			<tr>
				<td><span class="ch">#encodeForHTML( a.channel )#</span></td>
				<td>#encodeForHTML( structKeyExists( pl, "title" ) ? pl.title : "" )#</td>
				<td>#encodeForHTML( structKeyExists( pl, "score" ) ? pl.score : "" )#</td>
				<td>#encodeForHTML( a.sent_at )#</td>
			</tr>
		</cfloop>
	</table>

	<script>
		function testChannel(key, btn){
			var out = document.getElementById('out-' + key);
			out.style.display = 'block'; out.textContent = 'Sending…'; btn.disabled = true;
			fetch('tasks/testAlertChannel.cfm?channel=' + key)
				.then(function(r){ return r.json(); })
				.then(function(j){ out.textContent = JSON.stringify(j, null, 2); btn.disabled = false; })
				.catch(function(e){ out.textContent = 'Error: ' + e; btn.disabled = false; });
		}
	</script>
</body>
</html>
</cfoutput>
