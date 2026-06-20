<cfcomponent output="false" accessors="true">
	<!---
		GithubDiscoveryService — discover companies that USE ColdFusion and EMPLOY CF developers,
		via the GitHub REST API (legal, free; 5,000 req/hr with a token, 60/hr without).

		Strategy:
		  1. Search ColdFusion / CFML repositories → repo owners.
		  2. Owner is an Organization  -> that org IS a CF company.
		  3. Owner is a User (a CF dev) -> seed their `company` field AND their public org
		     affiliations (a proxy for current + past employers — the "LinkedIn work history" gap).
		Discovered companies are inserted as `career_page_scan` rows so the daily scrape, the
		Phase-2 fingerprinter, and company scoring all pick them up automatically.

		Token from AppConfig: secrets.github_token. Quota-bounded by SourceQuotaService.
		Tag syntax only (project standard).
	--->
	<cfproperty name="gw" type="any" />
	<cfproperty name="http" type="any" />
	<cfproperty name="loggerService" type="any" />
	<cfproperty name="graph" type="any" />
	<cfproperty name="careers" type="any" />

	<cffunction name="init" access="public" returntype="any" output="false">
		<cfargument name="dataGateway"       type="any" required="true" />
		<cfargument name="httpClientService" type="any" required="true" />
		<cfargument name="appConfig"         type="any" required="true" />
		<cfargument name="loggerService"     type="any" required="false" default="" />
		<cfargument name="graphService"      type="any" required="false" default="" />
		<cfargument name="careerDiscoverer"  type="any" required="false" default="" /><!--- CareerPageDiscoverer: host classification --->
		<cfset variables.gw = arguments.dataGateway />
		<cfset variables.http = arguments.httpClientService />
		<cfset variables.loggerService = arguments.loggerService />
		<cfset variables.graph = arguments.graphService />
		<cfset variables.careers = arguments.careerDiscoverer />
		<cfset variables.requireCareersGate = true /><!--- only keep orgs whose site shows a careers/hiring signal --->
		<cfset variables.gatedThisRun = 0 />
		<cfset variables.token = trim( arguments.appConfig.secret( "github_token" ) ) />
		<cfset variables.headers = {
			"Accept": "application/vnd.github+json",
			"User-Agent": "CF-Observer",
			"X-GitHub-Api-Version": "2022-11-28"
		} />
		<cfif len( variables.token )>
			<cfset variables.headers[ "Authorization" ] = "Bearer " & variables.token />
		</cfif>
		<cfreturn this />
	</cffunction>

	<cffunction name="isConfigured" access="public" returntype="boolean" output="false">
		<cfreturn len( variables.token ) GT 0 />
	</cffunction>

	<!--- ===== orchestration ===== --->
	<cffunction name="harvestCompanies" access="public" returntype="struct" output="false">
		<cfargument name="maxRepos" type="numeric" required="false" default="60" />
		<cfargument name="maxUserExpansions" type="numeric" required="false" default="20" /><!--- limit org-affiliation lookups (API cost) --->
		<cfargument name="requireCareers" type="boolean" required="false" default="true" /><!--- careers-gate: drop orgs with no hiring signal --->
		<cfset variables.requireCareersGate = arguments.requireCareers />
		<cfset variables.gatedThisRun = 0 />
		<cfset var summary = { reposScanned: 0, devsSeen: 0, companiesUpserted: 0, companiesGated: 0, tokenUsed: isConfigured(), errors: [] } />
		<cfset var seen = {} />
		<cfset var userExpansions = 0 />
		<cfset var langs = [ "ColdFusion", "CFML" ] />
		<cfset var perPage = 50 />
		<cfset var lang = "" />

		<cfloop array="#langs#" index="lang">
			<cfif summary.reposScanned GTE arguments.maxRepos><cfbreak /></cfif>
			<cfset var maxPages = ceiling( arguments.maxRepos / perPage ) />
			<cfif maxPages GT 2><cfset maxPages = 2 /></cfif>
			<cfloop from="1" to="#maxPages#" index="pg">
				<cfif summary.reposScanned GTE arguments.maxRepos><cfbreak /></cfif>
				<cftry>
					<cfset var data = ghGet( "/search/repositories?q=" & urlEncodedFormat( "language:" & lang )
						& "&sort=updated&per_page=" & perPage & "&page=" & pg ) />
					<cfif NOT isStruct( data ) OR NOT structKeyExists( data, "items" )><cfbreak /></cfif>
					<cfset var repo = "" />
					<cfloop array="#data.items#" index="repo">
						<cfif summary.reposScanned GTE arguments.maxRepos><cfbreak /></cfif>
						<cfset summary.reposScanned = summary.reposScanned + 1 />
						<cfif NOT structKeyExists( repo, "owner" )><cfcontinue /></cfif>
						<cfset var ownerType = structKeyExists( repo.owner, "type" ) ? repo.owner.type : "" />
						<cfset var login = structKeyExists( repo.owner, "login" ) ? repo.owner.login : "" />
						<cfif NOT len( login )><cfcontinue /></cfif>

						<cfif ownerType EQ "Organization">
							<cfset summary.companiesUpserted = summary.companiesUpserted + seedFromOrg( login, seen ) />
						<cfelse>
							<cfset summary.devsSeen = summary.devsSeen + 1 />
							<cfset summary.companiesUpserted = summary.companiesUpserted + seedFromUser( login, seen, ( userExpansions LT arguments.maxUserExpansions ) ) />
							<cfif userExpansions LT arguments.maxUserExpansions><cfset userExpansions = userExpansions + 1 /></cfif>
						</cfif>
						<cfset sleepMs( 120 ) />
					</cfloop>
					<cfcatch type="any">
						<cfset arrayAppend( summary.errors, "search #lang# p#pg#: " & cfcatch.message ) />
					</cfcatch>
				</cftry>
			</cfloop>
		</cfloop>

		<cfset summary.companiesGated = variables.gatedThisRun />
		<cfset recordYield( "github:company_discovery", summary.reposScanned, summary.companiesUpserted ) />
		<cfif isObject( variables.loggerService )>
			<cfset variables.loggerService.info( "GitHub discovery: repos=#summary.reposScanned# devs=#summary.devsSeen# companies=#summary.companiesUpserted# gated=#summary.companiesGated#" ) />
		</cfif>
		<cfreturn summary />
	</cffunction>

	<!--- ===== owners ===== --->
	<cffunction name="seedFromOrg" access="private" returntype="numeric" output="false">
		<cfargument name="login" type="string" required="true" />
		<cfargument name="seen" type="struct" required="true" />
		<cftry>
			<cfset var org = ghGet( "/orgs/" & arguments.login ) />
			<cfif NOT isStruct( org )><cfreturn 0 /></cfif>
			<cfset var name = ( structKeyExists( org, "name" ) AND len( trim( org.name ) ) ) ? org.name : arguments.login />
			<cfset var site = structKeyExists( org, "blog" ) AND isSimpleValue( org.blog ) ? trim( org.blog ) : "" />
			<cfreturn upsertCompany( name, site, "github_org", arguments.seen ) />
			<cfcatch type="any"><cfreturn 0 /></cfcatch>
		</cftry>
	</cffunction>

	<cffunction name="seedFromUser" access="private" returntype="numeric" output="false">
		<cfargument name="login" type="string" required="true" />
		<cfargument name="seen" type="struct" required="true" />
		<cfargument name="expandOrgs" type="boolean" required="false" default="false" />
		<cfset var added = 0 />
		<cftry>
			<cfset var user = ghGet( "/users/" & arguments.login ) />
			<cfif isStruct( user ) AND structKeyExists( user, "company" ) AND isSimpleValue( user.company ) AND len( trim( user.company ) )>
				<cfset var site = structKeyExists( user, "blog" ) AND isSimpleValue( user.blog ) ? trim( user.blog ) : "" />
				<cfset added = added + upsertCompany( cleanCompanyName( user.company ), site, "github_user_company", arguments.seen ) />
			</cfif>
			<!--- Employment-history proxy: orgs the dev is a public member of. --->
			<cfif arguments.expandOrgs>
				<cfset var orgs = ghGet( "/users/" & arguments.login & "/orgs" ) />
				<cfif isArray( orgs )>
					<cfset var o = "" />
					<cfloop array="#orgs#" index="o">
						<cfif structKeyExists( o, "login" )>
							<cfset added = added + seedFromOrg( o.login, arguments.seen ) />
						</cfif>
					</cfloop>
				</cfif>
			</cfif>
			<cfcatch type="any"></cfcatch>
		</cftry>
		<cfreturn added />
	</cffunction>

	<!--- ===== persistence ===== --->
	<cffunction name="upsertCompany" access="private" returntype="numeric" output="false">
		<cfargument name="name" type="string" required="true" />
		<cfargument name="website" type="string" required="true" />
		<cfargument name="src" type="string" required="true" />
		<cfargument name="seen" type="struct" required="true" />
		<cfset var nm = trim( arguments.name ) />
		<cfset var site = normalizeUrl( arguments.website ) />
		<cfif NOT len( nm ) OR NOT len( site )><cfreturn 0 /></cfif><!--- need a scannable URL --->
		<cfset var key = lCase( nm ) />
		<cfif structKeyExists( arguments.seen, key )><cfreturn 0 /></cfif>
		<cfset arguments.seen[ key ] = true />

		<!--- Skip if a company with this website or name already exists. --->
		<cfset var existing = val( variables.gw.scalar(
			"SELECT COUNT(*) FROM companies WHERE lower(name) = ? OR (website <> '' AND lower(website) = ?)",
			[ { value: lCase( nm ), cfsqltype: "cf_sql_varchar" }, { value: lCase( site ), cfsqltype: "cf_sql_varchar" } ], 0 ) ) />
		<cfif existing GT 0><cfreturn 0 /></cfif>

		<!--- Careers-gate: only keep orgs whose site actually shows a hiring signal.
		     Filters OSS projects / docs sites / ecosystem orgs that never hire. --->
		<cfif variables.requireCareersGate AND NOT passesCareersGate( nm, site )>
			<cfset variables.gatedThisRun = variables.gatedThisRun + 1 />
			<cfreturn 0 />
		</cfif>

		<cfset variables.gw.execute(
			"INSERT INTO companies (name, website, careers_url, careers_source, ats_config, created_at, updated_at)
			 VALUES (?, ?, ?, 'career_page_scan', ?, " & variables.gw.nowExpr() & ", " & variables.gw.nowExpr() & ")",
			[
				{ value: left( nm, 200 ), cfsqltype: "cf_sql_varchar" },
				{ value: site, cfsqltype: "cf_sql_varchar" },
				{ value: site, cfsqltype: "cf_sql_varchar" },
				{ value: serializeJSON( { discovery_source: arguments.src } ), cfsqltype: "cf_sql_longvarchar" }
			]
		) />
		<cfreturn 1 />
	</cffunction>

	<!--- ===== helpers ===== --->
	<cffunction name="ghGet" access="private" returntype="any" output="false">
		<cfargument name="path" type="string" required="true" />
		<cfset var body = variables.http.getTextWithHeaders( "https://api.github.com" & arguments.path, variables.headers, 30 ) />
		<cfreturn deserializeJSON( body ) />
	</cffunction>

	<!--- Clean a GitHub `company` value: drop leading @, collapse whitespace. --->
	<cffunction name="cleanCompanyName" access="public" returntype="string" output="false">
		<cfargument name="raw" type="string" required="true" />
		<cfset var c = trim( arguments.raw ) />
		<cfset c = reReplace( c, "^@+", "", "one" ) />
		<cfset c = reReplace( c, "\s+", " ", "all" ) />
		<cfreturn trim( c ) />
	</cffunction>

	<!--- Normalize a blog/website value into an http(s) URL, or "" if not usable. --->
	<cffunction name="normalizeUrl" access="public" returntype="string" output="false">
		<cfargument name="raw" type="string" required="true" />
		<cfset var u = trim( arguments.raw ) />
		<cfif NOT len( u )><cfreturn "" /></cfif>
		<cfif reFindNoCase( "^https?://", u ) EQ 0><cfset u = "https://" & u /></cfif>
		<cfif reFindNoCase( "^https?://[a-z0-9.\-]+\.[a-z]{2,}", u ) EQ 0><cfreturn "" /></cfif>
		<cfreturn u />
	</cffunction>

	<cffunction name="recordYield" access="private" returntype="void" output="false">
		<cfargument name="sourceKey" type="string" required="true" />
		<cfargument name="items" type="numeric" required="true" />
		<cfargument name="companies" type="numeric" required="true" />
		<cfif isObject( variables.graph )>
			<cftry>
				<cfset variables.graph.registerSource( arguments.sourceKey, "github", arguments.sourceKey, "active" ) />
				<cfset variables.graph.recordRun( sourceKey = arguments.sourceKey, itemsFound = arguments.items, companiesFound = arguments.companies ) />
				<cfcatch type="any"></cfcatch>
			</cftry>
		</cfif>
	</cffunction>

	<cffunction name="sleepMs" access="private" returntype="void" output="false">
		<cfargument name="ms" type="numeric" required="true" />
		<cftry><cfset sleep( arguments.ms ) /><cfcatch type="any"></cfcatch></cftry>
	</cffunction>

	<!--- ===== careers-gate (precision filter for GitHub-discovered orgs) ===== --->
	<!--- True only if the candidate site looks like an employer that is hiring.
	     Rejects doc/project hosts and job-board/social hosts cheaply, then fetches
	     the homepage and requires a careers/hiring signal in the markup. --->
	<cffunction name="passesCareersGate" access="private" returntype="boolean" output="false">
		<cfargument name="name" type="string" required="true" />
		<cfargument name="site" type="string" required="true" />
		<cfset var host = hostOf( arguments.site ) />
		<cfif NOT len( host )><cfreturn false /></cfif>
		<cfif isLikelyNonEmployerHost( host )><cfreturn false /></cfif>
		<cfif isObject( variables.careers ) AND variables.careers.isJobBoardOrSocialHost( host )><cfreturn false /></cfif>
		<cfset var html = "" />
		<cftry>
			<cfset html = variables.http.getText( arguments.site, 12 ) />
			<cfcatch type="any"><cfset html = "" /></cfcatch>
		</cftry>
		<cfif NOT len( html )><cfreturn false /></cfif>
		<cfreturn careersSignalInHtml( html ) />
	</cffunction>

	<!--- Bare host (no scheme/path/port/www) from a URL. --->
	<cffunction name="hostOf" access="public" returntype="string" output="false">
		<cfargument name="urlText" type="string" required="true" />
		<cfset var h = trim( arguments.urlText ) />
		<cfif NOT len( h )><cfreturn "" /></cfif>
		<cfset h = reReplaceNoCase( h, "^[a-z]+://", "", "one" ) />
		<cfset h = reReplace( h, "[/?##].*$", "", "one" ) />
		<cfset h = listFirst( h, ":" ) />
		<cfset h = lCase( trim( h ) ) />
		<cfif left( h, 4 ) EQ "www."><cfset h = mid( h, 5, len( h ) ) /></cfif>
		<cfreturn h />
	</cffunction>

	<!--- Documentation / project / static-hosting hosts that never represent an employer. --->
	<cffunction name="isLikelyNonEmployerHost" access="public" returntype="boolean" output="false">
		<cfargument name="host" type="string" required="true" />
		<cfset var h = lCase( trim( arguments.host ) ) />
		<cfif NOT len( h )><cfreturn true /></cfif>
		<cfif left( h, 5 ) EQ "docs." OR left( h, 5 ) EQ "blog." OR left( h, 4 ) EQ "wiki"><cfreturn true /></cfif>
		<cfset var suffixes = "js.org,github.io,gitbook.io,readthedocs.io,readthedocs.org,netlify.app,vercel.app,pages.dev,gitlab.io,surge.sh,web.app,firebaseapp.com,herokuapp.com" />
		<cfset var s = "" />
		<cfloop list="#suffixes#" index="s">
			<cfset s = trim( s ) />
			<cfif len( h ) GTE len( s ) AND right( h, len( s ) + 1 ) EQ "." & s><cfreturn true /></cfif>
			<cfif h EQ s><cfreturn true /></cfif>
		</cfloop>
		<cfreturn false />
	</cffunction>

	<!--- True if the page markup carries a careers / hiring / ATS signal. --->
	<cffunction name="careersSignalInHtml" access="public" returntype="boolean" output="false">
		<cfargument name="html" type="string" required="true" />
		<cfset var h = lCase( arguments.html ) />
		<cfif NOT len( h )><cfreturn false /></cfif>
		<!--- Phrase / path signals (careers nav, hiring copy, openings). --->
		<cfset var phrases = [
			"/careers", "/career", "career-opportunities", ">careers<", "careers</a", "we're hiring",
			"we are hiring", "now hiring", "join our team", "join the team", "join us", "work with us",
			"open positions", "open roles", "current openings", "job openings", "/jobs", "view jobs",
			"our openings", "vacancies", "life at", "come work" ] />
		<cfset var p = "" />
		<cfloop array="#phrases#" index="p">
			<cfif findNoCase( p, h ) GT 0><cfreturn true /></cfif>
		</cfloop>
		<!--- ATS host references embedded in links. --->
		<cfset var atsHosts = [
			"boards.greenhouse.io", "job-boards.greenhouse.io", "jobs.lever.co", "myworkdayjobs.com",
			"ashbyhq.com", "smartrecruiters.com", "bamboohr.com", "jobvite.com", "icims.com",
			"workable.com", "recruitee.com", "teamtailor.com", "breezy.hr", "applytojob.com", "workday.com" ] />
		<cfset var a = "" />
		<cfloop array="#atsHosts#" index="a">
			<cfif findNoCase( a, h ) GT 0><cfreturn true /></cfif>
		</cfloop>
		<cfreturn false />
	</cffunction>
</cfcomponent>
