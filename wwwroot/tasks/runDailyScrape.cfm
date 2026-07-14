<cfsetting showdebugoutput="false" />
<cfsetting requesttimeout="900" />
<!--- Runs the daily pipeline. Renders a human-readable report by default; append
      ?format=json for the raw machine-readable summary (used by tooling). --->
<cfparam name="url.format" default="report" />
<cftry>
	<cfset summary = application.pipelineService.runDaily() />
	<cfif url.format EQ "json">
		<cfcontent type="application/json; charset=utf-8" />
		<cfoutput>#serializeJSON( summary )#</cfoutput>
		<cfabort />
	</cfif>
	<cfcontent type="text/html; charset=utf-8" />
	<cfinclude template="_runReport.cfm" />
	<cfcatch type="any">
		<cfheader statusCode="500" />
		<cfcontent type="application/json; charset=utf-8" />
		<cfoutput>#serializeJSON( { "ok": false, "error": cfcatch.message } )#</cfoutput>
	</cfcatch>
</cftry>
