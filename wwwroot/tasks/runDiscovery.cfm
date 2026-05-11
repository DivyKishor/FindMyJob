<cfsetting showdebugoutput="false" />
<cfsetting requesttimeout="300" />
<cfcontent type="application/json; charset=utf-8" />
<cfparam name="url.force" default="0" />
<cftry>
	<cfset summary = application.discoveryService.runDiscovery( val( url.force ) EQ 1 ) />
	<cfoutput>#serializeJSON( summary )#</cfoutput>
	<cfcatch type="any">
		<cfheader statusCode="500" />
		<cfset errorBody = { "ok": false, "error": cfcatch.message } />
		<cfoutput>#serializeJSON( errorBody )#</cfoutput>
	</cfcatch>
</cftry>
