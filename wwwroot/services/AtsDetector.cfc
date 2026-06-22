<cfcomponent output="false" accessors="true">
	<!---
		AtsDetector — decides whether a URL is a job posting and which ATS it
		belongs to, using the declarative AtsRegistry.

		Behaviour-preserving replacement for ScrapeOrchestrator.isProbableJobPostingUrl:
		  1. Known ATS / generic job-path pattern  -> job posting.
		  2. Otherwise, a same-host URL that is deeper than the careers page and
		     mentions career/job in its path -> job posting.

		Tag syntax only (project standard).
	--->
	<cfproperty name="registry" type="any" />

	<cffunction name="init" access="public" returntype="any" output="false">
		<cfargument name="registry" type="any" required="false" default="" />
		<cfif isObject( arguments.registry )>
			<cfset variables.registry = arguments.registry />
		<cfelse>
			<cfset variables.registry = createObject( "component", "services.AtsRegistry" ).init() />
		</cfif>
		<cfreturn this />
	</cffunction>

	<cffunction name="detectProvider" access="public" returntype="string" output="false">
		<cfargument name="url" type="string" required="true" />
		<cfreturn variables.registry.detectProvider( arguments.url ) />
	</cffunction>

	<cffunction name="isProbableJobPostingUrl" access="public" returntype="boolean" output="false">
		<cfargument name="jobUrl" type="string" required="true" />
		<cfargument name="careersUrl" type="string" required="false" default="" />
		<cfif NOT len( trim( arguments.jobUrl ) )>
			<cfreturn false />
		</cfif>

		<!--- 1) Known ATS host or generic job-path pattern. --->
		<cfif variables.registry.matchesKnownPattern( arguments.jobUrl )>
			<cfreturn true />
		</cfif>

		<cfif NOT len( trim( arguments.careersUrl ) )>
			<cfreturn false />
		</cfif>

		<!--- 2) Same-host, deeper-than-careers path mentioning career/job. --->
		<cftry>
			<cfset var ju = createObject( "java", "java.net.URL" ).init( trim( arguments.jobUrl ) ) />
			<cfset var jc = createObject( "java", "java.net.URL" ).init( trim( arguments.careersUrl ) ) />
			<cfcatch type="any">
				<cfreturn false />
			</cfcatch>
		</cftry>

		<cfif normalizeUrlForCompare( ju.toString() ) EQ normalizeUrlForCompare( jc.toString() )>
			<cfreturn false />
		</cfif>
		<cfif ju.getHost() EQ jc.getHost()>
			<cfset var p = lCase( ju.getPath() ) />
			<cfset var pClean = reReplace( p, "^/+", "", "all" ) />
			<cfif len( pClean ) AND listLen( pClean, "/" ) GTE 3 AND ( find( "career", pClean ) OR find( "job", pClean ) )>
				<cfreturn true />
			</cfif>
		</cfif>
		<cfreturn false />
	</cffunction>

	<cffunction name="normalizeUrlForCompare" access="public" returntype="string" output="false">
		<cfargument name="url" type="string" required="true" />
		<cfset var u = lCase( trim( arguments.url ) ) />
		<cfset u = reReplaceNoCase( u, "^https?://", "", "one" ) />
		<cfset u = reReplaceNoCase( u, "^www\.", "", "one" ) />
		<cfset u = reReplace( u, "/+$", "", "one" ) />
		<cfreturn u />
	</cffunction>
</cfcomponent>
