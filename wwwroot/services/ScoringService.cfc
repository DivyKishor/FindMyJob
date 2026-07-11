<cfcomponent output="false" accessors="true">
	<!---
		ScoringService — v6_sponsor_aware (Phase 2 + post-demo refinement).

		Composes four independent scoring layers so each concern is testable in isolation:

		  cf_match         Taxonomy-driven keyword match (required baseline).    0 or 50
		  geo_eligibility  Geography / work-auth check (was classifyIndiaEligibility).
		                     yes→+50  likely→+30  likely_no→0  no→−30  unknown→0
		  remote_fit       Explicit remote-work signal bonus.                    0 or +10
		  visa_sponsorship Employer explicitly offers visa sponsorship.          0 or +20
		                     If present, it OVERRIDES the geo work-auth penalty
		                     (a sponsoring US role is a top match, not a blocked one).
		  ─────────────────────────────────────────────────────────────────────────────
		  Total capped 0–100.  Alert threshold: ≥ 70.

		Backward compatibility:
		  • scoreJob() return struct retains the `indiaEligible` key (alias for geoEligibility)
		    so callers built against v4 continue to work.
		  • classifyIndiaEligibility() is kept as a public deprecated alias.
		  • shouldPersistJob() is unchanged.

		Tag syntax only (project standard).
	--->

	<cfproperty name="ruleVersion"    type="string" />
	<cfproperty name="directKeywords" type="array"  />
	<cfproperty name="taxonomy"       type="any"    />

	<cffunction name="init" access="public" returntype="any" output="false">
		<cfargument name="taxonomy" type="any" required="false" default="" />
		<cfif isObject( arguments.taxonomy )>
			<cfset variables.taxonomy = arguments.taxonomy />
		<cfelse>
			<cfset variables.taxonomy = createObject( "component", "services.TechTaxonomy" ).init() />
		</cfif>
		<!--- v6: visa sponsorship now OVERRIDES the work-auth penalty (a sponsoring US role
		     is a top result for someone who needs sponsorship), and weighs more (+20). --->
		<cfset variables.ruleVersion      = "v7_sponsor_negation" />
		<cfset variables.directKeywords   = variables.taxonomy.allAliases() />
		<cfset variables.fullStackSignals = [ "full stack", "fullstack", "full-stack" ] />
		<cfset variables.backendCfPairs   = variables.taxonomy.allAliases() />

		<!--- Worldwide / anywhere remote signals (geo_eligibility "yes"). --->
		<cfset variables.globalRemote = [
			"worldwide", "work from anywhere", "remote - global", "global remote",
			"remote worldwide", "anywhere in the world", "remote (global)",
			"remote - anywhere", "globally remote", "international remote"
		] />

		<!--- Work-authorisation blockers — geo_eligibility "no".
		     Note: h1b/h-1b intentionally excluded — those strings also appear in positive
		     visa-sponsorship phrases ("H-1B sponsorship available") and are handled by
		     sponsorPositives in classifyVisaSponsorship() instead. --->
		<cfset variables.workAuthBlockers = [
			"us citizen", "u.s. citizen", "united states citizen",
			"green card", "greencard",
			"work authorization required",
			"authorized to work in the united states",
			"authorized to work in the us",
			"must be authorized to work in the u.s",
			"us work authorization", "ead or green card", "gc or citizen",
			"us persons", "itar restricted",
			"security clearance required", "secret clearance", "top secret", "public trust clearance",
			"australian citizen", "right to work in australia",
			"right to work in the uk", "right to work in canada",
			"eu work permit", "european work authorization",
			"without employer sponsorship", "without sponsorship", "no visa sponsorship",
			"no employer sponsorship", "permanent resident", "us permanent resident"
		] />

		<!--- Explicit visa-sponsorship positive signals.
		     Deliberately VISA-specific: bare "we sponsor"/"will sponsor"/"sponsorship available"
		     are excluded because they also match non-visa sponsorship (e.g. "we sponsor
		     employees for Security Clearance"). --->
		<cfset variables.sponsorPositives = [
			"visa sponsorship", "visa sponsor", "sponsor visa", "sponsor a visa",
			"sponsor work visa", "work visa sponsorship", "sponsoring visa",
			"will sponsor visa", "we sponsor visa", "able to sponsor visa", "can sponsor visa",
			"provide visa sponsorship", "offer visa sponsorship", "visa support provided",
			"h-1b sponsorship", "h1b sponsorship", "h-1b sponsor", "h1b sponsor",
			"sponsor h-1b", "sponsor h1b", "sponsoring h-1b", "sponsoring h1b",
			"green card sponsorship", "immigration sponsorship", "employment-based visa"
		] />

		<!--- Negative sponsorship phrases. These contain the word "sponsorship" but mean the
		     OPPOSITE (no sponsorship). Checked BEFORE positives so "no H-1B sponsorship" /
		     "without employer sponsorship" are never counted as a positive, and they also
		     mark the role as work-auth restricted. --->
		<cfset variables.sponsorNegatives = [
			"without employer sponsorship", "without sponsorship", "without need for sponsorship",
			"without requiring sponsorship", "no visa sponsorship", "no employer sponsorship",
			"no sponsorship", "not provide sponsorship", "does not provide sponsorship",
			"do not provide sponsorship", "not offer sponsorship", "does not offer sponsorship",
			"unable to sponsor", "not able to sponsor", "are not able to sponsor",
			"will not sponsor", "cannot sponsor", "can not sponsor", "not sponsor",
			"sponsorship is not available", "sponsorship not available", "no h-1b sponsorship", "no h1b sponsorship"
		] />

		<cfreturn this />
	</cffunction>

	<!--- ===== Primary scoring entry point ===== --->

	<cffunction name="scoreJob" access="public" returntype="struct" output="false">
		<cfargument name="title"       type="string" required="true" />
		<cfargument name="description" type="string" required="false" default="" />
		<cfargument name="location"    type="string" required="false" default="" />

		<cfset var text    = lCase( trim( arguments.title & " " & arguments.description ) ) />
		<cfset var locText = lCase( trim( arguments.location ) ) />
		<cfset var reasons = [] />
		<cfset var s       = 0 />

		<!--- Layer 1: cf_match — required; returns early with 0 if no CF tech detected. --->
		<cfset var directMatches = variables.taxonomy.matchText( text ) />
		<cfset var isFullStack   = arrayLen( matchedTerms( text, variables.fullStackSignals ) ) GT 0 />
		<cfif arrayLen( directMatches ) GT 0>
			<cfset s = 50 />
			<cfset arrayAppend( reasons, "cf_tech:" & arrayToList( directMatches, "," ) ) />
			<cfif isFullStack><cfset arrayAppend( reasons, "fullstack_cf" ) /></cfif>
		<cfelse>
			<!--- No CF keyword found — score 0 regardless of other signals. --->
			<cfreturn {
				ruleVersion:      variables.ruleVersion,
				score:            0,
				reasons:          reasons,
				alertEligible:    false,
				indiaEligible:    "unknown",
				geoEligibility:   "unknown",
				remoteFit:        0,
				visaSponsorship:  0
			} />
		</cfif>

		<!--- Visa sponsorship is computed first because it overrides the work-auth penalty. --->
		<cfset var visaBonus = classifyVisaSponsorship( text ) />
		<cfset var hasSponsor = ( visaBonus GT 0 ) />

		<!--- Layer 2: geo_eligibility (formerly classifyIndiaEligibility). --->
		<cfset var geoResult = classifyGeoEligibility( text, locText ) />
		<cfif geoResult EQ "yes">
			<cfset s = s + 50 />
			<cfset arrayAppend( reasons, "india_eligible" ) />
		<cfelseif geoResult EQ "likely">
			<cfset s = s + 30 />
			<cfset arrayAppend( reasons, "india_likely" ) />
		<cfelseif geoResult EQ "no">
			<cfif hasSponsor>
				<!--- Employer sponsors a visa, so the work-auth restriction does not block this seeker. --->
				<cfset arrayAppend( reasons, "work_auth_offset_by_sponsorship" ) />
			<cfelse>
				<cfset s = s - 30 />
				<cfset arrayAppend( reasons, "work_auth_restricted" ) />
			</cfif>
		</cfif>

		<!--- Layer 3: remote_fit — additive +10 for any explicit remote signal. --->
		<cfset var remoteBonus = classifyRemoteFit( text, locText ) />
		<cfif remoteBonus GT 0>
			<cfset s = s + remoteBonus />
			<cfset arrayAppend( reasons, "remote_fit:+" & remoteBonus ) />
		</cfif>

		<!--- Layer 4: visa_sponsorship — strong additive (+20); a sponsoring role is a top match. --->
		<cfif hasSponsor>
			<cfset s = s + visaBonus />
			<cfset arrayAppend( reasons, "visa_sponsorship:+" & visaBonus ) />
		</cfif>

		<cfif s LT 0><cfset s = 0 /></cfif>
		<cfif s GT 100><cfset s = 100 /></cfif>

		<cfreturn {
			ruleVersion:      variables.ruleVersion,
			score:            s,
			reasons:          reasons,
			alertEligible:    ( s GTE 70 ),
			indiaEligible:    geoResult,
			geoEligibility:   geoResult,
			remoteFit:        remoteBonus,
			visaSponsorship:  visaBonus
		} />
	</cffunction>

	<!--- ===== Scoring layers ===== --->

	<!---
		classifyGeoEligibility — geography + work-auth classification.
		Identical logic to v4 classifyIndiaEligibility; renamed for clarity.
		Returns: "yes" | "likely" | "likely_no" | "no" | "unknown"
	--->
	<cffunction name="classifyGeoEligibility" access="public" returntype="string" output="false">
		<cfargument name="jobText"      type="string" required="true" />
		<cfargument name="locationText" type="string" required="false" default="" />
		<cfset var t   = lCase( arguments.jobText ) />
		<cfset var loc = lCase( arguments.locationText ) />

		<!--- India city / country (word-boundary so "indiana" does not match "india"). --->
		<cfset var indiaTerms = [
			"india", "bengaluru", "bangalore", "hyderabad", "chennai", "mumbai",
			"pune", "delhi", "noida", "gurgaon", "gurugram", "kolkata",
			"ahmedabad", "jaipur", "kochi", "thiruvananthapuram", "coimbatore", "indore"
		] />
		<cfloop array="#indiaTerms#" index="it">
			<cfif termMatchesInText( t, it ) OR termMatchesInText( loc, it )>
				<cfreturn "yes" />
			</cfif>
		</cfloop>

		<!--- Worldwide / anywhere remote (also counts as India-accessible). --->
		<cfloop array="#variables.globalRemote#" index="gr">
			<cfif findNoCase( gr, t ) GT 0 OR findNoCase( gr, loc ) GT 0>
				<cfreturn "yes" />
			</cfif>
		</cfloop>

		<!--- Work-authorisation blockers. --->
		<cfloop array="#variables.workAuthBlockers#" index="bl">
			<cfif findNoCase( bl, t ) GT 0>
				<cfreturn "no" />
			</cfif>
		</cfloop>

		<!--- US-only location (no remote context). --->
		<cfset var usStates = [
			"united states", ", us", ", usa",
			"indiana", "indianapolis", "new york", "california", "texas", "florida",
			"virginia", "maryland", "georgia", "illinois", "washington, dc", "d.c.",
			"pennsylvania", "ohio", "north carolina", "massachusetts", "new jersey",
			"arizona", "colorado", "michigan", "minnesota", "tennessee", "oregon",
			"connecticut", "utah", "iowa", "alabama", "louisiana", "kentucky"
		] />
		<cfset var hasRemote = ( findNoCase( "remote", t ) GT 0 OR findNoCase( "remote", loc ) GT 0 ) />

		<cfif NOT hasRemote>
			<cfloop array="#usStates#" index="us">
				<cfif findNoCase( us, loc ) GT 0><cfreturn "no" /></cfif>
			</cfloop>
		</cfif>

		<cfif hasRemote AND len( loc ) GT 0>
			<cfset var hasUsLoc = false />
			<cfloop array="#usStates#" index="us">
				<cfif findNoCase( us, loc ) GT 0><cfset hasUsLoc = true /><cfbreak /></cfif>
			</cfloop>
			<cfif hasUsLoc><cfreturn "likely_no" /></cfif>
		</cfif>

		<cfif hasRemote><cfreturn "likely" /></cfif>
		<cfreturn "unknown" />
	</cffunction>

	<!---
		classifyRemoteFit — small bonus for any explicit remote-work signal.
		Returns: 10 if remote in text/location, 0 otherwise.
	--->
	<cffunction name="classifyRemoteFit" access="public" returntype="numeric" output="false">
		<cfargument name="jobText"      type="string" required="true" />
		<cfargument name="locationText" type="string" required="false" default="" />
		<cfif findNoCase( "remote", arguments.jobText ) GT 0
		   OR findNoCase( "remote", arguments.locationText ) GT 0>
			<cfreturn 10 />
		</cfif>
		<cfreturn 0 />
	</cffunction>

	<!---
		classifyVisaSponsorship — bonus when the employer explicitly offers visa sponsorship.
		Returns: 20 if positive sponsorship language found, 0 otherwise.
		Negative phrases ("no/without ... sponsorship") are checked first and force 0.
	--->
	<cffunction name="classifyVisaSponsorship" access="public" returntype="numeric" output="false">
		<cfargument name="jobText" type="string" required="true" />
		<cfset var t = lCase( trim( arguments.jobText ) ) />
		<!--- Negatives win: "no H-1B sponsorship" must NOT count as sponsorship. --->
		<cfloop array="#variables.sponsorNegatives#" index="neg">
			<cfif findNoCase( neg, t ) GT 0><cfreturn 0 /></cfif>
		</cfloop>
		<cfloop array="#variables.sponsorPositives#" index="sp">
			<cfif findNoCase( sp, t ) GT 0><cfreturn 20 /></cfif>
		</cfloop>
		<cfreturn 0 />
	</cffunction>

	<!---
		classifyIndiaEligibility — deprecated public alias for classifyGeoEligibility.
		Kept for backward compatibility with callers that used the v4 API name.
	--->
	<cffunction name="classifyIndiaEligibility" access="public" returntype="string" output="false">
		<cfargument name="jobText"      type="string" required="true" />
		<cfargument name="locationText" type="string" required="false" default="" />
		<cfreturn classifyGeoEligibility( arguments.jobText, arguments.locationText ) />
	</cffunction>

	<!--- ===== Helper / utility methods ===== --->

	<cffunction name="termMatchesInText" access="public" returntype="boolean" output="false">
		<cfargument name="haystack" type="string" required="true" />
		<cfargument name="term"     type="string" required="true" />
		<cfset var h    = lCase( trim( arguments.haystack ) ) />
		<cfset var term = lCase( trim( arguments.term ) ) />
		<cfif NOT len( h ) OR NOT len( term )><cfreturn false /></cfif>
		<cfif find( " ", term ) GT 0><cfreturn findNoCase( term, h ) GT 0 /></cfif>
		<cfset var escaped = reReplace( term, "([\.\^\$\|\?\*\+\(\)\[\]\{\}\\])", "\\\1", "all" ) />
		<cfreturn reFindNoCase( "\b#escaped#\b", h, 1 ) GT 0 />
	</cffunction>

	<cffunction name="matchedTerms" access="private" returntype="array" output="false">
		<cfargument name="haystack" type="string" required="true" />
		<cfargument name="terms"    type="array"  required="true" />
		<cfset var out = [] />
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
		<cfargument name="title"       type="string" required="true" />
		<cfargument name="description" type="string" required="false" default="" />
		<cfset var text = lCase( trim( arguments.title & " " & arguments.description ) ) />
		<cfif variables.taxonomy.matchesAny( text )><cfreturn true /></cfif>
		<cfif arrayLen( matchedTerms( text, variables.fullStackSignals ) ) GT 0
		   AND arrayLen( matchedTerms( text, variables.backendCfPairs ) ) GT 0>
			<cfreturn true />
		</cfif>
		<cfreturn false />
	</cffunction>

</cfcomponent>
