#!/usr/bin/env bash
#
# commit-phase1.sh — create the Phase 1 branch and per-PR commits.
#
# WHY THIS SCRIPT EXISTS
# The Phase 1 changes were authored into your working tree, but the sandbox
# that generated them could not commit reliably (its filesystem mount corrupted
# reads of large/edited files during `git add`). Your local filesystem is
# consistent, so running this on your machine produces correct commits.
#
# USAGE (from the repo root, e.g. Git Bash on Windows):
#   bash scripts/commit-phase1.sh
#
# It creates a `phase1` branch off origin/main and lays the work down as a
# pending-sync commit + seven per-PR commits + a wiring commit. Review, then:
#   git push -u origin phase1
# and open a PR (or seven, if you split locally).

set -euo pipefail

echo ">> Fetching origin..."
git fetch origin

echo ">> Creating branch phase1 off origin/main..."
git checkout -B phase1 origin/main

commit_group () {
  local msg="$1"; shift
  local any=0
  for p in "$@"; do
    if [ -e "$p" ]; then git add -- "$p"; any=1; fi
  done
  if git diff --cached --quiet; then
    echo "   (nothing staged for: $msg)"
  else
    git commit -q -m "$msg"
    echo "   committed: $msg"
  fi
}

# 0) Pre-Phase-1 local work that was never pushed (separate from Phase 1).
#    NOTE: ScoringService/JobService/ScrapeOrchestrator also contain small
#    pre-Phase-1 edits of yours; those ride along in the PR 1.5/1.6 commits.
commit_group "chore: sync pending local working-tree updates (pre-Phase-1)" \
  .gitignore server.json start-server.bat \
  wwwroot/assets/cf-observer.js \
  wwwroot/config/seed_companies.json \
  wwwroot/includes/layoutHead.cfm wwwroot/includes/layoutSidebar.cfm wwwroot/includes/layoutTopbar.cfm \
  wwwroot/index.cfm \
  wwwroot/services/AlertService.cfc wwwroot/services/CompanyService.cfc \
  wwwroot/services/DatabaseService.cfc wwwroot/services/DiscoveryService.cfc \
  wwwroot/services/HttpClientService.cfc wwwroot/services/ExpiryCheckerService.cfc \
  wwwroot/sql/schema.sql \
  wwwroot/tasks/checkJobExpiry.cfm wwwroot/tasks/setupSchedule.cfm \
  prototype \
  docs/IMPLEMENTATION_PLAN.md docs/PHASE1_PRS.md docs/DEPLOY_PHASE1.md

commit_group "PR 1.1: DataGateway seam (SQLite now, Postgres-ready)" \
  wwwroot/services/DataGateway.cfc tests/specs/DataGatewayTest.cfc

commit_group "PR 1.2: numbered migration runner (+ migrations 0001-0002)" \
  wwwroot/services/MigrationRunner.cfc \
  wwwroot/migrations/0001_baseline.sql wwwroot/migrations/0002_job_lifecycle_columns.sql \
  tests/specs/MigrationRunnerTest.cfc

commit_group "PR 1.3: config/secrets seam (AppConfig)" \
  wwwroot/services/AppConfig.cfc wwwroot/config/app.example.json tests/specs/AppConfigTest.cfc

commit_group "PR 1.4: TestBox harness + GitHub Actions CI" \
  box.json server-ci.json tests/Application.cfc tests/runner.cfm \
  tests/stubs/HttpClientStub.cfc .github/workflows/ci.yml

commit_group "PR 1.5: tech taxonomy + scoring/keyword fix (8 techs, v4 rule)" \
  wwwroot/services/TechTaxonomy.cfc wwwroot/services/ScoringService.cfc \
  wwwroot/services/JobService.cfc \
  tests/specs/TechTaxonomyTest.cfc tests/specs/ScoringServiceTest.cfc

commit_group "PR 1.6: ATS registry + detector (+ migration 0003)" \
  wwwroot/services/AtsRegistry.cfc wwwroot/services/AtsDetector.cfc \
  wwwroot/migrations/0003_company_ats_provider.sql \
  wwwroot/services/ScrapeOrchestrator.cfc tests/specs/AtsDetectorTest.cfc

commit_group "PR 1.7: extract CareerPageDiscoverer from ScrapeOrchestrator" \
  wwwroot/services/CareerPageDiscoverer.cfc tests/specs/CareerPageDiscovererTest.cfc

commit_group "PR 1.x: wire Phase 1 services in Application.cfc" \
  wwwroot/Application.cfc

# Catch anything not explicitly grouped above.
commit_group "chore: include any remaining Phase 1 files" .

echo ""
echo ">> Done. Review with:  git log --oneline origin/main..phase1"
echo ">> Then push:          git push -u origin phase1"
