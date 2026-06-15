<cfcomponent extends="testbox.system.BaseSpec" output="false">
	<!---
		CompanyScoreServiceTest — Phase 2, PR 2.2.

		Tests the pure scoreCompanyData() function with in-memory fixture arrays.
		No DB calls are made in these tests.
	--->

	<cffunction name="run" access="public" returntype="void" output="false">
		<cfscript>
		describe( "CompanyScoreService.scoreCompanyData()", function(){

			beforeEach( function(){
				// Stub DataGateway and LoggerService — scoreCompanyData() is pure and never calls them.
				var fakeGW  = {};
				var fakeLog = {};
				variables.svc = new services.CompanyScoreService( fakeGW, fakeLog );
			});

			it( "returns zero score when there are no signals, no discovery, no jobs", function(){
				var r = variables.svc.scoreCompanyData( [], [], 0 );
				expect( r.score ).toBe( 0 );
				expect( r.fpScore ).toBe( 0 );
				expect( r.discovScore ).toBe( 0 );
				expect( r.jobScore ).toBe( 0 );
			});

			it( "scores fingerprint signals proportionally up to 50", function(){
				// powered_by (3.5) + lucee_header (3.5) out of MAX_WEIGHT (22.0) => ~31.8 => int = 31/50
				var fp = [
					{ signal: "powered_by",  evidence: "X-Powered-By: ColdFusion", weight: 3.5 },
					{ signal: "lucee_header", evidence: "Server: Lucee",            weight: 3.5 }
				];
				var r = variables.svc.scoreCompanyData( fp, [], 0 );
				expect( r.fpScore ).toBeGTE( 15 );
				expect( r.fpScore ).toBeLTE( 50 );
			});

			it( "caps fingerprint subscore at 50 even with all signals present", function(){
				// All 8 signal types = MAX_WEIGHT, so fp subscore = 50.
				var fp = [
					{ signal: "powered_by",     weight: 3.5, evidence: "CF" },
					{ signal: "lucee_header",   weight: 3.5, evidence: "Lucee" },
					{ signal: "cf_cookie",      weight: 3.0, evidence: "CFID" },
					{ signal: "cfm_url",        weight: 3.0, evidence: ".cfm" },
					{ signal: "coldbox_marker", weight: 2.5, evidence: "ColdBox" },
					{ signal: "mura_marker",    weight: 2.5, evidence: "Mura" },
					{ signal: "box_json",       weight: 2.0, evidence: "box.json" },
					{ signal: "commandbox",     weight: 2.0, evidence: "CommandBox" }
				];
				var r = variables.svc.scoreCompanyData( fp, [], 0 );
				expect( r.fpScore ).toBe( 50 );
			});

			it( "adds discovery subscore from confidence average", function(){
				// avg confidence 80 / 100 * 30 = 24
				var sigs = [
					{ confidence_score: 80 },
					{ confidence_score: 80 },
					{ confidence_score: 80 }
				];
				var r = variables.svc.scoreCompanyData( [], sigs, 0 );
				expect( r.discovScore ).toBe( 24 );
				expect( r.score ).toBe( 24 );
			});

			it( "adds job history score: 10 for 1-4 jobs, 15 for 5-9, 20 for 10+", function(){
				expect( variables.svc.scoreCompanyData( [], [], 1  ).jobScore ).toBe( 10 );
				expect( variables.svc.scoreCompanyData( [], [], 5  ).jobScore ).toBe( 15 );
				expect( variables.svc.scoreCompanyData( [], [], 10 ).jobScore ).toBe( 20 );
			});

			it( "combines all three subscores and caps at 100", function(){
				// Max FP (50) + max discovery approx (30) + max job (20) = 100
				var fp = [
					{ signal: "powered_by",     weight: 3.5, evidence: "CF" },
					{ signal: "lucee_header",   weight: 3.5, evidence: "Lucee" },
					{ signal: "cf_cookie",      weight: 3.0, evidence: "CFID" },
					{ signal: "cfm_url",        weight: 3.0, evidence: ".cfm" },
					{ signal: "coldbox_marker", weight: 2.5, evidence: "ColdBox" },
					{ signal: "mura_marker",    weight: 2.5, evidence: "Mura" },
					{ signal: "box_json",       weight: 2.0, evidence: "box.json" },
					{ signal: "commandbox",     weight: 2.0, evidence: "CommandBox" }
				];
				var sigs = [ { confidence_score: 100 }, { confidence_score: 100 }, { confidence_score: 100 } ];
				var r = variables.svc.scoreCompanyData( fp, sigs, 10 );
				expect( r.score ).toBe( 100 );
			});

			it( "includes signal names in reasons", function(){
				var fp = [ { signal: "powered_by", weight: 3.5, evidence: "CF" } ];
				var r  = variables.svc.scoreCompanyData( fp, [], 0 );
				expect( arrayToList( r.reasons ) ).toInclude( "fp:powered_by" );
			});

			it( "includes job count in reasons when jobs > 0", function(){
				var r = variables.svc.scoreCompanyData( [], [], 7 );
				expect( arrayToList( r.reasons ) ).toInclude( "jobs:7" );
			});

			it( "returns correct ruleVersion", function(){
				var r = variables.svc.scoreCompanyData( [], [], 0 );
				expect( r.ruleVersion ).toBe( "v1_company_cf_likelihood" );
			});

		});
		</cfscript>
	</cffunction>

</cfcomponent>
