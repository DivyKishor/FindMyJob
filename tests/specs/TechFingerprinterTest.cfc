<cfcomponent extends="testbox.system.BaseSpec" output="false">
	<!---
		TechFingerprinterTest — Phase 2, PR 2.1.

		Tests the pure evaluateSignals() function with fixture HTML / header structs.
		No HTTP calls are made; the network-dependent fingerprint() method is not tested here
		(integration tests would cover that in a full test environment).
	--->

	<cffunction name="run" access="public" returntype="void" output="false">
		<cfscript>
		describe( "TechFingerprinter.evaluateSignals()", function(){

			beforeEach( function(){
				// We need a DataGateway stub — evaluateSignals() is pure and never calls the DB,
				// but init() requires a dataGateway argument.  Use a simple struct with a warn() shim.
				var fakeGW  = { execute: function(){}, query: function(){ return queryNew("") } };
				var fakeLog = new tests.stubs.HttpClientStub(); // reuse stub for logger shim
				variables.fp = new services.TechFingerprinter( fakeGW, fakeLog );
			});

			it( "detects X-Powered-By: ColdFusion header", function(){
				var result = variables.fp.evaluateSignals( "", { "X-Powered-By": "ColdFusion 2025" }, "" );
				var names  = extractSignalNames( result.signals );
				expect( arrayFindNoCase( names, "powered_by" ) ).toBeGT( 0 );
				expect( result.score ).toBeGT( 0 );
			});

			it( "detects Lucee in Server header", function(){
				var result = variables.fp.evaluateSignals( "", { "Server": "Lucee/6.0.0.326" }, "" );
				var names  = extractSignalNames( result.signals );
				expect( arrayFindNoCase( names, "lucee_header" ) ).toBeGT( 0 );
			});

			it( "detects CFID/CFTOKEN cookie", function(){
				var result = variables.fp.evaluateSignals( "", { "Set-Cookie": "CFID=12345; CFTOKEN=abc" }, "" );
				var names  = extractSignalNames( result.signals );
				expect( arrayFindNoCase( names, "cf_cookie" ) ).toBeGT( 0 );
			});

			it( "detects .cfm URLs in HTML href attributes", function(){
				var html   = '<html><body><a href="/login.cfm">Login</a></body></html>';
				var result = variables.fp.evaluateSignals( html, {}, "" );
				var names  = extractSignalNames( result.signals );
				expect( arrayFindNoCase( names, "cfm_url" ) ).toBeGT( 0 );
			});

			it( "detects .cfc URLs in form action attributes", function(){
				var html   = '<form action="/api/component.cfc?method=save">...</form>';
				var result = variables.fp.evaluateSignals( html, {}, "" );
				var names  = extractSignalNames( result.signals );
				expect( arrayFindNoCase( names, "cfm_url" ) ).toBeGT( 0 );
			});

			it( "detects ColdBox marker in HTML body", function(){
				var html   = '<html><head><script src="/coldbox/system/web/loader.js"></script></head></html>';
				var result = variables.fp.evaluateSignals( html, {}, "" );
				var names  = extractSignalNames( result.signals );
				expect( arrayFindNoCase( names, "coldbox_marker" ) ).toBeGT( 0 );
			});

			it( "detects WireBox marker in HTML body", function(){
				var html   = '<html><body><div id="wireboxApp">...</div></body></html>';
				var result = variables.fp.evaluateSignals( html, {}, "" );
				var names  = extractSignalNames( result.signals );
				expect( arrayFindNoCase( names, "coldbox_marker" ) ).toBeGT( 0 );
			});

			it( "detects Mura CMS marker", function(){
				var html   = '<html><head><script src="/mura/js/mura.js"></script></head></html>';
				var result = variables.fp.evaluateSignals( html, {}, "" );
				var names  = extractSignalNames( result.signals );
				expect( arrayFindNoCase( names, "mura_marker" ) ).toBeGT( 0 );
			});

			it( "detects CommandBox trace in HTML", function(){
				var html   = '<!-- Powered by CommandBox 6.0 -->';
				var result = variables.fp.evaluateSignals( html, {}, "" );
				var names  = extractSignalNames( result.signals );
				expect( arrayFindNoCase( names, "commandbox" ) ).toBeGT( 0 );
			});

			it( "returns zero signals and score 0 for a plain non-CF page", function(){
				var html   = '<html><body><h1>Hello World</h1><p>A simple page with no CF signals.</p></body></html>';
				var result = variables.fp.evaluateSignals( html, { "Server": "Apache/2.4" }, "" );
				expect( arrayLen( result.signals ) ).toBe( 0 );
				expect( result.score ).toBe( 0 );
			});

			it( "scores a page with multiple high-weight signals above 50", function(){
				var html   = '<html><body><a href="/app/login.cfm">Login</a><script>// WireBox</script></body></html>';
				var result = variables.fp.evaluateSignals( html, {
					"X-Powered-By": "ColdFusion 2025",
					"Set-Cookie":   "CFID=1; CFTOKEN=abc"
				}, "" );
				expect( result.score ).toBeGT( 50 );
			});

			it( "is case-insensitive for header names", function(){
				var result = variables.fp.evaluateSignals( "", { "x-powered-by": "coldfusion" }, "" );
				var names  = extractSignalNames( result.signals );
				expect( arrayFindNoCase( names, "powered_by" ) ).toBeGT( 0 );
			});

		});
		</cfscript>
	</cffunction>

	<!--- Helper: flatten signal names from an array of signal structs. --->
	<cffunction name="extractSignalNames" access="private" returntype="array" output="false">
		<cfargument name="signals" type="array" required="true" />
		<cfset var out = [] />
		<cfloop array="#arguments.signals#" index="s">
			<cfset arrayAppend( out, s.signal ) />
		</cfloop>
		<cfreturn out />
	</cffunction>

</cfcomponent>
