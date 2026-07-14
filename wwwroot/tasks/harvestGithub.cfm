<cfsetting showdebugoutput="false" requesttimeout="600" />
<cfcontent type="application/json; charset=utf-8" />
<!--- Discover CF companies + the employers of CF developers via GitHub.
      ?max=60 repos, ?expansions=20 org-affiliation lookups. --->
<cfparam name="url.max" default="60" />
<cfparam name="url.expansions" default="20" />
<cfparam name="url.gate" default="1" /><!--- 1 = careers-gate on (default), 0 = keep every org --->
<cftry>
	<cfset summary = application.githubDiscoveryService.harvestCompanies( val( url.max ), val( url.expansions ), ( val( url.gate ) EQ 1 ) ) />
	<cfoutput>#serializeJSON( {
		ok: true,
		tokenUsed: summary.tokenUsed,
		reposScanned: summary.reposScanned,
		devsSeen: summary.devsSeen,
		companiesUpserted: summary.companiesUpserted,
		companiesGated: summary.companiesGated,
		errors: summary.errors
	} )#</cfoutput>
	<cfcatch type="any">
		<cfheader statusCode="500" />
		<cfoutput>#serializeJSON( { ok: false, error: cfcatch.message } )#</cfoutput>
	</cfcatch>
</cftry>
