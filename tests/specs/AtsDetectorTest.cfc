<cfcomponent extends="testbox.system.BaseSpec" output="false">

	<cffunction name="run" access="public" returntype="void" output="false">
		<cfscript>
		describe( "AtsRegistry + AtsDetector", function(){

			beforeEach( function(){
				variables.det = new services.AtsDetector();
			});

			it( "identifies the ATS provider from a URL", function(){
				expect( variables.det.detectProvider( "https://boards.greenhouse.io/acme/jobs/123" ) ).toBe( "greenhouse" );
				expect( variables.det.detectProvider( "https://jobs.lever.co/acme/abc" ) ).toBe( "lever" );
				expect( variables.det.detectProvider( "https://acme.wd1.myworkdayjobs.com/x" ) ).toBe( "workday" );
				expect( variables.det.detectProvider( "https://jobs.ashbyhq.com/acme/123" ) ).toBe( "ashby" );
				expect( variables.det.detectProvider( "https://apply.workable.com/acme/j/ABC" ) ).toBe( "workable" );
				expect( variables.det.detectProvider( "https://acme.com/about-us" ) ).toBe( "" );
			});

			// Characterization: URLs the previous inline OR-chain accepted must still pass.
			it( "preserves legacy 'is a job posting' positives", function(){
				var careers = "https://acme.com/careers";
				for( var u in [
					"https://boards.greenhouse.io/acme/jobs/55?gh_jid=55",
					"https://jobs.lever.co/acme/abc",
					"https://acme.wd1.myworkdayjobs.com/External/job/123",
					"https://careers.acme.com/requisition/987",
					"https://acme.com/apply/now",
					"https://www.indeed.com/viewjob?jk=xyz",
					"https://www.linkedin.com/jobs/view/123",
					"https://acme.icims.com/jobs/4567/job"
				] ){
					expect( variables.det.isProbableJobPostingUrl( u, careers ) )
						.toBeTrue( "expected job-posting positive for #u#" );
				}
			});

			it( "treats same-host deep career paths as postings", function(){
				expect( variables.det.isProbableJobPostingUrl(
					"https://acme.com/careers/engineering/coldfusion-dev",
					"https://acme.com/careers" ) ).toBeTrue();
			});

			it( "rejects the careers page itself and unrelated pages", function(){
				expect( variables.det.isProbableJobPostingUrl(
					"https://acme.com/careers", "https://acme.com/careers" ) ).toBeFalse();
				expect( variables.det.isProbableJobPostingUrl(
					"https://acme.com/about", "https://acme.com/careers" ) ).toBeFalse();
			});

			it( "returns false for an empty job URL", function(){
				expect( variables.det.isProbableJobPostingUrl( "", "https://acme.com/careers" ) ).toBeFalse();
			});

		});
		</cfscript>
	</cffunction>

</cfcomponent>
