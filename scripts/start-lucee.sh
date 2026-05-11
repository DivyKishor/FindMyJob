#!/usr/bin/env bash
set -euo pipefail
# Local dev: Lucee Express + this repo's wwwroot on http://127.0.0.1:8888/
# Requires JDK 17+ (JAVA_HOME or /usr/libexec/java_home -v 17).

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RUNTIME_DIR="$ROOT_DIR/.runtime"
ZIP_URL="https://cdn.lucee.org/lucee-express-6.2.6.19.zip"
ZIP_NAME="lucee-express-6.2.6.19.zip"

mkdir -p "$RUNTIME_DIR"
cd "$RUNTIME_DIR"

if [ ! -f bin/catalina.sh ]; then
	echo "Downloading Lucee Express (first run only)..."
	curl -fsSL -o "$ZIP_NAME" "$ZIP_URL"
	unzip -q -o "$ZIP_NAME"
fi

WEBROOT="$ROOT_DIR/wwwroot"
cd "$RUNTIME_DIR/webapps"
if [ -L ROOT ]; then
	rm ROOT
elif [ -d ROOT ]; then
	rm -rf ROOT
fi
ln -sf "$WEBROOT" ROOT

if [ -z "${JAVA_HOME:-}" ]; then
	JAVA_HOME="$(/usr/libexec/java_home -v 17 2>/dev/null || true)"
	export JAVA_HOME
fi
# Non-interactive shells (CI, some IDE terminals) sometimes omit java_home from PATH; try common macOS installs.
if [ -z "${JAVA_HOME:-}" ] || [ ! -d "$JAVA_HOME" ]; then
	for _cand in \
		"/Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home" \
		"/Library/Java/JavaVirtualMachines/jdk-17.jdk/Contents/Home" \
		"/Library/Java/JavaVirtualMachines/microsoft-17.jdk/Contents/Home"; do
		if [ -d "$_cand" ]; then
			JAVA_HOME="$_cand"
			export JAVA_HOME
			break
		fi
	done
fi
if [ -z "${JAVA_HOME:-}" ] || [ ! -d "$JAVA_HOME" ]; then
	echo "Install JDK 17+ and set JAVA_HOME, or ensure /usr/libexec/java_home -v 17 works." >&2
	exit 1
fi

echo "Starting Lucee — open http://127.0.0.1:8888/index.cfm (use ?reinit=1 after code changes)"
cd "$RUNTIME_DIR"
chmod +x bin/*.sh 2>/dev/null || true
exec bin/catalina.sh run
