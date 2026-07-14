<cfcomponent extends="testbox.system.BaseSpec" output="false">

	<cffunction name="run" access="public" returntype="void" output="false">
		<cfscript>
		describe( "SourceScheduler (Phase 3, PR 3.4)", function(){

			beforeEach( function(){
				variables.sch = new services.SourceScheduler();
			});

			it( "tiers sources by yield", function(){
				expect( variables.sch.tierFor( { yield_score: 2.0 } ) ).toBe( "hot" );
				expect( variables.sch.tierFor( { yield_score: 0.3 } ) ).toBe( "warm" );
				expect( variables.sch.tierFor( { yield_score: 0.0 } ) ).toBe( "cold" );
			});

			it( "maps tiers to cadence intervals", function(){
				expect( variables.sch.intervalMinutesFor( "hot" ) ).toBe( 360 );
				expect( variables.sch.intervalMinutesFor( "warm" ) ).toBe( 1440 );
				expect( variables.sch.intervalMinutesFor( "cold" ) ).toBe( 10080 );
			});

			it( "is due only once the tier interval has elapsed", function(){
				// hot source: due after 6h (360m)
				expect( variables.sch.dueGivenElapsed( { yield_score: 2.0 }, 300 ) ).toBeFalse();
				expect( variables.sch.dueGivenElapsed( { yield_score: 2.0 }, 400 ) ).toBeTrue();
				// cold source: not due at 1 day, due after 7 days
				expect( variables.sch.dueGivenElapsed( { yield_score: 0.0 }, 1440 ) ).toBeFalse();
				expect( variables.sch.dueGivenElapsed( { yield_score: 0.0 }, 10100 ) ).toBeTrue();
			});

			it( "treats a never-run source as due", function(){
				expect( variables.sch.isDue( { yield_score: 0.0 } ) ).toBeTrue();
				expect( variables.sch.isDue( { yield_score: 0.0, last_run_at: "" } ) ).toBeTrue();
			});

			it( "treats a freshly-run hot source as not due", function(){
				var justNow = dateTimeFormat( now(), "yyyy-mm-dd HH:nn:ss" );
				expect( variables.sch.isDue( { yield_score: 2.0, last_run_at: justNow } ) ).toBeFalse();
			});

			it( "selects only due source keys", function(){
				var old = dateTimeFormat( dateAdd( "d", -30, now() ), "yyyy-mm-dd HH:nn:ss" );
				var fresh = dateTimeFormat( now(), "yyyy-mm-dd HH:nn:ss" );
				var metrics = [
					{ source_key: "stale_cold", yield_score: 0.0, last_run_at: old },
					{ source_key: "fresh_hot",  yield_score: 2.0, last_run_at: fresh },
					{ source_key: "never_run",  yield_score: 0.5 }
				];
				var due = variables.sch.selectDue( metrics );
				expect( due ).toInclude( "stale_cold" );
				expect( due ).toInclude( "never_run" );
				expect( due ).notToInclude( "fresh_hot" );
			});

		});
		</cfscript>
	</cffunction>

</cfcomponent>
