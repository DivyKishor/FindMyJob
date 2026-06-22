<cfcomponent output="false" accessors="true">
	<!---
		TechFingerprinter — Phase 2, PR 2.1.

		Scans a company domain with HEAD + GET and scores HTTP-level evidence for
		ColdFusion-ecosystem technology presence.  Signal rules are driven by
		TechTaxonomy so adding a new tech key automatically extends detection.

		Signal catalogue (weight / max-weight-for-normalisation):
		  powered_by      X-Powered-By header contains ColdFusion             3.5
		  lucee_header    Server/X-Powered-By contains Lucee or Railo         3.5
		  cf_cookie       CFID/CFTOKEN cookie in Set-Cookie header             3.0
		  cfm_url         .cfm or .cfc href/action in page HTML               3.0
		  coldbox_marker  ColdBox/WireBox/FuseBox marker in page HTML         2.5
		  mura_marker     Mura CMS marker in page HTML                        2.5
		  box_json        /box.json returns 200 OK                            2.0
		  commandbox      CommandBox trace in page HTML                       2.0
		  ─────────────────────────────────────────────────────────────────────
		  MAX_WEIGHT = 22.0   (score = min(100, sum/22*100))

		Key design choices:
		  - evaluateSignals() is a pure function so unit tests need no HTTP.
		  - fingerprint() does HEAD then GET, persists via upsertSignal(), returns the
		    evaluation result so callers can act on it immediately.
		  - Timeout is kept short (HEAD 12 s, GET 20 s) to avoid blocking pipelines.

		Tag syntax only (project standard).
	--->

	<cfproperty name="dataGateway" type="any" />
	<cfproperty name="loggerService" type="any" />
	<cfproperty name="taxonomy" type="any" />

	<!--- Sum of all signal weights — used to normalise to 0-100. --->
	<cfset variables.MAX_WEIGHT = 3.5 + 3.5 + 3.0 + 3.0 + 2.5 + 2.5 + 2.0 + 2.0 />

	<cffunction name="init" access="public" returntype="any" output="false">
		<cfargument name="dataGateway"  type="any" required="true" />
		<cfargument name="loggerService" type="any" required="true" />
		<cfargument name="taxonomy"     type="any" required="false" default="" />
		<cfset variables.dataGateway   = arguments.dataGateway />
		<cfset variables.loggerService = arguments.loggerService />
		<cfif isObject( arguments.taxonomy )>
			<cfset variables.taxonomy = arguments.taxonomy />
		<cfelse>
			<cfset variables.taxonomy = createObject( "component", "services.TechTaxonomy" ).init() />
		</cfif>
		<cfreturn this />
	</cffunction>

	<!--- ===== Public API ===== --->

	<!---
		fingerprint( companyId, domain )
		  Fetches the domain (HEAD + selective GET), evaluates all signals,
		  persists results to tech_fingerprints, and returns:
		    { signals:[{signal,evidence,weight},...], score:int(0-100), evidenceSummary:string }
	--->
	<cffunction name="fingerprint" access="public" returntype="struct" output="false">
		<cfargument name="companyId" type="numeric" required="true" />
		<cfargument name="domain"    type="string"  required="true" />
		<cfset var result = { signals: [], score: 0, evidenceSummary: "" } />
		<cfset var baseUrl = normaliseUrl( arguments.domain ) />
		<cfif NOT len( baseUrl )><cfreturn result /></cfif>

		<cftry>
			<cfset var headData  = doHead( baseUrl ) />
			<cfset var bodyText  = "" />
			<cfif headData.reachable>
				<cfset bodyText = doGet( baseUrl ) />
			</cfif>

			<cfset var evalResult = evaluateSignals( bodyText, headData.headers, baseUrl ) />
			<cfset result.signals         = evalResult.signals />
			<cfset result.score           = evalResult.score />
			<cfset result.evidenceSummary = evalResult.evidenceSummary />

			<!--- Persist each signal (upsert so re-scans refresh evidence). --->
			<cfloop array="#result.signals#" index="sig">
				<cfset upsertSignal( arguments.companyId, sig.signal, sig.evidence, sig.weight ) />
			</cfloop>

			<cfcatch type="any">
				<cfset variables.loggerService.warn(
					"TechFingerprinter error domain=#arguments.domain#: #cfcatch.message# :: #cfcatch.detail#"
				) />
			</cfcatch>
		</cftry>
		<cfreturn result />
	</cffunction>

	<!---
		evaluateSignals( bodyContent, headersStruct, baseUrl )
		  Pure evaluation function — separated from HTTP so it can be unit-tested
		  by passing fixture HTML / header structs without any network calls.
		  baseUrl is optional; when provided the /box.json probe is attempted.
	--->
	<cffunction name="evaluateSignals" access="public" returntype="struct" output="false">
		<cfargument name="bodyContent"  type="string" required="true" />
		<cfargument name="headersStruct" type="struct" required="true" />
		<cfargument name="baseUrl"      type="string" required="false" default="" />

		<cfset var signals = [] />

		<!--- 1. Header-level signals — case-insensitive key lookup. --->
		<cfset var pbVal     = "" />
		<cfset var serverVal = "" />
		<cfset var cookieVal = "" />
		<cfloop collection="#arguments.headersStruct#" item="hKey">
			<cfset var hKeyLc = lCase( hKey ) />
			<cfif hKeyLc EQ "x-powered-by"><cfset pbVal     = arguments.headersStruct[ hKey ] /></cfif>
			<cfif hKeyLc EQ "server">       <cfset serverVal = arguments.headersStruct[ hKey ] /></cfif>
			<cfif hKeyLc EQ "set-cookie">   <cfset cookieVal = arguments.headersStruct[ hKey ] /></cfif>
		</cfloop>

		<cfif findNoCase( "coldfusion", pbVal )>
			<cfset arrayAppend( signals, {
				signal: "powered_by",
				evidence: "X-Powered-By: " & left( pbVal, 120 ),
				weight: 3.5
			} ) />
		</cfif>
		<cfif findNoCase( "lucee", pbVal ) OR findNoCase( "railo", pbVal )
		   OR findNoCase( "lucee", serverVal ) OR findNoCase( "railo", serverVal )>
			<cfset arrayAppend( signals, {
				signal: "lucee_header",
				evidence: "Lucee/Railo detected in Server or X-Powered-By header",
				weight: 3.5
			} ) />
		</cfif>
		<cfif findNoCase( "cfid=", cookieVal ) OR findNoCase( "cftoken=", cookieVal )>
			<cfset arrayAppend( signals, {
				signal: "cf_cookie",
				evidence: "CFID/CFTOKEN session cookie detected",
				weight: 3.0
			} ) />
		</cfif>

		<!--- 2. HTML-body signals. --->
		<cfif len( arguments.bodyContent )>
			<cfset var bodyLc = lCase( arguments.bodyContent ) />

			<!--- .cfm / .cfc URL references in links, forms, or scripts. --->
			<cfif reFindNoCase( "(href|action|src)\s*=\s*[""'][^""']*\.(cfm|cfc)", arguments.bodyContent ) GT 0>
				<cfset arrayAppend( signals, {
					signal: "cfm_url",
					evidence: ".cfm/.cfc URL found in HTML (href, action, or src attribute)",
					weight: 3.0
				} ) />
			</cfif>

			<!--- ColdBox / WireBox / FuseBox markers. --->
			<cfif findNoCase( "coldbox", bodyLc ) OR findNoCase( "wirebox", bodyLc )
			   OR findNoCase( "fusebox", bodyLc )>
				<cfset var cbParts = [] />
				<cfif findNoCase( "coldbox", bodyLc )><cfset arrayAppend( cbParts, "ColdBox" ) /></cfif>
				<cfif findNoCase( "wirebox", bodyLc )><cfset arrayAppend( cbParts, "WireBox" ) /></cfif>
				<cfif findNoCase( "fusebox", bodyLc )><cfset arrayAppend( cbParts, "FuseBox" ) /></cfif>
				<cfset arrayAppend( signals, {
					signal: "coldbox_marker",
					evidence: arrayToList( cbParts, "/" ) & " marker found in HTML",
					weight: 2.5
				} ) />
			</cfif>

			<!--- Mura CMS markers. --->
			<cfif findNoCase( "mura cms", bodyLc ) OR findNoCase( "muracms", bodyLc )
			   OR findNoCase( "mura.js", bodyLc ) OR findNoCase( "/mura/", bodyLc )
			   OR findNoCase( "masa cms", bodyLc )>
				<cfset arrayAppend( signals, {
					signal: "mura_marker",
					evidence: "Mura CMS marker found in HTML",
					weight: 2.5
				} ) />
			</cfif>

			<!--- CommandBox traces. --->
			<cfif findNoCase( "commandbox", bodyLc )>
				<cfset arrayAppend( signals, {
					signal: "commandbox",
					evidence: "CommandBox trace found in HTML",
					weight: 2.0
				} ) />
			</cfif>
		</cfif>

		<!--- 3. /box.json probe (only when a baseUrl is supplied). --->
		<cfif len( arguments.baseUrl )>
			<cfif probeUrlExists( arguments.baseUrl & "/box.json" )>
				<cfset arrayAppend( signals, {
					signal: "box_json",
					evidence: "/box.json accessible (200 OK)",
					weight: 2.0
				} ) />
			</cfif>
		</cfif>

		<!--- Normalise: score = min(100, sum(weights) / MAX_WEIGHT * 100). --->
		<cfset var totalWeight  = 0 />
		<cfset var evidenceParts = [] />
		<cfloop array="#signals#" index="sigItem">
			<cfset totalWeight = totalWeight + sigItem.weight />
			<cfset arrayAppend( evidenceParts, sigItem.signal & ":" & sigItem.evidence ) />
		</cfloop>
		<cfset var score = 0 />
		<cfif variables.MAX_WEIGHT GT 0 AND totalWeight GT 0>
			<cfset score = min( 100, int( ( totalWeight / variables.MAX_WEIGHT ) * 100 ) ) />
		</cfif>

		<cfreturn {
			signals: signals,
			score: score,
			evidenceSummary: arrayToList( evidenceParts, " | " )
		} />
	</cffunction>

	<!--- ===== HTTP helpers ===== --->

	<cffunction name="doHead" access="private" returntype="struct" output="false">
		<cfargument name="url" type="string" required="true" />
		<cfset var result = { reachable: false, headers: {} } />
		<cftry>
			<cfhttp method="HEAD" url="#arguments.url#" timeout="12" result="hRes" redirect="true">
				<cfhttpparam type="header" name="User-Agent"      value="Mozilla/5.0 (compatible; CFIntel-Fingerprinter/1.0)" />
				<cfhttpparam type="header" name="Accept"          value="text/html,*/*;q=0.8" />
				<cfhttpparam type="header" name="Accept-Language" value="en-US,en;q=0.9" />
			</cfhttp>
			<cfset var statusNum = val( listFirst( hRes.statusCode, " " ) ) />
			<cfif statusNum GTE 200 AND statusNum LT 400>
				<cfset result.reachable = true />
			</cfif>
			<cfset result.headers = hRes.responseHeader />
			<cfcatch type="any">
				<!--- Unreachable or HTTPS handshake failure — leave reachable=false. --->
			</cfcatch>
		</cftry>
		<cfreturn result />
	</cffunction>

	<cffunction name="doGet" access="private" returntype="string" output="false">
		<cfargument name="url" type="string" required="true" />
		<cfset var content = "" />
		<cftry>
			<cfhttp method="GET" url="#arguments.url#" timeout="20" result="gRes" redirect="true">
				<cfhttpparam type="header" name="User-Agent"      value="Mozilla/5.0 (compatible; CFIntel-Fingerprinter/1.0)" />
				<cfhttpparam type="header" name="Accept"          value="text/html,application/xhtml+xml,*/*;q=0.8" />
				<cfhttpparam type="header" name="Accept-Language" value="en-US,en;q=0.9" />
			</cfhttp>
			<cfset var statusNum = val( listFirst( gRes.statusCode, " " ) ) />
			<cfif statusNum GTE 200 AND statusNum LT 400>
				<cfset content = toString( gRes.fileContent ) />
				<!--- Limit to first 250 KB to keep memory bounded. --->
				<cfif len( content ) GT 256000>
					<cfset content = left( content, 256000 ) />
				</cfif>
			</cfif>
			<cfcatch type="any">
				<!--- Leave content empty. --->
			</cfcatch>
		</cftry>
		<cfreturn content />
	</cffunction>

	<cffunction name="probeUrlExists" access="private" returntype="boolean" output="false">
		<cfargument name="url" type="string" required="true" />
		<cftry>
			<cfhttp method="HEAD" url="#arguments.url#" timeout="8" result="pRes" redirect="false">
				<cfhttpparam type="header" name="User-Agent" value="Mozilla/5.0 (compatible; CFIntel-Fingerprinter/1.0)" />
			</cfhttp>
			<cfset var statusNum = val( listFirst( pRes.statusCode, " " ) ) />
			<cfreturn statusNum EQ 200 />
			<cfcatch type="any">
				<cfreturn false />
			</cfcatch>
		</cftry>
		<cfreturn false />
	</cffunction>

	<!--- ===== Persistence ===== --->

	<cffunction name="upsertSignal" access="private" returntype="void" output="false">
		<cfargument name="companyId" type="numeric" required="true" />
		<cfargument name="signal"    type="string"  required="true" />
		<cfargument name="evidence"  type="string"  required="true" />
		<cfargument name="weight"    type="numeric" required="true" />
		<cfset variables.dataGateway.execute(
			"INSERT INTO tech_fingerprints (company_id, signal, evidence, weight, observed_at)
			 VALUES (?, ?, ?, ?, datetime('now'))
			 ON CONFLICT(company_id, signal) DO UPDATE SET
			     evidence    = excluded.evidence,
			     weight      = excluded.weight,
			     observed_at = excluded.observed_at",
			[
				{ value: val( arguments.companyId ), cfsqltype: "cf_sql_integer" },
				{ value: arguments.signal,            cfsqltype: "cf_sql_varchar" },
				{ value: left( arguments.evidence, 500 ), cfsqltype: "cf_sql_longvarchar" },
				{ value: arguments.weight,            cfsqltype: "cf_sql_float" }
			]
		) />
	</cffunction>

	<!--- ===== Misc helpers ===== --->

	<cffunction name="normaliseUrl" access="private" returntype="string" output="false">
		<cfargument name="url" type="string" required="true" />
		<cfset var u = trim( arguments.url ) />
		<cfif NOT len( u )><cfreturn "" /></cfif>
		<cfif NOT reFind( "^https?://", u )>
			<cfset u = "https://" & u />
		</cfif>
		<cfif right( u, 1 ) EQ "/"><cfset u = left( u, len( u ) - 1 ) /></cfif>
		<cfreturn u />
	</cffunction>

</cfcomponent>
