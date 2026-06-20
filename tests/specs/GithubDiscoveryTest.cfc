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

		});
		</cfscript>
	</cffunction>

</cfcomponent>
