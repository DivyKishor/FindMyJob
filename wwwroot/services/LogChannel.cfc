<cfcomponent extends="services.AlertChannel" output="false">
	<!---
		LogChannel — Phase 2, PR 2.4.

		Concrete alert channel that writes alerts to the `alerts` DB table and the
		scrape log.  This is the current (pre-channel) behavior, now expressed as a
		first-class channel so future channels (Telegram, WhatsApp) can be added by
		implementing AlertChannel without touching AlertService.

		Dedupe key format: "log|<rule_version>|<job_id>"
		  — unchanged from v1 so existing alert rows are not duplicated on upgrade.

		Tag syntax only (project standard).
	--->

	<cfproperty name="databaseService" type="any" />
	<cfproperty name="loggerService"   type="any" />

	<cffunction name="init" access="public" returntype="any" output="false">
		<cfargument name="databaseService" type="any" required="true" />
		<cfargument name="loggerService"   type="any" required="true" />
		<cfset variables.databaseService = arguments.databaseService />
		<cfset variables.loggerService   = arguments.loggerService />
		<cfset variables.channelName     = "log" />
		<cfset variables.enabled         = true />
		<cfreturn this />
	</cffunction>

	<cffunction name="ds" access="private" returntype="string" output="false">
		<cfreturn variables.databaseService.getDatasource() />
	</cffunction>

	<!---
		send( alertPayload ) — write to alerts table and scrape log.
		Idempotent: INSERT OR IGNORE on dedupe_key so re-runs never create duplicates.
		Returns { sent: true/false, error: "" }.
	--->
	<cffunction name="send" access="public" returntype="struct" output="false">
		<cfargument name="alertPayload" type="struct" required="true" />
		<cfset var p = arguments.alertPayload />
		<cfset var sent = false />

		<cftry>
			<cfset var ruleVer = structKeyExists( p, "rule_version" ) ? p.rule_version : "v5_layered" />
			<cfset var dedupe  = "log|" & ruleVer & "|" & val( p.job_id ) />

			<cfset var reasonsJson = "" />
			<cfif structKeyExists( p, "reasons" ) AND isArray( p.reasons )>
				<cfset reasonsJson = serializeJSON( p.reasons ) />
			<cfelseif structKeyExists( p, "reasons_json" )>
				<cfset reasonsJson = p.reasons_json />
			</cfif>

			<cfset var payloadForDb = {
				job_id:       p.job_id,
				company_id:   p.company_id,
				company_name: p.company_name,
				title:        p.title,
				location:     p.location,
				link:         p.link,
				score:        p.score,
				reasons:      isArray( p.reasons ) ? p.reasons : []
			} />

			<cfset queryExecute(
				"INSERT OR IGNORE INTO alerts (job_id, channel, payload_json, sent_at, dedupe_key)
				 VALUES (?, 'log', ?, datetime('now'), ?)",
				[
					{ value: val( p.job_id ),            cfsqltype: "cf_sql_integer" },
					{ value: serializeJSON( payloadForDb ), cfsqltype: "cf_sql_longvarchar" },
					{ value: dedupe,                     cfsqltype: "cf_sql_varchar" }
				],
				{ datasource: ds() }
			) />

			<cfset var chg = queryExecute( "SELECT changes() AS c", {}, { datasource: ds() } ) />
			<cfset var chgCol = listFirst( chg.columnList ) />
			<cfif val( chg[ chgCol ][ 1 ] ) EQ 1>
				<cfset sent = true />
				<cfset variables.loggerService.info(
					"ALERT score=#p.score# company=#p.company_name# title=#p.title#"
				) />
			</cfif>
			<cfcatch type="any">
				<cfreturn { sent: false, error: cfcatch.message } />
			</cfcatch>
		</cftry>

		<cfreturn { sent: sent, error: "" } />
	</cffunction>

</cfcomponent>
