<cfsetting showdebugoutput="false" />
<cfcontent type="application/json; charset=utf-8" />
<cfheader name="Access-Control-Allow-Origin" value="*" />
<cftry>
	<cfset data = application.companyService.list() />
	<cfset responseBody = {
		"ok": true,
		"data": data,
		"meta": { "count": arrayLen( data ) }
	} />
	<cfoutput>#serializeJSON( responseBody )#</cfoutput>
	<cfcatch type="any">
		<cfheader statusCode="500" />
		<cfset errorBody = { "ok": false, "error": cfcatch.message } />
		<cfoutput>#serializeJSON( errorBody )#</cfoutput>
	</cfcatch>
</cftry>
