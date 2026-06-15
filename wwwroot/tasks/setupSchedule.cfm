<cfsetting showdebugoutput="false" />
<!---
	Registers two Lucee scheduled tasks:
	  1. CF_Observer_Daily_Scrape   — runs runDailyScrape.cfm every day at the configured time
	  2. CF_Observer_Expiry_Check   — runs checkJobExpiry.cfm every 3 days

	Adjust startTime and baseUrl below to match your environment.
	Safe to re-run; cfschedule action="update" creates or overwrites.
--->

<cfparam name="url.base_url" default="http://127.0.0.1:8888" />
<cfparam name="url.scrape_time" default="06:00 AM" />
<cfparam name="url.expiry_time" default="03:00 AM" />

<cfset baseUrl = trim( url.base_url ) />
<cfset scrapeTime = trim( url.scrape_time ) />
<cfset expiryTime = trim( url.expiry_time ) />
<cfset today = dateFormat( now(), "mm/dd/yyyy" ) />
<cfset results = [] />

<cftry>
	<cfschedule
		action="update"
		task="CF_Observer_Daily_Scrape"
		operation="HTTPRequest"
		url="#baseUrl#/tasks/runDailyScrape.cfm"
		startDate="#today#"
		startTime="#scrapeTime#"
		interval="daily"
		resolveUrl="no"
		publish="no"
	/>
	<cfset arrayAppend( results, { task: "CF_Observer_Daily_Scrape", status: "scheduled", time: scrapeTime, interval: "daily" } ) />
<cfcatch type="any">
	<cfset arrayAppend( results, { task: "CF_Observer_Daily_Scrape", status: "error", error: cfcatch.message } ) />
</cfcatch>
</cftry>

<cftry>
	<cfschedule
		action="update"
		task="CF_Observer_Expiry_Check"
		operation="HTTPRequest"
		url="#baseUrl#/tasks/checkJobExpiry.cfm?limit=60&min_days=7"
		startDate="#today#"
		startTime="#expiryTime#"
		interval="259200"
		resolveUrl="no"
		publish="no"
	/>
	<cfset arrayAppend( results, { task: "CF_Observer_Expiry_Check", status: "scheduled", time: expiryTime, interval: "every 3 days" } ) />
<cfcatch type="any">
	<cfset arrayAppend( results, { task: "CF_Observer_Expiry_Check", status: "error", error: cfcatch.message } ) />
</cfcatch>
</cftry>

<cfoutput>#serializeJSON({ ok: true, tasks: results, note: "Tasks registered in Lucee scheduler. View in Lucee Admin → Scheduled Tasks." })#</cfoutput>
