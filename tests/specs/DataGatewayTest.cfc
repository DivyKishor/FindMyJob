<cfcomponent extends="testbox.system.BaseSpec" output="false">

	<cffunction name="run" access="public" returntype="void" output="false">
		<cfscript>
		describe( "DataGateway dialect abstraction", function(){

			it( "defaults to the sqlite dialect", function(){
				var gw = new services.DataGateway( "ds_unused" );
				expect( gw.getDialect() ).toBe( "sqlite" );
			});

			it( "rejects an unsupported dialect", function(){
				expect( function(){
					new services.DataGateway( "ds_unused", "oracle" );
				} ).toThrow( type = "DataGateway.UnsupportedDialect" );
			});

			it( "emits the correct now() expression per dialect", function(){
				expect( new services.DataGateway( "ds", "sqlite" ).nowExpr() ).toBe( "datetime('now')" );
				expect( new services.DataGateway( "ds", "postgres" ).nowExpr() ).toBe( "now()" );
			});

			it( "emits dialect-correct JSON extraction", function(){
				var lite = new services.DataGateway( "ds", "sqlite" );
				expect( lite.jsonExtract( "payload_json", "$.score" ) )
					.toBe( "json_extract(payload_json, '$.score')" );

				var pg = new services.DataGateway( "ds", "postgres" );
				expect( pg.jsonExtract( "payload_json", "$.score" ) )
					.toInclude( "payload_json::jsonb" );
				expect( pg.jsonExtract( "payload_json", "$.score" ) )
					.toInclude( "'{score}'" );
			});

			it( "emits insert-ignore syntax per dialect", function(){
				var lite = new services.DataGateway( "ds", "sqlite" );
				expect( lite.insertIgnorePrefix() ).toBe( "INSERT OR IGNORE" );
				expect( lite.insertIgnoreConflict( "dedupe_key" ) ).toBe( "" );

				var pg = new services.DataGateway( "ds", "postgres" );
				expect( pg.insertIgnorePrefix() ).toBe( "INSERT" );
				expect( pg.insertIgnoreConflict( "dedupe_key" ) )
					.toBe( " ON CONFLICT (dedupe_key) DO NOTHING" );
			});

		});
		</cfscript>
	</cffunction>

</cfcomponent>
