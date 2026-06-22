<cfcomponent output="false" accessors="true">
	<!---
		DataGateway — thin abstraction over queryExecute.

		Goal (Phase 1, F1): centralise the datasource and isolate SQL-dialect quirks
		(timestamp expression, JSON access, upsert/ignore syntax, affected-row count)
		so a later move from SQLite to PostgreSQL is a dialect swap, not a rewrite.

		This is ADDITIVE. Existing services keep calling queryExecute directly; new
		code should call the gateway. Migrate callers opportunistically, never in a
		big-bang rewrite.

		Tag syntax only (project standard).
	--->
	<cfproperty name="datasource" type="string" />
	<cfproperty name="dialect" type="string" />

	<cffunction name="init" access="public" returntype="any" output="false">
		<cfargument name="datasource" type="string" required="true" />
		<cfargument name="dialect" type="string" required="false" default="sqlite" />
		<cfset variables.datasource = arguments.datasource />
		<cfset variables.dialect = lCase( trim( arguments.dialect ) ) />
		<cfif variables.dialect NEQ "sqlite" AND variables.dialect NEQ "postgres">
			<cfthrow type="DataGateway.UnsupportedDialect"
				message="Unsupported dialect '#variables.dialect#'. Use 'sqlite' or 'postgres'." />
		</cfif>
		<cfreturn this />
	</cffunction>

	<cffunction name="getDialect" access="public" returntype="string" output="false">
		<cfreturn variables.dialect />
	</cffunction>

	<!--- ===== Core query helpers ===== --->

	<!--- Run a query and return the native query object. --->
	<cffunction name="query" access="public" returntype="query" output="false">
		<cfargument name="sql" type="string" required="true" />
		<cfargument name="params" type="any" required="false" default="#arrayNew(1)#" />
		<cfargument name="options" type="struct" required="false" default="#structNew()#" />
		<cfset var opts = duplicate( arguments.options ) />
		<cfset opts.datasource = variables.datasource />
		<cfreturn queryExecute( arguments.sql, arguments.params, opts ) />
	</cffunction>

	<!--- Return an array of structs (one per row). --->
	<cffunction name="queryArray" access="public" returntype="array" output="false">
		<cfargument name="sql" type="string" required="true" />
		<cfargument name="params" type="any" required="false" default="#arrayNew(1)#" />
		<cfset var q = this.query( arguments.sql, arguments.params ) />
		<cfreturn queryToArray( q ) />
	</cffunction>

	<!--- Return the first row as a struct, or an empty struct if none. --->
	<cffunction name="queryRow" access="public" returntype="struct" output="false">
		<cfargument name="sql" type="string" required="true" />
		<cfargument name="params" type="any" required="false" default="#arrayNew(1)#" />
		<cfset var rows = queryArray( arguments.sql, arguments.params ) />
		<cfif arrayLen( rows ) GTE 1>
			<cfreturn rows[ 1 ] />
		</cfif>
		<cfreturn structNew() />
	</cffunction>

	<!--- Return a single scalar value (first column of first row) or a default. --->
	<cffunction name="scalar" access="public" returntype="any" output="false">
		<cfargument name="sql" type="string" required="true" />
		<cfargument name="params" type="any" required="false" default="#arrayNew(1)#" />
		<cfargument name="defaultValue" type="any" required="false" default="" />
		<cfset var q = this.query( arguments.sql, arguments.params ) />
		<cfif q.recordCount GTE 1>
			<cfreturn q[ listFirst( q.columnList ) ][ 1 ] />
		</cfif>
		<cfreturn arguments.defaultValue />
	</cffunction>

	<!--- Execute a write (INSERT/UPDATE/DELETE) and return rows affected. --->
	<cffunction name="execute" access="public" returntype="numeric" output="false">
		<cfargument name="sql" type="string" required="true" />
		<cfargument name="params" type="any" required="false" default="#arrayNew(1)#" />
		<cfset var res = "" />
		<cfset var opts = { datasource: variables.datasource, result: "res" } />
		<cfset queryExecute( arguments.sql, arguments.params, opts ) />
		<cfreturn affectedRows() />
	</cffunction>

	<!--- Rows affected by the most recent statement on this connection. --->
	<cffunction name="affectedRows" access="public" returntype="numeric" output="false">
		<cfif variables.dialect EQ "sqlite">
			<cfset var c = this.query( "SELECT changes() AS c" ) />
			<cfreturn val( c[ listFirst( c.columnList ) ][ 1 ] ) />
		</cfif>
		<!--- Postgres: callers should prefer the cfquery result struct; default to 0 here. --->
		<cfreturn 0 />
	</cffunction>

	<!--- Convert a query object to an array of structs (key = lowercased column). --->
	<cffunction name="queryToArray" access="public" returntype="array" output="false">
		<cfargument name="q" type="query" required="true" />
		<cfset var out = arrayNew(1) />
		<cfset var cols = listToArray( arguments.q.columnList ) />
		<cfset var i = 0 />
		<cfset var colItem = "" />
		<cfloop from="1" to="#arguments.q.recordCount#" index="i">
			<cfset var row = structNew() />
			<cfloop array="#cols#" index="colItem">
				<cfset row[ lCase( colItem ) ] = arguments.q[ colItem ][ i ] />
			</cfloop>
			<cfset arrayAppend( out, row ) />
		</cfloop>
		<cfreturn out />
	</cffunction>

	<!--- ===== Dialect-specific SQL fragments ===== --->

	<!--- Current-timestamp SQL expression for use inside statements. --->
	<cffunction name="nowExpr" access="public" returntype="string" output="false">
		<cfif variables.dialect EQ "postgres">
			<cfreturn "now()" />
		</cfif>
		<cfreturn "datetime('now')" />
	</cffunction>

	<!--- JSON field extraction expression for a column + JSON path (e.g. '$.score'). --->
	<cffunction name="jsonExtract" access="public" returntype="string" output="false">
		<cfargument name="column" type="string" required="true" />
		<cfargument name="path" type="string" required="true" />
		<cfif variables.dialect EQ "postgres">
			<!--- jsonb #>> '{score}' style; convert $.a.b to {a,b} --->
			<cfset var pgPath = reReplace( arguments.path, "^\$\.?", "", "one" ) />
			<cfset pgPath = replace( pgPath, ".", ",", "all" ) />
			<cfreturn "(#arguments.column#::jsonb ##>> '{#pgPath#}')" />
		</cfif>
		<cfreturn "json_extract(#arguments.column#, '#arguments.path#')" />
	</cffunction>

	<!--- "Insert, ignore on unique-constraint conflict" prefix. --->
	<cffunction name="insertIgnorePrefix" access="public" returntype="string" output="false">
		<cfif variables.dialect EQ "postgres">
			<cfreturn "INSERT" />
		</cfif>
		<cfreturn "INSERT OR IGNORE" />
	</cffunction>

	<!--- Suffix to complete an insert-ignore for the given conflict target. --->
	<cffunction name="insertIgnoreConflict" access="public" returntype="string" output="false">
		<cfargument name="conflictColumns" type="string" required="true" />
		<cfif variables.dialect EQ "postgres">
			<cfreturn " ON CONFLICT (#arguments.conflictColumns#) DO NOTHING" />
		</cfif>
		<cfreturn "" />
	</cffunction>
</cfcomponent>
