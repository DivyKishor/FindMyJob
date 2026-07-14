<cfcomponent extends="services.AlertChannel" output="false">
	<!---
		WhatsAppChannel — Phase 4, PR 4.2.

		Delivers alerts via the WhatsApp Business Cloud API (graph.facebook.com).
		Credentials come from AppConfig:
		  secrets.whatsapp_token, secrets.whatsapp_phone_number_id, secrets.whatsapp_recipient
		Optional: whatsapp.api_version (default v20.0); alerts.whatsapp_min_score (default 80).

		NOTE: free-form text messages only reach a recipient inside the 24h customer
		service window; outside it, Meta requires a pre-approved template. For alerting
		your own number, send yourself a WhatsApp message first to open the window.

		Dedupe via the alerts table (key: whatsapp|<rule_version>|<job_id>).
		Tag syntax only (project standard).
	--->
	<cfproperty name="appConfig" type="any" />
	<cfproperty name="databaseService" type="any" />
	<cfproperty name="loggerService" type="any" />

	<cffunction name="init" access="public" returntype="any" output="false">
		<cfargument name="appConfig" type="any" required="true" />
		<cfargument name="databaseService" type="any" required="false" default="" />
		<cfargument name="loggerService" type="any" required="false" default="" />
		<cfargument name="minScore" type="numeric" required="false" default="80" />
		<cfset variables.appConfig = arguments.appConfig />
		<cfset variables.databaseService = arguments.databaseService />
		<cfset variables.loggerService = arguments.loggerService />
		<cfset variables.channelName = "whatsapp" />
		<cfset variables.token         = trim( arguments.appConfig.secret( "whatsapp_token" ) ) />
		<cfset variables.phoneNumberId = trim( arguments.appConfig.get( "secrets.whatsapp_phone_number_id", "" ) ) />
		<cfset variables.recipient     = trim( arguments.appConfig.get( "secrets.whatsapp_recipient", "" ) ) />
		<cfset variables.apiVersion    = trim( arguments.appConfig.get( "whatsapp.api_version", "v20.0" ) ) />
		<cfset variables.minScore      = val( arguments.appConfig.get( "alerts.whatsapp_min_score", arguments.minScore ) ) />
		<cfset variables.enabled = (
			len( variables.token ) GT 0
			AND len( variables.phoneNumberId ) GT 0
			AND len( variables.recipient ) GT 0
		) />
		<cfreturn this />
	</cffunction>

	<cffunction name="shouldSend" access="public" returntype="struct" output="false">
		<cfargument name="alertPayload" type="struct" required="true" />
		<cfif NOT variables.enabled>
			<cfreturn { ok: false, reason: "whatsapp not configured" } />
		</cfif>
		<cfif val( structKeyExists( arguments.alertPayload, "score" ) ? arguments.alertPayload.score : 0 ) LT variables.minScore>
			<cfreturn { ok: false, reason: "below whatsapp min score (" & variables.minScore & ")" } />
		</cfif>
		<cfreturn { ok: true, reason: "" } />
	</cffunction>

	<cffunction name="formatMessage" access="public" returntype="string" output="false">
		<cfargument name="p" type="struct" required="true" />
		<cfset var msg = p.title & " (score " & val( p.score ) & ")" & chr(10) />
		<cfset msg = msg & p.company_name />
		<cfif structKeyExists( p, "location" ) AND len( trim( p.location ) )>
			<cfset msg = msg & " — " & p.location />
		</cfif>
		<cfif structKeyExists( p, "link" ) AND len( trim( p.link ) )>
			<cfset msg = msg & chr(10) & p.link />
		</cfif>
		<cfreturn msg />
	</cffunction>

	<cffunction name="send" access="public" returntype="struct" output="false">
		<cfargument name="alertPayload" type="struct" required="true" />
		<cfargument name="persist" type="boolean" required="false" default="true" />
		<cfset var p = arguments.alertPayload />
		<cfset var gate = shouldSend( p ) />
		<cfif NOT gate.ok>
			<cfreturn { sent: false, error: gate.reason } />
		</cfif>

		<cfset var ruleVer = structKeyExists( p, "rule_version" ) ? p.rule_version : "v5_layered" />
		<cfset var dedupe = "whatsapp|" & ruleVer & "|" & val( p.job_id ) />
		<cfif arguments.persist AND isObject( variables.databaseService ) AND alreadySent( dedupe )>
			<cfreturn { sent: false, error: "already sent" } />
		</cfif>

		<cftry>
			<cfset var bodyStruct = {
				"messaging_product": "whatsapp",
				"to": variables.recipient,
				"type": "text",
				"text": { "preview_url": true, "body": formatMessage( p ) }
			} />
			<cfhttp url="https://graph.facebook.com/#variables.apiVersion#/#variables.phoneNumberId#/messages" method="POST" result="resp" timeout="15">
				<cfhttpparam type="header" name="Authorization" value="Bearer #variables.token#" />
				<cfhttpparam type="header" name="Content-Type" value="application/json" />
				<cfhttpparam type="body" value="#serializeJSON( bodyStruct )#" />
			</cfhttp>
			<cfset var code = val( listFirst( ( structKeyExists( resp, "statusCode" ) ? resp.statusCode : "0" ) & " 0", " " ) ) />
			<cfif code GTE 200 AND code LT 300>
				<cfif arguments.persist AND isObject( variables.databaseService )><cfset recordSent( p, dedupe ) /></cfif>
				<cfreturn { sent: true, error: "" } />
			</cfif>
			<cfreturn { sent: false, error: "WhatsApp HTTP " & code & ": " & left( ( structKeyExists( resp, "fileContent" ) ? resp.fileContent : "" ), 300 ) } />
			<cfcatch type="any">
				<cfreturn { sent: false, error: cfcatch.message } />
			</cfcatch>
		</cftry>
	</cffunction>

	<cffunction name="alreadySent" access="private" returntype="boolean" output="false">
		<cfargument name="dedupeKey" type="string" required="true" />
		<cfset var q = queryExecute(
			"SELECT 1 AS x FROM alerts WHERE dedupe_key = ?",
			[ { value: arguments.dedupeKey, cfsqltype: "cf_sql_varchar" } ],
			{ datasource: variables.databaseService.getDatasource() }
		) />
		<cfreturn q.recordCount GT 0 />
	</cffunction>

	<cffunction name="recordSent" access="private" returntype="void" output="false">
		<cfargument name="p" type="struct" required="true" />
		<cfargument name="dedupeKey" type="string" required="true" />
		<cfset queryExecute(
			"INSERT OR IGNORE INTO alerts (job_id, channel, payload_json, sent_at, dedupe_key)
			 VALUES (?, 'whatsapp', ?, datetime('now'), ?)",
			[
				{ value: val( arguments.p.job_id ), cfsqltype: "cf_sql_integer" },
				{ value: serializeJSON( arguments.p ), cfsqltype: "cf_sql_longvarchar" },
				{ value: arguments.dedupeKey, cfsqltype: "cf_sql_varchar" }
			],
			{ datasource: variables.databaseService.getDatasource() }
		) />
	</cffunction>
</cfcomponent>
