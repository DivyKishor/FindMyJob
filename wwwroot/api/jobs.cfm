<cfsetting showdebugoutput="false" />
<cfcontent type="application/json; charset=utf-8" />
<cfheader name="Access-Control-Allow-Origin" value="*" />
<cftry>
	<cfif structKeyExists( url, "company_id" )>
		<cfset companyId = val( url.company_id ) />
	<cfelse>
		<cfset companyId = 0 />
	</cfif>
	<cfif structKeyExists( url, "keyword" )>
		<cfset keyword = url.keyword />
	<cfelse>
		<cfset keyword = "" />
	</cfif>
	<cfif structKeyExists( url, "min_score" )>
		<cfset minScore = val( url.min_score ) />
	<cfelse>
		<cfset minScore = 0 />
	</cfif>
	<cfif structKeyExists( url, "location" )>
		<cfset locationKeyword = trim( url.location ) />
	<cfelse>
		<cfset locationKeyword = "" />
	</cfif>

	<cfset data = application.jobService.list( companyId, keyword, minScore, locationKeyword ) />
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
