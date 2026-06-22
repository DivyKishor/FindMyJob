<cfcomponent extends="testbox.system.BaseSpec" output="false">

	<cffunction name="run" access="public" returntype="void" output="false">
		<cfscript>
		describe( "CareerPageDiscoverer URL helpers", function(){

			beforeEach( function(){
				variables.cpd = new services.CareerPageDiscoverer();
			});

			it( "extracts a bare host (no scheme/www/path/port)", function(){
				expect( variables.cpd.extractHostFromUrl( "https://www.Acme.com:443/careers?x=1" ) ).toBe( "acme.com" );
				expect( variables.cpd.extractHostFromUrl( "http://jobs.acme.co.uk/x" ) ).toBe( "jobs.acme.co.uk" );
				expect( variables.cpd.extractHostFromUrl( "" ) ).toBe( "" );
			});

			it( "flags job boards / social hosts and passes employer hosts", function(){
				expect( variables.cpd.isJobBoardOrSocialHost( "linkedin.com" ) ).toBeTrue();
				expect( variables.cpd.isJobBoardOrSocialHost( "jobs.lever.co" ) ).toBeTrue();
				expect( variables.cpd.isJobBoardOrSocialHost( "careers.acme.com" ) ).toBeFalse();
				expect( variables.cpd.isJobBoardOrSocialHost( "" ) ).toBeTrue();
			});

			it( "recognises job-listing-style paths", function(){
				expect( variables.cpd.hrefLooksLikeJobListingPath( "https://acme.com/jobs/123" ) ).toBeTrue();
				expect( variables.cpd.hrefLooksLikeJobListingPath( "https://boards.greenhouse.io/x?gh_jid=9" ) ).toBeTrue();
				expect( variables.cpd.hrefLooksLikeJobListingPath( "https://acme.com/about" ) ).toBeFalse();
			});

			it( "resolves relative URLs against a base", function(){
				expect( variables.cpd.absolutizeUrl( "https://acme.com/careers/", "../jobs/12" ) )
					.toBe( "https://acme.com/jobs/12" );
				expect( variables.cpd.absolutizeUrl( "https://acme.com/careers", "https://other.com/x" ) )
					.toBe( "https://other.com/x" );
			});

			it( "extracts href values from anchor HTML (quoted + unquoted)", function(){
				expect( variables.cpd.extractHref( '<a href="https://acme.com/jobs/1" class="b">Job</a>' ) )
					.toBe( "https://acme.com/jobs/1" );
				expect( variables.cpd.extractHref( "<a href='/jobs/2'>x</a>" ) ).toBe( "/jobs/2" );
				expect( variables.cpd.extractHref( "<a href=/jobs/3>x</a>" ) ).toBe( "/jobs/3" );
				expect( variables.cpd.extractHref( "<a>no href</a>" ) ).toBe( "" );
			});

			it( "picks the first probable job URL from candidates", function(){
				var cands = [ "https://acme.com/about", "https://acme.com/jobs/55", "https://acme.com/team" ];
				expect( variables.cpd.firstProbableJobUrlFromArray( cands, "https://acme.com/careers" ) )
					.toBe( "https://acme.com/jobs/55" );
			});

		});
		</cfscript>
	</cffunction>

</cfcomponent>
