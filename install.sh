#!/bin/bash
# install.sh — 一键安装：依赖 + 配置 + 开机自启
set -euo pipefail
HSROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HSROOT"

GREEN='\033[0;32m'; YEL='\033[0;33m'; RED='\033[0;31m'; NC='\033[0m'
say(){ printf "${GREEN}==>${NC} %s\n" "$1"; }
warn(){ printf "${YEL}[!]${NC} %s\n" "$1"; }
die(){ printf "${RED}[x]${NC} %s\n" "$1"; exit 1; }

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
  say "下载 SidecarLauncher..."
  URL="$(curl -fsSL https://api.github.com/repos/Ocasio-J/SidecarLauncher/releases/latest \
        | grep browser_download_url | grep -i '.zip' | head -1 | cut -d'"' -f4)"
  [ -n "$URL" ] || die "无法获取 SidecarLauncher 下载地址（检查网络）"
  TMP="$(mktemp -d)"
  curl -fsSL -o "$TMP/sl.zip" "$URL"
  unzip -oq "$TMP/sl.zip" -d "$TMP/extract"
  BIN="$(find "$TMP/extract" -type f -name 'SidecarLauncher' | head -1)"
  [ -n "$BIN" ] || die "解压后未找到 SidecarLauncher 可执行文件"
  cp "$BIN" "$SL"; chmod +x "$SL"
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
    say "下载 BetterDisplay dmg..."
    URL="$(curl -fsSL https://api.github.com/repos/waydabber/BetterDisplay/releases/latest \
          | grep browser_download_url | grep -i '.dmg' | head -1 | cut -d'"' -f4)"
    [ -n "$URL" ] || die "无法获取 BetterDisplay 下载地址"
    TMP="$(mktemp -d)"; curl -fsSL -o "$TMP/bd.dmg" "$URL"
    VOL="$(hdiutil attach "$TMP/bd.dmg" -nobrowse -quiet | grep -o '/Volumes/.*' | head -1)"
    cp -R "$VOL/BetterDisplay.app" /Applications/ 2>/dev/null \
      || { warn "复制到 /Applications 需要权限，尝试 sudo"; sudo cp -R "$VOL/BetterDisplay.app" /Applications/; }
    hdiutil detach "$VOL" -quiet || true
    xattr -dr com.apple.quarantine "$BDAPP" 2>/dev/null || true
    rm -rf "$TMP"
    say "BetterDisplay 安装成功"
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
launchctl unload "$PLIST" 2>/dev/null || true
launchctl load "$PLIST"
say "开机自启已加载"

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
