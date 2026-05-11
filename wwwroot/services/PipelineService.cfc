<cfcomponent output="false" accessors="true">
	<cfproperty name="discoveryService" type="any" />
	<cfproperty name="scrapeOrchestrator" type="any" />
	<cfproperty name="jobScoreService" type="any" />
	<cfproperty name="alertService" type="any" />
	<cfproperty name="loggerService" type="any" />
	<cfproperty name="runStatusService" type="any" />

	<cffunction name="init" access="public" returntype="any" output="false">
		<cfargument name="discoveryService" type="any" required="true" />
		<cfargument name="scrapeOrchestrator" type="any" required="true" />
		<cfargument name="jobScoreService" type="any" required="true" />
		<cfargument name="alertService" type="any" required="true" />
		<cfargument name="loggerService" type="any" required="true" />
		<cfargument name="runStatusService" type="any" required="true" />
		<cfset variables.discoveryService = arguments.discoveryService />
		<cfset variables.scrapeOrchestrator = arguments.scrapeOrchestrator />
		<cfset variables.jobScoreService = arguments.jobScoreService />
		<cfset variables.alertService = arguments.alertService />
		<cfset variables.loggerService = arguments.loggerService />
		<cfset variables.runStatusService = arguments.runStatusService />
		<cfreturn this />
	</cffunction>

	<cffunction name="runDaily" access="public" returntype="struct" output="false">
		<cfset variables.loggerService.info( "Daily pipeline started." ) />
		<cftry>
			<cfset discoverySummary = variables.discoveryService.runDiscovery() />
			<cfset scrapeSummary = variables.scrapeOrchestrator.runAll() />
			<cfset scoreSummary = variables.jobScoreService.scoreAllJobs() />
			<cfset alertSummary = variables.alertService.generateAlerts( 40 ) />
			<cfset resultSummary = {
				discovery: discoverySummary,
				scrape: scrapeSummary,
				score: scoreSummary,
				alerts: alertSummary,
				runAt: dateTimeFormat( now(), "yyyy-mm-dd HH:nn:ss" )
			} />
			<cfset variables.runStatusService.recordSuccess( resultSummary ) />
			<cfset variables.loggerService.info( "Daily pipeline finished." ) />
			<cfreturn resultSummary />
			<cfcatch type="any">
				<cfset variables.runStatusService.recordFailure( cfcatch.message, cfcatch.detail ) />
				<cfset variables.loggerService.error( "Daily pipeline failed.", cfcatch ) />
				<cfrethrow />
			</cfcatch>
		</cftry>
	</cffunction>
</cfcomponent>
