#!/bin/bash
# common.sh — 共享函数与自动检测逻辑（被其他脚本 source）
# 不含任何机器特定的硬编码；所有机器相关值均运行时检测或由 config.sh 覆盖。
#
# 关键设计：对 BetterDisplay 的一切操作都以 **UUID** 为准，而不是显示器名字。
# 原因：真机上 Sidecar 屏在 BetterDisplay 里的名字是 "Sidecar Display"，
# 而 SidecarLauncher 的设备名是 "iPad"，二者不一致。按名字匹配会失败。

# 项目根目录（src 的上一级）
HSROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# 载入用户配置（可选）。config.sh 由用户从 config.example.sh 复制而来。
# shellcheck source=/dev/null
[ -f "$HSROOT/config.sh" ] && source "$HSROOT/config.sh"

# ---- 默认值（config.sh 可覆盖）----
: "${IPAD_NAME:=}"                 # 留空则自动探测
: "${POLL_INTERVAL:=5}"            # 守护轮询间隔（秒）
: "${DISABLE_BUILTIN:=auto}"       # auto|on|off：是否脚本化断开内置屏
: "${BUILTIN_UUID:=}"              # 留空则自动探测
: "${SIDECAR_WIRED:=on}"           # on 则强制有线 Sidecar 连接
: "${LOG_FILE:=$HSROOT/logs/run.log}"
: "${MAX_LOG_BYTES:=1048576}"      # 日志轮转阈值（默认 1MiB）
: "${BACKOFF_MAX:=60}"             # 连接失败退避上限（秒）
: "${FAIL_LIMIT:=5}"              # 连续失败到此值后进入冷却并告警
: "${NOTIFY:=on}"                 # on|off：连接成功/失败时弹 macOS 通知
: "${SIDECAR_SHA256:=}"           # 可选：校验 SidecarLauncher 二进制
: "${BD_SHA256:=}"                # 可选：校验 BetterDisplay dmg

mkdir -p "$HSROOT/logs" 2>/dev/null

# ---- SidecarLauncher 二进制定位 ----
sidecar_bin() {
  if [ -n "${SIDECAR_BIN:-}" ] && [ -x "$SIDECAR_BIN" ]; then echo "$SIDECAR_BIN"; return; fi
  local p
  for p in "$HSROOT/bin/SidecarLauncher" "$(command -v SidecarLauncher 2>/dev/null)"; do
    [ -n "$p" ] && [ -x "$p" ] && { echo "$p"; return; }
  done
}

# ---- BetterDisplay CLI 定位（其 app 主程序即 CLI 入口）----
bd_cli() {
  if [ -n "${BDCLI:-}" ] && [ -x "$BDCLI" ]; then echo "$BDCLI"; return; fi
  local p
  for p \
    in "/Applications/BetterDisplay.app/Contents/MacOS/BetterDisplay" \
       "$HOME/Applications/BetterDisplay.app/Contents/MacOS/BetterDisplay" \
       "$(command -v betterdisplaycli 2>/dev/null)"; do
    [ -n "$p" ] && [ -x "$p" ] && { echo "$p"; return; }
  done
}

# ---- 日志（带按大小轮转）----
rotate_log() {
  [ -f "$LOG_FILE" ] || return 0
  local sz
  sz=$(stat -f%z "$LOG_FILE" 2>/dev/null || echo 0)
  if [ "$sz" -gt "$MAX_LOG_BYTES" ] 2>/dev/null; then
    mv -f "$LOG_FILE" "$LOG_FILE.1" 2>/dev/null || true
  fi
}
log() { rotate_log; echo "$(date '+%F %T') $*" >> "$LOG_FILE"; }

# ---- macOS 桌面通知（坏屏用户看不到日志，连上后给个反馈）----
notify() {
  [ "$NOTIFY" = "on" ] || return 0
  osascript -e "display notification \"$1\" with title \"Headless Sidecar\"" >/dev/null 2>&1 || true
}

# ---- 是否有 jq（解析 BetterDisplay 输出更稳）----
have_jq() { command -v jq >/dev/null 2>&1; }

# ---- 取 BetterDisplay identifiers 原始输出 ----
_bd_identifiers() {
  local bd; bd="$(bd_cli)"; [ -z "$bd" ] && return 1
  "$bd" get --identifiers 2>/dev/null
}

# BetterDisplay 输出形如 {..},{..}，包一层 [] 即合法 JSON 数组。
_bd_json() { _bd_identifiers | { printf '['; cat; printf ']'; }; }

# ---- 自动探测 iPad 名称（用于 SidecarLauncher connect）----
# 优先 config 的 IPAD_NAME；否则用 SidecarLauncher 列出的第一个可达设备。
detect_ipad_name() {
  if [ -n "$IPAD_NAME" ]; then echo "$IPAD_NAME"; return; fi
  local sl; sl="$(sidecar_bin)"
  [ -z "$sl" ] && return
  "$sl" devices 2>/dev/null | sed '/^$/d' | head -1
}

# ---- iPad 是否经 USB 物理连接 ----
# 精确匹配 USB Product Name 含 iPad，避免误命中集线器/读卡器等描述串。
ipad_plugged() {
  ioreg -p IOUSB -l 2>/dev/null | grep -i '"USB Product Name"' | grep -qi 'ipad'
}

# ---- 探测 Sidecar 显示器 UUID（已连上才有）----
# 特征：deviceType=Display 且 name/productName 含 "Sidecar"。
detect_sidecar_uuid() {
  if have_jq; then
    _bd_json 2>/dev/null | jq -r '
      .[] | select(.deviceType=="Display")
      | select((.productName|test("Sidecar";"i")) or (.name|test("Sidecar";"i")))
      | .UUID' 2>/dev/null | head -1
    return
  fi
  # awk 兜底
  _bd_identifiers | awk '
    function reset(){ uuid=""; pn=""; nm="" }
    BEGIN{ reset() }
    /"UUID"/        { line=$0; gsub(/[",]/,"",line); n=split(line,a," "); uuid=a[n] }
    /"productName"/ { pn=$0 }
    /"name"/        { nm=$0 }
    /}/ {
      if ((pn ~ /Sidecar/ || nm ~ /Sidecar/) && uuid!="") { print uuid; exit }
      reset()
    }'
}

# ---- 自动探测内置屏 UUID（跨机型尽量通用）----
# 特征：registryLocation 含内置面板路径(disp0@ 且非 dispext)，或 productName=Color LCD。
detect_builtin_uuid() {
  [ -n "$BUILTIN_UUID" ] && { echo "$BUILTIN_UUID"; return; }
  if have_jq; then
    _bd_json 2>/dev/null | jq -r '
      .[] | select(.deviceType=="Display")
      | select(((.registryLocation|test("disp0@")) and (.registryLocation|test("dispext")|not))
               or (.productName=="Color LCD")
               or (.name|test("Built-?in|内建";"i")))
      | .UUID' 2>/dev/null | head -1
    return
  fi
  # awk 兜底
  _bd_identifiers | awk '
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
    }'
}

# ---- Sidecar 是否已激活（按 UUID 判定，而非名字）----
sidecar_active() {
  [ -n "$(detect_sidecar_uuid)" ]
}

# ---- Sidecar 屏是否已是主屏（按 UUID）----
sidecar_is_main() {
  local bd uuid; bd="$(bd_cli)"; [ -z "$bd" ] && return 1
  uuid="$(detect_sidecar_uuid)"; [ -z "$uuid" ] && return 1
  [ "$("$bd" get --uuid="$uuid" --main 2>/dev/null)" = "true" ]
}
