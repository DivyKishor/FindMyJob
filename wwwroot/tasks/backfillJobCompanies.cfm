<cfsetting showdebugoutput="false" />
<cfsetting requesttimeout="300" />
<cfcontent type="application/json; charset=utf-8" />
<cftry>
	<cfset result = application.scrapeOrchestrator.backfillUnknownCompanyJobs() />
	<cfset application.jobScoreService.refreshCompanyScores() />
	<cfoutput>#serializeJSON( result )#</cfoutput>
	<cfcatch type="any">
		<cfheader statusCode="500" />
		<cfset errorBody = { "ok": false, "error": cfcatch.message } />
		<cfoutput>#serializeJSON( errorBody )#</cfoutput>
	</cfcatch>
</cftry>
