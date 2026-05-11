<cfcomponent output="false" accessors="true">
	<cfproperty name="logFilePath" type="string" />

	<cffunction name="init" access="public" returntype="any" output="false">
		<cfargument name="logFilePath" type="string" required="true" />
		<cfset variables.logFilePath = arguments.logFilePath />
		<cfset dirPath = getDirectoryFromPath( arguments.logFilePath ) />
		<cfif NOT directoryExists( dirPath )>
			<cfset directoryCreate( dirPath ) />
		</cfif>
		<cfreturn this />
	</cffunction>

	<cffunction name="info" access="public" returntype="void" output="false">
		<cfargument name="message" type="string" required="true" />
		<cfset writeLine( "INFO", arguments.message ) />
	</cffunction>

	<cffunction name="warn" access="public" returntype="void" output="false">
		<cfargument name="message" type="string" required="true" />
		<cfset writeLine( "WARN", arguments.message ) />
	</cffunction>

	<cffunction name="error" access="public" returntype="void" output="false">
		<cfargument name="message" type="string" required="true" />
		<cfargument name="err" type="any" required="false" default="#{}#" />
		<cfset detail = arguments.message />
		<cfif isStruct( arguments.err ) AND structKeyExists( arguments.err, "message" )>
			<cfset detail = detail & " | " & arguments.err.message />
		</cfif>
		<cfset writeLine( "ERROR", detail ) />
	</cffunction>

	<cffunction name="writeLine" access="private" returntype="void" output="false">
		<cfargument name="level" type="string" required="true" />
		<cfargument name="message" type="string" required="true" />
		<cfset line = dateTimeFormat( now(), "yyyy-mm-dd HH:nn:ss" ) & " [" & arguments.level & "] " & arguments.message />
		<cftry>
			<cfset fileAppend( variables.logFilePath, line & chr(10), "utf-8" ) />
			<cfcatch type="any">
				<!--- Ignore logging file errors --->
			</cfcatch>
		</cftry>
	</cffunction>
</cfcomponent>
