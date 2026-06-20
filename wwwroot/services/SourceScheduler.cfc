<cfcomponent output="false" accessors="true">
	<!---
		SourceScheduler — Phase 3, PR 3.4.

		Moves the system from once-daily to a tiered, continuous cadence: high-yield
		("hot") sources are checked often, dead-ish ("cold") sources rarely. The
		tier/interval/elapsed logic is pure so it is fully unit-testable; isDue()
		layers real timestamps on top.

		Tag syntax only (project standard).
	--->
	<cfproperty name="hotYield" type="numeric" />
	<cfproperty name="warmYield" type="numeric" />
	<cfproperty name="hotIntervalMin" type="numeric" />
	<cfproperty name="warmIntervalMin" type="numeric" />
	<cfproperty name="coldIntervalMin" type="numeric" />

	<cffunction name="init" access="public" returntype="any" output="false">
		<cfargument name="hotYield" type="numeric" required="false" default="1.0" />
		<cfargument name="warmYield" type="numeric" required="false" default="0.1" />
		<cfargument name="hotIntervalMin" type="numeric" required="false" default="360" />     <!--- 6h --->
		<cfargument name="warmIntervalMin" type="numeric" required="false" default="1440" />   <!--- 1d --->
		<cfargument name="coldIntervalMin" type="numeric" required="false" default="10080" />  <!--- 7d --->
		<cfset variables.hotYield = arguments.hotYield />
		<cfset variables.warmYield = arguments.warmYield />
		<cfset variables.hotIntervalMin = arguments.hotIntervalMin />
		<cfset variables.warmIntervalMin = arguments.warmIntervalMin />
		<cfset variables.coldIntervalMin = arguments.coldIntervalMin />
		<cfreturn this />
	</cffunction>

	<cffunction name="tierFor" access="public" returntype="string" output="false">
		<cfargument name="metric" type="struct" required="true" />
		<cfset var y = val( structKeyExists( arguments.metric, "yield_score" ) ? arguments.metric.yield_score : 0 ) />
		<cfif y GTE variables.hotYield><cfreturn "hot" /></cfif>
		<cfif y GTE variables.warmYield><cfreturn "warm" /></cfif>
		<cfreturn "cold" />
	</cffunction>

	<cffunction name="intervalMinutesFor" access="public" returntype="numeric" output="false">
		<cfargument name="tier" type="string" required="true" />
		<cfswitch expression="#lCase( arguments.tier )#">
			<cfcase value="hot"><cfreturn variables.hotIntervalMin /></cfcase>
			<cfcase value="warm"><cfreturn variables.warmIntervalMin /></cfcase>
			<cfdefaultcase><cfreturn variables.coldIntervalMin /></cfdefaultcase>
		</cfswitch>
	</cffunction>

	<!--- Pure: is a source due given how many minutes have elapsed since its last run? --->
	<cffunction name="dueGivenElapsed" access="public" returntype="boolean" output="false">
		<cfargument name="metric" type="struct" required="true" />
		<cfargument name="elapsedMinutes" type="numeric" required="true" />
		<cfreturn arguments.elapsedMinutes GTE intervalMinutesFor( tierFor( arguments.metric ) ) />
	</cffunction>

	<!--- Real-clock variant. A never-run source (no last_run_at) is always due. --->
	<cffunction name="isDue" access="public" returntype="boolean" output="false">
		<cfargument name="metric" type="struct" required="true" />
		<cfargument name="nowDate" type="any" required="false" default="#now()#" />
		<cfif NOT structKeyExists( arguments.metric, "last_run_at" )
		      OR NOT isSimpleValue( arguments.metric.last_run_at )
		      OR NOT len( trim( arguments.metric.last_run_at ) )>
			<cfreturn true />
		</cfif>
		<cftry>
			<cfset var last = parseDateTime( arguments.metric.last_run_at ) />
			<cfset var elapsed = dateDiff( "n", last, arguments.nowDate ) />
			<cfreturn dueGivenElapsed( arguments.metric, elapsed ) />
			<cfcatch type="any">
				<cfreturn true /> <!--- unparseable timestamp: treat as due --->
			</cfcatch>
		</cftry>
	</cffunction>

	<!--- Filter a list of metric structs to those due now; returns their source_keys. --->
	<cffunction name="selectDue" access="public" returntype="array" output="false">
		<cfargument name="metrics" type="array" required="true" />
		<cfargument name="nowDate" type="any" required="false" default="#now()#" />
		<cfset var out = [] />
		<cfset var m = "" />
		<cfloop array="#arguments.metrics#" index="m">
			<cfif isDue( m, arguments.nowDate ) AND structKeyExists( m, "source_key" )>
				<cfset arrayAppend( out, m.source_key ) />
			</cfif>
		</cfloop>
		<cfreturn out />
	</cffunction>
</cfcomponent>
