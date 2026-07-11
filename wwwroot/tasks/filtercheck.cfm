<cfsetting showdebugoutput="false" requesttimeout="120" />
<cfcontent type="application/json; charset=utf-8" />
<!--- Read-only: runs the real listPaged() path for each filter flow and returns row counts. --->
<cfscript>
	try {
		js = application.jobService;

		cnt = function( opts ) {
			var d = js.listPaged(
				companyId       = structKeyExists( opts, "companyId" ) ? opts.companyId : 0,
				keyword         = structKeyExists( opts, "keyword" ) ? opts.keyword : "",
				minScore        = structKeyExists( opts, "minScore" ) ? opts.minScore : 0,
				page            = 1,
				pageSize        = 1,
				sortBy          = "score",
				sortDir         = "desc",
				locationKeyword = structKeyExists( opts, "loc" ) ? opts.loc : "",
				rawSource       = "",
				workType        = structKeyExists( opts, "wt" ) ? opts.wt : "",
				sponsorshipOnly = structKeyExists( opts, "sp" ) ? opts.sp : false,
				newWithinHours  = structKeyExists( opts, "nh" ) ? opts.nh : 0
			);
			return d.totalRows;
		};

		results = {
			"all"                = cnt( {} ),
			"min_score_70"       = cnt( { minScore: 70 } ),
			"min_score_85"       = cnt( { minScore: 85 } ),
			"remote"             = cnt( { wt: "remote" } ),
			"hybrid"             = cnt( { wt: "hybrid" } ),
			"onsite"             = cnt( { wt: "onsite" } ),
			"india_eligible_any" = cnt( { loc: "india-eligible" } ),
			"india_eligible_85"  = cnt( { loc: "india-eligible", minScore: 85 } ),
			"india_pure"         = cnt( { loc: "india" } ),
			"sponsorship"        = cnt( { sp: true } ),
			"new_24h"            = cnt( { nh: 24 } ),
			"kw_coldbox"         = cnt( { keyword: "coldbox" } ),
			"kw_lucee"           = cnt( { keyword: "lucee" } )
		};

		writeOutput( serializeJSON( { ok: true, ruleVersion: application.scoringService.getRuleVersion(), counts: results } ) );
	} catch ( any e ) {
		cfheader( statusCode = 500 );
		writeOutput( serializeJSON( { ok: false, error: e.message, detail: e.detail } ) );
	}
</cfscript>
