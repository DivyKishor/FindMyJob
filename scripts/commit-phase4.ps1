# commit-phase4.ps1 — create the phase4 branch (stacked on phase3) with per-PR commits.
#   powershell -ExecutionPolicy Bypass -File scripts\commit-phase4.ps1
# Then: git log --oneline phase3..phase4 ; git push -u origin phase4
# Open a PR: phase4 -> phase3 (or -> main after earlier phases merge).

function Commit-Group {
    param([string]$Message, [string[]]$Paths)
    foreach ($p in $Paths) { if (Test-Path -LiteralPath $p) { & git add -- $p } }
    & git diff --cached --quiet
    if ($LASTEXITCODE -ne 0) { & git commit -q -m $Message; Write-Host "   committed: $Message" }
    else { Write-Host "   (nothing staged for: $Message)" }
}

$base = "phase3"
& git rev-parse --verify phase3 *> $null
if ($LASTEXITCODE -ne 0) {
    & git rev-parse --verify phase1-2 *> $null
    if ($LASTEXITCODE -eq 0) { $base = "phase1-2" }
    else { & git fetch origin "+refs/heads/main:refs/remotes/origin/main"; $base = "origin/main" }
    Write-Host "!! phase3 not found — basing phase4 on $base (run earlier phase scripts first for a clean stack)."
}
Write-Host ">> Creating phase4 off $base..."
& git checkout -B phase4 $base
if ($LASTEXITCODE -ne 0) { throw "could not create phase4 branch" }

Commit-Group "[Phase 4] PR 4.1: Telegram alert channel" @(
    "wwwroot/services/TelegramChannel.cfc","tests/specs/TelegramChannelTest.cfc")

Commit-Group "[Phase 4] PR 4.2: WhatsApp alert channel" @(
    "wwwroot/services/WhatsAppChannel.cfc","tests/specs/WhatsAppChannelTest.cfc")

Commit-Group "[Phase 4] PR 4.3: wire channels + routing + operator UI" @(
    "wwwroot/services/AlertService.cfc",
    "wwwroot/Application.cfc",
    "wwwroot/alert-channels.cfm",
    "wwwroot/tasks/testAlertChannel.cfm",
    "wwwroot/config/app.example.json")

Commit-Group "[Phase 4] docs + manual tests" @(
    "docs/PHASE4_PRS.md","docs/DEPLOY_PHASE4.md","docs/MANUAL_TESTS.md",
    "scripts/commit-phase4.ps1","scripts/commit-phase4.sh")

Write-Host ""
Write-Host ">> Leftover (do NOT commit testbox/, wwwroot/lib/*.jar, *.db, *.log):"
& git status --short
Write-Host ""
Write-Host ">> Review: git log --oneline $base..phase4"
Write-Host ">> Push:   git push -u origin phase4"
