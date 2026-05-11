#!/usr/bin/env bash
###############################################################################
# Deploy Job Finder to Oracle Cloud instance
#
# Usage:
#   ./deploy/deploy.sh <server-ip> [ssh-key-path]
#
# Examples:
#   ./deploy/deploy.sh 129.154.xx.xx
#   ./deploy/deploy.sh 129.154.xx.xx ~/.ssh/oracle_key
#
# What it does:
#   1. rsync's wwwroot/ to /opt/jobfinder/wwwroot/ on the server
#   2. Fixes file ownership
#   3. Restarts the app (triggers Application.cfc reinit)
###############################################################################
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 <server-ip> [ssh-key-path]"
  echo "  server-ip    : Your Oracle Cloud instance public IP"
  echo "  ssh-key-path : Path to SSH private key (default: ~/.ssh/id_rsa)"
  exit 1
fi

SERVER_IP="$1"
SSH_KEY="${2:-$HOME/.ssh/id_rsa}"
SSH_USER="ubuntu"
REMOTE_DIR="/opt/jobfinder"

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WWWROOT="$ROOT_DIR/wwwroot"

if [ ! -d "$WWWROOT" ]; then
  echo "ERROR: wwwroot directory not found at $WWWROOT" >&2
  exit 1
fi

SSH_OPTS="-i $SSH_KEY -o StrictHostKeyChecking=accept-new"

echo "=== Uploading wwwroot to $SERVER_IP ==="
rsync -avz --progress \
  --exclude '.DS_Store' \
  --exclude '*.log' \
  --exclude 'data/*.db' \
  --exclude 'data/*.db-journal' \
  -e "ssh $SSH_OPTS" \
  "$WWWROOT/" \
  "$SSH_USER@$SERVER_IP:$REMOTE_DIR/wwwroot/"

echo ""
echo "=== Fixing ownership & restarting ==="
ssh $SSH_OPTS "$SSH_USER@$SERVER_IP" <<REMOTE
  sudo chown -R jobfinder:jobfinder $REMOTE_DIR
  sudo systemctl restart jobfinder
  echo "Waiting 8s for Lucee to start..."
  sleep 8
  curl -sf http://127.0.0.1:8888/index.cfm?reinit=1 > /dev/null 2>&1 && echo "App reinit OK" || echo "App reinit pending (may need more startup time)"
REMOTE

echo ""
echo "=== Deploy complete! ==="
echo "Visit: http://$SERVER_IP/"
