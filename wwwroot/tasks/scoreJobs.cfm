<cfsetting showdebugoutput="false" />
<cfcontent type="application/json; charset=utf-8" />
<cftry>
	<cfset summary = application.jobScoreService.scoreAllJobs() />
	<cfoutput>#serializeJSON( summary )#</cfoutput>
	<cfcatch type="any">
		<cfheader statusCode="500" />
		<cfset errorBody = { "ok": false, "error": cfcatch.message } />
		<cfoutput>#serializeJSON( errorBody )#</cfoutput>
	</cfcatch>
</cftry>
