<cfsetting showdebugoutput="false" />
<cfsetting requesttimeout="900" />
<cfcontent type="application/json; charset=utf-8" />
<cftry>
	<cfset maxEnrich = structKeyExists( url, "max" ) ? val( url.max ) : 50 />
	<cfif maxEnrich LTE 0><cfset maxEnrich = 50 /></cfif>
	<cfset braveKey = structKeyExists( url, "brave_key" ) ? trim( url.brave_key ) : "" />
	<cfset result = application.scrapeOrchestrator.enrichCompanyLinks( maxEnrich, braveKey ) />
	<cfoutput>#serializeJSON( { "ok": true, "result": result } )#</cfoutput>
	<cfcatch type="any">
		<cfheader statusCode="500" />
		<cfset errorBody = { "ok": false, "error": cfcatch.message } />
		<cfoutput>#serializeJSON( errorBody )#</cfoutput>
	</cfcatch>
</cftry>
