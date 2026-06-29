#!/bin/bash
# ============================================================
# Headless Sidecar 配置示例
# 用法：cp config.example.sh config.sh 然后按需修改。
# 所有项都可留默认；脚本会尽量自动探测。
# ============================================================

# iPad 的设备名称（设置 -> 通用 -> 关于本机 -> 名称）。
# 留空 = 自动用 SidecarLauncher 探测到的第一台设备。
# 多台 iPad 时建议显式填写，例如：IPAD_NAME="我的iPad Pro"
IPAD_NAME=""

# 守护进程轮询间隔（秒）。5 秒对续航几乎无感；可设 3~10。
POLL_INTERVAL=5

# 是否脚本化断开坏掉的内置屏：
#   auto = 尝试自动识别并断开（默认）
#   off  = 不在脚本里断开（改用 BetterDisplay 的“自动断开内置屏”开关）
DISABLE_BUILTIN="auto"

# 内置屏 UUID。留空 = 自动识别。
# 自动识别不准时，可运行：
#   /Applications/BetterDisplay.app/Contents/MacOS/BetterDisplay get --identifiers
# 找到内建显示屏(Color LCD / 内建显示屏)的 "UUID" 填到这里。
BUILTIN_UUID=""

# 是否强制有线 Sidecar（USB-C 连接更稳、更低延迟）。on / off
SIDECAR_WIRED="on"

# ---- 一般无需修改：可执行文件路径覆盖 ----
# SIDECAR_BIN="$HOME/headless-sidecar/bin/SidecarLauncher"
# BDCLI="/Applications/BetterDisplay.app/Contents/MacOS/BetterDisplay"
