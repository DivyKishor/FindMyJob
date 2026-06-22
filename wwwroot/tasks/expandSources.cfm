<cfsetting showdebugoutput="false" requesttimeout="300" />
<cfcontent type="application/json; charset=utf-8" />
<cftry>
	<cfset summary = application.sourceExpansionService.runExpansion() />
	<cfoutput>#serializeJSON({
		ok: true,
		evaluated: summary.evaluated,
		promoted: summary.promoted,
		quarantined: summary.quarantined
	})#</cfoutput>
	<cfcatch type="any">
		<cfheader statusCode="500" />
		<cfoutput>#serializeJSON({ ok: false, error: cfcatch.message })#</cfoutput>
	</cfcatch>
</cftry>
