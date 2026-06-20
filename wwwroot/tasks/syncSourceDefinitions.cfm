<cfsetting showdebugoutput="false" requesttimeout="300" />
<cfcontent type="application/json; charset=utf-8" />
<!---
	Onboard config-driven sources.
	Optionally add/update one definition inline via URL params, then sync:
	  ?source_key=acme_scan&adapter_kind=career_page_scan&label=Acme&url=https://acme.com/careers
--->
<cftry>
	<cfif structKeyExists( url, "source_key" ) AND structKeyExists( url, "adapter_kind" )>
		<cfset application.sourceRegistryService.upsertDefinition(
			sourceKey   = url.source_key,
			adapterKind = url.adapter_kind,
			label       = structKeyExists( url, "label" ) ? url.label : "",
			urlTemplate = structKeyExists( url, "url" ) ? url.url : ""
		) />
	</cfif>
	<cfset summary = application.sourceRegistryService.syncDefinitions() />
	<cfoutput>#serializeJSON({ ok: true, onboarded: summary.onboarded, skipped: summary.skipped })#</cfoutput>
	<cfcatch type="any">
		<cfheader statusCode="500" />
		<cfoutput>#serializeJSON({ ok: false, error: cfcatch.message })#</cfoutput>
	</cfcatch>
</cftry>
