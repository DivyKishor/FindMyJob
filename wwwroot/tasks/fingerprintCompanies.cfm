<cfsetting requesttimeout="600" />
<cfoutput>
<!DOCTYPE html>
<html>
<head><title>Fingerprint Companies — CF Intel</title></head>
<body>
<h2>Technology Fingerprinter</h2>
<p>Phase 2, PR 2.1 — Scans each company's website for HTTP-level CF ecosystem signals.</p>
<hr>
<cfset started = now() />
<cfset maxCompanies = structKeyExists( url, "max" ) ? val( url.max ) : 25 />
<cfset forceRun     = structKeyExists( url, "force" ) AND url.force EQ "1" />
<cfset companyId    = structKeyExists( url, "company_id" ) ? val( url.company_id ) : 0 />

<cfset fp  = application.techFingerprinter />
<cfset svc = application.companyScoreService />
<cfset gw  = application.dataGateway />

<cfif companyId GT 0>
	<!--- Single-company mode --->
	<cfset cRow = application.companyService.getById( companyId ) />
	<cfif structIsEmpty( cRow )>
		<p><b>Company #companyId# not found.</b></p>
	<cfelse>
		<cfset domain = len( trim( cRow.website ) ) ? cRow.website : cRow.careers_url />
		<p>Fingerprinting <b>#cRow.name#</b> (#domain#)…</p>
		<cfset result = fp.fingerprint( cRow.id, domain ) />
		<p>Score: #result.score# &nbsp;|&nbsp; Signals: #arrayLen( result.signals )#</p>
		<p>#result.evidenceSummary#</p>
		<cfset svc.scoreCompany( cRow.id ) />
		<p>Company score persisted.</p>
	</cfif>
<cfelse>
	<!--- Batch mode: companies with a website or careers_url, quota-bounded. --->
	<cfset q = gw.query(
		"SELECT id, name, website, careers_url
		 FROM companies
		 WHERE (website IS NOT NULL AND trim(website) <> '')
		    OR (careers_url IS NOT NULL AND trim(careers_url) <> '')
		 ORDER BY updated_at ASC, id ASC
		 LIMIT #int( maxCompanies )#"
	) />
	<cfset scanned = 0 />
	<cfset scored  = 0 />
	<table border="1" cellpadding="4">
	<tr><th>ID</th><th>Name</th><th>Domain</th><th>Signals</th><th>FP Score</th><th>Company Score</th></tr>
	<cfloop query="q">
		<cfset domain = len( trim( q.website ) ) ? q.website : q.careers_url />
		<cfset fpResult = fp.fingerprint( val( q.id ), domain ) />
		<cfset scoreResult = svc.scoreCompany( val( q.id ) ) />
		<cfset scanned = scanned + 1 />
		<cfset scored  = scored  + 1 />
		<tr>
			<td>#q.id#</td>
			<td>#encodeForHTML( q.name )#</td>
			<td>#encodeForHTML( domain )#</td>
			<td>#arrayLen( fpResult.signals )#</td>
			<td>#fpResult.score#</td>
			<td>#scoreResult.score#</td>
		</tr>
	</cfloop>
	</table>
	<p><b>Scanned: #scanned# companies.</b></p>
</cfif>

<p>Elapsed: #int( (now().getTime() - started.getTime()) / 1000 )# s</p>
</body>
</html>
</cfoutput>
