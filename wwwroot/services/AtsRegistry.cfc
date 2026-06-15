<cfcomponent output="false" accessors="true">
	<!---
		AtsRegistry — declarative catalogue of Applicant Tracking Systems and the
		URL fingerprints that identify a job/board page on each.

		Replaces the ad-hoc findNoCase() OR-chain that lived inside
		ScrapeOrchestrator.isProbableJobPostingUrl. New ATS providers are added by
		appending a row here, not by editing scraping logic.

		Each provider: { key, label, patterns:[ url substrings ] }.
		Tag syntax only (project standard).
	--->
	<cfproperty name="providers" type="array" />
	<cfproperty name="genericJobPathPatterns" type="array" />

	<cffunction name="init" access="public" returntype="any" output="false">
		<cfset variables.providers = [
			{ key: "greenhouse", label: "Greenhouse",
			  patterns: [ "boards.greenhouse.io", "job-boards.greenhouse.io", "greenhouse.io/embed", "gh_jid" ] },
			{ key: "lever",          label: "Lever",           patterns: [ "lever.co", "jobs.lever.co" ] },
			{ key: "workday",        label: "Workday",         patterns: [ "myworkdayjobs.com", ".workday.com" ] },
			{ key: "smartrecruiters",label: "SmartRecruiters", patterns: [ "smartrecruiters.com" ] },
			{ key: "ashby",          label: "Ashby",           patterns: [ "ashbyhq.com", "jobs.ashbyhq.com" ] },
			{ key: "icims",          label: "iCIMS",           patterns: [ "icims.com" ] },
			{ key: "taleo",          label: "Taleo",           patterns: [ "taleo.net", "taleo" ] },
			{ key: "brassring",      label: "BrassRing",       patterns: [ "brassring" ] },
			{ key: "successfactors", label: "SAP SuccessFactors", patterns: [ "successfactors", "jobs.sap.com" ] },
			{ key: "jobvite",        label: "Jobvite",         patterns: [ "jobvite.com" ] },
			{ key: "bamboohr",       label: "BambooHR",        patterns: [ "bamboohr.com" ] },
			{ key: "rippling",       label: "Rippling",        patterns: [ "rippling.com", "ats.rippling.com" ] },
			{ key: "darwinbox",      label: "Darwinbox",       patterns: [ "darwinbox" ] },
			{ key: "workable",       label: "Workable",        patterns: [ "workable.com", "apply.workable.com" ] },
			{ key: "recruitee",      label: "Recruitee",       patterns: [ "recruitee.com" ] },
			{ key: "personio",       label: "Personio",        patterns: [ "personio.com", "jobs.personio" ] },
			{ key: "teamtailor",     label: "Teamtailor",      patterns: [ "teamtailor.com" ] },
			{ key: "breezy",         label: "Breezy HR",       patterns: [ "breezy.hr" ] },
			{ key: "jazzhr",         label: "JazzHR",          patterns: [ "applytojob.com", "jazz.co" ] },
			{ key: "adp",            label: "ADP Workforce Now", patterns: [ "workforcenow.adp.com", "recruiting.adp.com" ] },
			{ key: "oracle",         label: "Oracle Cloud HCM", patterns: [ "oraclecloud.com/hcmui", "oraclecloud.com" ] },
			{ key: "zohorecruit",    label: "Zoho Recruit",    patterns: [ "zohorecruit" ] },
			{ key: "cutshort",       label: "Cutshort",        patterns: [ "cutshort.io" ] },
			{ key: "linkedin",       label: "LinkedIn Jobs",   patterns: [ "linkedin.com/jobs" ] },
			{ key: "indeed",         label: "Indeed",          patterns: [ "indeed." ] },
			{ key: "glassdoor",      label: "Glassdoor",       patterns: [ "glassdoor." ] }
		] />

		<!--- Provider-agnostic patterns that still strongly imply a job/posting URL. --->
		<cfset variables.genericJobPathPatterns = [
			"/job", "/jobs/", "/jobs/view/", "/jobs/search", "/job-search", "viewjob",
			"?job=", "&job=", "requisition", "/position/", "/opening/", "/vacancy",
			"/opportunit", "/apply", "/careers/"
		] />
		<cfreturn this />
	</cffunction>

	<cffunction name="getProviders" access="public" returntype="array" output="false">
		<cfreturn variables.providers />
	</cffunction>

	<cffunction name="getGenericJobPathPatterns" access="public" returntype="array" output="false">
		<cfreturn variables.genericJobPathPatterns />
	</cffunction>

	<!--- Return the provider key whose pattern appears in the URL, or "" if none. --->
	<cffunction name="detectProvider" access="public" returntype="string" output="false">
		<cfargument name="url" type="string" required="true" />
		<cfset var u = lCase( trim( arguments.url ) ) />
		<cfset var p = "" />
		<cfset var pat = "" />
		<cfif NOT len( u )><cfreturn "" /></cfif>
		<cfloop array="#variables.providers#" index="p">
			<cfloop array="#p.patterns#" index="pat">
				<cfif findNoCase( pat, u ) GT 0>
					<cfreturn p.key />
				</cfif>
			</cfloop>
		</cfloop>
		<cfreturn "" />
	</cffunction>

	<!--- True when the URL matches any known ATS pattern or generic job-path pattern. --->
	<cffunction name="matchesKnownPattern" access="public" returntype="boolean" output="false">
		<cfargument name="url" type="string" required="true" />
		<cfset var u = lCase( trim( arguments.url ) ) />
		<cfset var pat = "" />
		<cfif NOT len( u )><cfreturn false /></cfif>
		<cfif len( detectProvider( u ) )><cfreturn true /></cfif>
		<cfloop array="#variables.genericJobPathPatterns#" index="pat">
			<cfif findNoCase( pat, u ) GT 0>
				<cfreturn true />
			</cfif>
		</cfloop>
		<cfreturn false />
	</cffunction>
</cfcomponent>
