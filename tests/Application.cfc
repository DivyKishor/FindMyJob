<cfcomponent output="false">
	<!--- Test-only application context. Maps TestBox, the service package under
	      test, and a fixture SQLite datasource for DB-touching specs. --->
	<cfset this.name = "cfintel-tests-" & hash( getCurrentTemplatePath() ) />
	<cfset this.sessionManagement = false />
	<cfset this.setClientCookies = false />

	<cfset variables.testsDir = getDirectoryFromPath( getCurrentTemplatePath() ) />

	<cfset this.mappings[ "/testbox" ] = expandPath( "/testbox" ) />
	<cfset this.mappings[ "/tests" ] = variables.testsDir />
	<cfset this.mappings[ "/services" ] = expandPath( "/wwwroot/services" ) />
	<cfset this.mappings[ "/stubs" ] = variables.testsDir & "stubs" />

	<!--- Fixture datasource is only wired when the SQLite JDBC jar is present.
	      Pure-logic specs do not need it; DB-integration specs guard on it. --->
	<cfset variables.jarPath = expandPath( "/wwwroot/lib/sqlite-jdbc.jar" ) />
	<cfif fileExists( variables.jarPath )>
		<cfset this.javaSettings = { loadPaths: [ variables.jarPath ], reloadOnChange: false } />
		<cfset variables.fixtureDbDir = variables.testsDir & "results" />
		<cfif NOT directoryExists( variables.fixtureDbDir )>
			<cfset directoryCreate( variables.fixtureDbDir ) />
		</cfif>
		<cfset this.datasources[ "cfintel_test" ] = {
			class: "org.sqlite.JDBC",
			connectionString: "jdbc:sqlite:#variables.fixtureDbDir#/fixture.db",
			username: "",
			password: ""
		} />
	</cfif>

	<!---
		onApplicationStart — wires the application-scope services that DB-touching specs
		(AlertChannelTest LogChannel + AlertService dispatch) depend on.

		Pure-logic specs (TechFingerprinterTest, CompanyScoreServiceTest, ScoringServiceV5Test,
		AlertChannel base-class tests) do not use any of these; they instantiate their own
		stubs directly.  Wiring here only affects specs that reference application.* explicitly.

		Datasource used is "cfintel_test" (fixture SQLite DB defined in this.datasources above).
		Migration runner is NOT called here to keep test startup fast; DB-integration specs
		that need schema tables should call it themselves or guard with a try/catch.
	--->
	<cffunction name="onApplicationStart" access="public" returntype="boolean" output="false">
		<cfset application.datasource = "cfintel_test" />

		<cfset application.databaseService = createObject( "component", "services.DatabaseService" ).init(
			application.datasource
		) />

		<!--- Apply migrations to the fixture DB so DB-integration specs (AlertService
		     dispatch) have schema tables. Idempotent + fast (empty DB). --->
		<cfset var gw = createObject( "component", "services.DataGateway" ).init( application.datasource, "sqlite" ) />
		<cfset createObject( "component", "services.MigrationRunner" ).init( gw, expandPath( "/wwwroot/migrations" ) ).run() />

		<cfset application.loggerService = createObject( "component", "services.LoggerService" ).init(
			expandPath( "/wwwroot/logs/test-channel.log" )
		) />

		<!--- Wire alertService with an explicit LogChannel so AlertChannelTest dispatch tests work. --->
		<cfset var logCh = createObject( "component", "services.LogChannel" ).init(
			application.databaseService,
			application.loggerService
		) />
		<cfset application.alertService = createObject( "component", "services.AlertService" ).init(
			application.databaseService,
			application.loggerService,
			[ logCh ]
		) />

		<cfreturn true />
	</cffunction>

</cfcomponent>
