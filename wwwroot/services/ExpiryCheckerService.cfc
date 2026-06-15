<cfcomponent output="false">

	<cffunction name="init" access="public" returntype="any" output="false">
		<cfargument name="jobService" type="any" required="true" />
		<cfargument name="loggerService" type="any" required="true" />
		<cfset variables.jobService = arguments.jobService />
		<cfset variables.loggerService = arguments.loggerService />
		<cfreturn this />
	</cffunction>

	<!---
		Check up to `limit` jobs that haven't been verified in `minDaysSinceCheck` days.
		Sends a HEAD request (falls back to GET if 405). Marks jobs inactive on 404/410.
		Returns summary struct: { checked, active, expired, errors }.
	--->
	<cffunction name="checkBatch" access="public" returntype="struct" output="false">
		<cfargument name="limit" type="numeric" required="false" default="50" />
		<cfargument name="minDaysSinceCheck" type="numeric" required="false" default="7" />
		<cfset var summary = { checked: 0, active: 0, expired: 0, errors: 0 } />
		<cfset var jobs = variables.jobService.listForExpiryCheck( arguments.limit, arguments.minDaysSinceCheck ) />

		<cfloop array="#jobs#" index="j">
			<cftry>
				<cfset var result = checkJobUrl( j.link ) />
				<cfset variables.jobService.updateJobStatus( j.id, result.isActive ) />
				<cfif result.isActive>
					<cfset summary.active = summary.active + 1 />
				<cfelse>
					<cfset summary.expired = summary.expired + 1 />
					<cfset variables.loggerService.info( "Job expired (HTTP #result.statusCode#): [#j.id#] #j.title# — #j.company_name#" ) />
				</cfif>
				<cfset summary.checked = summary.checked + 1 />
				<cfset sleep( 400 ) />
			<cfcatch type="any">
				<cfset summary.errors = summary.errors + 1 />
				<cfset variables.loggerService.warn( "Expiry check failed for job #j.id# (#j.title#): #cfcatch.message#" ) />
			</cfcatch>
			</cftry>
		</cfloop>

		<cfset variables.loggerService.info( "Expiry check complete: checked=#summary.checked# active=#summary.active# expired=#summary.expired# errors=#summary.errors#" ) />
		<cfreturn summary />
	</cffunction>

	<!---
		Check a single job URL. Returns { isActive: boolean, statusCode: numeric }.
		Sends HEAD first; falls back to GET on 405 (method not allowed).
		404 or 410 → inactive. All other codes (including connection errors) → leave unchanged (treated as active).
	--->
	<cffunction name="checkJobUrl" access="private" returntype="struct" output="false">
		<cfargument name="url" type="string" required="true" />
		<cfset var u = trim( arguments.url ) />
		<cfif NOT len( u ) OR reFindNoCase( "^https?://", u ) EQ 0>
			<cfreturn { isActive: false, statusCode: 0 } />
		</cfif>

		<cfhttp url="#u#" method="HEAD" result="hRes" timeout="12" redirect="true" />
		<cfset var code = val( listFirst( hRes.statusCode & " 0", " " ) ) />

		<!--- Server doesn't support HEAD — retry with GET (just need the status) --->
		<cfif code EQ 405 OR code EQ 0>
			<cfhttp url="#u#" method="GET" result="hRes" timeout="15" redirect="true" />
			<cfset code = val( listFirst( hRes.statusCode & " 0", " " ) ) />
		</cfif>

		<!--- Only 404 / 410 are definitive "gone" signals; other errors we leave as active --->
		<cfif code EQ 404 OR code EQ 410>
			<cfreturn { isActive: false, statusCode: code } />
		</cfif>

		<!--- 200–3xx, 429, 5xx all mean "still alive" for our purposes --->
		<cfreturn { isActive: true, statusCode: code } />
	</cffunction>

</cfcomponent>
