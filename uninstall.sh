#!/bin/bash
# 卸载开机自启与本地文件，不卸载 BetterDisplay.app
set -uo pipefail
HSROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PLIST="$HOME/Library/LaunchAgents/com.headless-sidecar.daemon.plist"
LABEL="com.headless-sidecar.daemon"
echo "==> 停止并移除开机自启..."
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl unload "$PLIST" 2>/dev/null || true
rm -f "$PLIST"

echo "==> 停止仍在运行的守护进程..."
pkill -f "headless-sidecar/src/daemon.sh" 2>/dev/null || true

echo "==> 恢复内置屏连接（若曾被断开）..."
BD="/Applications/BetterDisplay.app/Contents/MacOS/BetterDisplay"
if [ -x "$BD" ]; then
  source "$HSROOT/src/common.sh" 2>/dev/null || true
  U="$(detect_builtin_uuid 2>/dev/null || true)"
  [ -n "${U:-}" ] && "$BD" set --uuid="$U" --connected=on 2>/dev/null || true
fi

echo "==> 清理日志..."
rm -f "$HSROOT/logs/"*.log 2>/dev/null || true

echo "完成。BetterDisplay.app 与 bin/SidecarLauncher 未删除，如需可手动移除。"
echo "若内置屏仍异常，重启一次即可恢复默认显示配置。"
