<cfsetting showdebugoutput="false" requesttimeout="120" />
<cfcontent type="application/json; charset=utf-8" />
<!---
	Read-only diagnostic: runs the LIVE classifier on real job rows so we can verify
	sponsorship / geo decisions against the actual DB (not the flaky sandbox mount).
	Usage: /tasks/dbcheck.cfm?company=PD Inc      (or ?keyword=coldfusion)
	No writes. Guarded by the same /tasks/ key when configured.
--->
<cfparam name="url.company" default="" />
<cfparam name="url.keyword" default="" />
<cftry>
	<cfset svc = application.scoringService />
	<cfset gw  = application.dataGateway />

	<cfset where = "1=1" />
	<cfset params = [] />
	<cfif len( trim( url.company ) )>
		<cfset where = where & " AND c.name LIKE ?" />
		<cfset arrayAppend( params, { value: "%" & trim( url.company ) & "%", cfsqltype: "cf_sql_varchar" } ) />
	</cfif>
	<cfif len( trim( url.keyword ) )>
		<cfset where = where & " AND (lower(j.title) LIKE lower(?) OR lower(j.description) LIKE lower(?))" />
		<cfset arrayAppend( params, { value: "%" & trim( url.keyword ) & "%", cfsqltype: "cf_sql_varchar" } ) />
		<cfset arrayAppend( params, { value: "%" & trim( url.keyword ) & "%", cfsqltype: "cf_sql_longvarchar" } ) />
	</cfif>

	<cfset rows = gw.queryArray(
		"SELECT j.id, c.name AS company, j.title, j.location, j.description
		 FROM jobs j INNER JOIN companies c ON c.id = j.company_id
		 WHERE " & where & " ORDER BY j.id LIMIT 40",
		params
	) />

	<cfset out = [] />
	<cfloop array="#rows#" index="r">
		<cfset txt = r.title & " " & ( structKeyExists( r, "description" ) ? r.description : "" ) />
		<cfset visa = svc.classifyVisaSponsorship( txt ) />
		<cfset geo  = svc.classifyGeoEligibility( txt, structKeyExists( r, "location" ) ? r.location : "" ) />
		<cfset full = svc.scoreJob( r.title, structKeyExists( r, "description" ) ? r.description : "", structKeyExists( r, "location" ) ? r.location : "" ) />
		<!--- show the text window around the first "sponsor" mention --->
		<cfset lc = lCase( txt ) />
		<cfset pos = find( "sponsor", lc ) />
		<cfset snippet = ( pos GT 0 ) ? mid( txt, max( 1, pos - 60 ), 140 ) : "" />
		<cfset arrayAppend( out, {
			id: r.id, company: r.company, title: r.title,
			location: ( structKeyExists( r, "location" ) ? r.location : "" ),
			visaBonus: visa, geo: geo, score: full.score, reasons: full.reasons,
			sponsorSnippet: snippet
		} ) />
	</cfloop>

	<cfset summary = { ok: true, ruleVersion: svc.getRuleVersion(), matched: arrayLen( out ), rows: out } />
	<cfoutput>#serializeJSON( summary )#</cfoutput>
	<cfcatch type="any">
		<cfheader statusCode="500" />
		<cfoutput>#serializeJSON( { ok: false, error: cfcatch.message } )#</cfoutput>
	</cfcatch>
</cftry>
