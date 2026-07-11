<cfcomponent extends="testbox.system.BaseSpec" output="false">

	<cffunction name="run" access="public" returntype="void" output="false">
		<cfscript>
		describe( "ScoringService (v5_layered — Phase 2, PR 2.3)", function(){

			beforeEach( function(){
				variables.svc = new services.ScoringService();
			});

			it( "uses the v7_sponsor_negation rule version", function(){
				expect( variables.svc.getRuleVersion() ).toBe( "v7_sponsor_negation" );
			});

			it( "scores ColdBox / CommandBox / WireBox roles", function(){
				// v5: remote adds +10 on top of the cf_match base of 50 → expect ≥ 60
				expect( variables.svc.scoreJob( "ColdBox Developer", "ColdBox MVC + WireBox", "Remote" ).score ).toBeGTE( 60 );
				expect( variables.svc.shouldPersistJob( "CommandBox Engineer", "CFML tooling" ) ).toBeTrue();
			});

			it( "tags reasons with the matched tech keys", function(){
				var r = variables.svc.scoreJob( "Senior ColdFusion Engineer", "Lucee + ColdBox", "Bengaluru, India" );
				var joined = arrayToList( r.reasons, "|" );
				expect( joined ).toInclude( "cf_tech:" );
				expect( joined ).toInclude( "coldfusion" );
			});

			it( "rejects unrelated roles", function(){
				expect( variables.svc.scoreJob( "Java Developer", "Spring Boot microservices" ).score ).toBe( 0 );
				expect( variables.svc.shouldPersistJob( "Ruby on Rails Developer", "Postgres" ) ).toBeFalse();
			});

			it( "scores CF + India eligibility at the top of the range", function(){
				var r = variables.svc.scoreJob( "ColdFusion Developer", "CFML maintenance", "Bangalore, India" );
				expect( r.score ).toBe( 100 );
				expect( r.indiaEligible ).toBe( "yes" );
			});

			it( "penalises US-work-authorisation blockers", function(){
				var r = variables.svc.scoreJob( "ColdFusion Developer", "Must be a US citizen with security clearance", "Virginia" );
				expect( r.indiaEligible ).toBe( "no" );
				expect( r.score ).toBeLT( 50 );
			});

		});
		</cfscript>
	</cffunction>

</cfcomponent>
