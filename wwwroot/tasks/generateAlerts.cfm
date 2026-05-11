<cfsetting showdebugoutput="false" />
<cfcontent type="application/json; charset=utf-8" />
<cftry>
	<cfif structKeyExists( url, "threshold" )>
		<cfset threshold = val( url.threshold ) />
	<cfelse>
		<cfset threshold = 40 />
	</cfif>
	<cfif threshold LTE 0>
		<cfset threshold = 40 />
	</cfif>
	<cfset summary = application.alertService.generateAlerts( threshold ) />
	<cfoutput>#serializeJSON( summary )#</cfoutput>
	<cfcatch type="any">
		<cfheader statusCode="500" />
		<cfset errorBody = { "ok": false, "error": cfcatch.message } />
		<cfoutput>#serializeJSON( errorBody )#</cfoutput>
	</cfcatch>
</cftry>
