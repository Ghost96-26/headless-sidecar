#!/bin/bash
# arrange.sh — Sidecar 连上后，把 iPad 设为唯一主屏，并按需断开内置屏。
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/common.sh"

BD="$(bd_cli)"
if [ -z "$BD" ]; then
  log "[arrange] 未找到 BetterDisplay，无法设置主屏"
  exit 1
fi

NAME="$(detect_ipad_name)"; [ -z "$NAME" ] && NAME="iPad"

# 1) 把 iPad 设为主屏（菜单栏/Dock 落到 iPad）
"$BD" set --name="$NAME" --main=on  >>"$LOG_FILE" 2>&1 \
  || "$BD" set --namelike="iPad" --main=on >>"$LOG_FILE" 2>&1

# 2) 断开坏掉的内置屏（可选）。
#    推荐优先用 BetterDisplay 设置里的开关：
#    "Auto-disconnect built-in screen upon connecting an external display"
#    （Apple Silicon）。脚本断开作为补充/Intel 兜底。
if [ "$DISABLE_BUILTIN" != "off" ]; then
  UUID="$(detect_builtin_uuid)"
  if [ -n "$UUID" ]; then
    "$BD" set --uuid="$UUID" --connected=off >>"$LOG_FILE" 2>&1 \
      && log "[arrange] 已断开内置屏 ($UUID)" \
      || log "[arrange] 断开内置屏失败 ($UUID)，可在 BetterDisplay 设置里改用自动断开开关"
  else
    log "[arrange] 未能自动识别内置屏 UUID，跳过（建议用 BetterDisplay 自动断开开关）"
  fi
fi

log "[arrange] iPad=\"$NAME\" 已设为主屏"
