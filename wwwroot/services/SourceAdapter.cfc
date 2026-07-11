<cfcomponent output="false" accessors="true">
	<!---
		SourceAdapter — Phase 3, PR 3.3.

		Base contract for a config-driven source. A definition row (source_definitions)
		declares an adapter_kind; the registry maps that to a known onboarding behavior.
		Today the supported kinds resolve to the company/source rows the existing
		ScrapeOrchestrator already understands, so onboarding is data, not code.

		Subclasses/registry should implement onboard(definition, companyService) and
		return a struct { onboarded: boolean, careersSource: string, reason: string }.

		Tag syntax only (project standard).
	--->
	<cfproperty name="adapterKind" type="string" />

	<cffunction name="init" access="public" returntype="any" output="false">
		<cfargument name="adapterKind" type="string" required="false" default="base" />
		<cfset variables.adapterKind = arguments.adapterKind />
		<cfreturn this />
	</cffunction>

	<cffunction name="getAdapterKind" access="public" returntype="string" output="false">
		<cfreturn variables.adapterKind />
	</cffunction>

	<!--- Map an adapter_kind to the careers_source the orchestrator dispatches on. --->
	<cffunction name="careersSourceFor" access="public" returntype="string" output="false">
		<cfargument name="adapterKind" type="string" required="true" />
		<cfset var k = lCase( trim( arguments.adapterKind ) ) />
		<cfset var known = {
			"greenhouse": "greenhouse",
			"career_page_scan": "career_page_scan",
			"career_scan": "career_page_scan",
			"getcfmljobs": "getcfmljobs_feed",
			"remoteok": "remoteok_feed",
			"jobicy": "jobicy_feed",
			"adzuna": "adzuna_feed",
			"usajobs": "usajobs_feed",
			"reddit": "reddit_feed"
		} />
		<cfif structKeyExists( known, k )>
			<cfreturn known[ k ] />
		</cfif>
		<cfreturn "" />
	</cffunction>

	<cffunction name="isSupported" access="public" returntype="boolean" output="false">
		<cfargument name="adapterKind" type="string" required="true" />
		<cfreturn len( careersSourceFor( arguments.adapterKind ) ) GT 0 />
	</cffunction>
</cfcomponent>
