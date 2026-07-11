<cfcomponent extends="testbox.system.BaseSpec" output="false">

	<cffunction name="run" access="public" returntype="void" output="false">
		<cfscript>
		describe( "WhatsAppChannel (Phase 4, PR 4.2)", function(){

			it( "is disabled without full credentials", function(){
				var ch = new services.WhatsAppChannel( new services.AppConfig( "" ) );
				expect( ch.getChannelName() ).toBe( "whatsapp" );
				expect( ch.isEnabled() ).toBeFalse();
				expect( ch.send( { score: 99 } ).sent ).toBeFalse();
			});

			it( "requires token + phone_number_id + recipient", function(){
				var partial = new services.AppConfig( "" );
				partial.setData( { secrets: { whatsapp_token: "t", whatsapp_phone_number_id: "p" } } ); // no recipient
				expect( new services.WhatsAppChannel( partial ).isEnabled() ).toBeFalse();

				var full = new services.AppConfig( "" );
				full.setData( { secrets: { whatsapp_token: "t", whatsapp_phone_number_id: "p", whatsapp_recipient: "919999999999" } } );
				expect( new services.WhatsAppChannel( full ).isEnabled() ).toBeTrue();
			});

			it( "gates by whatsapp_min_score (default 80)", function(){
				var cfg = new services.AppConfig( "" );
				cfg.setData( { secrets: { whatsapp_token: "t", whatsapp_phone_number_id: "p", whatsapp_recipient: "91999" } } );
				var ch = new services.WhatsAppChannel( cfg );
				expect( ch.shouldSend( { score: 75 } ).ok ).toBeFalse();
				expect( ch.shouldSend( { score: 85 } ).ok ).toBeTrue();
			});

			it( "formats a plain-text message with link", function(){
				var cfg = new services.AppConfig( "" );
				cfg.setData( { secrets: { whatsapp_token: "t", whatsapp_phone_number_id: "p", whatsapp_recipient: "91999" } } );
				var ch = new services.WhatsAppChannel( cfg );
				var m = ch.formatMessage( { title: "Lucee Engineer", company_name: "Beta", score: 88, location: "Pune, India", link: "https://beta.test/j/9" } );
				expect( m ).toInclude( "Lucee Engineer" );
				expect( m ).toInclude( "88" );
				expect( m ).toInclude( "https://beta.test/j/9" );
			});

		});
		</cfscript>
	</cffunction>

</cfcomponent>
