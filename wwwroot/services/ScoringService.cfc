<cfcomponent output="false" accessors="true">
	<cfproperty name="ruleVersion" type="string" />
	<cfproperty name="directKeywords" type="array" />

	<cffunction name="init" access="public" returntype="any" output="false">
		<cfset variables.ruleVersion = "v3_india_eligible" />
		<cfset variables.directKeywords = [ "coldfusion", "cfml", "lucee", "mura" ] />
		<!--- Secondary terms: full-stack roles that pair with CF backend tech. Only persist if a direct keyword also appears somewhere in title+desc. --->
		<cfset variables.fullStackSignals = [ "full stack", "fullstack", "full-stack" ] />
		<cfset variables.backendCfPairs = [ "coldfusion", "cfml", "lucee", "cold fusion", "adobe cf", "cf developer", "cfscript" ] />
		<cfreturn this />
	</cffunction>

	<cffunction name="scoreJob" access="public" returntype="struct" output="false">
		<cfargument name="title" type="string" required="true" />
		<cfargument name="description" type="string" required="false" default="" />
		<cfargument name="location" type="string" required="false" default="" />
		<cfset text = lCase( trim( arguments.title & " " & arguments.description ) ) />
		<cfset locText = lCase( trim( arguments.location ) ) />
		<cfset reasons = [] />
		<cfset s = 0 />

		<cfset directMatches = matchedTerms( text, variables.directKeywords ) />
		<cfset isFullStack = arrayLen( matchedTerms( text, variables.fullStackSignals ) ) GT 0 />
		<cfif arrayLen( directMatches ) GT 0>
			<cfset s = 50 />
			<cfset arrayAppend( reasons, "cf_keyword:" & arrayToList( directMatches, "," ) ) />
			<cfif isFullStack>
				<cfset arrayAppend( reasons, "fullstack_cf" ) />
			</cfif>
		<cfelseif isFullStack>
			<!--- Title says full-stack but no CF keyword in title+desc: skip --->
			<cfreturn { ruleVersion: variables.ruleVersion, score: 0, reasons: reasons, alertEligible: false, indiaEligible: "unknown" } />
		<cfelse>
			<cfreturn { ruleVersion: variables.ruleVersion, score: 0, reasons: reasons, alertEligible: false, indiaEligible: "unknown" } />
		</cfif>

		<cfset indiaEligible = classifyIndiaEligibility( text, locText ) />

		<cfif indiaEligible EQ "yes">
			<cfset s = s + 50 />
			<cfset arrayAppend( reasons, "india_eligible" ) />
		<cfelseif indiaEligible EQ "likely">
			<cfset s = s + 30 />
			<cfset arrayAppend( reasons, "india_likely" ) />
		<cfelseif indiaEligible EQ "no">
			<cfset s = s - 30 />
			<cfset arrayAppend( reasons, "work_auth_restricted" ) />
		</cfif>

		<cfif s LT 0><cfset s = 0 /></cfif>
		<cfif s GT 100><cfset s = 100 /></cfif>

		<cfreturn {
			ruleVersion: variables.ruleVersion,
			score: s,
			reasons: reasons,
			alertEligible: ( s GTE 70 ),
			indiaEligible: indiaEligible
		} />
	</cffunction>

	<cffunction name="classifyIndiaEligibility" access="public" returntype="string" output="false">
		<cfargument name="jobText" type="string" required="true" />
		<cfargument name="locationText" type="string" required="false" default="" />
		<cfset t = lCase( arguments.jobText ) />
		<cfset loc = lCase( arguments.locationText ) />

		<!--- India locations in title/desc/location --->
		<cfset indiaTerms = [ "india", "bengaluru", "bangalore", "hyderabad", "chennai", "mumbai", "pune", "delhi", "noida", "gurgaon", "gurugram", "kolkata", "ahmedabad", "jaipur", "kochi", "thiruvananthapuram", "coimbatore", "indore" ] />
		<cfloop array="#indiaTerms#" index="it">
			<cfif findNoCase( it, t ) GT 0 OR findNoCase( it, loc ) GT 0>
				<cfreturn "yes" />
			</cfif>
		</cfloop>

		<!--- Worldwide/anywhere remote signals --->
		<cfset globalRemote = [ "worldwide", "work from anywhere", "remote - global", "global remote", "remote worldwide", "anywhere in the world", "remote (global)", "remote - anywhere", "globally remote", "international remote" ] />
		<cfloop array="#globalRemote#" index="gr">
			<cfif findNoCase( gr, t ) GT 0 OR findNoCase( gr, loc ) GT 0>
				<cfreturn "yes" />
			</cfif>
		</cfloop>

		<!--- Work authorization blockers (US, Australia, UK, Canada, EU) --->
		<cfset blockers = [ "us citizen", "u.s. citizen", "united states citizen", "green card", "greencard", "h1b", "h-1b", "h1-b", "work authorization required", "authorized to work in the united states", "authorized to work in the us", "must be authorized to work in the u.s", "us work authorization", "ead or green card", "gc or citizen", "us persons", "itar restricted", "security clearance required", "secret clearance", "top secret", "public trust clearance", "australian citizen", "right to work in australia", "right to work in the uk", "right to work in canada", "eu work permit", "european work authorization" ] />
		<cfloop array="#blockers#" index="bl">
			<cfif findNoCase( bl, t ) GT 0>
				<cfreturn "no" />
			</cfif>
		</cfloop>

		<!--- US-only location signals (no remote + US city) --->
		<cfset usStates = [ "united states", ", us", ", usa", "new york", "california", "texas", "florida", "virginia", "maryland", "georgia", "illinois", "washington, dc", "d.c.", "pennsylvania", "ohio", "north carolina", "massachusetts", "new jersey", "arizona", "colorado", "michigan", "minnesota", "tennessee", "oregon", "connecticut", "utah", "iowa", "alabama", "louisiana", "kentucky" ] />
		<cfset hasRemote = ( findNoCase( "remote", t ) GT 0 OR findNoCase( "remote", loc ) GT 0 ) />

		<cfif NOT hasRemote>
			<cfloop array="#usStates#" index="us">
				<cfif findNoCase( us, loc ) GT 0>
					<cfreturn "no" />
				</cfif>
			</cfloop>
		</cfif>

		<cfif hasRemote AND len( loc ) GT 0>
			<cfset hasUsLoc = false />
			<cfloop array="#usStates#" index="us">
				<cfif findNoCase( us, loc ) GT 0><cfset hasUsLoc = true /><cfbreak /></cfif>
			</cfloop>
			<cfif hasUsLoc>
				<cfreturn "likely_no" />
			</cfif>
		</cfif>

		<cfif hasRemote>
			<cfreturn "likely" />
		</cfif>

		<cfreturn "unknown" />
	</cffunction>

	<cffunction name="matchedTerms" access="private" returntype="array" output="false">
		<cfargument name="haystack" type="string" required="true" />
		<cfargument name="terms" type="array" required="true" />
		<cfset out = [] />
		<cfloop array="#arguments.terms#" index="termItem">
			<cfif findNoCase( termItem, arguments.haystack ) GT 0>
				<cfset arrayAppend( out, termItem ) />
			</cfif>
		</cfloop>
		<cfreturn out />
	</cffunction>

	<cffunction name="getRuleVersion" access="public" returntype="string" output="false">
		<cfreturn variables.ruleVersion />
	</cffunction>

	<cffunction name="shouldPersistJob" access="public" returntype="boolean" output="false">
		<cfargument name="title" type="string" required="true" />
		<cfargument name="description" type="string" required="false" default="" />
		<cfset text = lCase( trim( arguments.title & " " & arguments.description ) ) />
		<cfif arrayLen( matchedTerms( text, variables.directKeywords ) ) GT 0>
			<cfreturn true />
		</cfif>
		<!--- Full-stack posting where CF appears as backend tech anywhere in the combined text --->
		<cfif arrayLen( matchedTerms( text, variables.fullStackSignals ) ) GT 0 AND arrayLen( matchedTerms( text, variables.backendCfPairs ) ) GT 0>
			<cfreturn true />
		</cfif>
		<cfreturn false />
	</cffunction>
</cfcomponent>
