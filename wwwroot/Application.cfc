<cfcomponent output="false">
	<cfset variables.appRoot = getDirectoryFromPath( getCurrentTemplatePath() ) />
	<cfset variables.libPath = variables.appRoot & "lib" />
	<cfset variables.dataPath = variables.appRoot & "data" />
	<cfset variables.sqlPath = variables.appRoot & "sql" />
	<cfset variables.configPath = variables.appRoot & "config" />
	<cfset variables.logsPath = variables.appRoot & "logs" />
	<cfset variables.servicesPath = variables.appRoot & "services" />

	<cfset this.name = "ColdFusionIntelligenceEngine" />
	<cfset this.sessionManagement = false />
	<cfset this.setClientCookies = false />

	<cfset this.javaSettings = {
		loadPaths: [ variables.libPath & "/sqlite-jdbc.jar" ],
		reloadOnChange: true
	} />

	<cfset this.datasources = {} />
	<!--- Lucee expects connectionString; Adobe CF accepts url — set both for local Lucee Express + CF2025 --->
	<cfset variables.sqliteJdbc = "jdbc:sqlite:#variables.dataPath#/coldfusion_intel.db" />
	<cfset this.datasources["coldfusion_intel"] = {
		class: "org.sqlite.JDBC",
		url: variables.sqliteJdbc,
		connectionString: variables.sqliteJdbc,
		username: "",
		password: ""
	} />
	<cfset this.datasource = "coldfusion_intel" />

	<cfset this.mappings = {} />
	<cfset this.mappings["/services"] = variables.servicesPath />

	<cffunction name="onApplicationStart" access="public" returntype="boolean" output="false">
		<cfset application.datasource = "coldfusion_intel" />
		<cfset application.startedAt = now() />

		<cfset application.databaseService = createObject("component", "services.DatabaseService").init( application.datasource ) />
		<cfset application.databaseService.ensureSchema( variables.sqlPath & "/schema.sql" ) />
		<cfset application.databaseService.ensureForeignKeys() />

		<cfset application.loggerService = createObject("component", "services.LoggerService").init( variables.logsPath & "/scrape.log" ) />
		<cfset application.runStatusService = createObject("component", "services.RunStatusService").init( application.databaseService ) />
		<cfset application.sourceQuotaService = createObject("component", "services.SourceQuotaService").init( application.databaseService ) />
		<cfset application.companyService = createObject("component", "services.CompanyService").init( application.databaseService, variables.configPath & "/seed_companies.json" ) />
		<cfset application.scoringService = createObject("component", "services.ScoringService").init() />
		<cfset application.jobService = createObject("component", "services.JobService").init(
			application.databaseService,
			application.scoringService.getRuleVersion()
		) />
		<cfset application.jobScoreService = createObject("component", "services.JobScoreService").init(
			application.databaseService,
			application.scoringService,
			application.loggerService
		) />
		<cfset application.alertService = createObject("component", "services.AlertService").init(
			application.databaseService,
			application.loggerService
		) />
		<cfset application.httpClientService = createObject("component", "services.HttpClientService").init() />
		<cfset application.greenhouseParser = createObject("component", "services.GreenhouseParser").init() />
		<cfset application.discoveryService = createObject("component", "services.DiscoveryService").init(
			application.databaseService,
			application.httpClientService,
			application.loggerService,
			application.companyService,
			application.sourceQuotaService
		) />
		<cfset application.scrapeOrchestrator = createObject("component", "services.ScrapeOrchestrator").init(
			application.companyService,
			application.jobService,
			application.httpClientService,
			application.greenhouseParser,
			application.loggerService,
			application.sourceQuotaService,
			application.scoringService
		) />
		<cfset application.pipelineService = createObject("component", "services.PipelineService").init(
			application.discoveryService,
			application.scrapeOrchestrator,
			application.jobScoreService,
			application.alertService,
			application.loggerService,
			application.runStatusService
		) />

		<cfset application.companyService.seedIfEmpty() />
		<cfset application.companyService.ensureFeedSources() />
		<cfreturn true />
	</cffunction>

	<cffunction name="onRequestStart" access="public" returntype="void" output="false">
		<cfargument name="targetPage" type="string" required="true" />
		<cfif structKeyExists( url, "reinit" ) AND val( url.reinit ) EQ 1>
			<cfset onApplicationStart() />
		</cfif>
		<cfset application.databaseService.ensureForeignKeys() />
	</cffunction>
</cfcomponent>
