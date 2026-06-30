#!/bin/bash
# install.sh — 一键安装：依赖 + 配置 + 开机自启
set -euo pipefail
HSROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HSROOT"

GREEN='\033[0;32m'; YEL='\033[0;33m'; RED='\033[0;31m'; NC='\033[0m'
say(){ printf "${GREEN}==>${NC} %s\n" "$1"; }
warn(){ printf "${YEL}[!]${NC} %s\n" "$1"; }
die(){ printf "${RED}[x]${NC} %s\n" "$1"; exit 1; }

# 强制校验 sha256（供应链安全：默认 fail-closed）。
# verify_sha <file> <expected> <label>
# - 期望值非空且匹配 → 通过；不匹配 → 中止。
# - 期望值为空 → 中止，除非显式 ALLOW_UNVERIFIED=1（仅供调试，不推荐）。
verify_sha(){
  local f="$1" want="$2" label="$3" got
  got="$(shasum -a 256 "$f" 2>/dev/null | awk '{print $1}')"
  if [ -z "$want" ]; then
    if [ "${ALLOW_UNVERIFIED:-0}" = "1" ]; then
      warn "$label 跳过校验（ALLOW_UNVERIFIED=1，有被篡改风险）。实际 sha256=$got"
      return 0
    fi
    die "$label 缺少校验和，已中止。请更新本仓库固定的版本与 sha256；如确需跳过，显式设 ALLOW_UNVERIFIED=1（不推荐）。实际 sha256=$got"
  fi
  if [ "$got" = "$want" ]; then
    say "$label sha256 校验通过 ($got)"
  else
    die "$label 校验失败：期望 $want，实际 $got。疑似下载被篡改/损坏，已中止。"
  fi
}

# ---- 依赖供应链锚点 ----
# SidecarLauncher：不下载任何预编译二进制，改为从本仓库 vendor/ 下**已审计冻结**
#   的源码本地编译（见 vendor/SidecarLauncher/NOTICE.md）。下方哈希用于在编译前
#   校验 vendored 源码未被本地篡改。
SWIFT_SRC="$HSROOT/vendor/SidecarLauncher/main.swift"
SWIFT_SRC_SHA256="fae6395bc283dada7ba61cbe179c91ec1632e4f8b6b00a5057ece00705a9a35a"
# BetterDisplay：仍用官方已公证 dmg（固定版本 + sha256 强校验）。升级时改版本号并用
#   curl -fsSL <url> | shasum -a 256 重算填这里（或安装时 BD_SHA256= 覆盖）。
BD_VERSION="${BD_VERSION:-v4.3.4}"
BD_DMG_SHA256="${BD_SHA256:-234122f7e4ec6e6b00ea2143d42c12720ad4ece3bd98bddf977feebc2612e092}"

echo "==================================================="
echo " Headless Sidecar 安装程序"
echo "==================================================="

# ---- 0. 基础检查 ----
[ "$(uname -s)" = "Darwin" ] || die "本工具仅适用于 macOS"
OSV="$(sw_vers -productVersion)"; say "macOS $OSV / $(uname -m)"

mkdir -p "$HSROOT/bin" "$HSROOT/logs"

# ---- 1. 从已审计的 vendored 源码本地编译 SidecarLauncher（不下载二进制）----
SL="$HSROOT/bin/SidecarLauncher"
if [ -x "$SL" ] && "$SL" devices >/dev/null 2>&1; then
  say "SidecarLauncher 已就绪（本地编译产物）"
else
  [ -f "$SWIFT_SRC" ] || die "缺少 vendored 源码 $SWIFT_SRC（仓库不完整？）"
  # 编译前校验 vendored 源码完整性（防本地被篡改）
  verify_sha "$SWIFT_SRC" "$SWIFT_SRC_SHA256" "SidecarLauncher 源码"
  command -v swiftc >/dev/null 2>&1 || die "未找到 swiftc。请先装 Xcode 命令行工具： xcode-select --install （装好后重跑本脚本）"
  say "从源码本地编译 SidecarLauncher（vendor/SidecarLauncher，无预编译二进制）..."
  if swiftc -O "$SWIFT_SRC" -o "$SL" 2>>"$HSROOT/logs/build.log"; then
    chmod +x "$SL"
    # 本地编译的产物不带 Gatekeeper quarantine，无需任何 xattr 操作。
    if "$SL" devices >/dev/null 2>&1; then say "SidecarLauncher 编译并自检成功"
    else warn "SidecarLauncher 编译成功但运行异常（可能 macOS 私有 API 已变化），稍后用 doctor 复查"; fi
  else
    die "SidecarLauncher 编译失败，详见 logs/build.log"
  fi
fi

# ---- 2. 安装 BetterDisplay ----
BDAPP="/Applications/BetterDisplay.app"
if [ -d "$BDAPP" ]; then
  say "BetterDisplay 已安装"
else
  if command -v brew >/dev/null 2>&1; then
    say "用 Homebrew 安装 BetterDisplay..."
    brew install --cask betterdisplay || warn "brew 安装失败，改用直接下载"
  fi
  if [ ! -d "$BDAPP" ]; then
    say "下载 BetterDisplay dmg（固定版本 $BD_VERSION）..."
    URL="https://github.com/waydabber/BetterDisplay/releases/download/${BD_VERSION}/BetterDisplay-${BD_VERSION}.dmg"
    TMP="$(mktemp -d)"
    curl -fsSL -o "$TMP/bd.dmg" "$URL" || die "下载 BetterDisplay 失败（检查网络或固定版本是否仍存在）"
    verify_sha "$TMP/bd.dmg" "$BD_DMG_SHA256" "BetterDisplay.dmg"
    VOL="$(hdiutil attach "$TMP/bd.dmg" -nobrowse -quiet | grep -o '/Volumes/.*' | head -1)"
    cp -R "$VOL/BetterDisplay.app" /Applications/ 2>/dev/null \
      || { warn "复制到 /Applications 需要权限，尝试 sudo"; sudo cp -R "$VOL/BetterDisplay.app" /Applications/; }
    hdiutil detach "$VOL" -quiet || true
    # 注意：不抹 BetterDisplay 的 quarantine —— 它已签名/公证，交给 Gatekeeper 验证。
    rm -rf "$TMP"
    say "BetterDisplay 安装成功（首次打开如有 Gatekeeper 提示，请在“系统设置 → 隐私与安全性”放行）"
  fi
fi
say "首次启动 BetterDisplay（请按屏幕提示授予权限，并在其设置中开启 Launch at login）..."
open -a "$BDAPP" || true
sleep 3

# ---- 3. 生成 config.sh（若不存在）----
if [ ! -f "$HSROOT/config.sh" ]; then
  cp "$HSROOT/config.example.sh" "$HSROOT/config.sh"
  say "已从示例生成 config.sh（默认自动探测，可自行编辑）"
fi

# ---- 4. 安装开机自启 LaunchAgent ----
say "安装开机自启..."
chmod +x "$HSROOT/src/"*.sh
LA="$HOME/Library/LaunchAgents"; mkdir -p "$LA"
PLIST="$LA/com.headless-sidecar.daemon.plist"
sed -e "s|__DAEMON_PATH__|$HSROOT/src/daemon.sh|g" \
    -e "s|__LOG_DIR__|$HSROOT/logs|g" \
    "$HSROOT/launchagent/com.headless-sidecar.daemon.plist.template" > "$PLIST"
LABEL="com.headless-sidecar.daemon"
# 优先用新版 launchctl bootstrap（macOS 11+）；失败再回退旧版 load。
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
if launchctl bootstrap "gui/$(id -u)" "$PLIST" 2>/dev/null; then
  say "开机自启已加载（bootstrap）"
else
  launchctl unload "$PLIST" 2>/dev/null || true
  launchctl load "$PLIST" && say "开机自启已加载（load 回退）" || warn "LaunchAgent 加载失败，可重启后由 RunAtLoad 拉起"
fi

# ---- 5. 自检 ----
echo; say "运行自检..."; echo
bash "$HSROOT/src/doctor.sh" || true

echo
echo "==================================================="
say "安装完成！还需你手动确认两件事："
echo "   1) 打开 BetterDisplay -> 设置 -> 开启 ‘Launch at login’"
echo "      （否则重启后无法自动设主屏）"
echo "   2) 若 doctor 未发现 iPad：确认 iPad 与 Mac 登录同一 Apple ID、"
echo "      已解锁、蓝牙/WiFi 开启，或用 USB-C 线连接"
echo "==================================================="
