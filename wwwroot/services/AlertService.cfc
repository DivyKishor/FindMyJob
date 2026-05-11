<cfcomponent output="false" accessors="true">
	<cfproperty name="databaseService" type="any" />
	<cfproperty name="loggerService" type="any" />

	<cffunction name="init" access="public" returntype="any" output="false">
		<cfargument name="databaseService" type="any" required="true" />
		<cfargument name="loggerService" type="any" required="true" />
		<cfset variables.databaseService = arguments.databaseService />
		<cfset variables.loggerService = arguments.loggerService />
		<cfreturn this />
	</cffunction>

	<cffunction name="ds" access="private" returntype="string" output="false">
		<cfreturn variables.databaseService.getDatasource() />
	</cffunction>

	<cffunction name="generateAlerts" access="public" returntype="struct" output="false">
		<cfargument name="threshold" type="numeric" required="false" default="40" />
		<cfset q = queryExecute(
			"SELECT j.id AS job_id, j.title, j.link, j.location,
			        c.id AS company_id, c.name AS company_name,
			        js.score, js.reasons_json, js.rule_version
			 FROM jobs j
			 INNER JOIN companies c ON c.id = j.company_id
			 INNER JOIN job_scores js ON js.job_id = j.id
			 WHERE js.score >= ?",
			[ { value: arguments.threshold, cfsqltype: "cf_sql_integer" } ],
			{ datasource: ds() }
		) />
		<cfset created = 0 />
		<cfloop from="1" to="#q.recordCount#" index="rowNum">
			<cfset dedupe = "log|" & q.rule_version[ rowNum ] & "|" & q.job_id[ rowNum ] />
			<cfset payload = {
				job_id: q.job_id[ rowNum ],
				company_id: q.company_id[ rowNum ],
				company_name: q.company_name[ rowNum ],
				title: q.title[ rowNum ],
				location: q.location[ rowNum ],
				link: q.link[ rowNum ],
				score: q.score[ rowNum ],
				reasons: parseReasons( q.reasons_json[ rowNum ] )
			} />
			<cfset queryExecute(
				"INSERT OR IGNORE INTO alerts (job_id, channel, payload_json, sent_at, dedupe_key)
				 VALUES (?, 'log', ?, datetime('now'), ?)",
				[
					{ value: q.job_id[ rowNum ], cfsqltype: "cf_sql_integer" },
					{ value: serializeJSON( payload ), cfsqltype: "cf_sql_longvarchar" },
					{ value: dedupe, cfsqltype: "cf_sql_varchar" }
				],
				{ datasource: ds() }
			) />
			<cfset chg = queryExecute( "SELECT changes() AS c", {}, { datasource: ds() } ) />
			<cfset cCol = listFirst( chg.columnList ) />
			<cfif val( chg[ cCol ][ 1 ] ) EQ 1>
				<cfset created = created + 1 />
				<cfset variables.loggerService.info( "ALERT score=#q.score[rowNum]# company=#q.company_name[rowNum]# title=#q.title[rowNum]#" ) />
			</cfif>
		</cfloop>
		<cfreturn { threshold: arguments.threshold, alertsCreated: created } />
	</cffunction>

	<cffunction name="listAlerts" access="public" returntype="array" output="false">
		<cfargument name="limitRows" type="numeric" required="false" default="200" />
		<cfset pageData = listAlertsPaged( page = 1, pageSize = arguments.limitRows, sortBy = "sent_at", sortDir = "desc" ) />
		<cfreturn pageData.rows />
	</cffunction>

	<cffunction name="listAlertsPaged" access="public" returntype="struct" output="false">
		<cfargument name="page" type="numeric" required="false" default="1" />
		<cfargument name="pageSize" type="numeric" required="false" default="25" />
		<cfargument name="sortBy" type="string" required="false" default="sent_at" />
		<cfargument name="sortDir" type="string" required="false" default="desc" />

		<cfif arguments.page LT 1><cfset arguments.page = 1 /></cfif>
		<cfif arguments.pageSize LT 1><cfset arguments.pageSize = 25 /></cfif>
		<cfif arguments.pageSize GT 200><cfset arguments.pageSize = 200 /></cfif>

		<cfset sortMap = {
			"sent_at": "a.sent_at",
			"channel": "a.channel",
			"company_name": "json_extract(a.payload_json, '$.company_name')",
			"title": "json_extract(a.payload_json, '$.title')",
			"score": "CAST(json_extract(a.payload_json, '$.score') AS INTEGER)"
		} />
		<cfset safeSortBy = lCase( arguments.sortBy ) />
		<cfif NOT structKeyExists( sortMap, safeSortBy )>
			<cfset safeSortBy = "sent_at" />
		</cfif>
		<cfset safeSortDir = lCase( arguments.sortDir ) />
		<cfif safeSortDir NEQ "asc"><cfset safeSortDir = "desc" /></cfif>

		<cfset countQ = queryExecute( "SELECT COUNT(*) AS cnt FROM alerts", {}, { datasource: ds() } ) />
		<cfset cntCol = listFirst( countQ.columnList ) />
		<cfset totalRows = val( countQ[ cntCol ][ 1 ] ) />
		<cfif totalRows EQ 0>
			<cfset totalPages = 1 />
		<cfelse>
			<cfset totalPages = ceiling( totalRows / arguments.pageSize ) />
		</cfif>
		<cfif arguments.page GT totalPages><cfset arguments.page = totalPages /></cfif>
		<cfset offsetRows = ( arguments.page - 1 ) * arguments.pageSize />

		<cfset dataSql = "SELECT a.id, a.job_id, a.channel, a.payload_json, a.sent_at, a.dedupe_key
		                  FROM alerts a
		                  ORDER BY " & sortMap[ safeSortBy ] & " " & safeSortDir & ", a.id DESC
		                  LIMIT ? OFFSET ?" />
		<cfset q = queryExecute(
			dataSql,
			[
				{ value: arguments.pageSize, cfsqltype: "cf_sql_integer" },
				{ value: offsetRows, cfsqltype: "cf_sql_integer" }
			],
			{ datasource: ds() }
		) />
		<cfset rows = variables.databaseService.queryToArray( q ) />
		<cfloop array="#rows#" index="rowItem">
			<cfset rowItem.payload = parsePayload( rowItem.payload_json ) />
			<cfset structDelete( rowItem, "payload_json" ) />
		</cfloop>

		<cfreturn {
			rows: rows,
			totalRows: totalRows,
			page: arguments.page,
			pageSize: arguments.pageSize,
			totalPages: totalPages,
			sortBy: safeSortBy,
			sortDir: safeSortDir
		} />
	</cffunction>

	<cffunction name="parseReasons" access="private" returntype="any" output="false">
		<cfargument name="reasonsJson" type="any" required="true" />
		<cfif isSimpleValue( arguments.reasonsJson ) AND len( trim( arguments.reasonsJson ) )>
			<cftry>
				<cfreturn deserializeJSON( arguments.reasonsJson ) />
				<cfcatch type="any">
					<cfreturn [] />
				</cfcatch>
			</cftry>
		</cfif>
		<cfreturn [] />
	</cffunction>

	<cffunction name="parsePayload" access="private" returntype="struct" output="false">
		<cfargument name="payloadJson" type="any" required="true" />
		<cfif isSimpleValue( arguments.payloadJson ) AND len( trim( arguments.payloadJson ) )>
			<cftry>
				<cfreturn deserializeJSON( arguments.payloadJson ) />
				<cfcatch type="any">
					<cfreturn {} />
				</cfcatch>
			</cftry>
		</cfif>
		<cfreturn {} />
	</cffunction>
</cfcomponent>
