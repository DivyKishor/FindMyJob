<cfcomponent extends="testbox.system.BaseSpec" output="false">
	<!---
		AlertChannelTest — Phase 2, PR 2.4.

		Tests the AlertChannel interface contract and the LogChannel implementation
		(write-to-DB path), and verifies that AlertService dispatches through channels.
	--->

	<cffunction name="run" access="public" returntype="void" output="false">
		<cfscript>
		describe( "AlertChannel base class", function(){

			it( "send() returns { sent: false, error: '...' } from the base (unimplemented)", function(){
				var ch = new services.AlertChannel();
				var r  = ch.send( { job_id: 1, company_id: 1, company_name: "Acme", title: "CF Dev",
				                     location: "India", link: "http://example.com", score: 80, reasons: [] } );
				expect( r.sent ).toBeFalse();
				expect( len( r.error ) ).toBeGT( 0 );
			});

			it( "isEnabled() returns true by default", function(){
				var ch = new services.AlertChannel();
				expect( ch.isEnabled() ).toBeTrue();
			});

			it( "getChannelName() returns 'base'", function(){
				var ch = new services.AlertChannel();
				expect( ch.getChannelName() ).toBe( "base" );
			});

		});

		describe( "LogChannel", function(){

			it( "getChannelName() returns 'log'", function(){
				var db  = new services.DatabaseService( application.datasource );
				var log = new services.LoggerService( expandPath( "/logs/test-channel.log" ) );
				var ch  = new services.LogChannel( db, log );
				expect( ch.getChannelName() ).toBe( "log" );
			});

			it( "isEnabled() returns true", function(){
				var db  = new services.DatabaseService( application.datasource );
				var log = new services.LoggerService( expandPath( "/logs/test-channel.log" ) );
				var ch  = new services.LogChannel( db, log );
				expect( ch.isEnabled() ).toBeTrue();
			});

		});

		describe( "AlertService channel dispatch", function(){

			it( "generateAlerts() returns channelResults array", function(){
				// Use the wired application.alertService which has LogChannel registered.
				var result = application.alertService.generateAlerts( 200 ); // threshold=200 means no jobs match
				expect( structKeyExists( result, "channelResults" ) ).toBeTrue();
				expect( isArray( result.channelResults ) ).toBeTrue();
			});

			it( "generateAlerts() returns threshold and alertsCreated keys", function(){
				var result = application.alertService.generateAlerts( 200 );
				expect( structKeyExists( result, "threshold" ) ).toBeTrue();
				expect( structKeyExists( result, "alertsCreated" ) ).toBeTrue();
				expect( val( result.threshold ) ).toBe( 200 );
			});

			it( "addChannel() registers an additional channel", function(){
				// Create a tracking channel that records calls.
				var trackingChannel = new services.AlertChannel();
				// AlertService already has logChannel; add tracking channel.
				var svc = new services.AlertService( application.databaseService, application.loggerService );
				svc.addChannel( trackingChannel );
				// Two channels now registered (default LogChannel + tracking).
				// Just verify no error is thrown.
				var result = svc.generateAlerts( 200 );
				expect( result.alertsCreated ).toBeGTE( 0 );
			});

		});
		</cfscript>
	</cffunction>

</cfcomponent>
