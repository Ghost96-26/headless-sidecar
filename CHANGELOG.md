# Changelog

本项目遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)
与[语义化版本](https://semver.org/lang/zh-CN/)。

## [Unreleased]

## [1.0.0] - 2026-06-30

首个正式版本：屏幕损坏的 Mac 登录后自动用 iPad（Sidecar）作为唯一主屏。

### Added
- 守护进程 `src/daemon.sh`：`ioreg` 轻量检测 iPad → 发起 Sidecar → 设为唯一主屏。
- `src/arrange.sh`：按 **UUID** 将 Sidecar 屏设主屏并断开坏掉的内置屏。
- `src/common.sh`：运行时自动探测 iPad 名称、Sidecar 屏 / 内置屏 UUID（jq 解析 + awk 兜底）。
- `src/doctor.sh`：只读自检（系统/芯片/依赖/连接/配置/自启）。
- `install.sh` / `uninstall.sh`：一键安装与干净卸载。
- 供应链安全：SidecarLauncher 改为 **vendored 冻结源码本地编译**（固定 commit + 源码 sha256 强校验）；BetterDisplay 固定版本 + dmg sha256 强校验，`verify_sha` 默认 fail-closed。
- 可观测性：macOS 桌面通知、日志按大小轮转。
- 健壮性：连接失败指数退避 + 冷却；冷却期间仍持续静默重试，连上即自动恢复。
- 多设备保护：发现多台可达设备且未设 `IPAD_NAME` 时告警，提示显式指定。
- 解析单元测试 `tests/`（fixture 驱动，CI 覆盖 awk 与 jq 两条路径）。
- LaunchAgent 加 `ThrottleInterval`，避免异常秒退导致的紧贴崩溃循环。
- CI：`shellcheck` + `bash -n` + 解析单测。
- 中 / 英 / 德三语 README。

### Known limitations
- 无法绕过登录界面：开机后输密码那一步 iPad 仍是黑的，需盲打。
- 依赖 Apple 私有 `SidecarCore`，可能随 macOS 大版本更新失效（本地编译仍会成功，但运行时可能不可用）。

[Unreleased]: https://github.com/Ghost96-26/headless-sidecar/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/Ghost96-26/headless-sidecar/releases/tag/v1.0.0
