#!/usr/bin/env bash
# 停止服务
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export LD_LIBRARY_PATH="$ROOT/lib:${LD_LIBRARY_PATH:-}"
"$ROOT/bin/nginx" -p "$ROOT" -c conf/nginx.conf -s stop 2>/dev/null || true
echo "[OK] 已停止"
