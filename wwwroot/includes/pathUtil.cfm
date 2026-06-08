<cfif NOT structKeyExists( variables, "appBasePath" ) OR NOT len( trim( variables.appBasePath ) )>
	<cfset appBasePath = getDirectoryFromPath( cgi.script_name ) />
	<cfif left( appBasePath, 1 ) NEQ "/"><cfset appBasePath = "/" & appBasePath /></cfif>
	<cfif right( appBasePath, 1 ) NEQ "/"><cfset appBasePath = appBasePath & "/" /></cfif>
</cfif>
<cfset indexUrl = appBasePath & "index.cfm" />
<cfset discoveryUrl = appBasePath & "discovery-signals.cfm" />
<cfset assetBase = appBasePath & "assets/" />
