# 贡献指南 / Contributing

欢迎 PR 与 issue，尤其是不同机型 / macOS 版本的兼容反馈（请附 `sw_vers`、`uname -m`、`hw.model`）。

## 本地检查（提交前必跑）

```bash
# 语法
for f in install.sh uninstall.sh config.example.sh src/*.sh tests/run.sh; do bash -n "$f"; done
# 静态检查（需 brew install shellcheck）
shellcheck -x -S warning install.sh uninstall.sh src/*.sh tests/run.sh
# 解析单元测试（无需真实硬件）
bash tests/run.sh
```

CI 会在 PR 上自动跑以上三项。

## 改动显示器解析逻辑时

`parse_sidecar_uuid` / `parse_builtin_uuid` 是从 stdin 读 `BetterDisplay get --identifiers`
的纯函数。若你改了解析规则，请同时更新 `tests/fixtures/identifiers.txt` 并确保 `tests/run.sh` 通过。
若在新机型上自动识别失败，最有价值的贡献是**附上你机器的 `BetterDisplay get --identifiers` 片段**（脱敏后）作为新 fixture。

## 升级 vendored 的 SidecarLauncher

见 [`vendor/SidecarLauncher/NOTICE.md`](vendor/SidecarLauncher/NOTICE.md)：
替换 `main.swift` → 重新审计 → 更新固定 commit 与 `main.swift` sha256（同时改 `install.sh` 里的 `SWIFT_SRC_SHA256`）。

## 升级 BetterDisplay 固定版本

改 `install.sh` 的 `BD_VERSION`，并用 `curl -fsSL <dmg-url> | shasum -a 256` 重算 `BD_DMG_SHA256`。

## 文档语言

`README.md`（中文）为权威版本；`README.en.md` / `README.de.md` 为镜像，**可能滞后**。
改动面向用户的行为时，请至少同步中文版与英文版。
