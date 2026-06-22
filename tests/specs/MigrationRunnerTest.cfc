<cfcomponent extends="testbox.system.BaseSpec" output="false">

	<cffunction name="run" access="public" returntype="void" output="false">
		<cfscript>
		describe( "MigrationRunner SQL handling", function(){

			beforeEach( function(){
				// Stub gateway: the splitter/benign-error logic needs no real DB.
				variables.gw = createStub();
				variables.runner = new services.MigrationRunner( variables.gw, "/no/such/path" );
				makePublic( variables.runner, "splitStatements" );
				makePublic( variables.runner, "isBenignError" );
			});

			it( "splits a multi-statement file and strips comments + blanks", function(){
				var sql = "-- a comment#chr(10)##chr(10)#CREATE TABLE a (id INTEGER);#chr(10)#-- another#chr(10)#ALTER TABLE a ADD COLUMN b TEXT;#chr(10)#";
				var stmts = variables.runner.splitStatements( sql );
				expect( stmts.len() ).toBe( 2 );
				expect( stmts[ 1 ] ).toBe( "CREATE TABLE a (id INTEGER)" );
				expect( stmts[ 2 ] ).toBe( "ALTER TABLE a ADD COLUMN b TEXT" );
			});

			it( "keeps a trailing statement with no closing newline", function(){
				var stmts = variables.runner.splitStatements( "UPDATE x SET y = 1;" );
				expect( stmts.len() ).toBe( 1 );
				expect( stmts[ 1 ] ).toBe( "UPDATE x SET y = 1" );
			});

			it( "treats duplicate-column / already-exists as benign", function(){
				expect( variables.runner.isBenignError( "duplicate column name: is_active" ) ).toBeTrue();
				expect( variables.runner.isBenignError( "table jobs already exists" ) ).toBeTrue();
			});

			it( "does not swallow real errors", function(){
				expect( variables.runner.isBenignError( "no such table: ghost" ) ).toBeFalse();
				expect( variables.runner.isBenignError( "syntax error near WHERE" ) ).toBeFalse();
			});

		});
		</cfscript>
	</cffunction>

</cfcomponent>
