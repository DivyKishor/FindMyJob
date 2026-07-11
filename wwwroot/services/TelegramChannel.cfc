<cfcomponent extends="services.AlertChannel" output="false">
	<!---
		TelegramChannel — Phase 4, PR 4.1.

		Delivers alerts to Telegram via the Bot API sendMessage endpoint.
		Credentials come from AppConfig (env CFINTEL_SECRETS_* or config/app.json):
		  secrets.telegram_bot_token, secrets.telegram_chat_id
		Per-channel min score: alerts.telegram_min_score (default 70).

		Dedupe: a row is written to the alerts table with channel='telegram' so the
		same job is not re-sent on later runs (key: telegram|<rule_version>|<job_id>).

		Tag syntax only (project standard).
	--->
	<cfproperty name="appConfig" type="any" />
	<cfproperty name="databaseService" type="any" />
	<cfproperty name="loggerService" type="any" />

	<cffunction name="init" access="public" returntype="any" output="false">
		<cfargument name="appConfig" type="any" required="true" />
		<cfargument name="databaseService" type="any" required="false" default="" />
		<cfargument name="loggerService" type="any" required="false" default="" />
		<cfargument name="minScore" type="numeric" required="false" default="70" />
		<cfset variables.appConfig = arguments.appConfig />
		<cfset variables.databaseService = arguments.databaseService />
		<cfset variables.loggerService = arguments.loggerService />
		<cfset variables.channelName = "telegram" />
		<cfset variables.botToken = trim( arguments.appConfig.secret( "telegram_bot_token" ) ) />
		<cfset variables.chatId   = trim( arguments.appConfig.get( "secrets.telegram_chat_id", "" ) ) />
		<cfset variables.minScore = val( arguments.appConfig.get( "alerts.telegram_min_score", arguments.minScore ) ) />
		<cfset variables.enabled  = ( len( variables.botToken ) GT 0 AND len( variables.chatId ) GT 0 ) />
		<cfreturn this />
	</cffunction>

	<!--- Pure gate: should this payload be delivered by this channel? --->
	<cffunction name="shouldSend" access="public" returntype="struct" output="false">
		<cfargument name="alertPayload" type="struct" required="true" />
		<cfif NOT variables.enabled>
			<cfreturn { ok: false, reason: "telegram not configured" } />
		</cfif>
		<cfif val( structKeyExists( arguments.alertPayload, "score" ) ? arguments.alertPayload.score : 0 ) LT variables.minScore>
			<cfreturn { ok: false, reason: "below telegram min score (" & variables.minScore & ")" } />
		</cfif>
		<cfreturn { ok: true, reason: "" } />
	</cffunction>

	<cffunction name="formatMessage" access="public" returntype="string" output="false">
		<cfargument name="p" type="struct" required="true" />
		<cfset var msg = "<b>" & encodeForHTML( p.title ) & "</b>" & chr(10) />
		<cfset msg = msg & encodeForHTML( p.company_name ) & " — score " & val( p.score ) & chr(10) />
		<cfif structKeyExists( p, "location" ) AND len( trim( p.location ) )>
			<cfset msg = msg & encodeForHTML( p.location ) & chr(10) />
		</cfif>
		<cfif structKeyExists( p, "reasons" ) AND isArray( p.reasons ) AND arrayLen( p.reasons )>
			<cfset msg = msg & "<i>" & encodeForHTML( arrayToList( p.reasons, ", " ) ) & "</i>" & chr(10) />
		</cfif>
		<cfif structKeyExists( p, "link" ) AND len( trim( p.link ) )>
			<cfset msg = msg & p.link />
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
		<cfset var dedupe = "telegram|" & ruleVer & "|" & val( p.job_id ) />

		<!--- Skip if already delivered on this channel (deduped runs only). --->
		<cfif arguments.persist AND isObject( variables.databaseService ) AND alreadySent( dedupe )>
			<cfreturn { sent: false, error: "already sent" } />
		</cfif>

		<cftry>
			<cfset var msg = formatMessage( p ) />
			<cfhttp url="https://api.telegram.org/bot#variables.botToken#/sendMessage" method="POST" result="resp" timeout="15">
				<cfhttpparam type="formfield" name="chat_id" value="#variables.chatId#" />
				<cfhttpparam type="formfield" name="text" value="#msg#" />
				<cfhttpparam type="formfield" name="parse_mode" value="HTML" />
				<cfhttpparam type="formfield" name="disable_web_page_preview" value="false" />
			</cfhttp>
			<cfset var code = val( listFirst( ( structKeyExists( resp, "statusCode" ) ? resp.statusCode : "0" ) & " 0", " " ) ) />
			<cfif code GTE 200 AND code LT 300>
				<cfif arguments.persist AND isObject( variables.databaseService )><cfset recordSent( p, dedupe ) /></cfif>
				<cfreturn { sent: true, error: "" } />
			</cfif>
			<cfreturn { sent: false, error: "Telegram HTTP " & code & ": " & left( ( structKeyExists( resp, "fileContent" ) ? resp.fileContent : "" ), 300 ) } />
			<cfcatch type="any">
				<cfreturn { sent: false, error: cfcatch.message } />
			</cfcatch>
		</cftry>
	</cffunction>

	<!--- ===== dedupe helpers ===== --->

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
			 VALUES (?, 'telegram', ?, datetime('now'), ?)",
			[
				{ value: val( arguments.p.job_id ), cfsqltype: "cf_sql_integer" },
				{ value: serializeJSON( arguments.p ), cfsqltype: "cf_sql_longvarchar" },
				{ value: arguments.dedupeKey, cfsqltype: "cf_sql_varchar" }
			],
			{ datasource: variables.databaseService.getDatasource() }
		) />
	</cffunction>
</cfcomponent>
