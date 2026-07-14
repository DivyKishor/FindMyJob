# Deploying CF/OBSERVER on Oracle Cloud Free Tier

A 24/7 always-free VM so the twice-daily scheduler actually fires (your laptop sleeping
was the reason runs were missed). The app binds to loopback only; Nginx is the single
public door and refuses `/tasks/`, so the scheduled jobs can run **only from the box
itself** — no key, no public route.

## What's in this folder
- `server.json` — CommandBox/Lucee config; binds the app to `127.0.0.1:8888`.
- `cfobserver.service` — systemd unit (auto-start, auto-restart, supervised JVM).
- `nginx-cfobserver.conf` — public TLS front door; blocks `/tasks/`, tags proxied requests.
- `setup-oracle.sh` — provisioning guide (packages, CommandBox, firewall, service, TLS, backup).

## How task lockdown works (defense in depth)
1. **App binds to `127.0.0.1:8888`** — unreachable from the internet at all.
2. **App guard** (`Application.cfc` `onRequestStart`): a `/tasks/` request is accepted only
   when it is from loopback **and** carries no proxy headers (`X-Forwarded-For`/`X-Real-IP`/
   `X-Public-Request`). The in-process scheduler calls `http://127.0.0.1:8888/tasks/...`
   directly, so it passes; anything arriving via Nginx is rejected.
3. **Nginx** returns `404` for `^~ /tasks/`, so the public never even reaches the app there.

Net: the only thing that can trigger a task is the scheduler running on the server (or you,
over SSH, hitting `127.0.0.1:8888` directly). An optional `security.task_key` still lets you
authorize a remote/manual run if you ever want one — but it is not required.

## Order of operations

### 1. Create the VM (Oracle Console — click-ops)
- Compute → Instances → **Create instance**.
- Image **Ubuntu 22.04**, shape **VM.Standard.A1.Flex** (ARM). Start at **1 OCPU / 6 GB**
  (well within the free ceiling, which dropped to **2 OCPU / 12 GB total** in June 2026).
  If you hit *"Out of host capacity"*, retry across availability domains or try later.
- Add your SSH public key. Note the **public IP**.
- **Strongly recommended:** Billing → **Upgrade to Pay As You Go**. It stays $0 for
  Always-Free resources but exempts you from idle-instance reclamation (a low-traffic
  app like this trips the <20% CPU / 7-day idle rule otherwise).

### 2. Open ingress (Oracle Console — click-ops)
- Networking → your VCN → **Security List** (or the instance's NSG) → add ingress rules:
  TCP **80** and **443** from `0.0.0.0/0`. (Port 8888 stays closed — it's loopback only.)

### 3. Point a domain at the IP (for TLS)
- Any A record → the VM's public IP. No domain? Use a free one (e.g. DuckDNS).
  TLS needs a hostname; certbot can't issue for a bare IP.

### 4. Deploy the app + run setup
```bash
ssh ubuntu@YOUR_PUBLIC_IP
sudo git clone https://github.com/DivyKishor/FindMyJob.git /opt/cfobserver
# copy your real secrets up (app.json is gitignored):
#   from your laptop:  scp "C:\Claude Space\FindMyJob\wwwroot\config\app.json" ubuntu@YOUR_PUBLIC_IP:/tmp/app.json
sudo mv /tmp/app.json /opt/cfobserver/wwwroot/config/app.json
# edit cfobserver.duckdns.org in deploy/nginx-cfobserver.conf, then:
sudo bash /opt/cfobserver/deploy/setup-oracle.sh
```
The script: installs Java 21 + CommandBox + Nginx, fetches `sqlite-jdbc.jar` (the gitignored
ARM-compatible 3.46.0.0 driver), opens the host firewall, installs+starts the systemd
service, wires Nginx, and adds a nightly SQLite backup. Then issue TLS:
```bash
sudo snap install --classic certbot && sudo ln -s /snap/bin/certbot /usr/bin/certbot
sudo certbot --nginx -d cfobserver.duckdns.org
```

### 5. Verify
```bash
systemctl status cfobserver                 # running
journalctl -u cfobserver -e                  # boot log / migrations
curl -fsS http://127.0.0.1:8888/ | head      # app responds locally
curl -fsS https://cfobserver.duckdns.org/ | head        # public site via TLS
curl -s -o /dev/null -w '%{http_code}\n' https://cfobserver.duckdns.org/tasks/runDailyScrape.cfm  # expect 404
```
The scheduled tasks self-register on app start (5AM Apify posts, 6AM/6PM scrape, etc.) and
now fire reliably because the box is always on.

## Notes
- **ARM is fine:** Lucee is JVM (arch-agnostic) and `sqlite-jdbc 3.46.0.0` bundles a
  `linux-aarch64` native lib. No native deps lack ARM builds.
- **Secrets:** `app.json` holds your Apify/GitHub tokens — it's `chmod 600` and gitignored.
  Rotate the Apify token you pasted earlier.
- **Backups:** nightly `.backup` to `/opt/cfobserver/backups`, pruned after 14 days. Consider
  also syncing to OCI Object Storage (Always Free: 20 GB) for off-box safety.
- **Updates:** `cd /opt/cfobserver && sudo git pull && sudo systemctl restart cfobserver`.
