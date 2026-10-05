#!/usr/bin/env bash
# 重载配置（先按需重新生成 stream 转发配置）
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export LD_LIBRARY_PATH="$ROOT/lib:${LD_LIBRARY_PATH:-}"
"$ROOT/bin/sync-conf.sh"
"$ROOT/bin/nginx" -p "$ROOT" -c nginx/conf/nginx.conf -s reload
echo "[OK] 已重载"
