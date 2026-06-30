#!/bin/bash
# 共享函数与自动检测逻辑，被其他脚本 source。无机器特定硬编码，
# 机器相关值一律运行时检测或由 config.sh 覆盖。
# 对 BetterDisplay 的操作统一按 UUID 进行：Sidecar 屏在 BetterDisplay 里
# 名为 "Sidecar Display"，而 SidecarLauncher 的设备名是 "iPad"，按名字会匹配不上。

HSROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck source=/dev/null
[ -f "$HSROOT/config.sh" ] && source "$HSROOT/config.sh"

# 默认值，可被 config.sh 覆盖
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

# 定位 SidecarLauncher 二进制
sidecar_bin() {
  if [ -n "${SIDECAR_BIN:-}" ] && [ -x "$SIDECAR_BIN" ]; then echo "$SIDECAR_BIN"; return; fi
  local p
  for p in "$HSROOT/bin/SidecarLauncher" "$(command -v SidecarLauncher 2>/dev/null)"; do
    [ -n "$p" ] && [ -x "$p" ] && { echo "$p"; return; }
  done
}

# 定位 BetterDisplay CLI（其 app 主程序即 CLI 入口）
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

# 日志，超过 MAX_LOG_BYTES 时轮转
rotate_log() {
  [ -f "$LOG_FILE" ] || return 0
  local sz
  sz=$(stat -f%z "$LOG_FILE" 2>/dev/null || echo 0)
  if [ "$sz" -gt "$MAX_LOG_BYTES" ] 2>/dev/null; then
    mv -f "$LOG_FILE" "$LOG_FILE.1" 2>/dev/null || true
  fi
}
log() { rotate_log; echo "$(date '+%F %T') $*" >> "$LOG_FILE"; }

# macOS 桌面通知（坏屏时看不到日志，靠它反馈）
notify() {
  [ "$NOTIFY" = "on" ] || return 0
  osascript -e "display notification \"$1\" with title \"Headless Sidecar\"" >/dev/null 2>&1 || true
}

have_jq() { command -v jq >/dev/null 2>&1; }

_bd_identifiers() {
  local bd; bd="$(bd_cli)"; [ -z "$bd" ] && return 1
  "$bd" get --identifiers 2>/dev/null
}

# BetterDisplay 输出形如 {..},{..}，包一层 [] 即合法 JSON 数组
_bd_json() { _bd_identifiers | { printf '['; cat; printf ']'; }; }

# 可达 Sidecar 设备数量，用于多设备保护
ipad_device_count() {
  local sl; sl="$(sidecar_bin)"; [ -z "$sl" ] && { echo 0; return; }
  "$sl" devices 2>/dev/null | sed '/^$/d' | grep -c .
}

# 探测 iPad 名称（用于 connect）。优先 IPAD_NAME，否则取第一台可达设备。
# 多台设备时仍返回第一台，调用方应先用 ipad_device_count 提示设置 IPAD_NAME。
detect_ipad_name() {
  if [ -n "$IPAD_NAME" ]; then echo "$IPAD_NAME"; return; fi
  local sl; sl="$(sidecar_bin)"
  [ -z "$sl" ] && return
  "$sl" devices 2>/dev/null | sed '/^$/d' | head -1
}

# iPad 是否经 USB 连接。精确匹配 USB Product Name，避免命中集线器等描述。
ipad_plugged() {
  ioreg -p IOUSB -l 2>/dev/null | grep -i '"USB Product Name"' | grep -qi 'ipad'
}

# parse_* 从 stdin 读 `BetterDisplay get --identifiers` 文本并输出 UUID，
# 与数据源解耦以便用 fixture 单测（见 tests/）。detect_* 是它们的封装。

# Sidecar 屏 UUID：deviceType=Display 且 name/productName 含 Sidecar
parse_sidecar_uuid() {
  if have_jq; then
    { printf '['; cat; printf ']'; } | jq -r '
      .[] | select(.deviceType=="Display")
      | select((.productName|test("Sidecar";"i")) or (.name|test("Sidecar";"i")))
      | .UUID' 2>/dev/null | head -1
    return
  fi
  awk '
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

# 内置屏 UUID：registryLocation 含 disp0@ 且非 dispext，或 productName=Color LCD，
# 或 name 含 Built-in/内建
parse_builtin_uuid() {
  if have_jq; then
    { printf '['; cat; printf ']'; } | jq -r '
      .[] | select(.deviceType=="Display")
      | select(((.registryLocation|test("disp0@")) and (.registryLocation|test("dispext")|not))
               or (.productName=="Color LCD")
               or (.name|test("Built-?in|内建";"i")))
      | .UUID' 2>/dev/null | head -1
    return
  fi
  awk '
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

detect_sidecar_uuid() { _bd_identifiers | parse_sidecar_uuid; }

detect_builtin_uuid() {
  [ -n "$BUILTIN_UUID" ] && { echo "$BUILTIN_UUID"; return; }
  _bd_identifiers | parse_builtin_uuid
}

# Sidecar 是否已连接（按 UUID 判定）
sidecar_active() {
  [ -n "$(detect_sidecar_uuid)" ]
}

# Sidecar 屏是否已是主屏
sidecar_is_main() {
  local bd uuid; bd="$(bd_cli)"; [ -z "$bd" ] && return 1
  uuid="$(detect_sidecar_uuid)"; [ -z "$uuid" ] && return 1
  [ "$("$bd" get --uuid="$uuid" --main 2>/dev/null)" = "true" ]
}
