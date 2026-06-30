#!/bin/bash
# Sidecar 连上后把 iPad 设为唯一主屏，并按需断开内置屏。全程按 UUID 操作。
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$DIR/common.sh"

BD="$(bd_cli)"
if [ -z "$BD" ]; then
  log "[arrange] 未找到 BetterDisplay，无法设置主屏"
  exit 1
fi

SIDECAR_UUID="$(detect_sidecar_uuid)"
if [ -z "$SIDECAR_UUID" ]; then
  log "[arrange] 未检测到已连接的 Sidecar 显示器，跳过设主屏"
  exit 1
fi

# 设 Sidecar 屏为主屏，菜单栏/Dock 落到 iPad
if "$BD" set --uuid="$SIDECAR_UUID" --main=on >>"$LOG_FILE" 2>&1; then
  log "[arrange] 已将 Sidecar 屏设为主屏 ($SIDECAR_UUID)"
else
  log "[arrange] 设置主屏失败 ($SIDECAR_UUID)"
fi

# 断开内置屏（可选）。Apple Silicon 上也可改用 BetterDisplay 的
# "Auto-disconnect built-in screen upon connecting an external display" 开关。
if [ "$DISABLE_BUILTIN" != "off" ]; then
  UUID="$(detect_builtin_uuid)"
  if [ -n "$UUID" ]; then
    if "$BD" set --uuid="$UUID" --connected=off >>"$LOG_FILE" 2>&1; then
      log "[arrange] 已断开内置屏 ($UUID)"
    else
      log "[arrange] 断开内置屏失败 ($UUID)，可在 BetterDisplay 设置里改用自动断开开关"
    fi
  else
    log "[arrange] 未能自动识别内置屏 UUID，跳过（建议用 BetterDisplay 自动断开开关）"
  fi
fi
