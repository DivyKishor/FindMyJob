<cfcomponent extends="testbox.system.BaseSpec" output="false">

	<cffunction name="run" access="public" returntype="void" output="false">
		<cfscript>
		describe( "TechTaxonomy ecosystem coverage", function(){

			beforeEach( function(){
				variables.tax = new services.TechTaxonomy();
			});

			it( "covers all 8 target technologies", function(){
				var keys = variables.tax.techKeys();
				expect( keys.len() ).toBe( 8 );
				for( var k in [ "coldfusion","cfml","lucee","mura","coldbox","fusebox","commandbox","wirebox" ] ){
					expect( keys ).toInclude( k );
				}
			});

			it( "detects the newly-covered frameworks that were previously missed", function(){
				expect( variables.tax.matchText( "Senior ColdBox Developer" ) ).toInclude( "coldbox" );
				expect( variables.tax.matchText( "WireBox DI specialist" ) ).toInclude( "wirebox" );
				expect( variables.tax.matchText( "CommandBox CLI engineer" ) ).toInclude( "commandbox" );
				expect( variables.tax.matchText( "legacy FuseBox application" ) ).toInclude( "fusebox" );
			});

			it( "still detects the original CF/CFML/Lucee/Mura set", function(){
				expect( variables.tax.matchText( "Adobe ColdFusion developer" ) ).toInclude( "coldfusion" );
				expect( variables.tax.matchText( "Lucee server admin" ) ).toInclude( "lucee" );
				expect( variables.tax.matchText( "Mura CMS contractor" ) ).toInclude( "mura" );
			});

			it( "matches .cfm/.cfc symbols as CFML", function(){
				expect( variables.tax.matchText( "maintain /jobs/view.cfm pages" ) ).toInclude( "cfml" );
			});

			it( "respects word boundaries (no false positives)", function(){
				expect( variables.tax.matchesAny( "Java Spring Boot Developer" ) ).toBeFalse();
				// 'wireboxes' must not match 'wirebox'
				expect( variables.tax.matchText( "we ship wireboxes for cars" ) ).notToInclude( "wirebox" );
			});

			it( "expands an umbrella keyword to every ecosystem alias", function(){
				var expanded = variables.tax.expandKeyword( "coldfusion" );
				expect( expanded ).toInclude( "coldbox" );
				expect( expanded ).toInclude( "lucee" );
				expect( expanded.len() ).toBeGT( 8 );
			});

			it( "leaves a non-umbrella keyword untouched", function(){
				expect( variables.tax.expandKeyword( "python" ) ).toBe( [ "python" ] );
			});

		});
		</cfscript>
	</cffunction>

</cfcomponent>
