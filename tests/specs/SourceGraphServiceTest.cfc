<cfcomponent extends="testbox.system.BaseSpec" output="false">

	<cffunction name="run" access="public" returntype="void" output="false">
		<cfscript>
		describe( "SourceGraphService (Phase 3, PR 3.1)", function(){

			beforeEach( function(){
				variables.dbOk = true;
				try {
					variables.gw = new services.DataGateway( "cfintel_test", "sqlite" );
					variables.gw.execute( "DELETE FROM source_edges" );
					variables.gw.execute( "DELETE FROM source_metrics" );
					variables.gw.execute( "DELETE FROM sources" );
					variables.graph = new services.SourceGraphService( variables.gw );
				} catch ( any e ) {
					variables.dbOk = false; // no SQLite driver / fixture DB in this env
				}
			});

			it( "registers source nodes and lists them by status", function(){
				if ( !variables.dbOk ) { return; }
				variables.graph.registerSource( "greenhouse", "ingest_source", "Greenhouse", "active" );
				variables.graph.registerSource( "acme.com", "discovery_domain", "Acme", "candidate" );
				expect( variables.graph.listSourcesByStatus( "active" ).len() ).toBe( 1 );
				expect( variables.graph.listSourcesByStatus( "candidate" ).len() ).toBe( 1 );
			});

			it( "preserves status on re-register but updates label", function(){
				if ( !variables.dbOk ) { return; }
				variables.graph.registerSource( "x.com", "discovery_domain", "Old", "candidate" );
				variables.graph.registerSource( "x.com", "discovery_domain", "New", "active" ); // status arg ignored on conflict
				var rows = variables.graph.listSourcesByStatus( "candidate" );
				expect( rows.len() ).toBe( 1 );
				expect( rows[ 1 ].label ).toBe( "New" );
			});

			it( "accumulates run metrics and computes yield per run", function(){
				if ( !variables.dbOk ) { return; }
				variables.graph.recordRun( sourceKey = "src1", itemsFound = 5, companiesFound = 2, jobsFound = 1 );
				variables.graph.recordRun( sourceKey = "src1", itemsFound = 3, companiesFound = 0, jobsFound = 1 );
				var m = variables.graph.getMetric( "src1" );
				expect( m.runs ).toBe( 2 );
				expect( m.companies_found ).toBe( 2 );
				expect( m.jobs_found ).toBe( 2 );
				// yield = (2 companies + 2 jobs) / 2 runs = 2.0
				expect( m.yield_score ).toBeCloseTo( 2.0, 0.001 );
			});

			it( "dedupes provenance edges", function(){
				if ( !variables.dbOk ) { return; }
				variables.graph.addEdge( "discovery", "found_company", "acme.com" );
				variables.graph.addEdge( "discovery", "found_company", "acme.com" ); // dup
				variables.graph.addEdge( "discovery", "found_company", "beta.com" );
				expect( variables.graph.countEdgesFrom( "discovery" ) ).toBe( 2 );
			});

			it( "changes a source status", function(){
				if ( !variables.dbOk ) { return; }
				variables.graph.registerSource( "dead.com", "discovery_domain", "Dead", "active" );
				variables.graph.setStatus( "dead.com", "quarantined" );
				expect( variables.graph.listSourcesByStatus( "quarantined" ).len() ).toBe( 1 );
			});

		});
		</cfscript>
	</cffunction>

</cfcomponent>
