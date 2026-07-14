# Phase 4 — Deployment & Verification

Telegram + WhatsApp alert channels on the Phase 2 `AlertChannel` seam. No migrations. Channels activate only when credentials are present, so deploying without config changes nothing.

## 1. Telegram setup

1. In Telegram, message **@BotFather** → `/newbot` → copy the **bot token**.
2. Get your **chat id**: message your new bot once, then open
   `https://api.telegram.org/bot<token>/getUpdates` and read `result[].message.chat.id`
   (for a group, add the bot to the group and use the negative group id).
3. Configure (either env vars or `config/app.json`):
   ```
   CFINTEL_SECRETS_TELEGRAM_BOT_TOKEN=123456:ABC...
   CFINTEL_SECRETS_TELEGRAM_CHAT_ID=987654321
   ```
   Optional routing: `alerts.telegram_min_score` (default 70).

## 2. WhatsApp setup (Meta WhatsApp Business Cloud API)

1. In Meta for Developers, create an app → add **WhatsApp** → get a **temporary/permanent access token** and the **phone number ID**.
2. Set the **recipient** (your number in international format, no `+`, e.g. `9198XXXXXXXX`).
3. Configure:
   ```
   CFINTEL_SECRETS_WHATSAPP_TOKEN=EAAB...
   CFINTEL_SECRETS_WHATSAPP_PHONE_NUMBER_ID=1234567890
   CFINTEL_SECRETS_WHATSAPP_RECIPIENT=9198XXXXXXXX
   ```
   Optional: `whatsapp.api_version` (default v20.0), `alerts.whatsapp_min_score` (default 80).
4. **24h window:** send a WhatsApp message *to* your business number first so free-text replies are allowed; otherwise Meta requires an approved template.

## 3. Apply config

`copy wwwroot\config\app.json` from `app.example.json` (gitignored) and fill the secrets, **or** set the `CFINTEL_*` env vars. Then reinit:
```
http://localhost:8500/index.cfm?reinit=1
```
On start, `Application.cfc` registers each channel whose credentials are complete.

## 4. Verify on the UI

Open the operator page:
```
http://localhost:8500/alert-channels.cfm
```
- Each channel shows **CONFIGURED** / **NOT CONFIGURED**.
- Click **Send test alert** → a synthetic alert is delivered (non-persisted, repeatable) and the JSON result (`sent:true`) shows inline; check your Telegram/WhatsApp for the message.
- The **Recent deliveries** table lists rows from the `alerts` table by channel.

## 5. Production alerting

The daily pipeline's `generateAlerts` now dispatches qualifying jobs to every enabled channel (deduped per channel via the `alerts` table). Tune per-channel thresholds with `alerts.telegram_min_score` / `alerts.whatsapp_min_score`.

## 6. Tests

```bash
box testbox run runner="http://localhost:8599/tests/runner.cfm" verbose=true
```
Phase 4 adds `TelegramChannelTest` + `WhatsAppChannelTest` (network-free: gating + formatting). Live send is exercised via the UI test button with real credentials.

## 7. Rollback
Additive. Remove the channel registration block in `Application.cfc` (and the two CFCs) to disable; the pipeline falls back to the LogChannel only.
