<cfsetting showdebugoutput="false" />
<cfcontent type="text/plain; charset=utf-8" />
<cftry>
	<cfset ds = application.datasource />
	<cfset deleted = 0 />
	<cfset q = queryExecute(
		"SELECT id, title, COALESCE(description, '') AS description FROM jobs ORDER BY id",
		{},
		{ datasource: ds }
	) />
	<cfloop from="1" to="#q.recordCount#" index="rowNum">
		<cfif NOT application.scoringService.shouldPersistJob( q.title[ rowNum ], q.description[ rowNum ] )>
			<cfset queryExecute(
				"DELETE FROM jobs WHERE id = ?",
				[ { value: q.id[ rowNum ], cfsqltype: "cf_sql_integer" } ],
				{ datasource: ds }
			) />
			<cfset deleted = deleted + 1 />
		</cfif>
	</cfloop>
	<cfset bogusCareer = application.scrapeOrchestrator.pruneCareerScanNonPostingJobs() />
	<cfset application.jobScoreService.refreshCompanyScores() />
	<cfoutput>OK: pruned #deleted# job(s) with no coldfusion / cfml / lucee / mura mention in title or description. Pruned #bogusCareer# career_page_scan row(s) whose link was not a job/ATS URL.</cfoutput>
	<cfcatch type="any">
		<cfheader statusCode="500" />
		<cfoutput>Error: #encodeForHTML( cfcatch.message )#</cfoutput>
	</cfcatch>
</cftry>
