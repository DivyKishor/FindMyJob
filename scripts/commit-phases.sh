#!/usr/bin/env bash
#
# commit-phases.sh — create the Phase 1 + Phase 2 branch and per-PR commits.
#
# WHY ONE BRANCH FOR BOTH PHASES
# Phase 2 was written directly on top of *uncommitted* Phase 1 in the same
# working tree, and several files (Application.cfc, ScoringService, AlertService,
# tests/Application.cfc) were edited by both phases. There is no commit boundary
# to split them on, so they ship together on one branch. The commit history below
# still separates the 11 logical PRs (7 in Phase 1, 4 in Phase 2) so the PR can be
# reviewed commit-by-commit.
#
# WHY A SCRIPT
# The sandbox that authored these files could not commit reliably (its filesystem
# mount corrupted reads during `git add`). Your local filesystem is consistent, so
# running this here produces correct commits.
#
# USAGE (from repo root, e.g. Git Bash on Windows):
#   bash scripts/commit-phases.sh
# Then:
#   git log --oneline origin/main..phase1-2
#   git push -u origin phase1-2
# and open ONE PR (phase1-2 -> main).

set -euo pipefail

echo ">> Fetching origin/main (explicit refspec so origin/main ref exists)..."
git fetch origin "+refs/heads/main:refs/remotes/origin/main"

echo ">> Creating branch phase1-2 off origin/main..."
git checkout -B phase1-2 origin/main

commit_group () {
  local msg="$1"; shift
  for p in "$@"; do
    if [ -e "$p" ]; then git add -- "$p"; fi
  done
  if git diff --cached --quiet; then
    echo "   (nothing staged for: $msg)"
  else
    git commit -q -m "$msg"
    echo "   committed: $msg"
  fi
}

# ---- 0) Pre-existing local work that was never pushed (separate from Phases 1-2) ----
commit_group "chore: sync pending local working-tree updates (pre-Phase-1)" \
  .gitignore server.json start-server.bat README.md \
  wwwroot/assets/cf-observer.js \
  wwwroot/config/seed_companies.json \
  wwwroot/includes/layoutHead.cfm wwwroot/includes/layoutSidebar.cfm wwwroot/includes/layoutTopbar.cfm \
  wwwroot/index.cfm \
  wwwroot/services/CompanyService.cfc wwwroot/services/DatabaseService.cfc \
  wwwroot/services/DiscoveryService.cfc wwwroot/services/HttpClientService.cfc \
  wwwroot/services/ExpiryCheckerService.cfc \
  wwwroot/sql/schema.sql \
  wwwroot/tasks/checkJobExpiry.cfm wwwroot/tasks/setupSchedule.cfm \
  prototype \
  docs/IMPLEMENTATION_PLAN.md docs/PHASE1_PRS.md docs/PHASE2_PRS.md \
  docs/DEPLOY_PHASE1.md docs/DEPLOY_PHASE2.md \
  scripts/commit-phase1.sh scripts/commit-phases.sh

# ====================== PHASE 1 ======================
commit_group "[Phase 1] PR 1.1: DataGateway seam (SQLite now, Postgres-ready)" \
  wwwroot/services/DataGateway.cfc tests/specs/DataGatewayTest.cfc

commit_group "[Phase 1] PR 1.2: numbered migration runner (+ migrations 0001-0002)" \
  wwwroot/services/MigrationRunner.cfc \
  wwwroot/migrations/0001_baseline.sql wwwroot/migrations/0002_job_lifecycle_columns.sql \
  tests/specs/MigrationRunnerTest.cfc

commit_group "[Phase 1] PR 1.3: config/secrets seam (AppConfig)" \
  wwwroot/services/AppConfig.cfc wwwroot/config/app.example.json tests/specs/AppConfigTest.cfc

commit_group "[Phase 1] PR 1.4: TestBox harness + GitHub Actions CI" \
  box.json server-ci.json tests/runner.cfm \
  tests/stubs/HttpClientStub.cfc .github/workflows/ci.yml

commit_group "[Phase 1] PR 1.5: tech taxonomy + keyword expansion (8 techs)" \
  wwwroot/services/TechTaxonomy.cfc wwwroot/services/JobService.cfc \
  tests/specs/TechTaxonomyTest.cfc

commit_group "[Phase 1] PR 1.6: ATS registry + detector (+ migration 0003)" \
  wwwroot/services/AtsRegistry.cfc wwwroot/services/AtsDetector.cfc \
  wwwroot/migrations/0003_company_ats_provider.sql \
  wwwroot/services/ScrapeOrchestrator.cfc tests/specs/AtsDetectorTest.cfc

commit_group "[Phase 1] PR 1.7: extract CareerPageDiscoverer from ScrapeOrchestrator" \
  wwwroot/services/CareerPageDiscoverer.cfc tests/specs/CareerPageDiscovererTest.cfc

# ====================== PHASE 2 ======================
commit_group "[Phase 2] PR 2.1: HTTP technology fingerprinting (+ migration 0004)" \
  wwwroot/services/TechFingerprinter.cfc \
  wwwroot/migrations/0004_tech_fingerprints.sql \
  wwwroot/tasks/fingerprintCompanies.cfm tests/specs/TechFingerprinterTest.cfc

commit_group "[Phase 2] PR 2.2: company CF-likelihood scoring (+ migration 0005)" \
  wwwroot/services/CompanyScoreService.cfc \
  wwwroot/migrations/0005_company_scores.sql \
  wwwroot/tasks/scoreCompanies.cfm tests/specs/CompanyScoreServiceTest.cfc

# PR 2.3 also embodies the PR 1.5 taxonomy integration (ScoringService is now v5_layered).
commit_group "[Phase 2] PR 2.3: layered scoring — cf_match/geo/remote/visa (v5_layered)" \
  wwwroot/services/ScoringService.cfc \
  tests/specs/ScoringServiceTest.cfc tests/specs/ScoringServiceV5Test.cfc

commit_group "[Phase 2] PR 2.4: alert channel seam (AlertChannel + LogChannel)" \
  wwwroot/services/AlertChannel.cfc wwwroot/services/LogChannel.cfc \
  wwwroot/services/AlertService.cfc tests/specs/AlertChannelTest.cfc

# ---- Wiring last so every referenced service already exists in history ----
commit_group "[Phases 1-2] wire services in Application.cfc + test harness" \
  wwwroot/Application.cfc tests/Application.cfc

# ---- Safety: report anything left uncommitted instead of blind-adding ----
echo ""
echo ">> Uncommitted/untracked after grouping (review manually; do NOT commit"
echo "   testbox/, wwwroot/lib/*.jar, *.db, or *.log):"
git status --short || true

echo ""
echo ">> Done. Review:  git log --oneline origin/main..phase1-2"
echo ">> Push:          git push -u origin phase1-2"
echo ">> Then open a PR:  phase1-2 -> main"
