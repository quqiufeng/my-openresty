#!/usr/bin/env bash
# =====================================================================
# 运行期系统依赖安装（仅需在目标机执行一次）
#   - nginx 二进制依赖: libssl3/libcrypto3, libpcre2-8, zlib, libcrypt
#   - Lua FFI 依赖:     libcrypto (加密), libgd (验证码/图像), libc (文件)
# 说明: LuaJIT 与其它 Lua 库已随 dist 打包，无需安装；这里只装系统 .so。
# =====================================================================
set -euo pipefail

SUDO=""
if [ "$(id -u)" != "0" ]; then SUDO="sudo"; fi

$SUDO apt-get update

# libssl3 / libssl3t64 名称随发行版不同（Ubuntu 24.04 为 libssl3t64）
SSL_PKG="libssl3"
if apt-cache show libssl3t64 >/dev/null 2>&1; then
    SSL_PKG="libssl3t64"
fi

$SUDO apt-get install -y \
    "$SSL_PKG" \
    libcrypt1 \
    libpcre2-8-0 \
    zlib1g \
    libgd3

echo "[OK] 运行期依赖安装完成（$SSL_PKG 等）"
