<cfcomponent output="false">
	<cfset variables.appRoot = getDirectoryFromPath( getCurrentTemplatePath() ) />
	<cfset variables.libPath = variables.appRoot & "lib" />
	<cfset variables.dataPath = variables.appRoot & "data" />
	<cfset variables.sqlPath = variables.appRoot & "sql" />
	<cfset variables.migrationsPath = variables.appRoot & "migrations" />
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

		<!--- F1: DataGateway seam — dialect-aware wrapper over queryExecute (SQLite now, Postgres-ready). --->
		<cfset application.dataGateway = createObject("component", "services.DataGateway").init( application.datasource, "sqlite" ) />

		<!--- F2: numbered migration runner replaces ensureSchema()/ensureMigrations().
		     Those DatabaseService methods remain as deprecated shims for one release. --->
		<cfset application.migrationRunner = createObject("component", "services.MigrationRunner").init(
			application.dataGateway,
			variables.migrationsPath
		) />
		<cfset application.migrationRunner.run() />
		<cfset application.databaseService.ensureForeignKeys() />

		<!--- F3: config/secrets seam — env > app.json > ats_config fallback. --->
		<cfset application.appConfig = createObject("component", "services.AppConfig").init( variables.configPath & "/app.json" ) />

		<cfset application.loggerService = createObject("component", "services.LoggerService").init( variables.logsPath & "/scrape.log" ) />
		<cfset application.runStatusService = createObject("component", "services.RunStatusService").init( application.databaseService ) />
		<cfset application.sourceQuotaService = createObject("component", "services.SourceQuotaService").init( application.databaseService ) />
		<cfset application.companyService = createObject("component", "services.CompanyService").init( application.databaseService, variables.configPath & "/seed_companies.json" ) />
		<!--- F5: shared technology taxonomy (8 ecosystem techs) — used by scoring + keyword expansion. --->
		<cfset application.techTaxonomy = createObject("component", "services.TechTaxonomy").init() />
		<cfset application.scoringService = createObject("component", "services.ScoringService").init( application.techTaxonomy ) />
		<cfset application.jobService = createObject("component", "services.JobService").init(
			application.databaseService,
			application.scoringService.getRuleVersion(),
			application.techTaxonomy
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
		<!--- PR 1.6: declarative ATS registry + detector (replaces inline OR-chain). --->
		<cfset application.atsRegistry = createObject("component", "services.AtsRegistry").init() />
		<cfset application.atsDetector = createObject("component", "services.AtsDetector").init( application.atsRegistry ) />
		<!--- PR 1.7: career/job URL helpers extracted from the orchestrator. --->
		<cfset application.careerPageDiscoverer = createObject("component", "services.CareerPageDiscoverer").init( application.atsDetector ) />

		<!--- Phase 3: self-expanding source graph, expansion engine, onboarding, scheduler. --->
		<cfset application.sourceGraphService = createObject("component", "services.SourceGraphService").init(
			application.dataGateway,
			application.loggerService
		) />
		<cfset application.sourceExpansionService = createObject("component", "services.SourceExpansionService").init(
			application.sourceGraphService,
			application.loggerService
		) />
		<cfset application.sourceAdapter = createObject("component", "services.SourceAdapter").init() />
		<cfset application.sourceRegistryService = createObject("component", "services.SourceRegistryService").init(
			application.dataGateway,
			application.sourceAdapter,
			application.sourceGraphService,
			application.loggerService
		) />
		<cfset application.sourceScheduler = createObject("component", "services.SourceScheduler").init() />

		<!--- GitHub company discovery: CF orgs + employers of CF devs (from repos/affiliations). --->
		<cfset application.githubDiscoveryService = createObject("component", "services.GithubDiscoveryService").init(
			application.dataGateway,
			application.httpClientService,
			application.appConfig,
			application.loggerService,
			application.sourceGraphService
		) />
		<cfset application.scrapeOrchestrator = createObject("component", "services.ScrapeOrchestrator").init(
			application.companyService,
			application.jobService,
			application.httpClientService,
			application.greenhouseParser,
			application.loggerService,
			application.sourceQuotaService,
			application.scoringService,
			application.atsDetector,
			application.careerPageDiscoverer
		) />
		<cfset application.pipelineService = createObject("component", "services.PipelineService").init(
			application.discoveryService,
			application.scrapeOrchestrator,
			application.jobScoreService,
			application.alertService,
			application.loggerService,
			application.runStatusService
		) />

		<cfset application.expiryCheckerService = createObject("component", "services.ExpiryCheckerService").init(
			application.jobService,
			application.loggerService
		) />

		<!--- PR 2.1: HTTP technology fingerprinter (HEAD+GET signal scanner per company domain). --->
		<cfset application.techFingerprinter = createObject("component", "services.TechFingerprinter").init(
			application.dataGateway,
			application.loggerService,
			application.techTaxonomy
		) />

		<!--- PR 2.2: Company CF-likelihood scorer (fingerprints + discovery signals + job history). --->
		<cfset application.companyScoreService = createObject("component", "services.CompanyScoreService").init(
			application.dataGateway,
			application.loggerService
		) />

		<!--- PR 2.4: Re-init alertService with explicit LogChannel so the channel seam is wired.
		     Existing behaviour is unchanged: LogChannel writes to the alerts table exactly as before.
		     To add Telegram/WhatsApp in Phase 4, call application.alertService.addChannel(newChannel). --->
		<cfset var logChannel = createObject("component", "services.LogChannel").init(
			application.databaseService,
			application.loggerService
		) />
		<cfset application.alertService = createObject("component", "services.AlertService").init(
			application.databaseService,
			application.loggerService,
			[ logChannel ]
		) />

		<cfset application.companyService.seedIfEmpty() />
		<cfset application.companyService.ensureFeedSources() />

		<!--- Self-registering Lucee scheduled tasks. Runs INSIDE Lucee, so it calls
		     localhost directly — no sandbox/ngrok/network dependency. Auto-(re)registers
		     on every app start and on ?reinit=1. action="update" is create-or-overwrite,
		     so this is safe to re-run. Edit times/base URL via config/app.json if desired. --->
		<cfset registerScheduledTasks() />

		<cfreturn true />
	</cffunction>

	<cffunction name="registerScheduledTasks" access="private" returntype="void" output="false">
		<cfset var baseUrl    = "http://127.0.0.1:8888" />
		<cfset var today      = dateFormat( now(), "mm/dd/yyyy" ) />

		<!--- Append the task key (if configured) so scheduled HTTPRequests pass the guard. --->
		<cfset var taskKey = structKeyExists( application, "appConfig" ) ? trim( application.appConfig.get( "security.task_key", "" ) ) : "" />

		<!--- Lean, cost-tuned cadence (staggered off-peak so a small box never runs two heavy jobs at once). --->
		<cfset var jobs = [
			{ name: "CF_Observer_Daily_Scrape",   path: "/tasks/runDailyScrape.cfm",            time: "06:00 AM", interval: "daily" },
			{ name: "CF_Observer_Fingerprint",    path: "/tasks/fingerprintCompanies.cfm?max=75", time: "02:00 AM", interval: "daily" },
			{ name: "CF_Observer_Company_Score",  path: "/tasks/scoreCompanies.cfm",            time: "02:45 AM", interval: "daily" },
			{ name: "CF_Observer_Expiry_Check",   path: "/tasks/checkJobExpiry.cfm?limit=60&min_days=7", time: "03:15 AM", interval: "259200" },
			{ name: "CF_Observer_Source_Expand",  path: "/tasks/expandSources.cfm",             time: "04:00 AM", interval: "604800" },
			{ name: "CF_Observer_Github",         path: "/tasks/harvestGithub.cfm?max=60",      time: "04:30 AM", interval: "604800" }
		] />

		<cfloop array="#jobs#" index="jobDef">
			<cftry>
				<cfset var sep = ( find( "?", jobDef.path ) GT 0 ) ? "&" : "?" />
				<cfset var fullUrl = baseUrl & jobDef.path & ( len( taskKey ) ? sep & "key=" & taskKey : "" ) />
				<cfschedule
					action="update"
					task="#jobDef.name#"
					operation="HTTPRequest"
					url="#fullUrl#"
					startDate="#today#"
					startTime="#jobDef.time#"
					interval="#jobDef.interval#"
					resolveUrl="no"
					publish="no" />
				<cfcatch type="any">
					<cfset application.loggerService.error( "scheduler: failed to register " & jobDef.name, cfcatch ) />
				</cfcatch>
			</cftry>
		</cfloop>
	</cffunction>

	<cffunction name="onRequestStart" access="public" returntype="void" output="false">
		<cfargument name="targetPage" type="string" required="true" />
		<cfif structKeyExists( url, "reinit" ) AND val( url.reinit ) EQ 1>
			<cfset onApplicationStart() />
		</cfif>
		<cfset application.databaseService.ensureForeignKeys() />

		<!--- Secret-key guard for /tasks/ endpoints. Only enforced when security.task_key
		     is configured (env CFINTEL_SECURITY_TASK_KEY or config/app.json), so local
		     dev stays open while public hosting can lock task triggers down. --->
		<cfif findNoCase( "/tasks/", arguments.targetPage ) GT 0>
			<cfset var taskKey = structKeyExists( application, "appConfig" ) ? trim( application.appConfig.get( "security.task_key", "" ) ) : "" />
			<cfif len( taskKey )>
				<cfset var provided = ( structKeyExists( url, "key" ) AND isSimpleValue( url.key ) ) ? trim( url.key ) : "" />
				<cfif provided NEQ taskKey>
					<cfheader statusCode="403" />
					<cfcontent type="application/json; charset=utf-8" />
					<cfoutput>#serializeJSON( { ok: false, error: "Forbidden: missing or invalid task key" } )#</cfoutput>
					<cfabort />
				</cfif>
			</cfif>
		</cfif>
	</cffunction>
</cfcomponent>
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           