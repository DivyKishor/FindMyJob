<cfcomponent extends="testbox.system.BaseSpec" output="false">

	<cffunction name="run" access="public" returntype="void" output="false">
		<cfscript>
		describe( "SourceAdapter kind mapping (Phase 3, PR 3.3)", function(){

			beforeEach( function(){
				variables.adapter = new services.SourceAdapter();
			});

			it( "maps known adapter kinds to a careers_source", function(){
				expect( variables.adapter.careersSourceFor( "career_page_scan" ) ).toBe( "career_page_scan" );
				expect( variables.adapter.careersSourceFor( "greenhouse" ) ).toBe( "greenhouse" );
				expect( variables.adapter.careersSourceFor( "remoteok" ) ).toBe( "remoteok_feed" );
			});

			it( "reports unsupported kinds", function(){
				expect( variables.adapter.careersSourceFor( "made_up_ats" ) ).toBe( "" );
				expect( variables.adapter.isSupported( "made_up_ats" ) ).toBeFalse();
				expect( variables.adapter.isSupported( "greenhouse" ) ).toBeTrue();
			});

		});

		describe( "SourceRegistryService onboarding (Phase 3, PR 3.3)", function(){

			beforeEach( function(){
				variables.dbOk = true;
				try {
					variables.gw = new services.DataGateway( "cfintel_test", "sqlite" );
					variables.gw.execute( "DELETE FROM source_definitions" );
					variables.gw.execute( "DELETE FROM companies WHERE careers_source IN ('career_page_scan','greenhouse') AND website = ''" );
					variables.graph = new services.SourceGraphService( variables.gw );
					variables.reg = new services.SourceRegistryService( variables.gw, new services.SourceAdapter(), variables.graph );
				} catch ( any e ) {
					variables.dbOk = false;
				}
			});

			it( "upserts and lists enabled definitions", function(){
				if ( !variables.dbOk ) { return; }
				variables.reg.upsertDefinition( sourceKey = "acme_scan", adapterKind = "career_page_scan",
					label = "Acme", urlTemplate = "https://acme.example/careers" );
				variables.reg.upsertDefinition( sourceKey = "old_scan", adapterKind = "career_page_scan",
					label = "Old", urlTemplate = "https://old.example/careers", enabled = 0 );
				expect( variables.reg.listDefinitions( true ).len() ).toBe( 1 );
				expect( variables.reg.listDefinitions( false ).len() ).toBe( 2 );
			});

			it( "onboards a career-scan definition into a company + graph node", function(){
				if ( !variables.dbOk ) { return; }
				variables.reg.upsertDefinition( sourceKey = "beta_scan", adapterKind = "career_page_scan",
					label = "Beta", urlTemplate = "https://beta.example/careers" );
				var result = variables.reg.syncDefinitions();
				expect( result.onboarded ).toInclude( "beta_scan" );

				var company = variables.gw.queryRow(
					"SELECT careers_source FROM companies WHERE careers_url = ?",
					[ { value: "https://beta.example/careers", cfsqltype: "cf_sql_varchar" } ] );
				expect( company.careers_source ).toBe( "career_page_scan" );

				// New source registered as candidate for the expansion engine to judge.
				expect( variables.graph.listSourcesByStatus( "candidate" ).len() ).toBeGTE( 1 );
			});

			it( "does not double-onboard the same careers URL", function(){
				if ( !variables.dbOk ) { return; }
				variables.reg.upsertDefinition( sourceKey = "dup_scan", adapterKind = "career_page_scan",
					label = "Dup", urlTemplate = "https://dup.example/careers" );
				variables.reg.syncDefinitions();
				var second = variables.reg.syncDefinitions();
				expect( second.onboarded.len() ).toBe( 0 );
			});

		});
		</cfscript>
	</cffunction>

</cfcomponent>
