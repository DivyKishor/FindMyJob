#!/usr/bin/env bash
# CF/OBSERVER — Oracle Cloud (Ubuntu 22.04, ARM Ampere A1) provisioning.
# Run as a sudo-capable user. Re-runnable. Review before executing; it is a guide,
# not a black box. Replace cfobserver.duckdns.org before the nginx/certbot steps.
set -euo pipefail

APP_DIR=/opt/cfobserver
APP_USER=cfobserver

echo "== 1. Base packages =="
sudo apt-get update
sudo apt-get install -y openjdk-21-jre-headless unzip curl nginx ca-certificates gnupg sqlite3 cron

echo "== 2. CommandBox (Lucee runner) =="
# noarch deb repo (CommandBox is pure-JVM, so ARM is fine). If apt-key is removed on
# your image, see https://commandbox.ortusbooks.com/setup/installation for the keyring method.
curl -fsSL https://downloads.ortussolutions.com/debs/gpg | sudo apt-key add -
echo "deb https://downloads.ortussolutions.com/debs/noarch /" | sudo tee /etc/apt/sources.list.d/commandbox.list
sudo apt-get update
sudo apt-get install -y commandbox
box version

echo "== 3. Service user + app dir =="
sudo useradd --system --home "$APP_DIR" --shell /usr/sbin/nologin "$APP_USER" 2>/dev/null || true
sudo mkdir -p "$APP_DIR"
# Deploy the repo to $APP_DIR (git clone or rsync). Example:
#   sudo git clone https://github.com/DivyKishor/FindMyJob.git "$APP_DIR"
# config/app.json (with your secrets) is gitignored — copy it up separately, e.g.:
#   scp config/app.json ubuntu@SERVER:/tmp/app.json && sudo mv /tmp/app.json "$APP_DIR/wwwroot/config/app.json"
sudo chown -R "$APP_USER:$APP_USER" "$APP_DIR"
sudo chmod 600 "$APP_DIR/wwwroot/config/app.json" 2>/dev/null || true

echo "== 3b. Fetch gitignored runtime deps (sqlite-jdbc.jar, ARM-compatible 3.46.0.0) =="
sudo -u "$APP_USER" bash "$APP_DIR/scripts/install-deps.sh"

echo "== 4. Firewall: open 80/443 in the host netfilter =="
# Oracle Ubuntu images ship restrictive iptables. (You ALSO must allow 80/443 ingress
# in the OCI console: Networking > VCN > Security List / NSG — that step is click-ops.)
sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 80  -j ACCEPT
sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 443 -j ACCEPT
sudo netfilter-persistent save || (sudo apt-get install -y iptables-persistent && sudo netfilter-persistent save)

echo "== 5. systemd service =="
sudo cp "$APP_DIR/deploy/cfobserver.service" /etc/systemd/system/cfobserver.service
sudo systemctl daemon-reload
sudo systemctl enable --now cfobserver
sleep 20
curl -fsS http://127.0.0.1:8888/ >/dev/null && echo "app responding on 127.0.0.1:8888" || echo "app not up yet — check: journalctl -u cfobserver -e"

echo "== 5b. DuckDNS dynamic-DNS updater =="
# Point your DuckDNS host at this VM and keep it current. Requires deploy/duckdns.env
# (copy from duckdns.env.example, fill in your label + token, chmod 600).
if [ -f "$APP_DIR/deploy/duckdns.env" ]; then
	sudo chmod 600 "$APP_DIR/deploy/duckdns.env"
	sudo chown "$APP_USER:$APP_USER" "$APP_DIR/deploy/duckdns.env"
	sudo -u "$APP_USER" bash "$APP_DIR/deploy/duckdns-update.sh" && echo "DuckDNS record updated to this VM's IP"
	echo "*/5 * * * * $APP_USER bash $APP_DIR/deploy/duckdns-update.sh" | sudo tee /etc/cron.d/cfobserver-duckdns >/dev/null
else
	echo "SKIP: create $APP_DIR/deploy/duckdns.env from duckdns.env.example, then re-run this section."
fi

echo "== 6. Nginx + TLS (edit cfobserver.duckdns.org -> your-host.duckdns.org in the conf first) =="
sudo cp "$APP_DIR/deploy/nginx-cfobserver.conf" /etc/nginx/sites-available/cfobserver
sudo ln -sf /etc/nginx/sites-available/cfobserver /etc/nginx/sites-enabled/cfobserver
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl reload nginx
# TLS (needs a real domain pointed at this VM's public IP):
#   sudo snap install --classic certbot && sudo ln -s /snap/bin/certbot /usr/bin/certbot
#   sudo certbot --nginx -d cfobserver.duckdns.org

echo "== 7. Nightly SQLite backup =="
sudo tee /etc/cron.d/cfobserver-backup >/dev/null <<CRON
30 3 * * * $APP_USER sqlite3 $APP_DIR/wwwroot/data/coldfusion_intel.db ".backup '$APP_DIR/backups/cfobserver-\$(date +\%Y\%m\%d).db'" && find $APP_DIR/backups -name 'cfobserver-*.db' -mtime +14 -delete
CRON
sudo -u "$APP_USER" mkdir -p "$APP_DIR/backups"

echo "== Done. Verify scheduled tasks register after first boot (they self-register on app start). =="
