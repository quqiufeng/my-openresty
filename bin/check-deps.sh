#!/usr/bin/env bash
# 检查运行期系统依赖是否齐全（缺失会打印 not found / MISS）
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0

echo "== 自带运行库 =="
for f in lib/libluajit-5.1.so.2; do
    if [ -e "$ROOT/$f" ]; then echo "  [OK] $f"; else echo "  [MISS] $f (请先 bin/build.sh)"; fail=1; fi
done

echo "== bin/nginx 动态依赖 =="
if [ -x "$ROOT/bin/nginx" ]; then
    nginx_ldd="$(LD_LIBRARY_PATH="$ROOT/lib:${LD_LIBRARY_PATH:-}" ldd "$ROOT/bin/nginx" 2>&1)"
    printf '%s\n' "$nginx_ldd" | grep -E "luajit|ssl|crypto|pcre|libz|crypt|libc\.so" || true
    if printf '%s\n' "$nginx_ldd" | grep -q "not found"; then fail=1; fi
else
    echo "  (缺少 bin/nginx，请先 bin/build.sh)"; fail=1
fi

echo "== Lua FFI 依赖 (dlopen) =="
ldcache="$(ldconfig -p 2>/dev/null)"
for lib in libcrypto.so.3 libgd.so.3 libc.so.6; do
    case "$ldcache" in
        *"$lib"*) echo "  [OK] $lib" ;;
        *) echo "  [MISS] $lib"; fail=1 ;;
    esac
done

if [ "$fail" = "0" ]; then
    echo "[OK] 依赖齐全"
else
    echo "[FAIL] 存在缺失依赖，请运行: bin/install-deps.sh"
    exit 1
fi
