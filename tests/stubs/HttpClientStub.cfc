<cfcomponent output="false" accessors="true">
	<!---
		Test double for HttpClientService. Lets specs register canned responses
		per URL (exact or substring match) so ingestion/discovery/fingerprint
		logic can be tested without real network calls.

		Mirrors the public surface used by the services: getText /
		getTextWithHeaders. Records calls for assertions.
	--->
	<cfproperty name="responses" type="array" />
	<cfproperty name="calls" type="array" />
	<cfproperty name="defaultBody" type="string" />

	<cffunction name="init" access="public" returntype="any" output="false">
		<cfargument name="defaultBody" type="string" required="false" default="" />
		<cfset variables.responses = arrayNew(1) />
		<cfset variables.calls = arrayNew(1) />
		<cfset variables.defaultBody = arguments.defaultBody />
		<cfreturn this />
	</cffunction>

	<!--- Register a response. urlMatch is matched as a case-insensitive substring. --->
	<cffunction name="setResponse" access="public" returntype="any" output="false">
		<cfargument name="urlMatch" type="string" required="true" />
		<cfargument name="body" type="string" required="true" />
		<cfset arrayAppend( variables.responses, { match: arguments.urlMatch, body: arguments.body } ) />
		<cfreturn this />
	</cffunction>

	<cffunction name="getText" access="public" returntype="string" output="false">
		<cfargument name="url" type="string" required="true" />
		<cfargument name="timeoutSeconds" type="numeric" required="false" default="60" />
		<cfreturn resolve( arguments.url ) />
	</cffunction>

	<cffunction name="getTextWithHeaders" access="public" returntype="string" output="false">
		<cfargument name="url" type="string" required="true" />
		<cfargument name="headers" type="struct" required="false" default="#structNew()#" />
		<cfargument name="timeoutSeconds" type="numeric" required="false" default="60" />
		<cfreturn resolve( arguments.url ) />
	</cffunction>

	<cffunction name="callCount" access="public" returntype="numeric" output="false">
		<cfreturn arrayLen( variables.calls ) />
	</cffunction>

	<cffunction name="resolve" access="private" returntype="string" output="false">
		<cfargument name="url" type="string" required="true" />
		<cfset arrayAppend( variables.calls, arguments.url ) />
		<cfset var r = "" />
		<cfloop array="#variables.responses#" index="r">
			<cfif findNoCase( r.match, arguments.url ) GT 0>
				<cfreturn r.body />
			</cfif>
		</cfloop>
		<cfreturn variables.defaultBody />
	</cffunction>
</cfcomponent>
