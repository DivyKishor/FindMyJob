<cfcomponent output="false">
	<cffunction name="init" access="public" returntype="any" output="false">
		<cfreturn this />
	</cffunction>

	<!--- Default retry policy: total attempts and base backoff (ms) for transient failures. --->
	<cfset variables.maxAttempts = 3 />
	<cfset variables.baseBackoffMs = 800 />

	<cffunction name="getText" access="public" returntype="string" output="false">
		<cfargument name="url" type="string" required="true" />
		<cfargument name="timeoutSeconds" type="numeric" required="false" default="60" />
		<cfset resultData = executeGet( arguments.url, arguments.timeoutSeconds, {} ) />
		<cfreturn resultData.content />
	</cffunction>

	<!--- Same as getText but lets callers override/add request headers (e.g. Reddit User-Agent, Brave X-Subscription-Token). --->
	<cffunction name="getTextWithHeaders" access="public" returntype="string" output="false">
		<cfargument name="url" type="string" required="true" />
		<cfargument name="headers" type="struct" required="false" default="#structNew()#" />
		<cfargument name="timeoutSeconds" type="numeric" required="false" default="60" />
		<cfset resultData = executeGet( arguments.url, arguments.timeoutSeconds, arguments.headers ) />
		<cfreturn resultData.content />
	</cffunction>

	<!--- Retries transient failures (connection drops, 429/5xx) with exponential backoff + jitter. --->
	<cffunction name="executeGet" access="private" returntype="struct" output="false">
		<cfargument name="url" type="string" required="true" />
		<cfargument name="timeoutSeconds" type="numeric" required="true" />
		<cfargument name="headers" type="struct" required="false" default="#structNew()#" />
		<cfset attempt = 0 />
		<cfset lastError = "" />
		<cfloop condition="attempt LT variables.maxAttempts">
			<cfset attempt = attempt + 1 />
			<cfset res = attemptGet( arguments.url, arguments.timeoutSeconds, arguments.headers ) />
			<cfif res.ok>
				<cfreturn { content: res.content } />
			</cfif>
			<cfset lastError = res.error />
			<cfif NOT res.retryable OR attempt GTE variables.maxAttempts>
				<cfbreak />
			</cfif>
			<!--- Exponential backoff with jitter: 0.8s, 1.6s, ... --->
			<cfset backoff = variables.baseBackoffMs * ( 2 ^ ( attempt - 1 ) ) + randRange( 0, 400 ) />
			<cfset sleep( backoff ) />
		</cfloop>
		<cfif res.statusError>
			<cfthrow type="HttpClient.HTTPError" message="#lastError# (after #attempt# attempt(s))" />
		</cfif>
		<cfthrow type="HttpClient.ConnectionFailure" message="#lastError# (after #attempt# attempt(s))" />
	</cffunction>

	<cffunction name="attemptGet" access="private" returntype="struct" output="false">
		<cfargument name="url" type="string" required="true" />
		<cfargument name="timeoutSeconds" type="numeric" required="true" />
		<cfargument name="headers" type="struct" required="false" default="#structNew()#" />
		<cfset defaults = {
			"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
			"Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
			"Accept-Language": "en-US,en;q=0.9"
		} />
		<cfloop collection="#arguments.headers#" item="hKey">
			<cfset defaults[ hKey ] = arguments.headers[ hKey ] />
		</cfloop>
		<cftry>
			<cfhttp url="#arguments.url#" method="GET" result="httpRes" timeout="#arguments.timeoutSeconds#" redirect="true">
				<cfloop collection="#defaults#" item="hKey">
					<cfhttpparam type="header" name="#hKey#" value="#defaults[ hKey ]#" />
				</cfloop>
			</cfhttp>
			<cfcatch type="any">
				<!--- Connection-level exception (reset, timeout): retryable --->
				<cfreturn { ok: false, retryable: true, statusError: false, content: "", error: "Connection failed for GET #arguments.url#: #cfcatch.message#" } />
			</cfcatch>
		</cftry>

		<cfif NOT structKeyExists( httpRes, "statusCode" )>
			<!--- Lucee omits statusCode on connection-level failures (DNS, timeout, reset): retryable --->
			<cfset errDetail = structKeyExists( httpRes, "error" ) ? httpRes.error : "no statusCode in response" />
			<cfreturn { ok: false, retryable: true, statusError: false, content: "", error: "Connection failed for GET #arguments.url#: #errDetail#" } />
		</cfif>

		<cfset code = val( listFirst( httpRes.statusCode, " " ) ) />
		<cfif code GTE 200 AND code LT 300>
			<cfreturn { ok: true, retryable: false, statusError: false, content: httpRes.fileContent, error: "" } />
		</cfif>
		<!--- 429 + 5xx are transient and worth retrying; other 4xx are not --->
		<cfset transient = ( code EQ 429 OR code EQ 500 OR code EQ 502 OR code EQ 503 OR code EQ 504 ) />
		<cfreturn { ok: false, retryable: transient, statusError: true, content: "", error: "HTTP #httpRes.statusCode# for GET #arguments.url#" } />
	</cffunction>
</cfcomponent>
