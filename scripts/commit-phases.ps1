# commit-phases.ps1 — PowerShell version of commit-phases.sh
#
# Creates the phase1-2 branch off origin/main and lays down per-PR commits
# (7 Phase 1 + 4 Phase 2 + sync + wiring). Run from the repo root:
#
#   powershell -ExecutionPolicy Bypass -File scripts\commit-phases.ps1
#
# Then:
#   git log --oneline origin/main..phase1-2
#   git push -u origin phase1-2
# and open ONE PR: phase1-2 -> main.

function Invoke-Git {
    param([Parameter(ValueFromRemainingArguments=$true)][string[]]$Args)
    & git @Args
    if ($LASTEXITCODE -ne 0) { throw "git $($Args -join ' ') failed (exit $LASTEXITCODE)" }
}

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

Write-Host ">> Fetching origin/main (explicit refspec so origin/main ref exists)..."
Invoke-Git fetch origin "+refs/heads/main:refs/remotes/origin/main"

Write-Host ">> Creating branch phase1-2 off origin/main..."
Invoke-Git checkout -B phase1-2 origin/main

# ---- 0) Pre-existing local work that was never pushed (separate from Phases 1-2) ----
Commit-Group "chore: sync pending local working-tree updates (pre-Phase-1)" @(
    ".gitignore","server.json","start-server.bat","README.md",
    "wwwroot/assets/cf-observer.js",
    "wwwroot/config/seed_companies.json",
    "wwwroot/includes/layoutHead.cfm","wwwroot/includes/layoutSidebar.cfm","wwwroot/includes/layoutTopbar.cfm",
    "wwwroot/index.cfm",
    "wwwroot/services/CompanyService.cfc","wwwroot/services/DatabaseService.cfc",
    "wwwroot/services/DiscoveryService.cfc","wwwroot/services/HttpClientService.cfc",
    "wwwroot/services/ExpiryCheckerService.cfc",
    "wwwroot/sql/schema.sql",
    "wwwroot/tasks/checkJobExpiry.cfm","wwwroot/tasks/setupSchedule.cfm",
    "prototype",
    "docs/IMPLEMENTATION_PLAN.md","docs/PHASE1_PRS.md","docs/PHASE2_PRS.md",
    "docs/DEPLOY_PHASE1.md","docs/DEPLOY_PHASE2.md","docs/MANUAL_TESTS.md",
    "scripts/commit-phase1.sh","scripts/commit-phases.sh","scripts/commit-phases.ps1"
)

# ====================== PHASE 1 ======================
Commit-Group "[Phase 1] PR 1.1: DataGateway seam (SQLite now, Postgres-ready)" @(
    "wwwroot/services/DataGateway.cfc","tests/specs/DataGatewayTest.cfc")

Commit-Group "[Phase 1] PR 1.2: numbered migration runner (+ migrations 0001-0002)" @(
    "wwwroot/services/MigrationRunner.cfc",
    "wwwroot/migrations/0001_baseline.sql","wwwroot/migrations/0002_job_lifecycle_columns.sql",
    "tests/specs/MigrationRunnerTest.cfc")

Commit-Group "[Phase 1] PR 1.3: config/secrets seam (AppConfig)" @(
    "wwwroot/services/AppConfig.cfc","wwwroot/config/app.example.json","tests/specs/AppConfigTest.cfc")

Commit-Group "[Phase 1] PR 1.4: TestBox harness + GitHub Actions CI" @(
    "box.json","server-ci.json","tests/runner.cfm",
    "tests/stubs/HttpClientStub.cfc",".github/workflows/ci.yml")

Commit-Group "[Phase 1] PR 1.5: tech taxonomy + keyword expansion (8 techs)" @(
    "wwwroot/services/TechTaxonomy.cfc","wwwroot/services/JobService.cfc",
    "tests/specs/TechTaxonomyTest.cfc")

Commit-Group "[Phase 1] PR 1.6: ATS registry + detector (+ migration 0003)" @(
    "wwwroot/services/AtsRegistry.cfc","wwwroot/services/AtsDetector.cfc",
    "wwwroot/migrations/0003_company_ats_provider.sql",
    "wwwroot/services/ScrapeOrchestrator.cfc","tests/specs/AtsDetectorTest.cfc")

Commit-Group "[Phase 1] PR 1.7: extract CareerPageDiscoverer from ScrapeOrchestrator" @(
    "wwwroot/services/CareerPageDiscoverer.cfc","tests/specs/CareerPageDiscovererTest.cfc")

# ====================== PHASE 2 ======================
Commit-Group "[Phase 2] PR 2.1: HTTP technology fingerprinting (+ migration 0004)" @(
    "wwwroot/services/TechFingerprinter.cfc",
    "wwwroot/migrations/0004_tech_fingerprints.sql",
    "wwwroot/tasks/fingerprintCompanies.cfm","tests/specs/TechFingerprinterTest.cfc")

Commit-Group "[Phase 2] PR 2.2: company CF-likelihood scoring (+ migration 0005)" @(
    "wwwroot/services/CompanyScoreService.cfc",
    "wwwroot/migrations/0005_company_scores.sql",
    "wwwroot/tasks/scoreCompanies.cfm","tests/specs/CompanyScoreServiceTest.cfc")

Commit-Group "[Phase 2] PR 2.3: layered scoring - cf_match/geo/remote/visa (v5_layered)" @(
    "wwwroot/services/ScoringService.cfc",
    "tests/specs/ScoringServiceTest.cfc","tests/specs/ScoringServiceV5Test.cfc")

Commit-Group "[Phase 2] PR 2.4: alert channel seam (AlertChannel + LogChannel)" @(
    "wwwroot/services/AlertChannel.cfc","wwwroot/services/LogChannel.cfc",
    "wwwroot/services/AlertService.cfc","tests/specs/AlertChannelTest.cfc")

# ---- Wiring last so every referenced service already exists in history ----
Commit-Group "[Phases 1-2] wire services in Application.cfc + test harness" @(
    "wwwroot/Application.cfc","tests/Application.cfc")

Write-Host ""
Write-Host ">> Uncommitted/untracked after grouping (review; do NOT commit testbox/, wwwroot/lib/*.jar, *.db, *.log):"
& git status --short

Write-Host ""
Write-Host ">> Review: git log --oneline origin/main..phase1-2"
Write-Host ">> Push:   git push -u origin phase1-2"
