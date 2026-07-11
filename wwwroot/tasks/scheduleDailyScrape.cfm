<cfsetting showdebugoutput="false" />
<cfcontent type="application/json; charset=utf-8" />
<!---
	Simple one-task scheduler.
	Registers a Lucee scheduled task that runs runDailyScrape.cfm once a day.
	Runs INSIDE Lucee, so it reaches localhost with no sandbox/network issue.
	Open this page once in a browser to (re)register the task.
	Safe to re-run: action="update" creates or overwrites.

	Optional URL params:
	  ?scrape_time=06:00 AM   (when to run, default 06:00 AM)
	  ?base_url=http://127.0.0.1:8888
--->
<cfparam name="url.base_url"    default="http://127.0.0.1:8888" />
<cfparam name="url.scrape_time" default="06:00 AM" />

<cftry>
	<cfschedule
		action="update"
		task="CF_Observer_Daily_Scrape"
		operation="HTTPRequest"
		url="#trim(url.base_url)#/tasks/runDailyScrape.cfm"
		startDate="#dateFormat(now(),'mm/dd/yyyy')#"
		startTime="#trim(url.scrape_time)#"
		interval="daily"
		resolveUrl="no"
		publish="no"
	/>
	<cfoutput>#serializeJSON({
		ok: true,
		task: "CF_Observer_Daily_Scrape",
		runs: "#trim(url.base_url)#/tasks/runDailyScrape.cfm",
		time: trim(url.scrape_time),
		interval: "daily",
		note: "Registered in Lucee scheduler. View/edit in Lucee Admin -> Scheduled Tasks."
	})#</cfoutput>
<cfcatch type="any">
	<cfheader statusCode="500" />
	<cfoutput>#serializeJSON({ ok: false, error: cfcatch.message })#</cfoutput>
</cfcatch>
</cftry>
