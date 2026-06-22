<cfcomponent output="false" accessors="true">
	<!---
		SourceExpansionService — Phase 3, PR 3.2.

		Reads source_metrics (via SourceGraphService) and grows/shrinks the source set:
		  • candidate sources with proven yield  -> promoted to active
		  • active sources that are dead/erroring -> quarantined

		classifyMetric() is pure (no DB) so the promotion/quarantine policy is fully
		unit-testable. runExpansion() applies the policy across the graph.

		Tag syntax only (project standard).
	--->
	<cfproperty name="graph" type="any" />
	<cfproperty name="loggerService" type="any" />
	<cfproperty name="minRuns" type="numeric" />
	<cfproperty name="promoteYield" type="numeric" />
	<cfproperty name="quarantineYield" type="numeric" />
	<cfproperty name="maxErrorRate" type="numeric" />

	<cffunction name="init" access="public" returntype="any" output="false">
		<cfargument name="graphService" type="any" required="false" default="" />
		<cfargument name="loggerService" type="any" required="false" default="" />
		<cfargument name="minRuns" type="numeric" required="false" default="3" />
		<cfargument name="promoteYield" type="numeric" required="false" default="0.5" />
		<cfargument name="quarantineYield" type="numeric" required="false" default="0.0" />
		<cfargument name="maxErrorRate" type="numeric" required="false" default="0.75" />
		<cfset variables.graph = arguments.graphService />
		<cfset variables.loggerService = arguments.loggerService />
		<cfset variables.minRuns = arguments.minRuns />
		<cfset variables.promoteYield = arguments.promoteYield />
		<cfset variables.quarantineYield = arguments.quarantineYield />
		<cfset variables.maxErrorRate = arguments.maxErrorRate />
		<cfreturn this />
	</cffunction>

	<!---
		Decide what to do with a source given its metrics.
		Returns: "promote" | "quarantine" | "keep"
	--->
	<cffunction name="classifyMetric" access="public" returntype="string" output="false">
		<cfargument name="metric" type="struct" required="true" />
		<cfset var runs = val( structKeyExists( arguments.metric, "runs" ) ? arguments.metric.runs : 0 ) />
		<cfset var yieldScore = val( structKeyExists( arguments.metric, "yield_score" ) ? arguments.metric.yield_score : 0 ) />
		<cfset var errors = val( structKeyExists( arguments.metric, "errors" ) ? arguments.metric.errors : 0 ) />

		<!--- Not enough evidence yet — leave it alone. --->
		<cfif runs LT variables.minRuns>
			<cfreturn "keep" />
		</cfif>

		<cfif yieldScore GTE variables.promoteYield>
			<cfreturn "promote" />
		</cfif>

		<cfset var errorRate = ( runs GT 0 ) ? ( errors / runs ) : 0 />
		<cfif yieldScore LTE variables.quarantineYield OR errorRate GTE variables.maxErrorRate>
			<cfreturn "quarantine" />
		</cfif>

		<cfreturn "keep" />
	</cffunction>

	<!--- Apply the policy across candidate + active sources. --->
	<cffunction name="runExpansion" access="public" returntype="struct" output="false">
		<cfset var summary = { evaluated: 0, promoted: [], quarantined: [] } />

		<cfset var candidates = variables.graph.listSourcesByStatus( "candidate" ) />
		<cfset var c = "" />
		<cfloop array="#candidates#" index="c">
			<cfset var m = variables.graph.getMetric( c.source_key ) />
			<cfif structIsEmpty( m )><cfcontinue /></cfif>
			<cfset summary.evaluated = summary.evaluated + 1 />
			<cfif classifyMetric( m ) EQ "promote">
				<cfset variables.graph.setStatus( c.source_key, "active" ) />
				<cfset arrayAppend( summary.promoted, c.source_key ) />
			</cfif>
		</cfloop>

		<cfset var actives = variables.graph.listSourcesByStatus( "active" ) />
		<cfset var a = "" />
		<cfloop array="#actives#" index="a">
			<cfset var m2 = variables.graph.getMetric( a.source_key ) />
			<cfif structIsEmpty( m2 )><cfcontinue /></cfif>
			<cfset summary.evaluated = summary.evaluated + 1 />
			<cfif classifyMetric( m2 ) EQ "quarantine">
				<cfset variables.graph.setStatus( a.source_key, "quarantined" ) />
				<cfset arrayAppend( summary.quarantined, a.source_key ) />
			</cfif>
		</cfloop>

		<cfif isObject( variables.loggerService )>
			<cfset variables.loggerService.info(
				"Source expansion: evaluated=" & summary.evaluated
				& " promoted=" & arrayLen( summary.promoted )
				& " quarantined=" & arrayLen( summary.quarantined )
			) />
		</cfif>
		<cfreturn summary />
	</cffunction>
</cfcomponent>
