<cfsetting showdebugoutput="false" />
<cfcontent type="application/json; charset=utf-8" />
<cfheader name="Access-Control-Allow-Origin" value="*" />
<cftry>
	<cfif structKeyExists( url, "limit" )>
		<cfset limitRows = val( url.limit ) />
	<cfelse>
		<cfset limitRows = 200 />
	</cfif>
	<cfif limitRows LTE 0>
		<cfset limitRows = 200 />
	</cfif>

	<cfset data = application.alertService.listAlerts( limitRows ) />
	<cfset responseBody = {
		"ok": true,
		"data": data,
		"meta": { "count": arrayLen( data ), "threshold": 40 }
	} />
	<cfoutput>#serializeJSON( responseBody )#</cfoutput>
	<cfcatch type="any">
		<cfheader statusCode="500" />
		<cfset errorBody = { "ok": false, "error": cfcatch.message } />
		<cfoutput>#serializeJSON( errorBody )#</cfoutput>
	</cfcatch>
</cftry>
