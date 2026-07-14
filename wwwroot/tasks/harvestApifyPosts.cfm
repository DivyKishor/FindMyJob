<cfsetting showdebugoutput="false" requesttimeout="600" />
<cfcontent type="application/json; charset=utf-8" />
<!--- Pull CF hiring POSTS from LinkedIn via the Apify "No Cookies" actor and upsert the
      real ones (rawSource=apify_post). Token-gated: no-ops cleanly when no apify_token is
      set. Recency is enforced inside the adapter (default <= 7 days), so the board never
      fills with month-old posts.

      Optional config/app.json overrides:
        secrets.apify_token   (required to run)
        apify.search_queries  (array; defaults to the tuned CF query set)
        apify.max_posts       (numeric per query; default 25)
        apify.max_age_days    (numeric; default 7) --->
<cftry>
	<cfset token = trim( application.appConfig.secret( "apify_token" ) ) />
	<cfif NOT len( token )>
		<cfoutput>#serializeJSON( { ok: false, skipped: true, reason: "apify_token not configured (set secrets.apify_token in config/app.json)" } )#</cfoutput>
		<cfabort />
	</cfif>

	<cfset args = { token: token } />
	<cfset cfgQueries = application.appConfig.get( "apify.search_queries", "" ) />
	<cfif isArray( cfgQueries ) AND arrayLen( cfgQueries ) GT 0>
		<cfset args.searchQueries = cfgQueries />
	</cfif>
	<cfset cfgMax = val( application.appConfig.get( "apify.max_posts", 0 ) ) />
	<cfif cfgMax GT 0><cfset args.maxPosts = cfgMax /></cfif>
	<cfset cfgAge = val( application.appConfig.get( "apify.max_age_days", 0 ) ) />
	<cfif cfgAge GT 0><cfset args.maxAgeDays = cfgAge /></cfif>

	<cfset summary = application.scrapeOrchestrator.ingestApifyPosts( argumentCollection = args ) />
	<cfoutput>#serializeJSON( summary )#</cfoutput>
	<cfcatch type="any">
		<cfheader statusCode="500" />
		<cfoutput>#serializeJSON( { ok: false, error: cfcatch.message } )#</cfoutput>
	</cfcatch>
</cftry>
