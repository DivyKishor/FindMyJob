<cfcomponent extends="testbox.system.BaseSpec" output="false">

	<cffunction name="run" access="public" returntype="void" output="false">
		<cfscript>
		describe( "TelegramChannel (Phase 4, PR 4.1)", function(){

			it( "is disabled without credentials and never sends", function(){
				var ch = new services.TelegramChannel( new services.AppConfig( "" ) );
				expect( ch.getChannelName() ).toBe( "telegram" );
				expect( ch.isEnabled() ).toBeFalse();
				expect( ch.send( { score: 99 } ).sent ).toBeFalse();          // no HTTP — gated out
				expect( ch.shouldSend( { score: 99 } ).reason ).toInclude( "not configured" );
			});

			it( "is enabled with credentials and gates by score", function(){
				var cfg = new services.AppConfig( "" );
				cfg.setData( { secrets: { telegram_bot_token: "t", telegram_chat_id: "c" } } );
				var ch = new services.TelegramChannel( cfg );
				expect( ch.isEnabled() ).toBeTrue();
				expect( ch.shouldSend( { score: 95 } ).ok ).toBeTrue();
				expect( ch.shouldSend( { score: 50 } ).ok ).toBeFalse();
			});

			it( "honours a configured telegram_min_score", function(){
				var cfg = new services.AppConfig( "" );
				cfg.setData( { secrets: { telegram_bot_token: "t", telegram_chat_id: "c" }, alerts: { telegram_min_score: 90 } } );
				var ch = new services.TelegramChannel( cfg );
				expect( ch.shouldSend( { score: 85 } ).ok ).toBeFalse();
				expect( ch.shouldSend( { score: 95 } ).ok ).toBeTrue();
			});

			it( "formats a readable HTML message", function(){
				var cfg = new services.AppConfig( "" );
				cfg.setData( { secrets: { telegram_bot_token: "t", telegram_chat_id: "c" } } );
				var ch = new services.TelegramChannel( cfg );
				var m = ch.formatMessage( {
					title: "ColdFusion Developer", company_name: "Acme",
					score: 95, location: "Remote", link: "https://acme.test/jobs/1",
					reasons: [ "cf_tech:coldfusion" ]
				} );
				expect( m ).toInclude( "ColdFusion Developer" );
				expect( m ).toInclude( "95" );
				expect( m ).toInclude( "https://acme.test/jobs/1" );
			});

		});
		</cfscript>
	</cffunction>

</cfcomponent>
