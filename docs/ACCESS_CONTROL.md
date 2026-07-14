# Access Control — current state

No login system. Admin/operator features are gated two ways:

## 1. `isLocal` gate (UI admin controls) — IMPLEMENTED

`index.cfm` computes:

```
isLocal = ( CGI.REMOTE_ADDR in {127.0.0.1, ::1, 0:0:0:0:0:0:0:1} )
          AND NOT len( trim( CGI.HTTP_X_FORWARDED_FOR ) )
```

Why the `X-Forwarded-For` part: ngrok (and most reverse proxies) connect to the local CF server
*from* localhost, so `REMOTE_ADDR` is `127.0.0.1` even for public visitors. The presence of an
`X-Forwarded-For` header means the request came **through a proxy** (i.e. a public visitor), so
`isLocal` is forced false.

`isLocal` is passed into the layout and used to show/hide admin UI:
- **Pipeline** and **Network** nav links (`layoutTopbar.cfm`, inside `<cfif isLocal>`).
- The **"Run now"** (run daily pipeline) button on the dashboard (`index.cfm`).

Net effect: browse directly on `http://127.0.0.1:8888` → you see admin controls. Browse the public
ngrok/host URL → you don't. No password needed.

## 2. Task-endpoint key guard — IMPLEMENTED

Every `/tasks/*.cfm` is protected when `security.task_key` is set (env `CFINTEL_SECURITY_TASK_KEY`
or `config/app.json`); requests without a matching `?key=…` get `403`. Blank key ⇒ open (local dev).
The scheduler appends the key automatically.

## Known gap (hardening recommendation)

The `isLocal` gate hides the **nav links** to admin pages, but the standalone operator pages
themselves don't re-check it, so a public visitor who knows the URL can still open:
`discovery-signals.cfm`, `discovery-health.cfm`, `alert-channels.cfm`.

To close this, add the same `isLocal` check at the top of those pages (or factor it into a shared
include) and return `403` when not local — e.g.:

```cfml
<cfset isLocal = ( listFindNoCase("127.0.0.1,::1,0:0:0:0:0:0:0:1", cgi.remote_addr) GT 0 )
                 AND NOT len( trim( cgi.http_x_forwarded_for ) ) />
<cfif NOT isLocal><cfheader statusCode="403" /><cfoutput>Forbidden</cfoutput><cfabort /></cfif>
```

(Alternatively the magic-link/admin-key approach if you ever want to grant access to a non-local
machine without exposing it to everyone.)
