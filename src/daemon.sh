#!/bin/bash
# daemon.sh — 守护进程：检测 iPad 插入 -> 连 Sidecar -> 设为唯一主屏。
# 由 LaunchAgent 在登录后拉起；也可手动运行调试。
#
# 健壮性：连接失败采用指数退避；连续失败到 FAIL_LIMIT 进入冷却并告警，
# 避免握手失败时每个周期硬连、刷爆日志。显式状态跟踪以减少重复动作与噪音。
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$DIR/common.sh"

SL="$(sidecar_bin)"

connect_sidecar() {
  local name; name="$(detect_ipad_name)"; [ -z "$name" ] && name="iPad"
  [ -z "$SL" ] && { log "[daemon] 缺少 SidecarLauncher，无法发起连接（请运行 install.sh）"; return 1; }
  if [ "$SIDECAR_WIRED" = "on" ]; then
    "$SL" connect "$name" -wired >>"$LOG_FILE" 2>&1 \
      || "$SL" connect "$name" >>"$LOG_FILE" 2>&1
  else
    "$SL" connect "$name" >>"$LOG_FILE" 2>&1
  fi
}

log "[daemon] 启动，目标 iPad=\"$(detect_ipad_name)\" 间隔=${POLL_INTERVAL}s 退避上限=${BACKOFF_MAX}s"
trap 'log "[daemon] 退出"' EXIT

fails=0          # 连续连接失败计数
backoff=0        # 当前额外退避秒数
arranged=0       # 是否已完成设主屏（避免重复 arrange 刷日志）
cooldown_warned=0

while true; do
  if ipad_plugged; then
    if sidecar_active; then
      fails=0; backoff=0; cooldown_warned=0
      # 已连上但还不是主屏（含 BetterDisplay 刚启动尚未就绪）则补设
      if ! sidecar_is_main; then
        "$DIR/arrange.sh"
        if [ "$arranged" -eq 0 ] && sidecar_is_main; then
          arranged=1
          notify "iPad 已设为主屏 ✅"
          log "[daemon] iPad 已成为主屏"
        fi
      else
        arranged=1
      fi
    else
      arranged=0
      in_cooldown=0; [ "$fails" -ge "$FAIL_LIMIT" ] && in_cooldown=1
      if [ "$in_cooldown" -eq 1 ]; then
        # 冷却：只告警一次，避免刷屏；但仍按 BACKOFF_MAX 间隔持续静默重试，连上即恢复
        if [ "$cooldown_warned" -eq 0 ]; then
          log "[daemon] 连接连续失败 ${fails} 次，进入冷却：之后每 ${BACKOFF_MAX}s 仍会静默重试，连上即自动恢复。请检查 iPad 解锁/同一 Apple ID/蓝牙 WiFi"
          notify "Sidecar 连接反复失败，请检查 iPad 与网络"
          cooldown_warned=1
        fi
      else
        log "[daemon] 检测到 iPad 已插入但未连，发起 Sidecar...（已失败 ${fails} 次）"
      fi
      # 无论是否冷却都真正尝试连接（修复：冷却不再放弃）
      if connect_sidecar; then
        sleep 4
        if sidecar_active; then
          [ "$in_cooldown" -eq 1 ] && { log "[daemon] 冷却中重试成功，已恢复连接"; notify "Sidecar 已恢复连接 ✅"; }
          fails=0; cooldown_warned=0
        else
          fails=$((fails+1))
        fi
      else
        fails=$((fails+1))
      fi
      # 退避：冷却固定为上限，否则指数退避 4,8,16,... 封顶 BACKOFF_MAX
      if [ "$fails" -ge "$FAIL_LIMIT" ]; then
        backoff="$BACKOFF_MAX"
      else
        backoff=$(( (1 << (fails<5?fails:5)) * 2 ))
        [ "$backoff" -gt "$BACKOFF_MAX" ] && backoff="$BACKOFF_MAX"
      fi
    fi
  else
    # iPad 拔出，重置状态
    fails=0; backoff=0; arranged=0; cooldown_warned=0
  fi

  sleep "$((POLL_INTERVAL + backoff))"
done
