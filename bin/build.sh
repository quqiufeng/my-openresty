#!/usr/bin/env bash
# =====================================================================
# MyResty HTTP 后端「自包含」构建脚本
#   1) 编译 LuaJIT（与框架一起打包）
#   2) 复制 OpenResty 的 nginx 二进制（把 OpenResty 当编译期依赖）
#   3) 汇集 Lua 库(.lua) 与 .so 到 lib/
#   4) 组装可部署目录 dist/ = bin + lib + nginx/conf + app + config + .env
#
# 运行：bin/start.sh （内部 nginx -p <root> -c nginx/conf/nginx.conf）
# 部署：拷贝 dist/ 到目标机 -> dist/bin/start.sh
#
# 环境变量可覆盖：OPENRESTY_HOME / NGINX_BIN / OPENRESTY_SRC / LUAJIT_SRC / LUALIB / JOBS
# 跳过 LuaJIT 编译：SKIP_LUAJIT=1
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

mkdir -p "$ROOT/bin" "$ROOT/lib" "$ROOT/logs/cache" "$ROOT/run"

# ---------- 1) 编译 LuaJIT ----------
if [ "${SKIP_LUAJIT:-0}" != "1" ]; then
    if [ -f "$LUAJIT_SRC/Makefile" ]; then
        echo "==> [1/5] 编译 LuaJIT ..."
        if ! make -C "$LUAJIT_SRC" -j"$JOBS" > /tmp/myresty-luajit-build.log 2>&1; then
            echo "[ERROR] LuaJIT 编译失败:" >&2; tail -n 30 /tmp/myresty-luajit-build.log >&2; exit 1
        fi
        install -m 0755 "$LUAJIT_SRC/src/luajit" "$ROOT/bin/luajit"
        cp -f "$LUAJIT_SRC/src/libluajit.so" "$ROOT/lib/libluajit-5.1.so.2"
        ln -sf libluajit-5.1.so.2 "$ROOT/lib/libluajit-5.1.so"
    else
        echo "[WARN] 未找到 LuaJIT 源码 ($LUAJIT_SRC)，跳过编译" >&2
    fi
else
    echo "==> [1/5] 跳过 LuaJIT 编译 (SKIP_LUAJIT=1)"
    [ -x /usr/local/bin/luajit ] && install -m 0755 /usr/local/bin/luajit "$ROOT/bin/luajit"
    [ -e /usr/local/luajit/lib/libluajit-5.1.so.2 ] && cp -fL /usr/local/luajit/lib/libluajit-5.1.so.2 "$ROOT/lib/libluajit-5.1.so.2"
fi

# ---------- 2) 复制 nginx 二进制 ----------
echo "==> [2/5] 复制 nginx 二进制 ..."
[ -f "$NGINX_BIN" ] || { echo "[ERROR] 找不到 nginx: $NGINX_BIN" >&2; exit 1; }
install -m 0755 "$NGINX_BIN" "$ROOT/bin/nginx"
echo "    -> bin/nginx"

# ---------- 3) 复制 Lua 库 + .so + mime.types ----------
echo "==> [3/5] 汇集 Lua 库到 lib/ ..."
for d in resty ngx rds redis; do
    [ -d "$LUALIB/$d" ] && cp -rf "$LUALIB/$d" "$ROOT/lib/" && echo "    -> lib/$d/"
done
for f in "$LUALIB"/*.lua "$LUALIB"/*.so; do
    [ -e "$f" ] && cp -f "$f" "$ROOT/lib/" && echo "    -> lib/$(basename "$f")"
done
[ -f "$ROOT/nginx/conf/mime.types" ] || cp -f "$OPENRESTY_HOME/conf/mime.types" "$ROOT/nginx/conf/mime.types"

# ---------- 4) 语法自检 ----------
echo "==> [4/5] nginx 配置自检 ..."
LD_LIBRARY_PATH="$ROOT/lib:${LD_LIBRARY_PATH:-}" "$ROOT/bin/nginx" -p "$ROOT" -c nginx/conf/nginx.conf -t

# ---------- 5) 组装 dist/ ----------
echo "==> [5/5] 组装 dist/ ..."
rm -rf "$ROOT/dist"
mkdir -p "$ROOT/dist"
cp -r "$ROOT/bin" "$ROOT/lib" "$ROOT/nginx" "$ROOT/app" "$ROOT/middleware" \
      "$ROOT/config" "$ROOT/bootstrap.lua" "$ROOT/init.lua" "$ROOT/init_worker.lua" \
      "$ROOT/.env" "$ROOT/dist/"
[ -f "$ROOT/.env.example" ] && cp -f "$ROOT/.env.example" "$ROOT/dist/.env.example"
mkdir -p "$ROOT/dist/logs/cache" "$ROOT/dist/run" "$ROOT/dist/uploads" "$ROOT/dist/static"

echo
echo "[OK] 构建完成"
echo "     本地运行: $ROOT/bin/start.sh"
echo "     部署方式: 拷贝 dist/ 到目标机 -> dist/bin/start.sh"
echo "     目标机系统库: libssl3 libcrypto3 libpcre2-8 zlib libcrypt (及 FFI 需要的 libgd)"
