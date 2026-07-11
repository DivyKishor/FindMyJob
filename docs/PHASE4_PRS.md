# Phase 4 — Pull Request Breakdown

Real-time alert delivery on the Phase 2 `AlertChannel` seam: Telegram + WhatsApp, config-gated, deduped, with per-channel score routing and an operator UI to verify it.

---

## PR 4.1 — Telegram channel
**What:** `TelegramChannel.cfc` (extends `AlertChannel`) delivers via the Bot API `sendMessage`. Credentials from `AppConfig` (`secrets.telegram_bot_token`, `secrets.telegram_chat_id`); per-channel routing via `alerts.telegram_min_score` (default 70). `shouldSend()` is a pure gate (enabled + score); `send()` posts and dedupes through the `alerts` table (`telegram|<rule_version>|<job_id>`). `send(payload, persist=false)` allows repeatable test sends without writing a row.
**Why:** First real delivery channel (D9).
**Risk:** Low — only active when configured; HTML message escapes dynamic fields. **Rollback:** remove the channel + wiring.
**Tests:** `TelegramChannelTest` — disabled-without-creds, score gating, custom threshold, message formatting (no network).

## PR 4.2 — WhatsApp channel
**What:** `WhatsAppChannel.cfc` via the WhatsApp Business Cloud API (`graph.facebook.com/<ver>/<phone_number_id>/messages`, Bearer token). Needs `secrets.whatsapp_token` + `whatsapp_phone_number_id` + `whatsapp_recipient`; `whatsapp.api_version` (default v20.0); `alerts.whatsapp_min_score` (default 80). Same gate/dedupe/persist model as Telegram.
**Why:** Second channel; proves the seam generalises.
**Risk:** Low. Note: free-text reaches a recipient only inside Meta's 24h window — outside it a template is required (documented).
**Tests:** `WhatsAppChannelTest` — credential completeness, score gating, formatting.

## PR 4.3 — Wiring + routing + UI
**What:** `AlertService.getChannels()`; `Application.cfc` builds Telegram/WhatsApp from `AppConfig` and registers them **only when enabled** (so an unconfigured channel never breaks the pipeline). New operator page `alert-channels.cfm` shows each channel's configured/enabled status + a "Send test alert" button, and lists recent deliveries (with channel) from the `alerts` table. `tasks/testAlertChannel.cfm?channel=telegram|whatsapp` sends a synthetic alert (non-persisted, repeatable). `config/app.example.json` updated with the new keys.
**Why:** Operability + a UI to verify delivery without DB spelunking.
**Risk:** Low — additive page/task; no change to the daily pipeline beyond channel registration.
**Tests:** covered by 4.1/4.2 specs; UI verified manually (MT-15/16).

---

## Verification status
- **Structure:** all new CFCs tag-balanced; no BIF-name collisions; the UI page's `##` are all CSS hex escapes inside `<cfoutput>`.
- **TestBox:** Phase 4 adds `TelegramChannelTest`, `WhatsAppChannelTest` (8 specs, network-free). Suite total → ~117.
- **Live delivery** requires real credentials (your Telegram bot / Meta WhatsApp number) — see `DEPLOY_PHASE4.md`.
