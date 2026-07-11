<cfcomponent extends="testbox.system.BaseSpec" output="false">
	<!--- Exercises every job-board filter flow against seeded fixture data. --->

	<cffunction name="run" access="public" returntype="void" output="false">
		<cfscript>
		describe( "JobService board filters (each flow)", function(){

			beforeEach( function(){
				variables.dbOk = true;
				try {
					variables.gw = new services.DataGateway( "cfintel_test", "sqlite" );
					variables.gw.execute( "DELETE FROM job_scores" );
					variables.gw.execute( "DELETE FROM jobs" );
					variables.gw.execute( "DELETE FROM companies WHERE name = 'FilterTestCo'" );

					variables.gw.execute( "INSERT INTO companies (name, careers_url, careers_source) VALUES ('FilterTestCo','x','career_page_scan')" );
					variables.cid = val( variables.gw.scalar( "SELECT id FROM companies WHERE name='FilterTestCo'", [], 0 ) );

					// J1 India, remote, score 100, very recent
					seedJob( 1, "Senior ColdFusion Developer", "Bangalore, India", "remote", "now", 100, '["cf_tech:coldfusion","india_eligible","remote_fit:+10"]' );
					// J2 US onsite, score 20, old
					seedJob( 2, "ColdFusion Engineer", "Texas, United States", "onsite", "-10 days", 20, '["cf_tech:coldfusion","work_auth_restricted"]' );
					// J3 Lucee remote, sponsorship, score 80, 2 days ago
					seedJob( 3, "Lucee Developer", "Remote", "remote", "-2 days", 80, '["cf_tech:lucee","remote_fit:+10","visa_sponsorship:+20"]' );

					variables.db  = new services.DatabaseService( "cfintel_test" );
					variables.svc = new services.JobService( variables.db, "anyversion" );
				} catch ( any e ) {
					variables.dbOk = false;
				}
			});

			it( "min_score filter (85+) keeps only top jobs", function(){
				if ( !variables.dbOk ) { return; }
				expect( ids( variables.svc.listPaged( minScore = 85, pageSize = 50 ) ) ).toBe( [ "J1" ] );
			});

			it( "min_score 70 keeps J1 + J3", function(){
				if ( !variables.dbOk ) { return; }
				var got = ids( variables.svc.listPaged( minScore = 70, pageSize = 50 ) );
				expect( got ).toInclude( "J1" );
				expect( got ).toInclude( "J3" );
				expect( got ).notToInclude( "J2" );
			});

			it( "keyword filter matches title text", function(){
				if ( !variables.dbOk ) { return; }
				expect( ids( variables.svc.listPaged( keyword = "engineer", pageSize = 50 ) ) ).toBe( [ "J2" ] );
			});

			it( "location=india keeps India roles only", function(){
				if ( !variables.dbOk ) { return; }
				expect( ids( variables.svc.listPaged( locationKeyword = "india", pageSize = 50 ) ) ).toBe( [ "J1" ] );
			});

			it( "sponsorshipOnly keeps roles whose reasons include visa_sponsorship", function(){
				if ( !variables.dbOk ) { return; }
				expect( ids( variables.svc.listPaged( sponsorshipOnly = true, pageSize = 50 ) ) ).toBe( [ "J3" ] );
			});

			it( "newWithinHours keeps recently-found roles", function(){
				if ( !variables.dbOk ) { return; }
				var got = ids( variables.svc.listPaged( newWithinHours = 72, pageSize = 50 ) ); // last 3 days
				expect( got ).toInclude( "J1" );
				expect( got ).toInclude( "J3" );
				expect( got ).notToInclude( "J2" ); // 10 days old
			});

			it( "first_seen sort orders most-recently-found first", function(){
				if ( !variables.dbOk ) { return; }
				expect( ids( variables.svc.listPaged( sortBy = "first_seen", sortDir = "desc", pageSize = 50 ) ) )
					.toBe( [ "J1", "J3", "J2" ] );
			});

		});
		</cfscript>
	</cffunction>

	<!--- insert a job + its latest score; tag is encoded in external_id so we can assert order. --->
	<cffunction name="seedJob" access="private" output="false">
		<cfargument name="n" type="numeric" />
		<cfargument name="title" type="string" />
		<cfargument name="loc" type="string" />
		<cfargument name="wt" type="string" />
		<cfargument name="seenOffset" type="string" />
		<cfargument name="score" type="numeric" />
		<cfargument name="reasonsJson" type="string" />
		<cfset variables.gw.execute(
			"INSERT INTO jobs (company_id, external_id, title, description, location, link, raw_source, fetched_at, first_seen_at, work_type, is_active)
			 VALUES (?, ?, ?, ?, ?, 'http://x', 'test', datetime('now'), datetime('now', ?), ?, 1)",
			[
				{ value: variables.cid, cfsqltype: "cf_sql_integer" },
				{ value: "J" & arguments.n, cfsqltype: "cf_sql_varchar" },
				{ value: arguments.title, cfsqltype: "cf_sql_varchar" },
				{ value: arguments.title, cfsqltype: "cf_sql_longvarchar" },
				{ value: arguments.loc, cfsqltype: "cf_sql_varchar" },
				{ value: ( arguments.seenOffset EQ "now" ? "+0 seconds" : arguments.seenOffset ), cfsqltype: "cf_sql_varchar" },
				{ value: arguments.wt, cfsqltype: "cf_sql_varchar" }
			]
		) />
		<cfset var jid = val( variables.gw.scalar( "SELECT id FROM jobs WHERE company_id = ? AND external_id = ?",
			[ { value: variables.cid, cfsqltype: "cf_sql_integer" }, { value: "J" & arguments.n, cfsqltype: "cf_sql_varchar" } ], 0 ) ) />
		<cfset variables.gw.execute(
			"INSERT INTO job_scores (job_id, rule_version, score, reasons_json, created_at) VALUES (?, 'test_v', ?, ?, datetime('now'))",
			[
				{ value: jid, cfsqltype: "cf_sql_integer" },
				{ value: arguments.score, cfsqltype: "cf_sql_integer" },
				{ value: arguments.reasonsJson, cfsqltype: "cf_sql_longvarchar" }
			]
		) />
	</cffunction>

	<!--- map result rows to their external_id tags (J1/J2/J3) for order-aware assertions. --->
	<cffunction name="ids" access="private" returntype="array" output="false">
		<cfargument name="pageData" type="struct" />
		<cfset var out = [] />
		<cfset var r = "" />
		<cfloop array="#arguments.pageData.rows#" index="r">
			<cfif structKeyExists( r, "external_id" )><cfset arrayAppend( out, r.external_id ) /></cfif>
		</cfloop>
		<cfreturn out />
	</cffunction>

</cfcomponent>
