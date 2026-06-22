<cfcomponent output="false" accessors="true">
	<!---
		TechTaxonomy — single source of truth for the ColdFusion-ecosystem
		technologies this system targets.

		Before this, only coldfusion/cfml/lucee/mura were recognised, so ColdBox,
		FuseBox, CommandBox and WireBox jobs were silently missed. This taxonomy
		feeds scoring, dashboard keyword expansion, and (Phase 2) fingerprinting
		and discovery queries from one place.

		Tag syntax only (project standard).
	--->
	<cfproperty name="techs" type="array" />

	<cffunction name="init" access="public" returntype="any" output="false">
		<cfset variables.techs = [
			{ key: "coldfusion", label: "ColdFusion", category: "language",
			  aliases: [ "coldfusion", "cold fusion", "adobe coldfusion", "adobe cf", "cf developer", "cfscript" ] },
			{ key: "cfml", label: "CFML", category: "language",
			  aliases: [ "cfml", ".cfm", ".cfc" ] },
			{ key: "lucee", label: "Lucee", category: "server",
			  aliases: [ "lucee", "railo" ] },
			{ key: "mura", label: "Mura CMS", category: "cms",
			  aliases: [ "mura", "mura cms", "masa cms" ] },
			{ key: "coldbox", label: "ColdBox", category: "framework",
			  aliases: [ "coldbox", "cold box" ] },
			{ key: "fusebox", label: "FuseBox", category: "framework",
			  aliases: [ "fusebox", "fuse box" ] },
			{ key: "commandbox", label: "CommandBox", category: "tooling",
			  aliases: [ "commandbox", "command box" ] },
			{ key: "wirebox", label: "WireBox", category: "framework",
			  aliases: [ "wirebox", "wire box" ] }
		] />
		<cfreturn this />
	</cffunction>

	<cffunction name="getTechs" access="public" returntype="array" output="false">
		<cfreturn variables.techs />
	</cffunction>

	<cffunction name="techKeys" access="public" returntype="array" output="false">
		<cfset var out = arrayNew(1) />
		<cfset var t = "" />
		<cfloop array="#variables.techs#" index="t">
			<cfset arrayAppend( out, t.key ) />
		</cfloop>
		<cfreturn out />
	</cffunction>

	<!--- Flat list of every alias across all techs (for search expansion). --->
	<cffunction name="allAliases" access="public" returntype="array" output="false">
		<cfset var out = arrayNew(1) />
		<cfset var t = "" />
		<cfset var a = "" />
		<cfloop array="#variables.techs#" index="t">
			<cfloop array="#t.aliases#" index="a">
				<cfif NOT arrayFindNoCase( out, a )>
					<cfset arrayAppend( out, a ) />
				</cfif>
			</cfloop>
		</cfloop>
		<cfreturn out />
	</cffunction>

	<!--- Return the tech keys whose aliases appear in the given text. --->
	<cffunction name="matchText" access="public" returntype="array" output="false">
		<cfargument name="text" type="string" required="true" />
		<cfset var h = lCase( trim( arguments.text ) ) />
		<cfset var matched = arrayNew(1) />
		<cfset var t = "" />
		<cfset var a = "" />
		<cfif NOT len( h )><cfreturn matched /></cfif>
		<cfloop array="#variables.techs#" index="t">
			<cfloop array="#t.aliases#" index="a">
				<cfif termMatches( h, a )>
					<cfif NOT arrayFindNoCase( matched, t.key )>
						<cfset arrayAppend( matched, t.key ) />
					</cfif>
					<cfbreak />
				</cfif>
			</cfloop>
		</cfloop>
		<cfreturn matched />
	</cffunction>

	<cffunction name="matchesAny" access="public" returntype="boolean" output="false">
		<cfargument name="text" type="string" required="true" />
		<cfreturn arrayLen( matchText( arguments.text ) ) GT 0 />
	</cffunction>

	<!--- Expand a user keyword: if it's an ecosystem umbrella term, return every
	      alias so a search for "coldfusion" / "cf" also finds ColdBox etc. --->
	<cffunction name="expandKeyword" access="public" returntype="array" output="false">
		<cfargument name="keyword" type="string" required="true" />
		<cfset var kw = lCase( trim( arguments.keyword ) ) />
		<cfset var umbrellaTriggers = [ "coldfusion", "cf", "cfml", "lucee", "cold fusion", "cf stack", "coldfusion stack" ] />
		<cfif arrayFindNoCase( umbrellaTriggers, kw )>
			<cfreturn allAliases() />
		</cfif>
		<cfreturn [ trim( arguments.keyword ) ] />
	</cffunction>

	<!--- Word-boundary match for single tokens; substring for multi-word/symbol terms. --->
	<cffunction name="termMatches" access="public" returntype="boolean" output="false">
		<cfargument name="haystack" type="string" required="true" />
		<cfargument name="term" type="string" required="true" />
		<cfset var h = lCase( trim( arguments.haystack ) ) />
		<cfset var term = lCase( trim( arguments.term ) ) />
		<cfif NOT len( h ) OR NOT len( term )><cfreturn false /></cfif>
		<!--- Terms containing whitespace or a leading dot/symbol: plain substring. --->
		<cfif reFind( "[^a-z0-9]", term ) GT 0>
			<cfreturn findNoCase( term, h ) GT 0 />
		</cfif>
		<cfset var escaped = reReplace( term, "([\.\^\$\|\?\*\+\(\)\[\]\{\}\\])", "\\\1", "all" ) />
		<cfreturn reFindNoCase( "\b#escaped#\b", h, 1 ) GT 0 />
	</cffunction>
</cfcomponent>
