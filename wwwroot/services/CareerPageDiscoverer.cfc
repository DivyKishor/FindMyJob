<cfcomponent output="false" accessors="true">
	<!---
		CareerPageDiscoverer — career/job link classification & URL helpers.

		First behaviour-preserving extraction of the self-contained URL utilities
		from the 2.8k-line ScrapeOrchestrator. The orchestrator keeps thin private
		shims that delegate here, so every existing caller works unchanged while the
		god object shrinks and this logic becomes independently testable.

		Tag syntax only (project standard).
	--->
	<cfproperty name="atsDetector" type="any" />

	<cffunction name="init" access="public" returntype="any" output="false">
		<cfargument name="atsDetector" type="any" required="false" default="" />
		<cfif isObject( arguments.atsDetector )>
			<cfset variables.atsDetector = arguments.atsDetector />
		<cfelse>
			<cfset variables.atsDetector = createObject( "component", "services.AtsDetector" ).init() />
		</cfif>
		<cfreturn this />
	</cffunction>

	<!--- Bare host (no scheme/path/port/www) from a URL. --->
	<cffunction name="extractHostFromUrl" access="public" returntype="string" output="false">
		<cfargument name="urlText" type="string" required="true" />
		<cfset var u = trim( arguments.urlText ) />
		<cfif NOT len( u )><cfreturn "" /></cfif>
		<cfset var h = reReplaceNoCase( u, "^[a-z]+://", "", "one" ) />
		<cfset h = reReplace( h, "[/?##].*$", "", "one" ) />
		<cfif find( "@", h ) GT 0><cfset h = listLast( h, "@" ) /></cfif>
		<cfset h = listFirst( h, ":" ) />
		<cfset h = lCase( trim( h ) ) />
		<cfif left( h, 4 ) EQ "www."><cfset h = mid( h, 5, len( h ) ) /></cfif>
		<cfreturn h />
	</cffunction>

	<!--- True if the host is a job board / aggregator / social site (not an employer site). --->
	<cffunction name="isJobBoardOrSocialHost" access="public" returntype="boolean" output="false">
		<cfargument name="host" type="string" required="true" />
		<cfset var h = lCase( trim( arguments.host ) ) />
		<cfif NOT len( h )><cfreturn true /></cfif>
		<cfset var blocked = "linkedin.com,indeed.com,glassdoor.com,dice.com,ziprecruiter.com,monster.com,simplyhired.com,
			careerbuilder.com,devjobsscanner.com,devitjobs.com,devitjobs.us,devitjobs.uk,wellfound.com,angel.co,
			remoteok.com,remotive.com,weworkremotely.com,jobicy.com,arbeitnow.com,stackoverflow.com,
			boards.greenhouse.io,job-boards.greenhouse.io,greenhouse.io,jobs.lever.co,lever.co,
			myworkdayjobs.com,workday.com,smartrecruiters.com,ashbyhq.com,icims.com,jobvite.com,bamboohr.com,
			taleo.net,brassring.com,successfactors.com,jobs.jobvite.com,naukri.com,foundit.in,monsterindia.com,
			shine.com,instahyre.com,cutshort.io,weekday.works,jooble.org,adzuna.com,usajobs.gov,
			facebook.com,twitter.com,x.com,reddit.com,youtube.com,medium.com,github.com,
			google.com,bing.com,wikipedia.org,crunchbase.com,zoominfo.com,levels.fyi,
			builtin.com,themuse.com,jobserve.com,cwjobs.co.uk,totaljobs.com,reed.co.uk,seek.com.au,
			talent.com,jobstreet.com,glints.com,hired.com,toptal.com,arc.dev" />
		<cfset var b = "" />
		<cfset var bb = "" />
		<cfloop list="#blocked#" index="b" delimiters=",#chr(10)##chr(13)#">
			<cfset bb = trim( b ) />
			<cfif NOT len( bb )><cfcontinue /></cfif>
			<cfif h EQ bb><cfreturn true /></cfif>
			<cfif len( h ) GT len( bb ) AND right( h, len( bb ) + 1 ) EQ "." & bb><cfreturn true /></cfif>
		</cfloop>
		<cfreturn false />
	</cffunction>

	<!--- True if a full URL looks like a specific job/listing page (ATS or path heuristics). --->
	<cffunction name="hrefLooksLikeJobListingPath" access="public" returntype="boolean" output="false">
		<cfargument name="fullUrl" type="string" required="true" />
		<cfset var u = lCase( trim( arguments.fullUrl ) ) />
		<cfif findNoCase( "gh_jid", u ) GT 0 OR findNoCase( "?job=", u ) GT 0 OR findNoCase( "&job=", u ) GT 0 OR findNoCase( "myworkdayjobs.com", u ) GT 0 OR findNoCase( "lever.co", u ) GT 0 OR findNoCase( "boards.greenhouse.io", u ) GT 0 OR findNoCase( "job-boards.greenhouse.io", u ) GT 0 OR findNoCase( "smartrecruiters.com", u ) GT 0 OR findNoCase( "ashbyhq.com", u ) GT 0 OR findNoCase( "icims.com", u ) GT 0 OR findNoCase( "successfactors.com", u ) GT 0 OR findNoCase( "taleo.net", u ) GT 0 OR findNoCase( "bamboohr.com", u ) GT 0 OR findNoCase( "darwinbox", u ) GT 0 OR findNoCase( "cutshort.io", u ) GT 0 OR findNoCase( "/job/", u ) GT 0 OR findNoCase( "/jobs/", u ) GT 0 OR findNoCase( "/jobs/search", u ) GT 0 OR findNoCase( "/job-search", u ) GT 0 OR findNoCase( "/position", u ) GT 0 OR findNoCase( "/opening", u ) GT 0 OR findNoCase( "/vacancy", u ) GT 0 OR findNoCase( "/requisition", u ) GT 0>
			<cfreturn true />
		</cfif>
		<cfif findNoCase( "/careers/", u ) GT 0 AND listLen( reReplace( listLast( u, "/" ), "[?##].*$", "", "all" ), "-" ) GTE 3>
			<cfreturn true />
		</cfif>
		<cfreturn false />
	</cffunction>

	<!--- Resolve a possibly-relative target URL against a base URL. --->
	<cffunction name="absolutizeUrl" access="public" returntype="string" output="false">
		<cfargument name="baseUrl" type="string" required="true" />
		<cfargument name="targetUrl" type="string" required="true" />
		<cftry>
			<cfset var baseObj = createObject( "java", "java.net.URL" ).init( arguments.baseUrl ) />
			<cfset var resolvedObj = createObject( "java", "java.net.URL" ).init( baseObj, arguments.targetUrl ) />
			<cfreturn toString( resolvedObj.toString() ) />
			<cfcatch type="any">
				<cfif left( arguments.targetUrl, 4 ) EQ "http">
					<cfreturn arguments.targetUrl />
				</cfif>
				<cfreturn "" />
			</cfcatch>
		</cftry>
	</cffunction>

	<!--- Extract the href value from a single anchor tag's HTML. --->
	<cffunction name="extractHref" access="public" returntype="string" output="false">
		<cfargument name="anchorHtml" type="string" required="true" />
		<cfset var hrefPos = findNoCase( "href", arguments.anchorHtml ) />
		<cfif hrefPos LTE 0><cfreturn "" /></cfif>
		<cfset var eqPos = find( "=", arguments.anchorHtml, hrefPos ) />
		<cfif eqPos LTE 0><cfreturn "" /></cfif>
		<cfset var rawValue = trim( mid( arguments.anchorHtml, eqPos + 1, len( arguments.anchorHtml ) - eqPos ) ) />
		<cfif NOT len( rawValue )><cfreturn "" /></cfif>
		<cfset var firstChar = left( rawValue, 1 ) />
		<cfset var endPos = 0 />
		<cfif firstChar EQ chr(34) OR firstChar EQ chr(39)>
			<cfset endPos = find( firstChar, rawValue, 2 ) />
			<cfif endPos GT 2>
				<cfreturn trim( mid( rawValue, 2, endPos - 2 ) ) />
			</cfif>
		<cfelse>
			<cfset var endSpace = find( " ", rawValue ) />
			<cfset var endTag = find( ">", rawValue ) />
			<cfif endSpace GT 0 AND endTag GT 0>
				<cfset endPos = min( endSpace, endTag ) />
			<cfelseif endSpace GT 0>
				<cfset endPos = endSpace />
			<cfelseif endTag GT 0>
				<cfset endPos = endTag />
			<cfelse>
				<cfset endPos = 0 />
			</cfif>
			<cfif endPos GT 1>
				<cfreturn trim( left( rawValue, endPos - 1 ) ) />
			</cfif>
		</cfif>
		<cfreturn "" />
	</cffunction>

	<!--- First candidate URL that looks like a real job posting (vs the careers index). --->
	<cffunction name="firstProbableJobUrlFromArray" access="public" returntype="string" output="false">
		<cfargument name="candidateUrls" type="array" required="true" />
		<cfargument name="careersUrl" type="string" required="true" />
		<cfset var cand = "" />
		<cfloop array="#arguments.candidateUrls#" index="cand">
			<cfif variables.atsDetector.isProbableJobPostingUrl( cand, arguments.careersUrl )>
				<cfreturn cand />
			</cfif>
		</cfloop>
		<cfreturn "" />
	</cffunction>
</cfcomponent>
