<cfcomponent extends="testbox.system.BaseSpec" output="false">
	<!---
		ScoringServiceV5Test — Phase 2, PR 2.3.

		Tests the four scoring layers added / restructured in v5_layered:
		  cf_match, geo_eligibility, remote_fit, visa_sponsorship.

		The existing ScoringServiceTest.cfc is updated separately to reflect the new
		rule version string; these tests cover the new layer-specific behaviours.
	--->

	<cffunction name="run" access="public" returntype="void" output="false">
		<cfscript>
		describe( "ScoringService v5_layered", function(){

			beforeEach( function(){
				variables.svc = new services.ScoringService();
			});

			// ─── Rule version ─────────────────────────────────────────────────────
			it( "reports v7_sponsor_negation rule version", function(){
				expect( variables.svc.getRuleVersion() ).toBe( "v7_sponsor_negation" );
			});

			it( "does NOT count negative sponsorship phrases as sponsorship", function(){
				// "without employer sponsorship" / "no H-1B sponsorship" mean the opposite.
				expect( variables.svc.classifyVisaSponsorship( "Must be authorized to work in the US without employer sponsorship" ) ).toBe( 0 );
				expect( variables.svc.classifyVisaSponsorship( "No H-1B sponsorship available for this role" ) ).toBe( 0 );
				var r = variables.svc.scoreJob(
					"ColdFusion Developer",
					"Must be legally authorized to work in the United States without employer sponsorship, now or in the future.",
					"United States" );
				var joined = arrayToList( r.reasons, "|" );
				expect( joined ).notToInclude( "visa_sponsorship" );
				expect( joined ).toInclude( "work_auth_restricted" );
				expect( r.score ).toBeLT( 50 );
			});

			// ─── v6: sponsorship overrides the work-auth penalty ─────────────────
			it( "lets visa sponsorship override the US work-auth penalty", function(){
				var r = variables.svc.scoreJob(
					"ColdFusion Developer",
					"US role. Visa sponsorship available for the right candidate.",
					"New York, United States" );
				var joined = arrayToList( r.reasons, "|" );
				expect( joined ).toInclude( "visa_sponsorship:" );
				expect( joined ).notToInclude( "work_auth_restricted" );
				expect( r.score ).toBeGTE( 70 );
			});

			it( "still penalises a US role that does NOT sponsor", function(){
				var r = variables.svc.scoreJob( "ColdFusion Developer", "Must be a US citizen.", "Texas" );
				expect( arrayToList( r.reasons, "|" ) ).toInclude( "work_auth_restricted" );
				expect( r.score ).toBeLT( 50 );
			});

			// ─── cf_match layer ──────────────────────────────────────────────────
			it( "returns 0 for non-CF jobs (cf_match gate)", function(){
				expect( variables.svc.scoreJob( "Java Developer", "Spring Boot" ).score ).toBe( 0 );
			});

			it( "returns at least 50 for CF-matched jobs", function(){
				expect( variables.svc.scoreJob( "ColdFusion Developer", "CFML" ).score ).toBeGTE( 50 );
			});

			it( "still matches ColdBox, WireBox, CommandBox, FuseBox", function(){
				expect( variables.svc.scoreJob( "ColdBox MVC Engineer", "WireBox DI" ).score ).toBeGTE( 50 );
				expect( variables.svc.shouldPersistJob( "CommandBox CI Developer", "CFML pipeline" ) ).toBeTrue();
			});

			// ─── geo_eligibility layer (formerly classifyIndiaEligibility) ───────
			it( "gives full score for explicit India location", function(){
				var r = variables.svc.scoreJob( "ColdFusion Developer", "CFML", "Bangalore, India" );
				expect( r.score ).toBe( 100 );
				expect( r.geoEligibility ).toBe( "yes" );
				// backward-compat alias
				expect( r.indiaEligible ).toBe( "yes" );
			});

			it( "classifyIndiaEligibility() still works as public deprecated alias", function(){
				expect( variables.svc.classifyIndiaEligibility( "coldfusion job", "Hyderabad" ) ).toBe( "yes" );
			});

			it( "classifyGeoEligibility() is the canonical method", function(){
				expect( variables.svc.classifyGeoEligibility( "coldfusion job", "Hyderabad" ) ).toBe( "yes" );
			});

			it( "penalises US-work-auth blockers (geo=no)", function(){
				var r = variables.svc.scoreJob( "ColdFusion Developer", "Must be a US citizen with top secret clearance", "Virginia" );
				expect( r.geoEligibility ).toBe( "no" );
				expect( r.score ).toBeLT( 50 );
			});

			it( "does NOT classify 'indiana' as India (word-boundary check)", function(){
				var r = variables.svc.classifyGeoEligibility( "developer job in indiana", "Indianapolis, Indiana" );
				expect( r ).notToBe( "yes" );
			});

			// ─── remote_fit layer ─────────────────────────────────────────────────
			it( "classifyRemoteFit returns 10 for remote jobs", function(){
				expect( variables.svc.classifyRemoteFit( "coldfusion developer remote", "" ) ).toBe( 10 );
				expect( variables.svc.classifyRemoteFit( "coldfusion developer", "Remote" ) ).toBe( 10 );
			});

			it( "classifyRemoteFit returns 0 for non-remote jobs", function(){
				expect( variables.svc.classifyRemoteFit( "coldfusion developer on-site", "New York" ) ).toBe( 0 );
			});

			it( "remote_fit bonus appears in scoreJob return struct", function(){
				var r = variables.svc.scoreJob( "ColdFusion Developer", "CFML remote role", "" );
				expect( r.remoteFit ).toBe( 10 );
			});

			it( "remote score is higher than on-site score for otherwise identical jobs", function(){
				var remote  = variables.svc.scoreJob( "ColdFusion Developer", "CFML", "Remote" );
				var onSite  = variables.svc.scoreJob( "ColdFusion Developer", "CFML", "Dallas" );
				expect( remote.score ).toBeGT( onSite.score );
			});

			// ─── visa_sponsorship layer ───────────────────────────────────────────
			it( "classifyVisaSponsorship returns 20 for explicit sponsorship language", function(){
				expect( variables.svc.classifyVisaSponsorship( "coldfusion developer - visa sponsorship available" ) ).toBe( 20 );
				expect( variables.svc.classifyVisaSponsorship( "we will sponsor H-1B for the right candidate" ) ).toBe( 20 );
				expect( variables.svc.classifyVisaSponsorship( "able to sponsor work visa" ) ).toBe( 20 );
			});

			it( "classifyVisaSponsorship returns 0 when no sponsorship language present", function(){
				expect( variables.svc.classifyVisaSponsorship( "coldfusion developer remote" ) ).toBe( 0 );
			});

			it( "visa_sponsorship bonus appears in scoreJob return struct", function(){
				var r = variables.svc.scoreJob( "ColdFusion Developer", "Visa sponsorship available for this role", "Remote" );
				expect( r.visaSponsorship ).toBe( 20 );
				var joinedReasons = arrayToList( r.reasons, "|" );
				expect( joinedReasons ).toInclude( "visa_sponsorship" );
			});

			it( "combined sponsorship + remote + CF scores ≥ 90", function(){
				var r = variables.svc.scoreJob(
					"ColdFusion Developer",
					"CFML remote position. H-1B visa sponsorship available.",
					"Remote"
				);
				expect( r.score ).toBeGTE( 90 );
			});

			// ─── Overall score contract ───────────────────────────────────────────
			it( "score is always 0-100", function(){
				var r1 = variables.svc.scoreJob( "ColdFusion Developer", "CFML India remote visa sponsorship", "Bangalore" );
				var r2 = variables.svc.scoreJob( "Ruby Developer", "Rails Postgres", "New York" );
				expect( r1.score ).toBeGTE( 0 );
				expect( r1.score ).toBeLTE( 100 );
				expect( r2.score ).toBe( 0 );
			});

			it( "alertEligible is true only at score >= 70", function(){
				var high = variables.svc.scoreJob( "ColdFusion Developer", "CFML", "Bangalore, India" );
				var low  = variables.svc.scoreJob( "ColdFusion Developer", "CFML", "" );
				expect( high.alertEligible ).toBeTrue();
				expect( low.alertEligible ).toBeFalse();
			});

		});
		</cfscript>
	</cffunction>

</cfcomponent>
