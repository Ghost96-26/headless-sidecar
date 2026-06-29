#!/bin/bash
# common.sh — 共享函数与自动检测逻辑（被其他脚本 source）
# 不含任何机器特定的硬编码；所有机器相关值均运行时检测或由 config.sh 覆盖。

# 项目根目录（src 的上一级）
HSROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# 载入用户配置（可选）。config.sh 由用户从 config.example.sh 复制而来。
[ -f "$HSROOT/config.sh" ] && source "$HSROOT/config.sh"

# ---- 默认值（config.sh 可覆盖）----
: "${IPAD_NAME:=}"                 # 留空则自动探测
: "${POLL_INTERVAL:=5}"            # 守护轮询间隔（秒）
: "${DISABLE_BUILTIN:=auto}"       # auto|on|off：是否脚本化断开内置屏
: "${BUILTIN_UUID:=}"              # 留空则自动探测
: "${SIDECAR_WIRED:=on}"           # on 则强制有线 Sidecar 连接
: "${LOG_FILE:=$HSROOT/logs/run.log}"

mkdir -p "$HSROOT/logs" 2>/dev/null

# ---- SidecarLauncher 二进制定位 ----
sidecar_bin() {
  if [ -n "${SIDECAR_BIN:-}" ] && [ -x "$SIDECAR_BIN" ]; then echo "$SIDECAR_BIN"; return; fi
  for p in "$HSROOT/bin/SidecarLauncher" "$(command -v SidecarLauncher 2>/dev/null)"; do
    [ -n "$p" ] && [ -x "$p" ] && { echo "$p"; return; }
  done
}

# ---- BetterDisplay CLI 定位（其 app 主程序即 CLI 入口）----
bd_cli() {
  if [ -n "${BDCLI:-}" ] && [ -x "$BDCLI" ]; then echo "$BDCLI"; return; fi
  for p \
    in "/Applications/BetterDisplay.app/Contents/MacOS/BetterDisplay" \
       "$HOME/Applications/BetterDisplay.app/Contents/MacOS/BetterDisplay" \
       "$(command -v betterdisplaycli 2>/dev/null)"; do
    [ -n "$p" ] && [ -x "$p" ] && { echo "$p"; return; }
  done
}

log() { echo "$(date '+%F %T') $*" >> "$LOG_FILE"; }

# ---- 自动探测 iPad 名称 ----
# 优先 config 的 IPAD_NAME；否则用 SidecarLauncher 列出的第一个可达设备。
detect_ipad_name() {
  if [ -n "$IPAD_NAME" ]; then echo "$IPAD_NAME"; return; fi
  local sl; sl="$(sidecar_bin)"
  [ -z "$sl" ] && return
  "$sl" devices 2>/dev/null | sed '/^$/d' | head -1
}

# ---- iPad 是否经 USB 物理连接 ----
ipad_plugged() {
  ioreg -p IOUSB -l 2>/dev/null | grep -qi 'ipad'
}

# ---- iPad 是否已是在线显示器（Sidecar 已激活）----
sidecar_active() {
  local bd; bd="$(bd_cli)"; [ -z "$bd" ] && return 1
  "$bd" get --identifiers 2>/dev/null | grep -qi '"name" : "iPad'
}

# ---- 自动探测内置屏 UUID（跨机型尽量通用）----
# 思路：解析 BetterDisplay identifiers，命中内置面板特征：
#   1) registryLocation 含内置面板路径(disp0@ / 不含 dispext)
#   2) 或 productName 为常见内置名（Color LCD / Built-in / 内建显示屏）
detect_builtin_uuid() {
  [ -n "$BUILTIN_UUID" ] && { echo "$BUILTIN_UUID"; return; }
  local bd; bd="$(bd_cli)"; [ -z "$bd" ] && return
  "$bd" get --identifiers 2>/dev/null | awk '
    function reset(){ uuid=""; pn=""; nm=""; rl="" }
    BEGIN{ reset() }
    /"UUID"/        { line=$0; gsub(/[",]/,"",line); n=split(line,a," "); uuid=a[n] }
    /"productName"/ { pn=$0 }
    /"name"/        { nm=$0 }
    /"registryLocation"/ { rl=$0 }
    /}/ {
      builtin=0
      if (rl ~ /disp0@/ && rl !~ /dispext/) builtin=1
      if (pn ~ /Color LCD/) builtin=1
      if (nm ~ /Built-?in/ || nm ~ /内建/) builtin=1
      if (builtin && uuid!="") { print uuid; exit }
      reset()
    }
  '
}
