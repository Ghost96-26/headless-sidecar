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

# 连上/失败时是否弹 macOS 桌面通知（坏屏看不到日志时有用）。on / off
NOTIFY="on"

# 日志按大小轮转阈值（字节）。超过则把 run.log 转存为 run.log.1。
MAX_LOG_BYTES=1048576

# 连接失败的退避上限（秒）与连续失败冷却阈值。
BACKOFF_MAX=60
FAIL_LIMIT=5

# 可选：依赖二进制的 sha256 校验值（安装时核对，防止下载被篡改）。
# 留空则只打印实际哈希、不校验。可先跑一次 install.sh 记录哈希再回填。
SIDECAR_SHA256=""
BD_SHA256=""

# ---- 一般无需修改：可执行文件路径覆盖 ----
# SIDECAR_BIN="$HOME/headless-sidecar/bin/SidecarLauncher"
# BDCLI="/Applications/BetterDisplay.app/Contents/MacOS/BetterDisplay"
