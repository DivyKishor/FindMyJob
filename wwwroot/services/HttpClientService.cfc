<cfcomponent output="false">
	<cffunction name="init" access="public" returntype="any" output="false">
		<cfreturn this />
	</cffunction>

	<cffunction name="getText" access="public" returntype="string" output="false">
		<cfargument name="url" type="string" required="true" />
		<cfargument name="timeoutSeconds" type="numeric" required="false" default="60" />
		<cfset resultData = executeGet( arguments.url, arguments.timeoutSeconds ) />
		<cfreturn resultData.content />
	</cffunction>

	<cffunction name="executeGet" access="private" returntype="struct" output="false">
		<cfargument name="url" type="string" required="true" />
		<cfargument name="timeoutSeconds" type="numeric" required="true" />
		<cftry>
			<cfhttp url="#arguments.url#" method="GET" result="httpRes" timeout="#arguments.timeoutSeconds#" redirect="true">
				<cfhttpparam type="header" name="User-Agent" value="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36" />
				<cfhttpparam type="header" name="Accept" value="text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" />
				<cfhttpparam type="header" name="Accept-Language" value="en-US,en;q=0.9" />
			</cfhttp>
			<cfcatch type="any">
				<cfthrow type="HttpClient.ConnectionFailure" message="Connection failed for GET #arguments.url#: #cfcatch.message#" />
			</cfcatch>
		</cftry>

		<cfif NOT structKeyExists( httpRes, "statusCode" )>
			<!--- Lucee omits statusCode on connection-level failures (DNS, timeout, reset) --->
			<cfset errDetail = structKeyExists( httpRes, "error" ) ? httpRes.error : "no statusCode in response" />
			<cfthrow type="HttpClient.ConnectionFailure" message="Connection failed for GET #arguments.url#: #errDetail#" />
		</cfif>

		<cfset code = val( listFirst( httpRes.statusCode, " " ) ) />
		<cfif code LT 200 OR code GTE 300>
			<cfthrow type="HttpClient.HTTPError" message="HTTP #httpRes.statusCode# for GET #arguments.url#" />
		</cfif>
		<cfreturn { content: httpRes.fileContent } />
	</cffunction>
</cfcomponent>
