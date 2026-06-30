#!/bin/bash
# doctor.sh — 自检：环境、硬件、依赖、权限、连通性。只读，不改系统。
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$DIR/common.sh"

GREEN='\033[0;32m'; YEL='\033[0;33m'; RED='\033[0;31m'; DIM='\033[2m'; NC='\033[0m'
ok(){ printf "  ${GREEN}✓${NC} %s\n" "$1"; }
warn(){ printf "  ${YEL}!${NC} %s\n" "$1"; }
bad(){ printf "  ${RED}✗${NC} %s\n" "$1"; }
info(){ printf "  ${DIM}·${NC} %s\n" "$1"; }

echo "==================================================="
echo " Headless Sidecar — 自检 (doctor)"
echo "==================================================="

# ---- 1. 操作系统 ----
echo; echo "[1] macOS 版本"
OSV="$(sw_vers -productVersion 2>/dev/null)"
OSMAJ="${OSV%%.*}"
if [ -n "$OSV" ]; then
  if [ "$OSMAJ" -ge 11 ] 2>/dev/null || [ "$OSV" = "10.15" ] || [[ "$OSV" == 10.1[5-9]* ]]; then
    ok "macOS $OSV（满足 Sidecar 要求：10.15+）"
  else
    bad "macOS $OSV 过低，Sidecar 需要 10.15 Catalina 及以上"
  fi
else
  bad "无法读取 macOS 版本"
fi

# ---- 2. 芯片架构 ----
echo; echo "[2] 芯片 / 机型"
ARCH="$(uname -m)"
MODEL="$(sysctl -n hw.model 2>/dev/null)"
CHIP="$(sysctl -n machdep.cpu.brand_string 2>/dev/null)"
if [ "$ARCH" = "arm64" ]; then
  ok "Apple Silicon ($CHIP) — 支持 BetterDisplay 自动断开内置屏"
else
  warn "Intel 芯片 ($CHIP) — 可用，但‘自动断开内置屏’行为不同，建议用脚本断开或外接诱骗"
fi
info "机型: ${MODEL:-未知}"

# Sidecar 受支持机型提示（不阻断，仅提示）
case "$MODEL" in
  MacBookPro1[5-9]*|MacBookPro2*|MacBookAir9*|MacBookAir1*|Macmini[89]*|Macmini2*|iMac19*|iMac2*|iMacPro1*|MacPro7*|Mac1[3-9]*|Mac2*)
    ok "机型大致在 Sidecar 支持范围内" ;;
  *)
    warn "未能确认机型是否支持 Sidecar，请对照苹果官方支持列表" ;;
esac

# ---- 3. 依赖：SidecarLauncher（本地从 vendored 源码编译）----
echo; echo "[3] 依赖 — SidecarLauncher"
if command -v swiftc >/dev/null 2>&1; then
  ok "swiftc 可用（可从源码本地编译，无需下载二进制）"
else
  warn "未找到 swiftc。首次安装需 Xcode 命令行工具： xcode-select --install"
fi
SL="$(sidecar_bin)"
if [ -n "$SL" ]; then
  ok "已安装（本地编译产物）: $SL"
  if "$SL" devices >/dev/null 2>&1; then
    DEVS="$("$SL" devices 2>/dev/null | sed '/^$/d')"
    if [ -n "$DEVS" ]; then
      ok "可达 Sidecar 设备:"; echo "$DEVS" | while read -r d; do info "→ $d"; done
      if [ -z "$IPAD_NAME" ] && [ "$(ipad_device_count)" -gt 1 ] 2>/dev/null; then
        warn "发现多台设备但未设 IPAD_NAME，守护进程会盲选第一台，可能连错。请在 config.sh 设置 IPAD_NAME"
      fi
    else
      warn "未发现可达 iPad。请确认：iPad 已解锁、与 Mac 同一 Apple ID、蓝牙/WiFi 开启、或已用 USB-C 连接"
    fi
  else
    warn "SidecarLauncher 无法运行（可能因 macOS 更新导致私有 API 失效）"
  fi
else
  bad "未编译 SidecarLauncher，请运行 ./install.sh（会从 vendor/ 源码本地编译）"
fi

# ---- 4. 依赖：BetterDisplay ----
echo; echo "[4] 依赖 — BetterDisplay"
BD="$(bd_cli)"
if [ -n "$BD" ]; then
  ok "已安装: $BD"
  if "$BD" get --identifiers >/dev/null 2>&1; then
    ok "BetterDisplay 后台进程在运行，CLI 可用"
    have_jq && info "jq 可用，使用 JSON 解析显示器信息（更稳）" || warn "未装 jq，回退 awk 解析（仍可用，建议 brew install jq）"
    CNT="$("$BD" get --identifiers 2>/dev/null | grep -c '"UUID"')"
    info "当前识别到 $CNT 块显示器"
    U="$(detect_builtin_uuid)"
    [ -n "$U" ] && ok "已识别内置屏 UUID: $U" || warn "未能自动识别内置屏（可手动在 config.sh 设 BUILTIN_UUID，或用 BetterDisplay 自动断开开关）"
    SU="$(detect_sidecar_uuid)"
    if [ -n "$SU" ]; then
      ok "Sidecar 屏已连接 UUID: $SU"
      sidecar_is_main && ok "Sidecar 屏当前已是主屏" || warn "Sidecar 已连但还不是主屏（守护进程会自动补设，或手动跑 ./src/arrange.sh）"
    else
      info "当前未检测到已连接的 Sidecar 屏（连上后才会出现）"
    fi
  else
    warn "BetterDisplay 已安装但后台未运行。请打开一次 BetterDisplay 并授予权限，建议开启 ‘Launch at login’"
  fi
else
  bad "未安装 BetterDisplay，请运行 ./install.sh"
fi

# ---- 5. iPad 物理连接 ----
echo; echo "[5] iPad USB 连接"
if ipad_plugged; then ok "检测到 iPad 经 USB 连接"; else info "当前未检测到 USB 连接的 iPad（无线 Sidecar 也可用）"; fi

# ---- 6. 配置 ----
echo; echo "[6] 配置"
if [ -f "$HSROOT/config.sh" ]; then
  ok "config.sh 存在"
  NAME="$(detect_ipad_name)"
  [ -n "$NAME" ] && info "目标 iPad 名称: \"$NAME\"" || warn "无法确定 iPad 名称，请在 config.sh 设 IPAD_NAME"
else
  warn "未创建 config.sh（将使用默认值并自动探测）。可 cp config.example.sh config.sh 自定义"
fi

# ---- 7. 开机自启 ----
echo; echo "[7] 开机自启 (LaunchAgent)"
PLIST="$HOME/Library/LaunchAgents/com.headless-sidecar.daemon.plist"
if [ -f "$PLIST" ]; then
  ok "已安装 LaunchAgent"
  launchctl list 2>/dev/null | grep -q 'headless-sidecar' && ok "服务已加载运行" || warn "LaunchAgent 未加载，运行 ./install.sh 或 launchctl load"
else
  warn "未安装开机自启，运行 ./install.sh 完成安装"
fi

echo; echo "==================================================="
echo " 提示：本工具无法跳过登录界面——开机后输密码那一步"
echo " iPad 仍是黑的，需盲打密码；登录后才会自动上屏。"
echo "==================================================="
