<cfsetting requesttimeout="300" />
<cfoutput>
<!DOCTYPE html>
<html>
<head><title>Score Companies — CF Intel</title></head>
<body>
<h2>Company Score Backfill</h2>
<p>Phase 2, PR 2.2 — Scores all companies using fingerprint evidence, discovery signals, and job history.</p>
<hr>
<cfset started = now() />
<cfset result  = application.companyScoreService.scoreAllCompanies() />
<p><b>Scored: #result.scored# companies.</b></p>
<cfif arrayLen( result.errors ) GT 0>
	<p><b>Errors (#arrayLen( result.errors )#):</b></p>
	<ul>
	<cfloop array="#result.errors#" index="err">
		<li>#encodeForHTML( err )#</li>
	</cfloop>
	</ul>
</cfif>
<p>Elapsed: #int( (now().getTime() - started.getTime()) / 1000 )# s</p>
</body>
</html>
</cfoutput>
