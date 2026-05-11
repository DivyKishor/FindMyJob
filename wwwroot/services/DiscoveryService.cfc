<cfcomponent output="false" accessors="true">
	<cfproperty name="databaseService" type="any" />
	<cfproperty name="httpClientService" type="any" />
	<cfproperty name="loggerService" type="any" />
	<cfproperty name="companyService" type="any" />
	<cfproperty name="sourceQuotaService" type="any" />

	<cffunction name="init" access="public" returntype="any" output="false">
		<cfargument name="databaseService" type="any" required="true" />
		<cfargument name="httpClientService" type="any" required="true" />
		<cfargument name="loggerService" type="any" required="true" />
		<cfargument name="companyService" type="any" required="true" />
		<cfargument name="sourceQuotaService" type="any" required="true" />
		<cfset variables.databaseService = arguments.databaseService />
		<cfset variables.httpClientService = arguments.httpClientService />
		<cfset variables.loggerService = arguments.loggerService />
		<cfset variables.companyService = arguments.companyService />
		<cfset variables.sourceQuotaService = arguments.sourceQuotaService />
		<cfreturn this />
	</cffunction>

	<cffunction name="ds" access="private" returntype="string" output="false">
		<cfreturn variables.databaseService.getDatasource() />
	</cffunction>

	<cffunction name="runDiscovery" access="public" returntype="struct" output="false">
		<cfargument name="forceRun" type="boolean" required="false" default="false" />
		<cfset queryPlans = buildQueryPlans() />
		<cfset seenDomains = {} />
		<cfset summary = { queriesTried: 0, signalsStored: 0, companiesUpserted: 0, errors: [] } />

		<cfloop array="#queryPlans#" index="plan">
			<cfset sourceKey = "discovery:" & hash( plan.signal_type & "|" & plan.query_text ) />
			<cfif NOT arguments.forceRun>
				<cfset quota = variables.sourceQuotaService.canRun( sourceKey, 1, 720 ) />
				<cfif NOT quota.allowed>
					<cfcontinue />
				</cfif>
			</cfif>

			<cftry>
				<cfset rows = fetchSearchResults( plan.query_text ) />
				<cfif NOT isArray( rows )><cfset rows = [] /></cfif>
				<cfset summary.queriesTried = summary.queriesTried + 1 />
				<cfloop array="#rows#" index="rowItem">
					<cfset combinedEvidence = rowItem.title & " " & rowItem.snippet & " " & rowItem.url />
					<cfif NOT isRelevantSignal( combinedEvidence, plan.query_text, plan.signal_type )>
						<cfcontinue />
					</cfif>
					<cfset domain = extractDomain( rowItem.url ) />
					<cfif isNonEmployerSignalHost( domain )>
						<cfcontinue />
					</cfif>
					<cfset companyName = inferCompanyName( domain ) />
					<cfset confidence = estimateConfidence( plan.query_text, combinedEvidence ) />
					<!--- Do not persist forum/social threads as dashboard signals (not company career pages) --->
					<cfif plan.signal_type NEQ "community_signal">
						<cfset insertSignal(
							signalType = plan.signal_type,
							sourceName = plan.source_name,
							queryText = plan.query_text,
							companyName = companyName,
							companyDomain = domain,
							targetUrl = rowItem.url,
							evidenceText = left( rowItem.title & " | " & rowItem.snippet, 900 ),
							confidenceScore = confidence
						) />
						<cfset summary.signalsStored = summary.signalsStored + 1 />
					</cfif>
					<cfif plan.signal_type EQ "community_signal">
						<cfcontinue />
					</cfif>

					<cfif NOT shouldUpsertCompany( domain, rowItem.url, plan.signal_type, combinedEvidence )>
						<cfcontinue />
					</cfif>
					<cfif structKeyExists( seenDomains, domain )>
						<cfcontinue />
					</cfif>
					<cfset seenDomains[ domain ] = true />
					<cfset baseUrl = "https://" & domain />
					<cfset careersUrl = deriveCareersUrl( baseUrl, plan.query_text ) />
					<cfset variables.companyService.upsertDiscoveredCompany(
						name = companyName,
						website = baseUrl,
						careersUrl = careersUrl,
						discoverySource = plan.signal_type
					) />
					<cfset summary.companiesUpserted = summary.companiesUpserted + 1 />
				</cfloop>
				<cfset variables.sourceQuotaService.markRun( sourceKey ) />
				<cfset sleepMs( 250 ) />
				<cfcatch type="any">
					<cfset rawCatch = "" />
					<cftry>
						<cfset rawCatch = serializeJSON( cfcatch ) />
						<cfcatch type="any"><cfset rawCatch = "" /></cfcatch>
					</cftry>
					<cfset arrayAppend( summary.errors, "Discovery query failed: #plan.query_text# :: #cfcatch.message# :: #cfcatch.detail#" ) />
					<cfset variables.loggerService.warn( "Discovery query failed (#plan.query_text#): #cfcatch.message# :: #cfcatch.detail# :: #left( rawCatch, 1200 )#" ) />
				</cfcatch>
			</cftry>
		</cfloop>

		<cfset variables.loggerService.info( "Discovery finished: queries=#summary.queriesTried# signals=#summary.signalsStored# companies=#summary.companiesUpserted#" ) />
		<cfreturn summary />
	</cffunction>

	<cffunction name="buildQueryPlans" access="private" returntype="array" output="false">
		<cfreturn [
			{ signal_type: "job_discovery", source_name: "bing_rss", query_text: "coldfusion developer jobs India" },
			{ signal_type: "job_discovery", source_name: "bing_rss", query_text: "cfml developer India hiring" },
			{ signal_type: "job_discovery", source_name: "bing_rss", query_text: "lucee developer India job" },
			{ signal_type: "job_discovery", source_name: "bing_rss", query_text: "coldfusion remote developer job worldwide" },
			{ signal_type: "job_discovery", source_name: "bing_rss", query_text: "hiring coldfusion developer remote" },
			{ signal_type: "job_discovery", source_name: "bing_rss", query_text: "coldfusion developer Bangalore Hyderabad" },
			{ signal_type: "job_discovery", source_name: "bing_rss", query_text: "coldfusion developer jobs company" },
			{ signal_type: "job_discovery", source_name: "bing_rss", query_text: "cfml jobs company" },
			{ signal_type: "job_discovery", source_name: "bing_rss", query_text: "lucee developer job opening" },
			{ signal_type: "career_keyword", source_name: "bing_rss", query_text: "coldfusion careers India" },
			{ signal_type: "career_keyword", source_name: "bing_rss", query_text: "cfml engineer careers page" },
			{ signal_type: "stack_detection", source_name: "bing_rss", query_text: "builtwith coldfusion sites India" },
			{ signal_type: "stack_detection", source_name: "bing_rss", query_text: "coldfusion companies India" },
			{ signal_type: "stack_detection", source_name: "bing_rss", query_text: "cfml websites list" },
			{ signal_type: "stack_detection", source_name: "bing_rss", query_text: "powered by lucee website" },
			{ signal_type: "ecosystem_signal", source_name: "bing_rss", query_text: "coldbox users company" },
			{ signal_type: "ecosystem_signal", source_name: "bing_rss", query_text: "lucee server companies India" },
			{ signal_type: "ecosystem_signal", source_name: "bing_rss", query_text: "ortus solutions coldfusion" },
			{ signal_type: "community_signal", source_name: "bing_rss", query_text: "coldfusion developer India community" },
			{ signal_type: "community_signal", source_name: "bing_rss", query_text: "cfml companies discussion" },
			{ signal_type: "community_signal", source_name: "bing_rss", query_text: "companies still using coldfusion" },
			{ signal_type: "job_discovery", source_name: "bing_rss", query_text: "full stack developer coldfusion India" },
			{ signal_type: "job_discovery", source_name: "bing_rss", query_text: "fullstack coldfusion backend developer remote" },
			{ signal_type: "job_discovery", source_name: "bing_rss", query_text: "full stack coldfusion developer hiring" },
			{ signal_type: "job_discovery", source_name: "bing_rss", query_text: "full stack developer cfml backend India" },
			{ signal_type: "job_discovery", source_name: "bing_rss", query_text: "coldfusion developer Pune Hyderabad Bengaluru hiring" },
			{ signal_type: "job_discovery", source_name: "bing_rss", query_text: "cfml developer Kerala Trivandrum Kochi hiring" },
			{ signal_type: "job_discovery", source_name: "bing_rss", query_text: "coldfusion developer Chennai Noida Mumbai hiring" },
			{ signal_type: "career_keyword", source_name: "bing_rss", query_text: "coldfusion outsourcing company India careers" },
			{ signal_type: "career_keyword", source_name: "bing_rss", query_text: "cfml development company India hiring" },
			{ signal_type: "stack_detection", source_name: "bing_rss", query_text: "Liventus coldfusion India developer" },
			{ signal_type: "stack_detection", source_name: "bing_rss", query_text: "Stridely Solutions coldfusion developer" },
			{ signal_type: "stack_detection", source_name: "bing_rss", query_text: "TELUS Digital coldfusion Noida" },
			{ signal_type: "stack_detection", source_name: "bing_rss", query_text: "Infoane Technologies coldfusion Hyderabad" },
			{ signal_type: "stack_detection", source_name: "bing_rss", query_text: "Neologix coldfusion Trivandrum developer" },
			{ signal_type: "stack_detection", source_name: "bing_rss", query_text: "Aumni Techworks coldfusion Pune" },
			{ signal_type: "job_discovery", source_name: "bing_rss", query_text: "coldfusion developer jobs India site:naukri.com" },
			{ signal_type: "job_discovery", source_name: "bing_rss", query_text: "coldfusion developer India site:glassdoor.co.in" },
			{ signal_type: "job_discovery", source_name: "bing_rss", query_text: "coldfusion developer India site:indeed.co.in" },
			{ signal_type: "job_discovery", source_name: "bing_rss", query_text: "coldfusion developer India site:instahyre.com" },
			{ signal_type: "job_discovery", source_name: "bing_rss", query_text: "coldfusion developer India site:expertini.com" },
			{ signal_type: "job_discovery", source_name: "bing_rss", query_text: "coldfusion developer India site:jooble.org" },
			{ signal_type: "job_discovery", source_name: "bing_rss", query_text: "coldfusion developer Accenture India hiring 2026" },
			{ signal_type: "job_discovery", source_name: "bing_rss", query_text: "In Time Tec coldfusion developer Bangalore" },
			{ signal_type: "job_discovery", source_name: "bing_rss", query_text: "Reveille Technologies coldfusion developer Pune" },
			{ signal_type: "job_discovery", source_name: "bing_rss", query_text: "TeachEdison coldfusion developer India" },
			{ signal_type: "job_discovery", source_name: "bing_rss", query_text: "coldfusion developer India site:trabajo.org" },
			{ signal_type: "career_keyword", source_name: "bing_rss", query_text: "coldfusion developer freelance India Toptal Arc.dev" }
		] />
	</cffunction>

	<cffunction name="listRecentSignals" access="public" returntype="array" output="false">
		<cfargument name="limit" type="numeric" required="false" default="40" />
		<cfargument name="sortBy" type="string" required="false" default="created_at" />
		<cfargument name="sortDir" type="string" required="false" default="desc" />
		<cfif arguments.limit LT 1><cfset arguments.limit = 40 /></cfif>
		<cfif arguments.limit GT 200><cfset arguments.limit = 200 /></cfif>
		<cfset sb = lCase( trim( arguments.sortBy ) ) />
		<cfset sd = lCase( trim( arguments.sortDir ) ) />
		<cfif sd NEQ "asc"><cfset sd = "desc" /></cfif>
		<cfif listFindNoCase( "created_at,confidence_score,company_domain,signal_type,query_text", sb ) EQ 0><cfset sb = "created_at" /></cfif>
		<cfset orderCol = "datetime(created_at)" />
		<cfif sb EQ "confidence_score"><cfset orderCol = "confidence_score" /></cfif>
		<cfif sb EQ "company_domain"><cfset orderCol = "lower(company_domain)" /></cfif>
		<cfif sb EQ "signal_type"><cfset orderCol = "signal_type" /></cfif>
		<cfif sb EQ "query_text"><cfset orderCol = "query_text" /></cfif>
		<cfset q = queryExecute(
			"SELECT id, signal_type, query_text, company_name, company_domain, target_url, evidence_text, confidence_score, created_at
			 FROM discovery_signals
			 WHERE signal_type <> 'community_signal'
			   AND company_domain NOT LIKE '%reddit%'
			   AND company_domain NOT LIKE '%stackoverflow%'
			   AND company_domain NOT LIKE '%stackexchange%'
			   AND company_domain NOT LIKE '%community.adobe%'
			   AND company_domain NOT LIKE '%forums.adobe%'
			 ORDER BY " & orderCol & " " & uCase( sd ) & "
			 LIMIT ?",
			[ { value: arguments.limit, cfsqltype: "cf_sql_integer" } ],
			{ datasource: ds() }
		) />
		<cfreturn variables.databaseService.queryToArray( q ) />
	</cffunction>

	<cffunction name="fetchSearchResults" access="private" returntype="array" output="false">
		<cfargument name="queryText" type="string" required="true" />
		<cftry>
			<cfset requestUrl = "https://www.bing.com/search?format=rss&q=" & urlEncodedFormat( arguments.queryText ) />
			<cfset body = variables.httpClientService.getText( requestUrl, 15 ) />
			<cfset xmlDoc = xmlParse( body ) />
			<cfset itemNodes = xmlSearch( xmlDoc, "/rss/channel/item" ) />
			<cfset out = [] />
			<cfif isArray( itemNodes )>
				<cfloop array="#itemNodes#" index="itemNode">
					<cfset title = getFirstXmlValue( xmlSearch( itemNode, "title/text()" ) ) />
					<cfset link = getFirstXmlValue( xmlSearch( itemNode, "link/text()" ) ) />
					<cfset snippet = getFirstXmlValue( xmlSearch( itemNode, "description/text()" ) ) />
					<cfif len( trim( link ) )>
						<cfset arrayAppend( out, { title: title, url: link, snippet: snippet } ) />
					</cfif>
				</cfloop>
			</cfif>
			<cfreturn out />
			<cfcatch type="any">
				<cfset ctx = "" />
				<cftry><cfset ctx = serializeJSON( cfcatch.tagContext ) /><cfcatch type="any"><cfset ctx = "" /></cfcatch></cftry>
				<cfthrow message="fetchSearchResults failed: #cfcatch.message# :: #ctx#" detail="#cfcatch.detail#" />
			</cfcatch>
		</cftry>
	</cffunction>

	<cffunction name="getFirstXmlValue" access="private" returntype="string" output="false">
		<cfargument name="nodes" type="any" required="true" />
		<cfif isArray( arguments.nodes ) AND arrayLen( arguments.nodes ) GT 0>
			<cfset firstNode = arguments.nodes[ 1 ] />
			<cfif isStruct( firstNode ) AND structKeyExists( firstNode, "xmlText" )>
				<cfset rawValue = toString( firstNode.xmlText ) />
			<cfelseif isStruct( firstNode ) AND structKeyExists( firstNode, "xmlValue" )>
				<cfset rawValue = toString( firstNode.xmlValue ) />
			<cfelse>
				<cfset rawValue = toString( firstNode ) />
			</cfif>
			<cfset rawValue = replaceNoCase( rawValue, "<?xml version=""1.0"" encoding=""UTF-8""?>", "", "all" ) />
			<cfset rawValue = replaceNoCase( rawValue, "<?xml version=""1.0"" encoding=""utf-8""?>", "", "all" ) />
			<cfset rawValue = reReplaceNoCase( rawValue, "(?is)<\?xml[^>]*\?>", "", "all" ) />
			<cfset rawValue = replace( rawValue, "<![CDATA[", "", "all" ) />
			<cfset rawValue = replace( rawValue, "]]>", "", "all" ) />
			<cfreturn trim( rawValue ) />
		</cfif>
		<cfreturn "" />
	</cffunction>

	<cffunction name="insertSignal" access="private" returntype="void" output="false">
		<cfargument name="signalType" type="string" required="true" />
		<cfargument name="sourceName" type="string" required="true" />
		<cfargument name="queryText" type="string" required="true" />
		<cfargument name="companyName" type="string" required="false" default="" />
		<cfargument name="companyDomain" type="string" required="false" default="" />
		<cfargument name="targetUrl" type="string" required="false" default="" />
		<cfargument name="evidenceText" type="string" required="false" default="" />
		<cfargument name="confidenceScore" type="numeric" required="false" default="0" />
		<cfset queryExecute(
			"INSERT INTO discovery_signals (
			 signal_type, source_name, query_text, company_name, company_domain, target_url, evidence_text, confidence_score, created_at
			 ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, datetime('now'))",
			[
				{ value: arguments.signalType, cfsqltype: "cf_sql_varchar" },
				{ value: arguments.sourceName, cfsqltype: "cf_sql_varchar" },
				{ value: arguments.queryText, cfsqltype: "cf_sql_varchar" },
				{ value: arguments.companyName, cfsqltype: "cf_sql_varchar" },
				{ value: arguments.companyDomain, cfsqltype: "cf_sql_varchar" },
				{ value: arguments.targetUrl, cfsqltype: "cf_sql_varchar" },
				{ value: arguments.evidenceText, cfsqltype: "cf_sql_longvarchar" },
				{ value: arguments.confidenceScore, cfsqltype: "cf_sql_integer" }
			],
			{ datasource: ds() }
		) />
	</cffunction>

	<cffunction name="deriveCareersUrl" access="private" returntype="string" output="false">
		<cfargument name="baseUrl" type="string" required="true" />
		<cfargument name="queryText" type="string" required="true" />
		<cfset q = lCase( arguments.queryText ) />
		<cfif find( "career", q ) OR find( "job", q ) OR find( "hiring", q )>
			<cfreturn arguments.baseUrl & "/careers" />
		</cfif>
		<cfreturn arguments.baseUrl />
	</cffunction>

	<cffunction name="extractDomain" access="private" returntype="string" output="false">
		<cfargument name="targetUrl" type="string" required="true" />
		<cftry>
			<cfset u = createObject( "java", "java.net.URL" ).init( trim( arguments.targetUrl ) ) />
			<cfset host = lCase( trim( u.getHost() ) ) />
			<cfset host = reReplace( host, "^www\.", "", "one" ) />
			<cfreturn host />
			<cfcatch type="any">
				<cfreturn "" />
			</cfcatch>
		</cftry>
	</cffunction>

	<cffunction name="inferCompanyName" access="private" returntype="string" output="false">
		<cfargument name="domain" type="string" required="true" />
		<cfif NOT len( arguments.domain )><cfreturn "Unknown Company" /></cfif>
		<cfset root = listFirst( arguments.domain, "." ) />
		<cfset root = replace( root, "-", " ", "all" ) />
		<cfset root = replace( root, "_", " ", "all" ) />
		<cfreturn uCase( left( root, 1 ) ) & mid( root, 2, len( root ) ) />
	</cffunction>

	<cffunction name="estimateConfidence" access="private" returntype="numeric" output="false">
		<cfargument name="queryText" type="string" required="true" />
		<cfargument name="evidenceText" type="string" required="true" />
		<cfset score = 20 />
		<cfset evidenceLc = lCase( arguments.evidenceText ) />
		<cfif find( "coldfusion", evidenceLc )><cfset score = score + 40 /></cfif>
		<cfif find( "cfml", evidenceLc )><cfset score = score + 25 /></cfif>
		<cfif find( "lucee", evidenceLc )><cfset score = score + 20 /></cfif>
		<cfif find( "careers", evidenceLc ) OR find( "job", evidenceLc )><cfset score = score + 10 /></cfif>
		<cfif score GT 100><cfset score = 100 /></cfif>
		<cfreturn score />
	</cffunction>

	<cffunction name="isNonEmployerSignalHost" access="private" returntype="boolean" output="false">
		<cfargument name="domain" type="string" required="true" />
		<cfset d = lCase( trim( arguments.domain ) ) />
		<cfif NOT len( d )><cfreturn true /></cfif>
		<cfset blocked = [ "reddit.com", "stackoverflow.com", "stackexchange.com", "community.adobe.com", "forums.adobe.com", "news.ycombinator.com", "medium.com", "quora.com", "twitter.com", "x.com", "facebook.com", "linkedin.com", "youtube.com", "youtu.be", "discord.com", "t.co", "tiktok.com", "instagram.com" ] />
		<cfloop array="#blocked#" index="b">
			<cfif find( b, d ) GT 0>
				<cfreturn true />
			</cfif>
		</cfloop>
		<cfreturn false />
	</cffunction>

	<cffunction name="isIgnoredDomain" access="private" returntype="boolean" output="false">
		<cfargument name="domain" type="string" required="true" />
		<cfif isNonEmployerSignalHost( arguments.domain )>
			<cfreturn true />
		</cfif>
		<cfset ignored = [ "bing.com", "microsoft.com", "linkedin.com", "reddit.com", "stackoverflow.com", "youtube.com", "facebook.com", "twitter.com", "x.com" ] />
		<cfloop array="#ignored#" index="item">
			<cfif right( arguments.domain, len( item ) ) EQ item>
				<cfreturn true />
			</cfif>
		</cfloop>
		<cfreturn false />
	</cffunction>

	<cffunction name="shouldUpsertCompany" access="private" returntype="boolean" output="false">
		<cfargument name="domain" type="string" required="true" />
		<cfargument name="targetUrl" type="string" required="true" />
		<cfargument name="signalType" type="string" required="true" />
		<cfargument name="evidenceText" type="string" required="true" />
		<cfset d = lCase( trim( arguments.domain ) ) />
		<cfif NOT len( d ) OR isIgnoredDomain( d )>
			<cfreturn false />
		</cfif>
		<cfset noiseDomains = [
			"wikipedia.org","marketwatch.com","stockanalysis.com","marketbeat.com","cnbc.com","cnn.com","britannica.com","education.com",
			"spaceplace.nasa.gov","nasa.gov","naukri.com","internshala.com","simplyhired.com","randstad.com","forum.","zhihu.com",
			"developer.mozilla.org","support.","npmjs.com","tektips.in","usingenglish.com","donanimhaber.com","avast.com",
			"reuters.com","packtpub.com"
		] />
		<cfloop array="#noiseDomains#" index="nd">
			<cfif findNoCase( nd, d ) GT 0>
				<cfreturn false />
			</cfif>
		</cfloop>
		<cfset text = lCase( arguments.evidenceText & " " & arguments.targetUrl ) />
		<cfif arguments.signalType EQ "job_discovery" OR arguments.signalType EQ "career_keyword">
			<cfif NOT ( find( "career", text ) OR find( "job", text ) OR find( "hiring", text ) OR find( "opening", text ) OR find( "vacancy", text ) OR find( "position", text ) OR find( "requirement", text ) )>
				<cfreturn false />
			</cfif>
		</cfif>
		<cfreturn true />
	</cffunction>

	<cffunction name="isRelevantSignal" access="private" returntype="boolean" output="false">
		<cfargument name="evidenceText" type="string" required="true" />
		<cfargument name="queryText" type="string" required="true" />
		<cfargument name="signalType" type="string" required="false" default="" />
		<cfset text = lCase( arguments.evidenceText ) />
		<!--- Core CF terms always qualify --->
		<cfset mustHave = [ "coldfusion", "cfml", "lucee" ] />
		<!--- Stack / tech-detector queries: Bing snippets often say "BuiltWith" without spelling "coldfusion" --->
		<cfif arguments.signalType EQ "stack_detection">
			<cfset arrayAppend( mustHave, "builtwith" ) />
			<cfset arrayAppend( mustHave, "wappalyzer" ) />
			<cfset arrayAppend( mustHave, "adobe" ) />
			<cfset arrayAppend( mustHave, "railo" ) />
		</cfif>
		<!--- Ecosystem (frameworks) may appear in titles without the word "coldfusion" --->
		<cfif arguments.signalType EQ "ecosystem_signal">
			<cfset arrayAppend( mustHave, "coldbox" ) />
			<cfset arrayAppend( mustHave, "mura" ) />
			<cfset arrayAppend( mustHave, "ortus" ) />
		</cfif>
		<cfloop array="#mustHave#" index="kw">
			<cfif find( kw, text )>
				<cfreturn true />
			</cfif>
		</cfloop>
		<cfreturn false />
	</cffunction>

	<cffunction name="extractTagValue" access="private" returntype="string" output="false">
		<cfargument name="xmlChunk" type="string" required="true" />
		<cfargument name="tagName" type="string" required="true" />
		<cfset openTag = "<" & arguments.tagName & ">" />
		<cfset closeTag = "</" & arguments.tagName & ">" />
		<cfset openPos = findNoCase( openTag, arguments.xmlChunk ) />
		<cfif openPos GT 0>
			<cfset valueStart = openPos + len( openTag ) />
			<cfset closePos = findNoCase( closeTag, arguments.xmlChunk, valueStart ) />
			<cfif closePos GT valueStart>
				<cfreturn mid( arguments.xmlChunk, valueStart, closePos - valueStart ) />
			</cfif>
		</cfif>
		<cfreturn "" />
	</cffunction>

	<cffunction name="decodeXmlText" access="private" returntype="string" output="false">
		<cfargument name="value" type="string" required="true" />
		<cfset out = arguments.value />
		<cfset out = replace( out, "&amp;", "&", "all" ) />
		<cfset out = replace( out, "&lt;", "<", "all" ) />
		<cfset out = replace( out, "&gt;", ">", "all" ) />
		<cfset out = replace( out, "&quot;", chr(34), "all" ) />
		<cfreturn out />
	</cffunction>

	<cffunction name="sleepMs" access="private" returntype="void" output="false">
		<cfargument name="ms" type="numeric" required="true" />
		<cfset createObject( "java", "java.lang.Thread" ).sleep( javacast( "int", arguments.ms ) ) />
	</cffunction>
</cfcomponent>
