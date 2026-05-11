#!/usr/bin/env bash
###############################################################################
# Oracle Cloud "Always Free" Ubuntu ARM — one-shot server setup
#
# Usage (run as root on your fresh VM):
#   chmod +x setup-server.sh && sudo ./setup-server.sh
#
# What it does:
#   1. Installs JDK 17, unzip, SQLite, nginx, certbot
#   2. Installs CommandBox (official APT repo)
#   3. Creates a dedicated 'jobfinder' system user
#   4. Prepares /opt/jobfinder for deployment
#   5. Installs nginx reverse-proxy config (port 80 → 8888)
#   6. Installs systemd service for auto-start
#   7. Opens firewall ports 80/443 (iptables — Oracle Cloud Linux firewall)
#   8. Sets up a daily cron for the scraping pipeline
###############################################################################
set -euo pipefail

APP_USER="jobfinder"
APP_DIR="/opt/jobfinder"
APP_PORT="8888"

echo "=== [1/8] System packages ==="
apt-get update -qq
apt-get install -y -qq \
  openjdk-17-jdk-headless \
  unzip curl wget gnupg2 sqlite3 \
  nginx certbot python3-certbot-nginx \
  cron

echo "=== [2/8] CommandBox ==="
if ! command -v box &>/dev/null; then
  curl -fsSl https://downloads.ortussolutions.com/debs/gpg | gpg --dearmor -o /usr/share/keyrings/ortussolutions.gpg
  echo "deb [signed-by=/usr/share/keyrings/ortussolutions.gpg] https://downloads.ortussolutions.com/debs/noarch /" \
    > /etc/apt/sources.list.d/commandbox.list
  apt-get update -qq
  apt-get install -y -qq commandbox
fi
box version

echo "=== [3/8] Application user & directory ==="
if ! id "$APP_USER" &>/dev/null; then
  useradd -r -m -d "$APP_DIR" -s /usr/sbin/nologin "$APP_USER"
fi
mkdir -p "$APP_DIR/wwwroot" "$APP_DIR/wwwroot/data" "$APP_DIR/wwwroot/logs" "$APP_DIR/wwwroot/lib"

SQLITE_JAR="$APP_DIR/wwwroot/lib/sqlite-jdbc.jar"
if [ ! -f "$SQLITE_JAR" ]; then
  echo "Downloading SQLite JDBC driver..."
  curl -fsSL -o "$SQLITE_JAR" "https://repo1.maven.org/maven2/org/xerial/sqlite-jdbc/3.47.3.0/sqlite-jdbc-3.47.3.0.jar"
fi

chown -R "$APP_USER:$APP_USER" "$APP_DIR"

echo "=== [4/8] server.json (CommandBox config) ==="
if [ ! -f "$APP_DIR/server.json" ]; then
  cat > "$APP_DIR/server.json" <<'SERVERJSON'
{
  "name": "jobfinder",
  "app": {
    "cfengine": "lucee@6",
    "webroot": "wwwroot"
  },
  "web": {
    "host": "127.0.0.1",
    "http": {
      "port": 8888,
      "enable": true
    },
    "ajp": { "enable": false }
  },
  "jvm": {
    "heapSize": "256",
    "minHeapSize": "128",
    "args": "--add-opens=java.base/java.lang=ALL-UNNAMED --add-opens=java.base/java.io=ALL-UNNAMED --add-opens=java.base/java.util=ALL-UNNAMED"
  }
}
SERVERJSON
  chown "$APP_USER:$APP_USER" "$APP_DIR/server.json"
fi

echo "=== [5/8] nginx reverse proxy ==="
cat > /etc/nginx/sites-available/jobfinder <<NGINX
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    # Replace with your domain once DNS points here, then run:
    #   sudo certbot --nginx -d your-domain.com
    # server_name your-domain.com;

    client_max_body_size 5M;

    location / {
        proxy_pass         http://127.0.0.1:${APP_PORT};
        proxy_set_header   Host              \$host;
        proxy_set_header   X-Real-IP         \$remote_addr;
        proxy_set_header   X-Forwarded-For   \$proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto \$scheme;
        proxy_read_timeout 120s;
    }

    # Block direct access to sensitive paths
    location ~* ^/(services|sql|config|lib|data|logs)/ {
        deny all;
        return 404;
    }
}
NGINX
rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/jobfinder /etc/nginx/sites-enabled/jobfinder
nginx -t
systemctl enable nginx
systemctl restart nginx

echo "=== [6/8] systemd service ==="
cat > /etc/systemd/system/jobfinder.service <<SERVICE
[Unit]
Description=ColdFusion Job Finder (Lucee via CommandBox)
After=network.target

[Service]
Type=forking
User=${APP_USER}
Group=${APP_USER}
WorkingDirectory=${APP_DIR}
Environment="HOME=${APP_DIR}"
ExecStart=/usr/bin/box server start
ExecStop=/usr/bin/box server stop
Restart=on-failure
RestartSec=10
TimeoutStartSec=120

[Install]
WantedBy=multi-user.target
SERVICE
systemctl daemon-reload
systemctl enable jobfinder.service

echo "=== [7/8] Firewall (iptables — Oracle Cloud Ubuntu) ==="
if iptables -L INPUT -n 2>/dev/null | grep -q "DROP"; then
  iptables -I INPUT 6 -m state --state NEW -p tcp --dport 80  -j ACCEPT 2>/dev/null || true
  iptables -I INPUT 6 -m state --state NEW -p tcp --dport 443 -j ACCEPT 2>/dev/null || true
  netfilter-persistent save 2>/dev/null || iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
fi

echo "=== [8/8] Daily scrape cron ==="
CRON_CMD="curl -sf http://127.0.0.1:${APP_PORT}/tasks/runDailyScrape.cfm > /dev/null 2>&1"
( crontab -u "$APP_USER" -l 2>/dev/null | grep -v runDailyScrape; echo "0 6,18 * * * $CRON_CMD" ) | crontab -u "$APP_USER" -

echo ""
echo "============================================="
echo "  Setup complete!"
echo "============================================="
echo ""
echo "Next steps:"
echo "  1. From your laptop, deploy code:"
echo "     ./deploy/deploy.sh YOUR_SERVER_IP ~/.ssh/your-oracle-key"
echo ""
echo "  2. Or use first-deploy.sh to do setup + deploy in one go:"
echo "     ./deploy/first-deploy.sh YOUR_SERVER_IP ~/.ssh/your-oracle-key"
echo ""
echo "  3. Visit:  http://YOUR_SERVER_IP/"
echo ""
echo "  4. (Optional) Add SSL:"
echo "     sudo certbot --nginx -d your-domain.com"
echo ""
echo "  Daily scraping runs at 6:00 AM & 6:00 PM UTC via cron."
echo "============================================="
