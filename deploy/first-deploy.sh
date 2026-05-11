#!/usr/bin/env bash
###############################################################################
# First-time deploy: runs setup-server.sh on the VM, then deploys code
#
# Usage:
#   ./deploy/first-deploy.sh <server-ip> [ssh-key-path]
#
# This combines setup + deploy into a single command for initial provisioning.
###############################################################################
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 <server-ip> [ssh-key-path]"
  exit 1
fi

SERVER_IP="$1"
SSH_KEY="${2:-$HOME/.ssh/id_rsa}"
SSH_USER="ubuntu"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SSH_OPTS="-i $SSH_KEY -o StrictHostKeyChecking=accept-new"

echo "=== [Step 1/3] Uploading setup script ==="
scp $SSH_OPTS "$ROOT_DIR/deploy/setup-server.sh" "$SSH_USER@$SERVER_IP:/tmp/setup-server.sh"

echo "=== [Step 2/3] Running server setup (this takes 2-3 minutes) ==="
ssh $SSH_OPTS "$SSH_USER@$SERVER_IP" "chmod +x /tmp/setup-server.sh && sudo /tmp/setup-server.sh"

echo "=== [Step 3/3] Deploying application code ==="
"$ROOT_DIR/deploy/deploy.sh" "$SERVER_IP" "$SSH_KEY"

echo ""
echo "============================================="
echo "  First deploy complete!"
echo "  Visit: http://$SERVER_IP/"
echo "============================================="
