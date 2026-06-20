<cfsetting showdebugoutput="false" requesttimeout="300" />
<cfcontent type="application/json; charset=utf-8" />
<cftry>
	<cfset summary = application.sourceGraphService.backfillFromExisting() />
	<cfoutput>#serializeJSON({ ok: true, nodes: summary.nodes })#</cfoutput>
	<cfcatch type="any">
		<cfheader statusCode="500" />
		<cfoutput>#serializeJSON({ ok: false, error: cfcatch.message })#</cfoutput>
	</cfcatch>
</cftry>
