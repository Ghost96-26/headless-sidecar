#!/bin/bash
# daemon.sh — 守护进程：检测 iPad 插入 -> 连 Sidecar -> 设为唯一主屏。
# 由 LaunchAgent 在登录后拉起；也可手动运行调试。
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/common.sh"

SL="$(sidecar_bin)"
BD="$(bd_cli)"

connect_sidecar() {
  local name; name="$(detect_ipad_name)"; [ -z "$name" ] && name="iPad"
  if [ -n "$SL" ]; then
    if [ "$SIDECAR_WIRED" = "on" ]; then
      "$SL" connect "$name" -wired >>"$LOG_FILE" 2>&1 \
        || "$SL" connect "$name" >>"$LOG_FILE" 2>&1
    else
      "$SL" connect "$name" >>"$LOG_FILE" 2>&1
    fi
  else
    log "[daemon] 缺少 SidecarLauncher，无法发起连接（请运行 install.sh）"
    return 1
  fi
}

ipad_is_main() {
  [ -n "$BD" ] || return 1
  local name; name="$(detect_ipad_name)"; [ -z "$name" ] && name="iPad"
  [ "$("$BD" get --name="$name" --main 2>/dev/null)" = "true" ]
}

log "[daemon] 启动，目标 iPad=\"$(detect_ipad_name)\" 间隔=${POLL_INTERVAL}s"
trap 'log "[daemon] 退出"' EXIT

while true; do
  if ipad_plugged; then
    if ! sidecar_active; then
      log "[daemon] 检测到 iPad 已插入但未连，发起 Sidecar..."
      connect_sidecar
      sleep 4
    fi
    # 已连上但还不是主屏（含 BetterDisplay 刚启动尚未就绪）则补设
    if sidecar_active && ! ipad_is_main; then
      "$DIR/arrange.sh"
    fi
  fi
  sleep "$POLL_INTERVAL"
done
