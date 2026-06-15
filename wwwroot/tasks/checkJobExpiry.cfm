<cfsetting showdebugoutput="false" requesttimeout="900" />
<cfparam name="url.limit" default="50" />
<cfparam name="url.min_days" default="7" />

<cftry>
	<cfset summary = application.expiryCheckerService.checkBatch(
		val( url.limit ),
		val( url.min_days )
	) />
	<cfoutput>#serializeJSON({ ok: true, checked: summary.checked, active: summary.active, expired: summary.expired, errors: summary.errors })#</cfoutput>
<cfcatch type="any">
	<cfoutput>#serializeJSON({ ok: false, error: cfcatch.message })#</cfoutput>
</cfcatch>
</cftry>
