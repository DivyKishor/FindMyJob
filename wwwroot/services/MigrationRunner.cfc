<cfcomponent output="false" accessors="true">
	<!---
		MigrationRunner — applies numbered SQL migrations in order and records
		them in a schema_migrations table so each runs exactly once.

		Replaces the dual source of truth (sql/schema.sql + hardcoded DDL in
		DatabaseService.ensureSchema) and the ad-hoc ensureMigrations() list.

		Files live in /migrations and are named NNNN_description.sql (zero-padded,
		ascending). Each file may contain multiple ";"-terminated statements.

		Idempotency strategy: a migration runs only if its version is not yet in
		schema_migrations. Within a migration, statements that fail with benign
		"already applied" errors (duplicate column / already exists) are tolerated,
		so legacy databases that already received columns via the old ensureMigrations
		path migrate cleanly.

		Tag syntax only (project standard).
	--->
	<cfproperty name="dataGateway" type="any" />
	<cfproperty name="loggerService" type="any" />
	<cfproperty name="migrationsPath" type="string" />

	<cffunction name="init" access="public" returntype="any" output="false">
		<cfargument name="dataGateway" type="any" required="true" />
		<cfargument name="migrationsPath" type="string" required="true" />
		<cfargument name="loggerService" type="any" required="false" default="" />
		<cfset variables.dataGateway = arguments.dataGateway />
		<cfset variables.migrationsPath = arguments.migrationsPath />
		<cfset variables.loggerService = arguments.loggerService />
		<cfreturn this />
	</cffunction>

	<cffunction name="run" access="public" returntype="struct" output="false">
		<cfset var summary = { applied: [], skipped: [], errors: [] } />
		<cfset ensureMigrationsTable() />
		<cfset var applied = appliedVersions() />

		<cfset var files = listMigrationFiles() />
		<cfset var fileItem = "" />
		<cfloop array="#files#" index="fileItem">
			<cfset var version = listFirst( fileItem, "_" ) />
			<cfif structKeyExists( applied, version )>
				<cfset arrayAppend( summary.skipped, fileItem ) />
				<cfcontinue />
			</cfif>
			<cftry>
				<cfset applyFile( fileItem ) />
				<cfset recordApplied( version, fileItem ) />
				<cfset arrayAppend( summary.applied, fileItem ) />
				<cfset logInfo( "Migration applied: " & fileItem ) />
				<cfcatch type="any">
					<cfset arrayAppend( summary.errors, fileItem & " :: " & cfcatch.message ) />
					<cfset logError( "Migration failed: " & fileItem & " :: " & cfcatch.message ) />
					<cfthrow type="MigrationRunner.Failed"
						message="Migration #fileItem# failed: #cfcatch.message#"
						detail="#cfcatch.detail#" />
				</cfcatch>
			</cftry>
		</cfloop>
		<cfreturn summary />
	</cffunction>

	<!--- ===== internals ===== --->

	<cffunction name="ensureMigrationsTable" access="private" returntype="void" output="false">
		<cfset variables.dataGateway.execute(
			"CREATE TABLE IF NOT EXISTS schema_migrations (
			   version TEXT PRIMARY KEY,
			   filename TEXT NOT NULL,
			   applied_at TEXT NOT NULL DEFAULT (" & variables.dataGateway.nowExpr() & ")
			 )"
		) />
	</cffunction>

	<cffunction name="appliedVersions" access="private" returntype="struct" output="false">
		<cfset var out = structNew() />
		<cfset var rows = variables.dataGateway.queryArray( "SELECT version FROM schema_migrations" ) />
		<cfset var r = "" />
		<cfloop array="#rows#" index="r">
			<cfset out[ r.version ] = true />
		</cfloop>
		<cfreturn out />
	</cffunction>

	<cffunction name="listMigrationFiles" access="private" returntype="array" output="false">
		<cfset var out = arrayNew(1) />
		<cfif NOT directoryExists( variables.migrationsPath )>
			<cfreturn out />
		</cfif>
		<cfset var listing = directoryList( variables.migrationsPath, false, "name", "*.sql", "name asc" ) />
		<cfset var nm = "" />
		<cfloop array="#listing#" index="nm">
			<cfif reFind( "^[0-9]+_", nm )>
				<cfset arrayAppend( out, nm ) />
			</cfif>
		</cfloop>
		<!--- Explicit sort: Lucee directoryList sort is not reliably honored across OSes (Linux CI returned files unsorted -> 0005 ran before 0001). --->
		<cfset arraySort( out, "textnocase", "asc" ) />
		<cfreturn out />
	</cffunction>

	<cffunction name="applyFile" access="private" returntype="void" output="false">
		<cfargument name="filename" type="string" required="true" />
		<cfset var fullPath = variables.migrationsPath & "/" & arguments.filename />
		<cfset var raw = fileRead( fullPath ) />
		<cfset var statements = splitStatements( raw ) />
		<cfset var stmt = "" />
		<cfloop array="#statements#" index="stmt">
			<cftry>
				<cfset variables.dataGateway.execute( stmt ) />
				<cfcatch type="any">
					<cfif isBenignError( cfcatch.message )>
						<cfset logInfo( "Tolerated benign migration error in #arguments.filename#: #cfcatch.message#" ) />
					<cfelse>
						<cfrethrow />
					</cfif>
				</cfcatch>
			</cftry>
		</cfloop>
	</cffunction>

	<!--- Split on ";" at end of statement, dropping comments and blank lines. --->
	<cffunction name="splitStatements" access="private" returntype="array" output="false">
		<cfargument name="raw" type="string" required="true" />
		<cfset var out = arrayNew(1) />
		<cfset var lines = listToArray( arguments.raw, chr(10), false ) />
		<cfset var buffer = "" />
		<cfset var ln = "" />
		<cfset var trimmed = "" />
		<cfloop array="#lines#" index="ln">
			<cfset trimmed = trim( ln ) />
			<cfif NOT len( trimmed ) OR left( trimmed, 2 ) EQ "--">
				<cfcontinue />
			</cfif>
			<cfset buffer = buffer & " " & trimmed />
			<cfif right( trimmed, 1 ) EQ ";">
				<cfset arrayAppend( out, trim( reReplace( buffer, ";\s*$", "", "one" ) ) ) />
				<cfset buffer = "" />
			</cfif>
		</cfloop>
		<cfif len( trim( buffer ) )>
			<cfset arrayAppend( out, trim( buffer ) ) />
		</cfif>
		<cfreturn out />
	</cffunction>

	<cffunction name="isBenignError" access="private" returntype="boolean" output="false">
		<cfargument name="message" type="string" required="true" />
		<cfset var m = lCase( arguments.message ) />
		<cfreturn ( findNoCase( "duplicate column", m ) GT 0
			OR findNoCase( "already exists", m ) GT 0 ) />
	</cffunction>

	<cffunction name="recordApplied" access="private" returntype="void" output="false">
		<cfargument name="version" type="string" required="true" />
		<cfargument name="filename" type="string" required="true" />
		<cfset variables.dataGateway.execute(
			variables.dataGateway.insertIgnorePrefix()
			& " INTO schema_migrations (version, filename) VALUES (?, ?)"
			& variables.dataGateway.insertIgnoreConflict( "version" ),
			[
				{ value: arguments.version, cfsqltype: "cf_sql_varchar" },
				{ value: arguments.filename, cfsqltype: "cf_sql_varchar" }
			]
		) />
	</cffunction>

	<cffunction name="logInfo" access="private" returntype="void" output="false">
		<cfargument name="msg" type="string" required="true" />
		<cfif isObject( variables.loggerService )>
			<cfset variables.loggerService.info( arguments.msg ) />
		</cfif>
	</cffunction>

	<cffunction name="logError" access="private" returntype="void" output="false">
		<cfargument name="msg" type="string" required="true" />
		<cfif isObject( variables.loggerService )>
			<cfset variables.loggerService.error( arguments.msg ) />
		</cfif>
	</cffunction>
</cfcomponent>
