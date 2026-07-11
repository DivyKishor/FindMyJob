#!/usr/bin/env bash
# Downloads runtime dependencies that are gitignored (too large for git).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LIB_DIR="$ROOT_DIR/wwwroot/lib"
SQLITE_JAR="sqlite-jdbc.jar"
SQLITE_URL="https://repo1.maven.org/maven2/org/xerial/sqlite-jdbc/3.46.0.0/sqlite-jdbc-3.46.0.0.jar"

mkdir -p "$LIB_DIR"

if [ ! -f "$LIB_DIR/$SQLITE_JAR" ]; then
  echo "Downloading SQLite JDBC driver..."
  curl -fsSL -o "$LIB_DIR/$SQLITE_JAR" "$SQLITE_URL"
  echo "Downloaded → $LIB_DIR/$SQLITE_JAR"
else
  echo "SQLite JDBC already present."
fi
