#!/usr/bin/env bash
# 安装 logrotate 配置（按当前项目根路径生成）
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="/etc/logrotate.d/myresty"
SUDO=""
[ "$(id -u)" != "0" ] && SUDO="sudo"

$SUDO tee "$TARGET" >/dev/null <<EOF
# 由 my-openresty/bin/install-logrotate.sh 生成
$ROOT/logs/*.log {
    daily
    rotate 7
    missingok
    notifempty
    compress
    delaycompress
    copytruncate
}
EOF

echo "[OK] 已安装 $TARGET"
echo "    （copytruncate 原地截断，无需向 nginx 发信号）"
