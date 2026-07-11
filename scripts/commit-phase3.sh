#!/usr/bin/env bash
# commit-phase3.sh — create the phase3 branch (stacked on phase1-2) with per-PR commits.
# Run AFTER phase1-2 exists locally. Then: git push -u origin phase3
set -euo pipefail

commit_group () {
  local msg="$1"; shift
  for p in "$@"; do if [ -e "$p" ]; then git add -- "$p"; fi; done
  if git diff --cached --quiet; then echo "   (nothing staged: $msg)"; else git commit -q -m "$msg"; echo "   committed: $msg"; fi
}

if git rev-parse --verify phase1-2 >/dev/null 2>&1; then
  echo ">> Creating phase3 off phase1-2..."
  git checkout -B phase3 phase1-2
else
  echo "!! phase1-2 not found locally — basing phase3 on origin/main (run commit-phases.sh first for a clean stack)."
  git fetch origin "+refs/heads/main:refs/remotes/origin/main"
  git checkout -B phase3 origin/main
fi

commit_group "[Phase 3] PR 3.1: source graph model + service (+ migration 0006)" \
  wwwroot/services/SourceGraphService.cfc wwwroot/migrations/0006_source_graph.sql tests/specs/SourceGraphServiceTest.cfc

commit_group "[Phase 3] PR 3.2: source expansion engine (promote/quarantine)" \
  wwwroot/services/SourceExpansionService.cfc tests/specs/SourceExpansionServiceTest.cfc

commit_group "[Phase 3] PR 3.3: automated source onboarding (+ migration 0007)" \
  wwwroot/migrations/0007_source_definitions.sql wwwroot/services/SourceAdapter.cfc \
  wwwroot/services/SourceRegistryService.cfc tests/specs/SourceRegistryServiceTest.cfc

commit_group "[Phase 3] PR 3.4: continuous tiered scheduler" \
  wwwroot/services/SourceScheduler.cfc tests/specs/SourceSchedulerTest.cfc

commit_group "[Phase 3] wire services in Application.cfc + tasks + docs" \
  wwwroot/Application.cfc \
  wwwroot/tasks/buildSourceGraph.cfm wwwroot/tasks/expandSources.cfm wwwroot/tasks/syncSourceDefinitions.cfm \
  docs/PHASE3_PRS.md docs/DEPLOY_PHASE3.md docs/MANUAL_TESTS.md \
  scripts/commit-phase3.ps1 scripts/commit-phase3.sh

echo ""
echo ">> Leftover (do NOT commit testbox/, wwwroot/lib/*.jar, *.db, *.log):"
git status --short
echo ">> Review: git log --oneline phase1-2..phase3 ; Push: git push -u origin phase3"
