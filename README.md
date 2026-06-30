# Headless Sidecar 🏍️ — 让屏幕坏掉的 Mac 自动用 iPad 当主显示器

> **一句话**：MacBook 内置屏坏了？插上 iPad，登录后它会**自动连上 Sidecar 并把 iPad 设为唯一主屏**，无需每次手动点控制中心。专为「无头骑士」（headless / 坏屏）Mac 打造。
>
> **TL;DR (English)**: Broken-screen Mac? This tool auto-connects your iPad via Sidecar and makes it the **sole primary display** right after you log in. Built for headless / broken-internal-display Macs.

[![Platform](https://img.shields.io/badge/platform-macOS%2010.15%2B-blue)]()
[![Shell](https://img.shields.io/badge/shell-bash-green)]()
[![License](https://img.shields.io/badge/license-MIT-lightgrey)]()

---

## 📑 目录
- [它解决什么问题](#-它解决什么问题)
- [重要前提与限制（务必先读）](#️-重要前提与限制务必先读)
- [工作原理](#-工作原理)
- [快速开始（小白版）](#-快速开始小白版)
- [自检 doctor](#-自检-doctor)
- [配置说明](#️-配置说明)
- [它是怎么跑起来的（开发者）](#-它是怎么跑起来的开发者)
- [常见问题 FAQ](#-常见问题-faq)
- [卸载](#-卸载)
- [致谢与依赖](#-致谢与依赖)
- [许可证](#-许可证)

---

## 🎯 它解决什么问题

很多人有一台屏幕摔坏 / 进水 / 排线坏的 MacBook，机器其实还能正常运行。把它接到 iPad 上用 **Sidecar（随航）** 当显示器是最省钱的复活方式，但原生 Sidecar 有个痛点：

- 每次都要**手动**点「控制中心 → 屏幕镜像 → iPad」；
- 屏幕坏了根本看不见，没法点；
- 就算连上，**主屏（菜单栏/Dock）还停在坏掉的内置屏上**，操作错位。

本工具把「登录之后」的这一整套**全自动化**：检测到 iPad → 自动连 Sidecar → 把 iPad 设为唯一主屏 → 断开坏掉的内置屏。

---

## ⚠️ 重要前提与限制（务必先读）

1. **跳不过登录界面**。Sidecar 只能在**登录进桌面之后**工作。所以开机后输密码那一步，iPad 仍然是黑的，需要**盲打密码**。本工具自动化的是「登录之后」。
   > 想连登录界面都能看见 → 需要**真·外接显示器**（HDMI 显示器 / 电视 / 诱骗器 / AR 眼镜如 Xreal）。那种场景不需要本工具。
2. **必须满足 Sidecar 的硬性条件**：
   - Mac 与 iPad **登录同一个 Apple ID**，且都开启双重认证；
   - 双方都开 **蓝牙 + Wi-Fi**（即使用 USB-C 线，握手仍依赖它们）、开启 Handoff；
   - 机型与系统满足苹果 Sidecar 要求（macOS 10.15+ / iPadOS 13+）。
3. **依赖两个第三方工具**（安装脚本会自动获取）：
   - [SidecarLauncher](https://github.com/Ocasio-J/SidecarLauncher)：命令行发起 Sidecar 连接（使用私有 API，**可能随 macOS 更新失效**）；
   - [BetterDisplay](https://github.com/waydabber/BetterDisplay)：设置主屏、断开内置屏。
4. **首次设置需要看得见画面一次**：授予权限、勾选 BetterDisplay 的开机自启等。请在屏幕还能看见时、或临时借一台外接显示器/电视/诱骗器完成一次，之后永久生效。

---

## 🔧 工作原理

```
       开机 → 盲打密码登录 (iPad 仍黑，无法自动化这一步)
                         │
                         ▼
   LaunchAgent 登录后拉起守护进程 daemon.sh
                         │  每 5s 用 ioreg 轻量检测
                         ▼
            检测到 iPad 经 USB 插入？
                         │ 是
                         ▼
        SidecarLauncher connect "iPad" -wired   ← 发起连接
                         │
                         ▼
        BetterDisplay：① iPad 设为主屏
                       ② 断开坏掉的内置屏        ← arrange.sh
                         │
                         ▼
            iPad = 唯一主屏，菜单栏/Dock 到位 ✅
```

设计要点：
- **轻量、省电**：用 `ioreg` 而非 `system_profiler` 检测，5 秒间隔，对续航几乎无感；连上后不再重复动作。
- **不依赖 UI 自动化**：用 SidecarLauncher 二进制而非 AppleScript 点控制中心，避免 launchd 下「辅助功能权限」不稳的坑。
- **跨机型自适应**：iPad 名称、Sidecar 屏 / 内置屏 UUID 全部**运行时自动探测**，无硬编码。
- **一切按 UUID 操作**：Sidecar 屏在 BetterDisplay 里实际叫 `Sidecar Display`（不叫 `iPad`），故设主屏 / 判断状态全部以 UUID 为准，避免按名字匹配在真机上失效。
- **失败退避 + 冷却**：连接失败按指数退避（4→8→…→封顶 `BACKOFF_MAX`），连续失败 `FAIL_LIMIT` 次进入冷却并只告警一次，不刷日志。
- **桌面通知**：连上设主屏成功 / 反复失败时弹 macOS 通知（坏屏看不到日志时也能知道结果）。
- **日志轮转**：`run.log` 超过 `MAX_LOG_BYTES` 自动转存，长期常驻不胀大。
- **解析更稳**：优先用 `jq` 解析 BetterDisplay 输出，无 `jq` 时回退 `awk`。

---

## 🚀 快速开始（小白版）

> 全程跟着做即可，命令直接复制粘贴到「终端」。

### 第 0 步：先确认能看见画面
屏幕坏了的话，先临时接一个能显示的东西（HDMI 显示器 / 电视 / USB-C 诱骗器 / AR 眼镜），让你能看到 macOS 桌面来完成设置。

### 第 1 步：确认 Sidecar 本身能用（30 秒手动测试）
点屏幕右上角**控制中心 → 屏幕镜像**，看列表里有没有你的 iPad，点它，确认 iPad 能变成扩展屏。
> 连不上？先解决根因：是否同一 Apple ID、蓝牙/Wi-Fi 是否开、iPad 是否解锁。**这一步不过，后面自动化也没用。**

### 第 2 步：下载本项目
```bash
git clone https://github.com/Ghost96-26/headless-sidecar.git
cd headless-sidecar
```

### 第 3 步：一键安装
```bash
chmod +x install.sh
./install.sh
```
安装脚本会自动：下载 SidecarLauncher、安装 BetterDisplay、生成配置、装好开机自启、并跑一次自检。

### 第 4 步：完成两个手动确认（重要）
1. 打开 **BetterDisplay**（首次会弹权限请求，全部允许）→ 进设置 → 勾选 **Launch at login（登录时启动）**。
   - 建议同时勾上 **「Auto-disconnect built-in screen upon connecting an external display」**（接入外接屏时自动断开内置屏，Apple Silicon）。
2. 如果安装时自检没发现 iPad：检查同一 Apple ID / 蓝牙 / Wi-Fi / iPad 解锁。

### 第 5 步：验证
插上 iPad（USB-C 线最稳），等几秒，iPad 应自动变成主屏。或手动跑：
```bash
./src/doctor.sh          # 自检
tail -f logs/run.log     # 看守护日志
```

### 第 6 步：重启实测
重启 Mac（趁外接屏还在），盲打密码登录后，iPad 应自动上屏。成功后就可以撤掉临时外接屏，日常只插 iPad 即可。

---

## 🩺 自检 doctor

任何时候排查问题，先跑：
```bash
./src/doctor.sh
```
它会检查并彩色输出：macOS 版本、芯片/机型、SidecarLauncher、BetterDisplay、iPad 连接、配置、开机自启状态，并给出针对性建议。

---

## ⚙️ 配置说明

复制示例并按需修改（不改也能用，默认全自动探测）：
```bash
cp config.example.sh config.sh
```

| 配置项 | 默认 | 说明 |
|---|---|---|
| `IPAD_NAME` | 空（自动探测） | iPad 设备名；多台 iPad 时建议显式填写 |
| `POLL_INTERVAL` | `5` | 守护轮询间隔（秒） |
| `DISABLE_BUILTIN` | `auto` | `auto`/`off`，是否脚本化断开内置屏 |
| `BUILTIN_UUID` | 空（自动探测） | 内置屏 UUID，自动识别不准时手填 |
| `SIDECAR_WIRED` | `on` | 是否强制有线 Sidecar（更稳） |
| `NOTIFY` | `on` | 连上 / 失败时是否弹 macOS 通知 |
| `MAX_LOG_BYTES` | `1048576` | 日志轮转阈值（字节） |
| `BACKOFF_MAX` | `60` | 连接失败退避上限（秒） |
| `FAIL_LIMIT` | `5` | 连续失败到此值进入冷却并告警 |
| `SIDECAR_SHA256` / `BD_SHA256` | 空 | 可选，安装时校验依赖二进制完整性 |

> `config.sh` 含你的个人信息，已被 `.gitignore` 忽略，不会上传。

---

## 🛠 它是怎么跑起来的（开发者）

```
headless-sidecar/
├── install.sh                 # 一键安装：拉依赖 + 配置 + 自启 + 自检
├── uninstall.sh               # 卸载自启、恢复内置屏
├── config.example.sh          # 配置模板（用户 cp 成 config.sh）
├── launchagent/
│   └── com.headless-sidecar.daemon.plist.template  # 自启模板（含占位符）
└── src/
    ├── common.sh              # 共享函数 + 自动探测（iPad名/内置屏UUID/路径）
    ├── daemon.sh              # 守护循环：检测→连接→设主屏
    ├── arrange.sh             # 设 iPad 为主屏 + 断开内置屏
    └── doctor.sh              # 只读自检
```

**关键自动探测逻辑（`src/common.sh`）**
- `detect_ipad_name`：优先读 `config.sh`，否则取 `SidecarLauncher devices` 的第一台。
- `detect_sidecar_uuid`：从 `BetterDisplay get --identifiers` 找 name/productName 含 `Sidecar` 的显示器 UUID。
- `detect_builtin_uuid`：按内置面板特征命中——registryLocation 含 `disp0@` 且非 `dispext`，或 productName 为 `Color LCD`，或名称含 `Built-in/内建`。
- 上述解析优先 `jq`（包一层 `[]` 成合法 JSON 数组），无 `jq` 时回退 `awk`。
- `ipad_plugged`：`ioreg -p IOUSB` 精确匹配 `USB Product Name` 含 iPad（避免误命中集线器等描述）。
- `sidecar_active` / `sidecar_is_main`：均按 Sidecar 屏 UUID 判断，不按名字。

**开机自启**：`install.sh` 把模板里的 `__DAEMON_PATH__` / `__LOG_DIR__` 替换成真实路径，写入
`~/Library/LaunchAgents/com.headless-sidecar.daemon.plist`，优先用新版 `launchctl bootstrap gui/$UID`（失败回退旧版 `launchctl load`）。`RunAtLoad + KeepAlive` 保证登录后常驻。

**为什么不用 AppleScript 点控制中心？** 在 launchd 环境里给 osascript 授「辅助功能」权限非常不稳定（macOS 会以 `-1719 不允许辅助访问` 拒绝）。改用 SidecarLauncher 二进制，发起连接不依赖任何 UI 权限。

**贡献**：欢迎 PR。改动脚本后请确保 `bash -n` 与 `shellcheck` 通过（CI 会跑 `.github/workflows/ci.yml`），并在真机跑一遍 `./src/doctor.sh`。不同机型 / macOS 版本的兼容反馈尤其欢迎（请附 `sw_vers`、`uname -m`、`hw.model`）。

---

## ❓ 常见问题 FAQ

**Q：能不能开机时连登录界面都显示在 iPad 上？**
A：不能。Sidecar 是登录后能力，这是苹果的限制，任何软件都绕不过。要全程可见请用真外接显示器/诱骗器/AR 眼镜。

**Q：SidecarLauncher 提示无法运行 / 连接失败？**
A：它用私有 API，可能随 macOS 大版本更新失效。关注其[上游仓库](https://github.com/Ocasio-J/SidecarLauncher)更新；本工具会优先调用你 `bin/` 下的版本。

**Q：iPad 连上了但主屏没切过去？**
A：多半是 BetterDisplay 后台没运行。打开它并开启 Launch at login；或跑 `./src/doctor.sh` 看提示。

**Q：内置屏没被识别 / 没断开？**
A：跑 `BetterDisplay get --identifiers` 找到内建屏 UUID，填进 `config.sh` 的 `BUILTIN_UUID`；或直接用 BetterDisplay 的「自动断开内置屏」开关（Apple Silicon）。

**Q：Intel Mac 能用吗？**
A：能。Sidecar 连接与设主屏都可用，但「自动断开内置屏」在 Intel 上行为不同，建议用诱骗器或脚本断开。

**Q：很费电吗？会伤设备吗？**
A：不会。`ioreg` 检测极轻量、5 秒一次，对续航几乎无感，对硬件寿命无影响。

---

## 🧹 卸载
```bash
./uninstall.sh
```
会停止并移除开机自启、结束守护进程、尝试恢复内置屏连接、清理日志。BetterDisplay.app 和 `bin/SidecarLauncher` 不会被删除，可按需手动移除。

---

## 🙏 致谢与依赖
- [Ocasio-J/SidecarLauncher](https://github.com/Ocasio-J/SidecarLauncher) — 命令行 Sidecar 连接
- [waydabber/BetterDisplay](https://github.com/waydabber/BetterDisplay) — 显示器管理 / 内置屏断开
- 同类思路参考：[wberry9813/SideLinker](https://github.com/wberry9813/SideLinker)、[raonehere/sidecar-autoconnect](https://github.com/raonehere/sidecar-autoconnect)

本项目仅编排上述工具，不修改/重分发其源码；各自版权归原作者。

---

## 📄 许可证
MIT License，详见 [LICENSE](LICENSE)。

> 免责声明：本工具按「现状」提供，依赖私有 API 的第三方组件可能失效。请自行评估风险，作者不对任何数据丢失或设备问题负责。
