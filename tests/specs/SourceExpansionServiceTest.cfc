<cfcomponent extends="testbox.system.BaseSpec" output="false">

	<cffunction name="run" access="public" returntype="void" output="false">
		<cfscript>
		describe( "SourceExpansionService.classifyMetric (Phase 3, PR 3.2)", function(){

			beforeEach( function(){
				// Pure-logic: no graph/DB needed for classifyMetric.
				variables.svc = new services.SourceExpansionService();
			});

			it( "keeps sources with too few runs (insufficient evidence)", function(){
				expect( variables.svc.classifyMetric( { runs: 1, yield_score: 5.0, errors: 0 } ) ).toBe( "keep" );
				expect( variables.svc.classifyMetric( { runs: 2, yield_score: 0.0, errors: 2 } ) ).toBe( "keep" );
			});

			it( "promotes sources with proven yield", function(){
				expect( variables.svc.classifyMetric( { runs: 3, yield_score: 0.5, errors: 0 } ) ).toBe( "promote" );
				expect( variables.svc.classifyMetric( { runs: 10, yield_score: 2.3, errors: 1 } ) ).toBe( "promote" );
			});

			it( "quarantines sources with zero yield after enough runs", function(){
				expect( variables.svc.classifyMetric( { runs: 5, yield_score: 0.0, errors: 0 } ) ).toBe( "quarantine" );
			});

			it( "quarantines sources with a high error rate", function(){
				// 4 errors / 4 runs = 1.0 >= 0.75 threshold, low yield
				expect( variables.svc.classifyMetric( { runs: 4, yield_score: 0.2, errors: 4 } ) ).toBe( "quarantine" );
			});

			it( "keeps middling sources (some yield, not dead, not great)", function(){
				expect( variables.svc.classifyMetric( { runs: 5, yield_score: 0.3, errors: 0 } ) ).toBe( "keep" );
			});

			it( "honours custom thresholds", function(){
				var strict = new services.SourceExpansionService( promoteYield = 2.0, minRuns = 2 );
				expect( strict.classifyMetric( { runs: 3, yield_score: 1.0, errors: 0 } ) ).toBe( "keep" );
				expect( strict.classifyMetric( { runs: 3, yield_score: 2.5, errors: 0 } ) ).toBe( "promote" );
			});

		});
		</cfscript>
	</cffunction>

</cfcomponent>
