<cfcomponent extends="testbox.system.BaseSpec" output="false">

	<cffunction name="run" access="public" returntype="void" output="false">
		<cfscript>
		describe( "GithubDiscoveryService helpers", function(){

			beforeEach( function(){
				// Pure helpers don't use the deps; AppConfig stub returns "" for token.
				var cfg = new services.AppConfig( "" );
				variables.svc = new services.GithubDiscoveryService( createStub(), createStub(), cfg );
			});

			it( "is unconfigured without a token (still usable at 60/hr)", function(){
				expect( variables.svc.isConfigured() ).toBeFalse();
			});

			it( "cleans GitHub company values", function(){
				expect( variables.svc.cleanCompanyName( "@Acme Corp" ) ).toBe( "Acme Corp" );
				expect( variables.svc.cleanCompanyName( "  Beta   Labs " ) ).toBe( "Beta Labs" );
			});

			it( "normalizes blog/website values to http(s) URLs", function(){
				expect( variables.svc.normalizeUrl( "acme.com" ) ).toBe( "https://acme.com" );
				expect( variables.svc.normalizeUrl( "https://beta.io/team" ) ).toBe( "https://beta.io/team" );
				expect( variables.svc.normalizeUrl( "not a url" ) ).toBe( "" );
				expect( variables.svc.normalizeUrl( "" ) ).toBe( "" );
			});

			it( "extracts a bare host from a URL", function(){
				expect( variables.svc.hostOf( "https://www.acme.com/careers" ) ).toBe( "acme.com" );
				expect( variables.svc.hostOf( "http://docs.foo.io:8080/x" ) ).toBe( "docs.foo.io" );
			});

			it( "flags doc/project/static-hosting hosts as non-employers", function(){
				expect( variables.svc.isLikelyNonEmployerHost( "redux.js.org" ) ).toBeTrue();
				expect( variables.svc.isLikelyNonEmployerHost( "docs.theframedrops.com" ) ).toBeTrue();
				expect( variables.svc.isLikelyNonEmployerHost( "myproject.github.io" ) ).toBeTrue();
				expect( variables.svc.isLikelyNonEmployerHost( "acme.com" ) ).toBeFalse();
			});

			it( "detects a careers / hiring signal in page markup", function(){
				expect( variables.svc.careersSignalInHtml( "<a href='/careers'>Careers</a>" ) ).toBeTrue();
				expect( variables.svc.careersSignalInHtml( "We're hiring engineers" ) ).toBeTrue();
				expect( variables.svc.careersSignalInHtml( "<a href='https://boards.greenhouse.io/acme'>Jobs</a>" ) ).toBeTrue();
				expect( variables.svc.careersSignalInHtml( "<h1>An open source UI library</h1>" ) ).toBeFalse();
				expect( variables.svc.careersSignalInHtml( "" ) ).toBeFalse();
			});

		});
		</cfscript>
	</cffunction>

</cfcomponent>
