<cfsetting showdebugoutput="false" />
<cfcontent type="application/json; charset=utf-8" />
<cftry>
	<cfset application.companyService.seedIfEmpty() />
	<cfset n = application.companyService.count() />
	<cfset responseBody = { "ok": true, "message": "Seed sync complete (upserts rows from config/seed_companies.json by name + careers_source).", "companyCount": n } />
	<cfoutput>#serializeJSON( responseBody )#</cfoutput>
	<cfcatch type="any">
		<cfheader statusCode="500" />
		<cfset errorBody = { "ok": false, "error": cfcatch.message } />
		<cfoutput>#serializeJSON( errorBody )#</cfoutput>
	</cfcatch>
</cftry>
