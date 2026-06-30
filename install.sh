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

# ---- 固定依赖版本与校验和（供应链安全锚点）----
# 默认对下载物做强校验。升级依赖时：改版本号，并用
#   curl -fsSL <url> | shasum -a 256
# 重新计算填到这里（或安装时用 SIDECAR_SHA256 / BD_SHA256 覆盖）。
SIDECAR_VERSION="${SIDECAR_VERSION:-1.2}"
SIDECAR_ZIP_SHA256="${SIDECAR_SHA256:-fc3df81639f400aaff9b44ba20650cf56ef2f73a033b927bbe378cb3c73b9764}"
BD_VERSION="${BD_VERSION:-v4.3.4}"
BD_DMG_SHA256="${BD_SHA256:-234122f7e4ec6e6b00ea2143d42c12720ad4ece3bd98bddf977feebc2612e092}"

echo "==================================================="
echo " Headless Sidecar 安装程序"
echo "==================================================="

# ---- 0. 基础检查 ----
[ "$(uname -s)" = "Darwin" ] || die "本工具仅适用于 macOS"
OSV="$(sw_vers -productVersion)"; say "macOS $OSV / $(uname -m)"

mkdir -p "$HSROOT/bin" "$HSROOT/logs"

# ---- 1. 安装 SidecarLauncher（GitHub release 二进制）----
SL="$HSROOT/bin/SidecarLauncher"
if [ -x "$SL" ] && "$SL" devices >/dev/null 2>&1; then
  say "SidecarLauncher 已就绪"
else
  say "下载 SidecarLauncher（固定版本 $SIDECAR_VERSION）..."
  URL="https://github.com/Ocasio-J/SidecarLauncher/releases/download/${SIDECAR_VERSION}/SidecarLauncher.zip"
  TMP="$(mktemp -d)"
  curl -fsSL -o "$TMP/sl.zip" "$URL" || die "下载 SidecarLauncher 失败（检查网络或固定版本是否仍存在）"
  # 先校验下载物（供应链锚点），通过后再解压
  verify_sha "$TMP/sl.zip" "$SIDECAR_ZIP_SHA256" "SidecarLauncher.zip"
  unzip -oq "$TMP/sl.zip" -d "$TMP/extract"
  BIN="$(find "$TMP/extract" -type f -name 'SidecarLauncher' | head -1)"
  [ -n "$BIN" ] || die "解压后未找到 SidecarLauncher 可执行文件"
  cp "$BIN" "$SL"; chmod +x "$SL"
  # 仅对“已通过 sha256 校验”的 SidecarLauncher 解除隔离（未签名 CLI，需此步才能 headless 运行）
  xattr -dr com.apple.quarantine "$SL" 2>/dev/null || true
  rm -rf "$TMP"
  if "$SL" devices >/dev/null 2>&1; then say "SidecarLauncher 安装成功"
  else warn "SidecarLauncher 安装了但运行异常（可能 macOS 私有 API 失效），稍后用 doctor 复查"; fi
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
