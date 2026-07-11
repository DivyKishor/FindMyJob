#!/usr/bin/env bash
# Refresh the DuckDNS A record to this box's current public IP. Runs from cron every
# few minutes so the hostname self-heals if Oracle ever changes the instance IP.
# Reads DUCKDNS_DOMAIN (label only, e.g. "cfobserver") and DUCKDNS_TOKEN from
# duckdns.env sitting next to this script (chmod 600, gitignored).
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$DIR/duckdns.env"

# Empty ip= tells DuckDNS to auto-detect the caller's public IP.
resp="$(curl -fsS "https://www.duckdns.org/update?domains=${DUCKDNS_DOMAIN}&token=${DUCKDNS_TOKEN}&ip=")"
mkdir -p "$DIR/../logs" 2>/dev/null || true
echo "$(date -Is) duckdns: ${resp}" >> "$DIR/../logs/duckdns.log" 2>/dev/null || true
if [ "$resp" != "OK" ]; then
	echo "DuckDNS update failed (response: '${resp}') — check DUCKDNS_DOMAIN/DUCKDNS_TOKEN in duckdns.env" >&2
	exit 1
fi
