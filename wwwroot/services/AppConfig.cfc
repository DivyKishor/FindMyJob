<cfcomponent output="false" accessors="true">
	<!---
		AppConfig — single entry point for configuration and secrets.

		Precedence (highest first):
		  1. Environment variable  CFINTEL_<UPPER_SNAKE_KEY>
		  2. config/app.json       (gitignored; dotted-path lookup)
		  3. caller-supplied fallback (e.g. a company's ats_config struct)
		  4. default value

		Goal (Phase 1, F3): move API keys out of the SQLite ats_config / repo and
		into env vars, while staying backward compatible — existing rows keep working
		because ats_config is still consulted as the fallback layer.

		Tag syntax only (project standard).
	--->
	<cfproperty name="configPath" type="string" />
	<cfproperty name="data" type="struct" />
	<cfproperty name="env" type="struct" />
	<cfproperty name="envPrefix" type="string" />

	<cffunction name="init" access="public" returntype="any" output="false">
		<cfargument name="configPath" type="string" required="false" default="" />
		<cfargument name="envPrefix" type="string" required="false" default="CFINTEL_" />
		<cfset variables.configPath = arguments.configPath />
		<cfset variables.envPrefix = arguments.envPrefix />
		<cfset variables.data = loadJsonFile( arguments.configPath ) />
		<cfset variables.env = loadEnvironment() />
		<cfreturn this />
	</cffunction>

	<!--- Resolve a scalar config value by dotted key (e.g. "alerts.min_score"). --->
	<cffunction name="get" access="public" returntype="any" output="false">
		<cfargument name="key" type="string" required="true" />
		<cfargument name="defaultValue" type="any" required="false" default="" />
		<cfset var envVal = envLookup( arguments.key ) />
		<cfif len( envVal )>
			<cfreturn envVal />
		</cfif>
		<cfset var found = jsonLookup( arguments.key ) />
		<cfif found.exists>
			<cfreturn found.value />
		</cfif>
		<cfreturn arguments.defaultValue />
	</cffunction>

	<cffunction name="has" access="public" returntype="boolean" output="false">
		<cfargument name="key" type="string" required="true" />
		<cfif len( envLookup( arguments.key ) )>
			<cfreturn true />
		</cfif>
		<cfreturn jsonLookup( arguments.key ).exists />
	</cffunction>

	<!---
		Resolve a secret, with a fallback struct (typically a parsed ats_config).
		Checks env (secrets.<name> -> CFINTEL_SECRETS_<NAME>), then app.json
		secrets.<name>, then fallbackStruct[fallbackKey], then default.
	--->
	<cffunction name="secret" access="public" returntype="any" output="false">
		<cfargument name="name" type="string" required="true" />
		<cfargument name="fallback" type="struct" required="false" default="#structNew()#" />
		<cfargument name="fallbackKey" type="string" required="false" default="" />
		<cfargument name="defaultValue" type="any" required="false" default="" />

		<cfset var val = get( "secrets." & arguments.name, "" ) />
		<cfif len( val )>
			<cfreturn val />
		</cfif>
		<cfset var fk = len( arguments.fallbackKey ) ? arguments.fallbackKey : arguments.name />
		<cfif structKeyExists( arguments.fallback, fk )
		      AND isSimpleValue( arguments.fallback[ fk ] )
		      AND len( trim( arguments.fallback[ fk ] ) )>
			<cfreturn arguments.fallback[ fk ] />
		</cfif>
		<cfreturn arguments.defaultValue />
	</cffunction>

	<!--- ===== internals ===== --->

	<cffunction name="loadJsonFile" access="private" returntype="struct" output="false">
		<cfargument name="path" type="string" required="true" />
		<cfif NOT len( arguments.path ) OR NOT fileExists( arguments.path )>
			<cfreturn structNew() />
		</cfif>
		<cftry>
			<cfset var parsed = deserializeJSON( fileRead( arguments.path ) ) />
			<cfif isStruct( parsed )><cfreturn parsed /></cfif>
			<cfcatch type="any"><!--- malformed config: ignore, fall back to env/defaults ---></cfcatch>
		</cftry>
		<cfreturn structNew() />
	</cffunction>

	<cffunction name="loadEnvironment" access="private" returntype="struct" output="false">
		<cfset var out = structNew() />
		<cftry>
			<cfset var sysEnv = server.system.environment />
			<cfif isStruct( sysEnv )>
				<cfset structAppend( out, sysEnv, true ) />
			</cfif>
			<cfcatch type="any"><!--- not available on this runtime ---></cfcatch>
		</cftry>
		<cftry>
			<cfset var sysProps = server.system.properties />
			<cfif isStruct( sysProps )>
				<cfset structAppend( out, sysProps, false ) />
			</cfif>
			<cfcatch type="any"><!--- ignore ---></cfcatch>
		</cftry>
		<cfreturn out />
	</cffunction>

	<!--- Map a dotted key to CFINTEL_UPPER_SNAKE and look it up in env. --->
	<cffunction name="envLookup" access="private" returntype="string" output="false">
		<cfargument name="key" type="string" required="true" />
		<cfset var envKey = variables.envPrefix & uCase( reReplace( arguments.key, "[\.\-\s]", "_", "all" ) ) />
		<cfif structKeyExists( variables.env, envKey )
		      AND isSimpleValue( variables.env[ envKey ] )
		      AND len( trim( variables.env[ envKey ] ) )>
			<cfreturn trim( variables.env[ envKey ] ) />
		</cfif>
		<cfreturn "" />
	</cffunction>

	<!--- Walk variables.data along a dotted path. --->
	<cffunction name="jsonLookup" access="private" returntype="struct" output="false">
		<cfargument name="key" type="string" required="true" />
		<cfset var node = variables.data />
		<cfset var part = "" />
		<cfloop list="#arguments.key#" delimiters="." index="part">
			<cfif isStruct( node ) AND structKeyExists( node, part )>
				<cfset node = node[ part ] />
			<cfelse>
				<cfreturn { exists: false, value: "" } />
			</cfif>
		</cfloop>
		<cfreturn { exists: true, value: node } />
	</cffunction>
</cfcomponent>
