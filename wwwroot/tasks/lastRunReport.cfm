<cfsetting showdebugoutput="false" />
<!--- View the most recent pipeline run as a report WITHOUT re-running it. Reads the stored
      summary from pipeline_runs. Append ?format=json for the raw stored summary. --->
<cfparam name="url.format" default="report" />
<cftry>
	<cfset q = queryExecute(
		"SELECT summary_json FROM pipeline_runs
		 WHERE status = 'success' AND summary_json IS NOT NULL AND summary_json <> '{}'
		 ORDER BY id DESC LIMIT 1",
		{},
		{ datasource: application.databaseService.getDatasource() }
	) />
	<cfif q.recordCount EQ 0>
		<cfcontent type="text/html; charset=utf-8" />
		<cfoutput><p>No successful pipeline run has been recorded yet.</p></cfoutput>
		<cfabort />
	</cfif>
	<cfif url.format EQ "json">
		<cfcontent type="application/json; charset=utf-8" />
		<cfoutput>#q.summary_json[ 1 ]#</cfoutput>
		<cfabort />
	</cfif>
	<cfset summary = deserializeJSON( q.summary_json[ 1 ] ) />
	<cfcontent type="text/html; charset=utf-8" />
	<cfinclude template="_runReport.cfm" />
	<cfcatch type="any">
		<cfheader statusCode="500" />
		<cfcontent type="application/json; charset=utf-8" />
		<cfoutput>#serializeJSON( { "ok": false, "error": cfcatch.message } )#</cfoutput>
	</cfcatch>
</cftry>
