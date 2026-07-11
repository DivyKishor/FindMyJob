#!/usr/bin/env bash
# commit-phase4.sh — create the phase4 branch (stacked on phase3) with per-PR commits.
# Then: git push -u origin phase4
set -euo pipefail

commit_group () {
  local msg="$1"; shift
  for p in "$@"; do if [ -e "$p" ]; then git add -- "$p"; fi; done
  if git diff --cached --quiet; then echo "   (nothing staged: $msg)"; else git commit -q -m "$msg"; echo "   committed: $msg"; fi
}

if git rev-parse --verify phase3 >/dev/null 2>&1; then base=phase3
elif git rev-parse --verify phase1-2 >/dev/null 2>&1; then base=phase1-2
else git fetch origin "+refs/heads/main:refs/remotes/origin/main"; base=origin/main; fi
echo ">> Creating phase4 off $base..."
git checkout -B phase4 "$base"

commit_group "[Phase 4] PR 4.1: Telegram alert channel" \
  wwwroot/services/TelegramChannel.cfc tests/specs/TelegramChannelTest.cfc

commit_group "[Phase 4] PR 4.2: WhatsApp alert channel" \
  wwwroot/services/WhatsAppChannel.cfc tests/specs/WhatsAppChannelTest.cfc

commit_group "[Phase 4] PR 4.3: wire channels + routing + operator UI" \
  wwwroot/services/AlertService.cfc wwwroot/Application.cfc \
  wwwroot/alert-channels.cfm wwwroot/tasks/testAlertChannel.cfm wwwroot/config/app.example.json

commit_group "[Phase 4] docs + manual tests" \
  docs/PHASE4_PRS.md docs/DEPLOY_PHASE4.md docs/MANUAL_TESTS.md \
  scripts/commit-phase4.ps1 scripts/commit-phase4.sh

echo ""; echo ">> Leftover:"; git status --short
echo ">> Review: git log --oneline $base..phase4 ; Push: git push -u origin phase4"
