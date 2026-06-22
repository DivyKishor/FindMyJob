<cfcomponent extends="testbox.system.BaseSpec" output="false">

	<cffunction name="run" access="public" returntype="void" output="false">
		<cfscript>
		describe( "AppConfig precedence + secret resolution", function(){

			beforeEach( function(){
				// No config file -> exercises env/fallback/default paths deterministically.
				variables.cfg = new services.AppConfig( "" );
			});

			it( "returns the default when nothing is configured", function(){
				expect( variables.cfg.get( "alerts.min_score", 70 ) ).toBe( 70 );
				expect( variables.cfg.has( "secrets.nope" ) ).toBeFalse();
			});

			it( "reads dotted keys from an app.json struct", function(){
				makePublic( variables.cfg, "jsonLookup" );
				variables.cfg.setData( { alerts: { min_score: 85 }, secrets: { brave_api_key: "abc" } } );
				expect( variables.cfg.get( "alerts.min_score", 70 ) ).toBe( 85 );
				expect( variables.cfg.get( "secrets.brave_api_key" ) ).toBe( "abc" );
			});

			it( "falls back to a supplied ats_config struct for a secret", function(){
				var atsConfig = { app_id: "fromDB", app_key: "keyDB" };
				expect( variables.cfg.secret( "adzuna_app_id", atsConfig, "app_id" ) ).toBe( "fromDB" );
			});

			it( "prefers app.json over the ats_config fallback", function(){
				variables.cfg.setData( { secrets: { adzuna_app_id: "fromJson" } } );
				var atsConfig = { app_id: "fromDB" };
				expect( variables.cfg.secret( "adzuna_app_id", atsConfig, "app_id" ) ).toBe( "fromJson" );
			});

			it( "maps a dotted key to a CFINTEL_ env var name", function(){
				makePublic( variables.cfg, "envLookup" );
				variables.cfg.setEnv( { "CFINTEL_SECRETS_TELEGRAM_BOT_TOKEN": "tok123" } );
				expect( variables.cfg.get( "secrets.telegram_bot_token" ) ).toBe( "tok123" );
			});

			it( "env overrides app.json", function(){
				variables.cfg.setData( { secrets: { telegram_bot_token: "jsonTok" } } );
				variables.cfg.setEnv( { "CFINTEL_SECRETS_TELEGRAM_BOT_TOKEN": "envTok" } );
				expect( variables.cfg.get( "secrets.telegram_bot_token" ) ).toBe( "envTok" );
			});

		});
		</cfscript>
	</cffunction>

</cfcomponent>
