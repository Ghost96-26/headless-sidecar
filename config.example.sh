#!/bin/bash
# 配置示例：cp config.example.sh config.sh 后按需修改。所有项都可留默认（自动探测）。

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

# 依赖完整性（供应链安全）：
# - SidecarLauncher 不下载二进制，由 install.sh 从本仓库 vendor/ 下已审计冻结
#   的源码本地编译（见 vendor/SidecarLauncher/NOTICE.md），编译前校验源码 sha256。
# - BetterDisplay 用官方已公证 dmg，install.sh 内置固定版本(v4.3.4)+sha256 强校验，
#   不匹配即中止。通常无需在此设置；仅当装其它 BD 版本时作为 install 环境变量覆盖：
#     BD_VERSION=vX.Y.Z BD_SHA256=<dmg哈希> ./install.sh
#   调试时如确需跳过 BD 校验（有风险）：ALLOW_UNVERIFIED=1 ./install.sh
# （注意：BD_SHA256 由 install.sh 读取环境变量，写在 config.sh 不生效。）
BD_SHA256=""

# 一般无需修改：可执行文件路径覆盖
# SIDECAR_BIN="$HOME/headless-sidecar/bin/SidecarLauncher"
# BDCLI="/Applications/BetterDisplay.app/Contents/MacOS/BetterDisplay"
