#!/usr/bin/env bash
# 由 nginx/conf/forward.lua 生成 nginx/conf/stream.d/forward.conf
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

LUAJIT="${LUAJIT:-}"
if [ -z "$LUAJIT" ]; then
    if [ -x "$ROOT/bin/luajit" ]; then
        LUAJIT="$ROOT/bin/luajit"
    else
        LUAJIT="$(command -v luajit || true)"
    fi
fi
if [ -z "$LUAJIT" ]; then
    echo "[ERROR] 未找到 luajit（请先运行 bin/build.sh）" >&2
    exit 1
fi

mkdir -p "$ROOT/nginx/conf/stream.d"
"$LUAJIT" "$ROOT/bin/gen-conf.lua" "$ROOT" > "$ROOT/nginx/conf/stream.d/forward.conf"
echo "[OK] 生成 nginx/conf/stream.d/forward.conf"
