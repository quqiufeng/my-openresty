#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export LD_LIBRARY_PATH="$ROOT/lib:${LD_LIBRARY_PATH:-}"
PIDF="$ROOT/run/nginx.pid"
if [ -f "$PIDF" ] && kill -0 "$(cat "$PIDF")" 2>/dev/null; then
    echo "[RUNNING] pid=$(cat "$PIDF")"
else
    echo "[STOPPED]"
fi
"$ROOT/bin/nginx" -p "$ROOT" -c nginx/conf/nginx.conf -t
