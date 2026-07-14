<cfsetting showdebugoutput="false" requesttimeout="60" />
<cfcontent type="application/json; charset=utf-8" />
<!--- Sends a synthetic alert through one channel WITHOUT persisting (repeatable).
      Usage: /tasks/testAlertChannel.cfm?channel=telegram | whatsapp --->
<cfparam name="url.channel" default="telegram" />
<cftry>
	<cfif url.channel EQ "telegram">
		<cfset ch = application.telegramChannel />
	<cfelseif url.channel EQ "whatsapp">
		<cfset ch = application.whatsappChannel />
	<cfelse>
		<cfthrow message="Unknown channel '#encodeForHTML( url.channel )#' (use telegram or whatsapp)" />
	</cfif>

	<cfset payload = {
		job_id: 0,
		company_id: 0,
		company_name: "CF Observer Test",
		title: "ColdFusion / Lucee Engineer — TEST ALERT",
		location: "Remote — India",
		link: "https://github.com/DivyKishor/FindMyJob",
		score: 99,
		rule_version: "manual_test",
		reasons: [ "cf_tech:coldfusion,lucee", "remote_fit:+10", "manual_test" ]
	} />

	<cfset result = ch.send( payload, false ) />
	<cfoutput>#serializeJSON({ ok: true, channel: url.channel, enabled: ch.isEnabled(), result: result })#</cfoutput>
	<cfcatch type="any">
		<cfheader statusCode="500" />
		<cfoutput>#serializeJSON({ ok: false, error: cfcatch.message })#</cfoutput>
	</cfcatch>
</cftry>
