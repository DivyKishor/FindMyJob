<cfsetting showdebugoutput="false" />
<!---
	Registers the "Lean" cost-tuned schedule (cfschedule / Lucee scheduler).
	Mirrors Application.registerScheduledTasks(); use this to (re)register with a
	custom base_url (e.g. your public host) or after changing the task key.

	  CF_Observer_Daily_Scrape   runDailyScrape.cfm        daily 06:00  (watcher→discovery→scrape→score→alerts)
	  CF_Observer_Fingerprint    fingerprintCompanies?max=75 daily 02:00 (rotates oldest first)
	  CF_Observer_Company_Score  scoreCompanies.cfm       daily 02:45
	  CF_Observer_Expiry_Check   checkJobExpiry?limit=60   every 3 days 03:15
	  CF_Observer_Source_Expand  expandSources.cfm        weekly 04:00

	Safe to re-run; action="update" creates or overwrites.
	The task key (security.task_key from AppConfig) is appended automatically when set,
	so scheduled HTTPRequests pass the /tasks/ guard.
--->

<cfparam name="url.base_url" default="http://127.0.0.1:8888" />
<cfset baseUrl = trim( url.base_url ) />
<cfset today   = dateFormat( now(), "mm/dd/yyyy" ) />
<cfset taskKey = structKeyExists( application, "appConfig" ) ? trim( application.appConfig.get( "security.task_key", "" ) ) : "" />
<cfset results = [] />

<cfset jobs = [
	{ name: "CF_Observer_Daily_Scrape",  path: "/tasks/runDailyScrape.cfm",                  time: "06:00 AM", interval: "daily" },
	{ name: "CF_Observer_Fingerprint",   path: "/tasks/fingerprintCompanies.cfm?max=75",     time: "02:00 AM", interval: "daily" },
	{ name: "CF_Observer_Company_Score", path: "/tasks/scoreCompanies.cfm",                  time: "02:45 AM", interval: "daily" },
	{ name: "CF_Observer_Expiry_Check",  path: "/tasks/checkJobExpiry.cfm?limit=60&min_days=7", time: "03:15 AM", interval: "259200" },
	{ name: "CF_Observer_Source_Expand", path: "/tasks/expandSources.cfm",                   time: "04:00 AM", interval: "604800" },
	{ name: "CF_Observer_Github",        path: "/tasks/harvestGithub.cfm?max=60",            time: "04:30 AM", interval: "604800" }
] />

<cfloop array="#jobs#" index="jobDef">
	<cftry>
		<cfset sep = ( find( "?", jobDef.path ) GT 0 ) ? "&" : "?" />
		<cfset fullUrl = baseUrl & jobDef.path & ( len( taskKey ) ? sep & "key=" & taskKey : "" ) />
		<cfschedule
			action="update"
			task="#jobDef.name#"
			operation="HTTPRequest"
			url="#fullUrl#"
			startDate="#today#"
			startTime="#jobDef.time#"
			interval="#jobDef.interval#"
			resolveUrl="no"
			publish="no"
		/>
		<cfset arrayAppend( results, { task: jobDef.name, status: "scheduled", time: jobDef.time, interval: jobDef.interval } ) />
	<cfcatch type="any">
		<cfset arrayAppend( results, { task: jobDef.name, status: "error", error: cfcatch.message } ) />
	</cfcatch>
	</cftry>
</cfloop>

<cfcontent type="application/json; charset=utf-8" />
<cfoutput>#serializeJSON({ ok: true, keyEnabled: ( len( taskKey ) GT 0 ), tasks: results, note: "Registered in Lucee scheduler. View in Lucee Admin -> Scheduled Tasks." })#</cfoutput>
