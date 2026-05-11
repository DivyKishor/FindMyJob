<cfcomponent output="false">
	<cffunction name="init" access="public" returntype="any" output="false">
		<cfreturn this />
	</cffunction>

	<cffunction name="parseJobs" access="public" returntype="array" output="false">
		<cfargument name="jsonText" type="string" required="true" />
		<cfset payload = deserializeJSON( arguments.jsonText ) />
		<cfif NOT structKeyExists( payload, "jobs" ) OR NOT isArray( payload.jobs )>
			<cfreturn [] />
		</cfif>
		<cfset out = [] />
		<cfloop array="#payload.jobs#" index="jobItem">
			<cfif NOT isStruct( jobItem )>
				<cfcontinue />
			</cfif>
			<cfset loc = "" />
			<cfif structKeyExists( jobItem, "location" ) AND isStruct( jobItem.location ) AND structKeyExists( jobItem.location, "name" )>
				<cfset loc = jobItem.location.name />
			</cfif>
			<cfif structKeyExists( jobItem, "id" )>
				<cfset externalId = toString( jobItem.id ) />
			<cfelse>
				<cfset externalId = "" />
			</cfif>
			<cfif structKeyExists( jobItem, "title" )>
				<cfset titleValue = jobItem.title />
			<cfelse>
				<cfset titleValue = "" />
			</cfif>
			<cfif structKeyExists( jobItem, "absolute_url" )>
				<cfset linkValue = jobItem.absolute_url />
			<cfelse>
				<cfset linkValue = "" />
			</cfif>
			<cfset descPlain = normalizeGreenhouseContent( jobItem ) />
			<cfset arrayAppend( out, {
				externalId: externalId,
				title: titleValue,
				description: descPlain,
				location: loc,
				link: linkValue
			} ) />
		</cfloop>
		<cfreturn out />
	</cffunction>

	<cffunction name="normalizeGreenhouseContent" access="private" returntype="string" output="false">
		<cfargument name="jobItem" type="struct" required="true" />
		<cfif NOT structKeyExists( arguments.jobItem, "content" )>
			<cfreturn "" />
		</cfif>
		<cfset raw = trim( toString( arguments.jobItem.content ) ) />
		<cfif NOT len( raw )>
			<cfreturn "" />
		</cfif>
		<cftry>
			<cfset raw = htmlDecode( raw ) />
			<cfcatch type="any">
				<cfset raw = replace( raw, "&lt;", "<", "all" ) />
				<cfset raw = replace( raw, "&gt;", ">", "all" ) />
				<cfset raw = replace( raw, "&quot;", chr( 34 ), "all" ) />
				<cfset raw = replace( raw, "&" & chr( 35 ) & "39;", chr( 39 ), "all" ) />
				<cfset raw = replace( raw, "&apos;", chr( 39 ), "all" ) />
				<cfset raw = replace( raw, "&nbsp;", " ", "all" ) />
				<cfset raw = replace( raw, "&amp;", "&", "all" ) />
			</cfcatch>
		</cftry>
		<cfset raw = reReplace( raw, "<[^>]+>", " ", "all" ) />
		<cfset raw = trim( reReplace( raw, "\s+", " ", "all" ) ) />
		<cfif len( raw ) GT 200000>
			<cfset raw = left( raw, 200000 ) />
		</cfif>
		<cfreturn raw />
	</cffunction>
</cfcomponent>
