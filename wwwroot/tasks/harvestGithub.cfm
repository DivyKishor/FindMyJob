<cfsetting showdebugoutput="false" requesttimeout="600" />
<cfcontent type="application/json; charset=utf-8" />
<!--- Discover CF companies + the employers of CF developers via GitHub.
      ?max=60 repos, ?expansions=20 org-affiliation lookups. --->
<cfparam name="url.max" default="60" />
<cfparam name="url.expansions" default="20" />
<cftry>
	<cfset summary = application.githubDiscoveryService.harvestCompanies( val( url.max ), val( url.expansions ) ) />
	<cfoutput>#serializeJSON( {
		ok: true,
		tokenUsed: summary.tokenUsed,
		reposScanned: summary.reposScanned,
		devsSeen: summary.devsSeen,
		companiesUpserted: summary.companiesUpserted,
		errors: summary.errors
	} )#</cfoutput>
	<cfcatch type="any">
		<cfheader statusCode="500" />
		<cfoutput>#serializeJSON( { ok: false, error: cfcatch.message } )#</cfoutput>
	</cfcatch>
</cftry>
