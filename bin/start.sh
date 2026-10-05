#!/usr/bin/env bash
# 启动 MyResty HTTP 服务（自包含）
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export LD_LIBRARY_PATH="$ROOT/lib:${LD_LIBRARY_PATH:-}"

NGINX="$ROOT/bin/nginx"
[ -x "$NGINX" ] || { echo "[ERROR] 缺少 bin/nginx，请先运行 bin/build.sh" >&2; exit 1; }

mkdir -p "$ROOT/logs/cache" "$ROOT/run" "$ROOT/uploads"
[ -f "$ROOT/nginx/conf/stream.d/forward.conf" ] || "$ROOT/bin/sync-conf.sh"
PIDF="$ROOT/run/nginx.pid"
if [ -f "$PIDF" ] && kill -0 "$(cat "$PIDF")" 2>/dev/null; then
    echo "[INFO] 已在运行 pid=$(cat "$PIDF")"; exit 0
fi

"$NGINX" -p "$ROOT" -c nginx/conf/nginx.conf -t
"$NGINX" -p "$ROOT" -c nginx/conf/nginx.conf
sleep 0.3
echo "[OK] 启动完成 pid=$(cat "$PIDF" 2>/dev/null || echo '?')  访问 http://127.0.0.1:8080/"
