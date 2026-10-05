#!/usr/bin/env bash
# =====================================================================
# MyResty TCP/UDP 框架构建脚本
#   1) 编译 LuaJIT（与框架一起打包）
#   2) 汇集 OpenResty 的 nginx 二进制（把 OpenResty 当依赖）
#   3) 复制 Lua 库(.lua) 与 .so 到 lib/
#   4) 由 conf/forward.lua 生成 stream 转发配置
#   5) 组装可部署目录 dist/ = bin + lib + conf + lua
#
# 可用环境变量覆盖：
#   OPENRESTY_HOME  (默认 /usr/local/nginx)
#   NGINX_BIN       (默认 $OPENRESTY_HOME/sbin/nginx)
#   OPENRESTY_SRC   (默认 /opt/openresty-1.31.1.1)
#   LUAJIT_SRC      (默认 $OPENRESTY_SRC/bundle/LuaJIT-2.1-20260415)
#   LUALIB          (默认 /usr/local/lualib)
#   JOBS            (默认 nproc)
#   SKIP_LUAJIT=1   跳过编译，改为复制系统 luajit
# =====================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OPENRESTY_HOME="${OPENRESTY_HOME:-/usr/local/nginx}"
NGINX_BIN="${NGINX_BIN:-$OPENRESTY_HOME/sbin/nginx}"
OPENRESTY_SRC="${OPENRESTY_SRC:-/opt/openresty-1.31.1.1}"
LUAJIT_SRC="${LUAJIT_SRC:-$OPENRESTY_SRC/bundle/LuaJIT-2.1-20260415}"
LUALIB="${LUALIB:-/usr/local/lualib}"
JOBS="${JOBS:-$(nproc)}"

echo "==> ROOT        : $ROOT"
echo "==> nginx       : $NGINX_BIN"
echo "==> LuaJIT 源码 : $LUAJIT_SRC"
echo "==> Lua 库      : $LUALIB"
echo

mkdir -p "$ROOT/bin" "$ROOT/lib" "$ROOT/conf/stream.d" "$ROOT/logs" "$ROOT/run"

# ---------- 1) 编译 LuaJIT ----------
if [ "${SKIP_LUAJIT:-0}" != "1" ]; then
    if [ ! -f "$LUAJIT_SRC/Makefile" ]; then
        echo "[ERROR] 找不到 LuaJIT 源码: $LUAJIT_SRC" >&2
        echo "        用 LUAJIT_SRC=/path 指定，或 SKIP_LUAJIT=1 用系统 luajit" >&2
        exit 1
    fi
    echo "==> [1/5] 编译 LuaJIT ..."
    if ! make -C "$LUAJIT_SRC" -j"$JOBS" > /tmp/tcpudp-luajit-build.log 2>&1; then
        echo "[ERROR] LuaJIT 编译失败，末尾日志:" >&2
        tail -n 30 /tmp/tcpudp-luajit-build.log >&2
        exit 1
    fi
    install -m 0755 "$LUAJIT_SRC/src/luajit" "$ROOT/bin/luajit"
    cp -f "$LUAJIT_SRC/src/libluajit.so" "$ROOT/lib/libluajit-5.1.so.2"
    ln -sf libluajit-5.1.so.2 "$ROOT/lib/libluajit-5.1.so"
    echo "    -> bin/luajit, lib/libluajit-5.1.so.2"
else
    echo "==> [1/5] 跳过 LuaJIT 编译 (SKIP_LUAJIT=1)"
    [ -x /usr/local/bin/luajit ] && install -m 0755 /usr/local/bin/luajit "$ROOT/bin/luajit"
    if [ -e /usr/local/luajit/lib/libluajit-5.1.so.2 ]; then
        cp -fL /usr/local/luajit/lib/libluajit-5.1.so.2 "$ROOT/lib/libluajit-5.1.so.2"
        ln -sf libluajit-5.1.so.2 "$ROOT/lib/libluajit-5.1.so"
    fi
fi

# ---------- 2) 复制 nginx 二进制 ----------
echo "==> [2/5] 复制 nginx 二进制 ..."
[ -f "$NGINX_BIN" ] || { echo "[ERROR] 找不到 nginx: $NGINX_BIN" >&2; exit 1; }
install -m 0755 "$NGINX_BIN" "$ROOT/bin/nginx"
echo "    -> bin/nginx"

# ---------- 3) 复制 Lua 库(.lua) 与 .so ----------
echo "==> [3/5] 汇集 Lua 库到 lib/ ..."
for d in resty ngx rds redis; do
    if [ -d "$LUALIB/$d" ]; then
        cp -rf "$LUALIB/$d" "$ROOT/lib/"
        echo "    -> lib/$d/"
    fi
done
for f in "$LUALIB"/*.lua "$LUALIB"/*.so; do
    if [ -e "$f" ]; then
        cp -f "$f" "$ROOT/lib/"
        echo "    -> lib/$(basename "$f")"
    fi
done

# ---------- 4) 生成 stream 转发配置 ----------
echo "==> [4/5] 生成 conf/stream.d/forward.conf ..."
"$ROOT/bin/sync-conf.sh"

# ---------- 5) 组装部署包 dist/ ----------
echo "==> [5/5] 组装 dist/ ..."
rm -rf "$ROOT/dist"
mkdir -p "$ROOT/dist"
cp -r "$ROOT/bin" "$ROOT/lib" "$ROOT/conf" "$ROOT/lua" "$ROOT/dist/"
mkdir -p "$ROOT/dist/logs" "$ROOT/dist/run"

echo
echo "[OK] 构建完成"
echo "     本地运行: $ROOT/bin/start.sh"
echo "     部署方式: 拷贝 dist/ 到目标机 -> dist/bin/start.sh"
echo "               (需目标机具备 libssl3/libcrypto3/libpcre2/zlib 等系统库)"
