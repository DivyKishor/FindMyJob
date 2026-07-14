<cfcomponent output="false" accessors="true">
	<!---
		AlertService — Phase 2, PR 2.4 update.

		Now dispatches through an array of AlertChannel instances so new channels
		(Telegram, WhatsApp) can be added without modifying this service.

		Backward-compatible init signature: the `channels` argument is optional and
		defaults to a single LogChannel (which replicates the pre-PR-2.4 behaviour).
		All existing callers (Application.cfc, generateAlerts.cfm, tests) continue to
		work without changes.

		Tag syntax only (project standard).
	--->

	<cfproperty name="databaseService" type="any" />
	<cfproperty name="loggerService"   type="any" />
	<cfproperty name="channels"        type="array" />

	<cffunction name="init" access="public" returntype="any" output="false">
		<cfargument name="databaseService" type="any"   required="true" />
		<cfargument name="loggerService"   type="any"   required="true" />
		<!--- channels: array of AlertChannel instances.  Defaults to [LogChannel]. --->
		<cfargument name="channels"        type="array" required="false" default="#arrayNew(1)#" />
		<cfset variables.databaseService = arguments.databaseService />
		<cfset variables.loggerService   = arguments.loggerService />
		<cfif arrayLen( arguments.channels ) GT 0>
			<cfset variables.channels = arguments.channels />
		<cfelse>
			<!--- Default: LogChannel replicates the pre-P2.4 write-to-DB behaviour. --->
			<cfset variables.channels = [
				createObject( "component", "services.LogChannel" ).init(
					arguments.databaseService,
					arguments.loggerService
				)
			] />
		</cfif>
		<cfreturn this />
	</cffunction>

	<!--- Add a channel at runtime (e.g. after init when credentials become available). --->
	<cffunction name="addChannel" access="public" returntype="void" output="false">
		<cfargument name="channel" type="any" required="true" />
		<cfset arrayAppend( variables.channels, arguments.channel ) />
	</cffunction>

	<!--- Registered channels (used by the alert-channels operator page + test task). --->
	<cffunction name="getChannels" access="public" returntype="array" output="false">
		<cfreturn variables.channels />
	</cffunction>

	<cffunction name="ds" access="private" returntype="string" output="false">
		<cfreturn variables.databaseService.getDatasource() />
	</cffunction>

	<!---
		generateAlerts( threshold )
		  Finds qualifying job scores, builds a payload per job, then dispatches to
		  every registered channel.  Returns { threshold, alertsCreated, channelResults }.
		  alertsCreated counts distinct new alerts across all channels.
	--->
	<cffunction name="generateAlerts" access="public" returntype="struct" output="false">
		<cfargument name="threshold" type="numeric" required="false" default="40" />

		<!--- Most-recent score row per job, above threshold. --->
		<cfset var q = queryExecute(
			"SELECT j.id AS job_id, j.title, j.link, j.location,
			        c.id AS company_id, c.name AS company_name,
			        js.score, js.reasons_json, js.rule_version
			 FROM jobs j
			 INNER JOIN companies c ON c.id = j.company_id
			 INNER JOIN job_scores js ON js.job_id = j.id
			     AND js.id = (
			         SELECT id FROM job_scores js2
			         WHERE js2.job_id = j.id
			         ORDER BY js2.created_at DESC
			         LIMIT 1
			     )
			 WHERE js.score >= ?",
			[ { value: arguments.threshold, cfsqltype: "cf_sql_integer" } ],
			{ datasource: ds() }
		) />

		<cfset var created        = 0 />
		<cfset var channelResults = [] />

		<cfloop from="1" to="#q.recordCount#" index="rowNum">
			<cfset var payload = {
				job_id:       q.job_id[ rowNum ],
				company_id:   q.company_id[ rowNum ],
				company_name: q.company_name[ rowNum ],
				title:        q.title[ rowNum ],
				location:     q.location[ rowNum ],
				link:         q.link[ rowNum ],
				score:        q.score[ rowNum ],
				rule_version: q.rule_version[ rowNum ],
				reasons:      parseReasons( q.reasons_json[ rowNum ] )
			} />

			<!--- Dispatch to each enabled channel. --->
			<cfloop array="#variables.channels#" index="ch">
				<cfif ch.isEnabled()>
					<cftry>
						<cfset var chResult = ch.send( payload ) />
						<cfif chResult.sent>
							<cfset created = created + 1 />
						</cfif>
						<cfset arrayAppend( channelResults, {
							channel: ch.getChannelName(),
							job_id:  payload.job_id,
							sent:    chResult.sent,
							error:   chResult.error
						} ) />
						<cfcatch type="any">
							<cfset variables.loggerService.warn(
								"AlertChannel #ch.getChannelName()# error for job_id=#payload.job_id#: #cfcatch.message#"
							) />
							<cfset arrayAppend( channelResults, {
								channel: ch.getChannelName(),
								job_id:  payload.job_id,
								sent:    false,
								error:   cfcatch.message
							} ) />
						</cfcatch>
					</cftry>
				</cfif>
			</cfloop>
		</cfloop>

		<cfreturn {
			threshold:      arguments.threshold,
			alertsCreated:  created,
			channelResults: channelResults
		} />
	</cffunction>

	<!--- ===== Read-side (unchanged from pre-PR-2.4) ===== --->

	<cffunction name="listAlerts" access="public" returntype="array" output="false">
		<cfargument name="limitRows" type="numeric" required="false" default="200" />
		<cfset var pageData = listAlertsPaged( page = 1, pageSize = arguments.limitRows, sortBy = "sent_at", sortDir = "desc" ) />
		<cfreturn pageData.rows />
	</cffunction>

	<cffunction name="listAlertsPaged" access="public" returntype="struct" output="false">
		<cfargument name="page"     type="numeric" required="false" default="1" />
		<cfargument name="pageSize" type="numeric" required="false" default="25" />
		<cfargument name="sortBy"   type="string"  required="false" default="sent_at" />
		<cfargument name="sortDir"  type="string"  required="false" default="desc" />

		<cfif arguments.page     LT 1>  <cfset arguments.page     = 1 />  </cfif>
		<cfif arguments.pageSize LT 1>  <cfset arguments.pageSize = 25 /> </cfif>
		<cfif arguments.pageSize GT 200><cfset arguments.pageSize = 200 /></cfif>

		<cfset var sortMap = {
			"sent_at":      "a.sent_at",
			"channel":      "a.channel",
			"company_name": "json_extract(a.payload_json, '$.company_name')",
			"title":        "json_extract(a.payload_json, '$.title')",
			"score":        "CAST(json_extract(a.payload_json, '$.score') AS INTEGER)"
		} />
		<cfset var safeSortBy  = lCase( arguments.sortBy ) />
		<cfif NOT structKeyExists( sortMap, safeSortBy )><cfset safeSortBy = "sent_at" /></cfif>
		<cfset var safeSortDir = lCase( arguments.sortDir ) />
		<cfif safeSortDir NEQ "asc"><cfset safeSortDir = "desc" /></cfif>

		<cfset var countQ    = queryExecute( "SELECT COUNT(*) AS cnt FROM alerts", {}, { datasource: ds() } ) />
		<cfset var cntCol    = listFirst( countQ.columnList ) />
		<cfset var totalRows = val( countQ[ cntCol ][ 1 ] ) />
		<cfset var totalPages = ( totalRows EQ 0 ) ? 1 : ceiling( totalRows / arguments.pageSize ) />
		<cfif arguments.page GT totalPages><cfset arguments.page = totalPages /></cfif>
		<cfset var offsetRows = ( arguments.page - 1 ) * arguments.pageSize />

		<cfset var dataSql = "SELECT a.id, a.job_id, a.channel, a.payload_json, a.sent_at, a.dedupe_key
		                      FROM alerts a
		                      ORDER BY " & sortMap[ safeSortBy ] & " " & safeSortDir & ", a.id DESC
		                      LIMIT ? OFFSET ?" />
		<cfset var q = queryExecute(
			dataSql,
			[
				{ value: arguments.pageSize, cfsqltype: "cf_sql_integer" },
				{ value: offsetRows,         cfsqltype: "cf_sql_integer" }
			],
			{ datasource: ds() }
		) />
		<cfset var rows = variables.databaseService.queryToArray( q ) />
		<cfloop array="#rows#" index="rowItem">
			<cfset rowItem.payload = parsePayload( rowItem.payload_json ) />
			<cfset structDelete( rowItem, "payload_json" ) />
		</cfloop>

		<cfreturn {
			rows:       rows,
			totalRows:  totalRows,
			page:       arguments.page,
			pageSize:   arguments.pageSize,
			totalPages: totalPages,
			sortBy:     safeSortBy,
			sortDir:    safeSortDir
		} />
	</cffunction>

	<!--- ===== Private helpers ===== --->

	<cffunction name="parseReasons" access="private" returntype="any" output="false">
		<cfargument name="reasonsJson" type="any" required="true" />
		<cfif isSimpleValue( arguments.reasonsJson ) AND len( trim( arguments.reasonsJson ) )>
			<cftry>
				<cfreturn deserializeJSON( arguments.reasonsJson ) />
				<cfcatch type="any"><cfreturn [] /></cfcatch>
			</cftry>
		</cfif>
		<cfreturn [] />
	</cffunction>

	<cffunction name="parsePayload" access="private" returntype="struct" output="false">
		<cfargument name="payloadJson" type="any" required="true" />
		<cfif isSimpleValue( arguments.payloadJson ) AND len( trim( arguments.payloadJson ) )>
			<cftry>
				<cfreturn deserializeJSON( arguments.payloadJson ) />
				<cfcatch type="any"><cfreturn {} /></cfcatch>
			</cftry>
		</cfif>
		<cfreturn {} />
	</cffunction>

</cfcomponent>
