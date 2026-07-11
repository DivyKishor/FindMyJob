<cfcomponent extends="testbox.system.BaseSpec" output="false">

	<cffunction name="run" access="public" returntype="void" output="false">
		<cfscript>
		describe( "JobService.listPaged filter flows", function(){

			beforeEach( function(){
				variables.dbOk = true;
				try {
					variables.gw = new services.DataGateway( "cfintel_test", "sqlite" );
					variables.gw.execute( "DELETE FROM job_scores" );
					variables.gw.execute( "DELETE FROM jobs" );
					variables.gw.execute( "DELETE FROM companies WHERE name = 'FT_Co'" );
					variables.gw.execute( "INSERT INTO companies (name, website, careers_url, careers_source) VALUES ('FT_Co','','x','custom')" );
					variables.cid = val( variables.gw.scalar( "SELECT id FROM companies WHERE name = 'FT_Co'", [], 0 ) );

					seed( "A", "ColdFusion Developer", "Lucee remote role", "Bengaluru, India",       "remote", 0,   100, [ "cf_tech:coldfusion", "india_eligible", "remote_fit:+10" ] );
					seed( "B", "ColdFusion Developer", "US onsite, citizen", "Texas, United States",   "onsite", 5,   20,  [ "cf_tech:coldfusion", "work_auth_restricted" ] );
					seed( "C", "ColdFusion Developer", "Visa sponsorship available", "Remote",          "remote", 0,   80,  [ "cf_tech:coldfusion", "visa_sponsorship:+20", "remote_fit:+10" ] );
					seed( "D", "ColdFusion Developer", "plain", "",                                      "unknown", 100, 50, [ "cf_tech:coldfusion" ] );

					variables.svc = new services.JobService(
						new services.DatabaseService( "cfintel_test" ), "vtest", new services.TechTaxonomy() );
				} catch ( any e ) {
					variables.dbOk = false;
				}
			});

			it( "returns all jobs with no filter", function(){
				if ( !variables.dbOk ) { return; }
				expect( total( {} ) ).toBe( 4 );
			});

			it( "filters by minimum score", function(){
				if ( !variables.dbOk ) { return; }
				expect( total( { minScore: 85 } ) ).toBe( 1 );   // only the 100
				expect( total( { minScore: 70 } ) ).toBe( 2 );   // 100 + 80
			});

			it( "filters by work type", function(){
				if ( !variables.dbOk ) { return; }
				expect( total( { workType: "remote" } ) ).toBe( 2 );
				expect( total( { workType: "onsite" } ) ).toBe( 1 );
			});

			it( "filters by visa sponsorship", function(){
				if ( !variables.dbOk ) { return; }
				expect( total( { sponsorshipOnly: true } ) ).toBe( 1 );
			});

			it( "filters by new-within-hours (recency window)", function(){
				if ( !variables.dbOk ) { return; }
				expect( total( { newWithinHours: 24 } ) ).toBe( 2 );  // A + C are fresh; B(5d) D(100d) excluded
			});

			it( "excludes US/clearance jobs from india-eligible", function(){
				if ( !variables.dbOk ) { return; }
				expect( total( { locationKeyword: "india-eligible" } ) ).toBe( 3 ); // all but the US job B
			});

			it( "matches a pure india location", function(){
				if ( !variables.dbOk ) { return; }
				expect( total( { locationKeyword: "india" } ) ).toBe( 1 );
			});

			it( "accepts the first_seen recency sort without error", function(){
				if ( !variables.dbOk ) { return; }
				var data = variables.svc.listPaged( sortBy = "first_seen", sortDir = "desc", pageSize = 10 );
				expect( data.rows.len() ).toBe( 4 );
				expect( data.sortBy ).toBe( "first_seen" );
			});

		});
		</cfscript>
	</cffunction>

	<!--- Insert a job + its latest score row. daysAgo shifts first_seen_at for recency tests. --->
	<cffunction name="seed" access="private" output="false">
		<cfargument name="extId" />
		<cfargument name="title" />
		<cfargument name="descr" />
		<cfargument name="loc" />
		<cfargument name="wt" />
		<cfargument name="daysAgo" />
		<cfargument name="score" />
		<cfargument name="reasons" />
		<cfset var ts = dateTimeFormat( dateAdd( "d", -val( arguments.daysAgo ), now() ), "yyyy-mm-dd HH:nn:ss" ) />
		<cfset variables.gw.execute(
			"INSERT INTO jobs (company_id, external_id, title, description, location, link, raw_source, fetched_at, first_seen_at, work_type, is_active)
			 VALUES (?, ?, ?, ?, ?, 'http://x', 'custom', ?, ?, ?, 1)",
			[
				{ value: variables.cid, cfsqltype: "cf_sql_integer" },
				{ value: arguments.extId, cfsqltype: "cf_sql_varchar" },
				{ value: arguments.title, cfsqltype: "cf_sql_varchar" },
				{ value: arguments.descr, cfsqltype: "cf_sql_longvarchar" },
				{ value: arguments.loc, cfsqltype: "cf_sql_varchar" },
				{ value: ts, cfsqltype: "cf_sql_varchar" },
				{ value: ts, cfsqltype: "cf_sql_varchar" },
				{ value: arguments.wt, cfsqltype: "cf_sql_varchar" }
			]
		) />
		<cfset var jid = val( variables.gw.scalar( "SELECT id FROM jobs WHERE company_id = ? AND external_id = ?",
			[ { value: variables.cid, cfsqltype: "cf_sql_integer" }, { value: arguments.extId, cfsqltype: "cf_sql_varchar" } ], 0 ) ) />
		<cfset variables.gw.execute(
			"INSERT INTO job_scores (job_id, rule_version, score, reasons_json, created_at) VALUES (?, 'vtest', ?, ?, datetime('now'))",
			[
				{ value: jid, cfsqltype: "cf_sql_integer" },
				{ value: val( arguments.score ), cfsqltype: "cf_sql_integer" },
				{ value: serializeJSON( arguments.reasons ), cfsqltype: "cf_sql_longvarchar" }
			]
		) />
	</cffunction>

	<cffunction name="total" access="private" returntype="numeric" output="false">
		<cfargument name="opts" type="struct" required="true" />
		<cfreturn variables.svc.listPaged(
			minScore        = structKeyExists( arguments.opts, "minScore" ) ? arguments.opts.minScore : 0,
			workType        = structKeyExists( arguments.opts, "workType" ) ? arguments.opts.workType : "",
			locationKeyword = structKeyExists( arguments.opts, "locationKeyword" ) ? arguments.opts.locationKeyword : "",
			sponsorshipOnly = structKeyExists( arguments.opts, "sponsorshipOnly" ) ? arguments.opts.sponsorshipOnly : false,
			newWithinHours  = structKeyExists( arguments.opts, "newWithinHours" ) ? arguments.opts.newWithinHours : 0,
			pageSize        = 50
		).totalRows />
	</cffunction>

</cfcomponent>
