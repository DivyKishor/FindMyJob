# commit-phase3.ps1 — create the phase3 branch (stacked on phase1-2) with per-PR commits.
#
# Run AFTER phase1-2 exists locally (it carries Phase 1 + 2). Phase 3 depends on it.
#   powershell -ExecutionPolicy Bypass -File scripts\commit-phase3.ps1
# Then:
#   git log --oneline phase1-2..phase3
#   git push -u origin phase3
# Open a PR: phase3 -> phase1-2  (or -> main after phase1-2 merges).

function Commit-Group {
    param([string]$Message, [string[]]$Paths)
    foreach ($p in $Paths) { if (Test-Path -LiteralPath $p) { & git add -- $p } }
    & git diff --cached --quiet
    if ($LASTEXITCODE -ne 0) {
        & git commit -q -m $Message
        Write-Host "   committed: $Message"
    } else {
        Write-Host "   (nothing staged for: $Message)"
    }
}

# Base phase3 on phase1-2 if present, else origin/main (with a warning).
& git rev-parse --verify phase1-2 *> $null
if ($LASTEXITCODE -eq 0) {
    Write-Host ">> Creating phase3 off phase1-2..."
    & git checkout -B phase3 phase1-2
} else {
    Write-Host "!! phase1-2 not found locally — basing phase3 on origin/main."
    Write-Host "   (Phase 3 depends on Phase 1/2; run commit-phases.ps1 first for a clean stack.)"
    & git fetch origin "+refs/heads/main:refs/remotes/origin/main"
    & git checkout -B phase3 origin/main
}
if ($LASTEXITCODE -ne 0) { throw "could not create phase3 branch" }

Commit-Group "[Phase 3] PR 3.1: source graph model + service (+ migration 0006)" @(
    "wwwroot/services/SourceGraphService.cfc",
    "wwwroot/migrations/0006_source_graph.sql",
    "tests/specs/SourceGraphServiceTest.cfc")

Commit-Group "[Phase 3] PR 3.2: source expansion engine (promote/quarantine)" @(
    "wwwroot/services/SourceExpansionService.cfc",
    "tests/specs/SourceExpansionServiceTest.cfc")

Commit-Group "[Phase 3] PR 3.3: automated source onboarding (+ migration 0007)" @(
    "wwwroot/migrations/0007_source_definitions.sql",
    "wwwroot/services/SourceAdapter.cfc",
    "wwwroot/services/SourceRegistryService.cfc",
    "tests/specs/SourceRegistryServiceTest.cfc")

Commit-Group "[Phase 3] PR 3.4: continuous tiered scheduler" @(
    "wwwroot/services/SourceScheduler.cfc",
    "tests/specs/SourceSchedulerTest.cfc")

Commit-Group "[Phase 3] wire services in Application.cfc + tasks + docs" @(
    "wwwroot/Application.cfc",
    "wwwroot/tasks/buildSourceGraph.cfm",
    "wwwroot/tasks/expandSources.cfm",
    "wwwroot/tasks/syncSourceDefinitions.cfm",
    "docs/PHASE3_PRS.md","docs/DEPLOY_PHASE3.md","docs/MANUAL_TESTS.md",
    "scripts/commit-phase3.ps1","scripts/commit-phase3.sh")

Write-Host ""
Write-Host ">> Leftover (review; do NOT commit testbox/, wwwroot/lib/*.jar, *.db, *.log):"
& git status --short
Write-Host ""
Write-Host ">> Review: git log --oneline phase1-2..phase3"
Write-Host ">> Push:   git push -u origin phase3"
