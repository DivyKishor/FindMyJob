<cfsetting requesttimeout="900" showdebugoutput="false" />
<cfparam name="url.reporter" default="simple" />
<cfparam name="url.directory" default="tests.specs" />

<cfscript>
	testbox = new testbox.system.TestBox(
		directory = { mapping = url.directory, recurse = true }
	);
	writeOutput( testbox.run( reporter = url.reporter ) );
</cfscript>
