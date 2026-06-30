# Headless Sidecar 🏍️ — Auto-use an iPad as the primary display for a broken-screen Mac

> **In one line**: Broken MacBook screen? Plug in an iPad and, right after you log in, it **auto-connects via Sidecar and makes the iPad the sole primary display** — no more manually clicking through Control Center every time. Built for headless / broken-internal-display Macs.

[![Platform](https://img.shields.io/badge/platform-macOS%2010.15%2B-blue)]()
[![Shell](https://img.shields.io/badge/shell-bash-green)]()
[![License](https://img.shields.io/badge/license-MIT-lightgrey)]()

**🌐 语言 / Language / Sprache:** [中文](README.md) · **English** · [Deutsch](README.de.md)

---

## 📑 Table of Contents
- [What problem it solves](#-what-problem-it-solves)
- [Important prerequisites & limits (read first)](#️-important-prerequisites--limits-read-first)
- [How it works](#-how-it-works)
- [Quick start (beginner-friendly)](#-quick-start-beginner-friendly)
- [Self-check: doctor](#-self-check-doctor)
- [Configuration](#️-configuration)
- [How it runs under the hood (for developers)](#-how-it-runs-under-the-hood-for-developers)
- [FAQ](#-faq)
- [Uninstall](#-uninstall)
- [Acknowledgements & dependencies](#-acknowledgements--dependencies)
- [License](#-license)

---

## 🎯 What problem it solves

Many people have a MacBook with a cracked / water-damaged / cable-broken screen that otherwise still runs fine. Connecting it to an iPad and using **Sidecar** as the display is the cheapest way to revive it, but stock Sidecar has pain points:

- You must **manually** click **Control Center → Screen Mirroring → iPad** every time;
- With a broken screen you can't see anything, so you can't click;
- Even once connected, the **primary display (menu bar / Dock) is still stuck on the broken internal screen**, so everything is misaligned.

This tool **fully automates** the whole "after login" sequence: detect iPad → auto-connect Sidecar → make the iPad the sole primary display → disconnect the broken internal screen.

---

## ⚠️ Important prerequisites & limits (read first)

1. **It cannot bypass the login screen.** Sidecar only works **after you log into the desktop**. So at the post-boot password prompt the iPad is still black and you have to **type your password blind**. What this tool automates is everything "after login".
   > Want the login screen visible too? You need a **real external display** (HDMI monitor / TV / display dongle / AR glasses like Xreal). That scenario doesn't need this tool.
2. **Sidecar's hard requirements must be met:**
   - Mac and iPad **signed into the same Apple ID**, both with two-factor auth enabled;
   - Both have **Bluetooth + Wi-Fi** on (the handshake relies on them even over USB-C) and Handoff enabled;
   - Model and OS meet Apple's Sidecar requirements (macOS 10.15+ / iPadOS 13+).
3. **It depends on two third-party tools:**
   - [SidecarLauncher](https://github.com/Ocasio-J/SidecarLauncher): starts a Sidecar connection from the command line (uses a private API, **may break with macOS updates**). This project does **not** download its prebuilt binary — it **compiles it locally** from audited, frozen source under `vendor/`, so first-time install needs the **Xcode Command Line Tools** (`xcode-select --install`).
   - [BetterDisplay](https://github.com/waydabber/BetterDisplay): sets the primary display and disconnects the internal screen. The installer downloads its **officially notarized dmg** (pinned version + sha256 check).
4. **First-time setup needs a visible screen once**: to grant permissions, tick BetterDisplay's launch-at-login, etc. Do it while the screen still works, or borrow an external monitor/TV/dongle once — after that it's permanent.

---

## 🔧 How it works

```
       Boot → type password blind to log in (iPad still black, this step can't be automated)
                         │
                         ▼
   LaunchAgent starts the daemon (daemon.sh) after login
                         │  lightweight ioreg check every 5s
                         ▼
            iPad plugged in over USB?
                         │ yes
                         ▼
        SidecarLauncher connect "iPad" -wired   ← initiate connection
                         │
                         ▼
        BetterDisplay: ① set iPad as primary
                       ② disconnect the broken internal screen   ← arrange.sh
                         │
                         ▼
            iPad = sole primary display, menu bar / Dock in place ✅
```

Design highlights:
- **Lightweight & power-friendly**: uses `ioreg` instead of `system_profiler`, polling every 5s with negligible battery impact; once connected it stops repeating actions.
- **No UI automation**: uses the SidecarLauncher binary instead of AppleScript clicking Control Center, avoiding the flaky "Accessibility permission" trap under launchd.
- **Cross-model adaptive**: iPad name, Sidecar-display / internal-display UUIDs are all **auto-detected at runtime** — nothing hard-coded.
- **Everything keyed by UUID**: in BetterDisplay the Sidecar screen is actually named `Sidecar Display` (not `iPad`), so setting the primary / checking state is all done by UUID, avoiding name-matching that fails on real hardware.
- **Failure backoff + cooldown (never gives up)**: connection failures back off exponentially (4→8→… capped at `BACKOFF_MAX`); after `FAIL_LIMIT` consecutive failures it enters a cooldown and warns only once instead of spamming the log — but **keeps retrying silently at the `BACKOFF_MAX` interval and recovers automatically once it connects**.
- **Supply-chain safety (zero prebuilt-binary trust)**: SidecarLauncher is **not** downloaded as a binary — it's compiled locally from **audited source frozen at a pinned commit** under `vendor/`, so a future compromise of the upstream repo can't reach your users; a locally compiled binary carries no Gatekeeper quarantine, so no `xattr` games are needed. BetterDisplay uses the **officially notarized dmg with a pinned-version sha256 check**, aborting on mismatch (skippable with `ALLOW_UNVERIFIED=1`, not recommended). See [`vendor/SidecarLauncher/NOTICE.md`](vendor/SidecarLauncher/NOTICE.md).
- **Desktop notifications**: pops a macOS notification when it succeeds at setting the primary, or when it keeps failing (so you know the result even when the screen is dead).
- **Log rotation**: `run.log` is rotated once it exceeds `MAX_LOG_BYTES`, so a long-running daemon doesn't bloat it.
- **Sturdier parsing**: prefers `jq` to parse BetterDisplay output, falling back to `awk` when `jq` is absent.

---

## 🚀 Quick start (beginner-friendly)

> Just follow along; copy-paste the commands into Terminal.

### Step 0: Make sure you can see something first
If the screen is broken, temporarily attach something that displays (HDMI monitor / TV / USB-C dongle / AR glasses) so you can see the macOS desktop to do the setup.

### Step 1: Confirm Sidecar itself works (30-second manual test)
Click **Control Center → Screen Mirroring** in the top-right, check whether your iPad is listed, click it, and confirm the iPad becomes an extended display.
> Can't connect? Fix the root cause first: same Apple ID, Bluetooth/Wi-Fi on, iPad unlocked. **If this step fails, the automation is useless too.**

### Step 2: Download this project
```bash
git clone https://github.com/Ghost96-26/headless-sidecar.git
cd headless-sidecar
```

### Step 3: One-command install
```bash
chmod +x install.sh
./install.sh
```
The installer automatically **compiles SidecarLauncher from source** (needs Xcode Command Line Tools), downloads and installs BetterDisplay, generates the config, sets up launch-at-login, and runs a self-check.

### Step 4: Complete two manual confirmations (important)
1. Open **BetterDisplay** (it will request permissions on first launch — allow all) → Settings → tick **Launch at login**.
   - It's recommended to also tick **"Auto-disconnect built-in screen upon connecting an external display"** (Apple Silicon).
2. If the self-check didn't find the iPad: check same Apple ID / Bluetooth / Wi-Fi / iPad unlocked.

### Step 5: Verify
Plug in the iPad (a USB-C cable is most reliable), wait a few seconds, and the iPad should become primary automatically. Or run manually:
```bash
./src/doctor.sh          # self-check
tail -f logs/run.log     # watch the daemon log
```

### Step 6: Reboot test
Reboot the Mac (while the external display is still attached), log in by typing your password blind, and the iPad should come up automatically. Once it works you can remove the temporary external display and just plug in the iPad day-to-day.

---

## 🩺 Self-check: doctor

Whenever you troubleshoot, run this first:
```bash
./src/doctor.sh
```
It checks and prints in color: macOS version, chip/model, SidecarLauncher, BetterDisplay, iPad connection, configuration, launch-at-login status — with targeted suggestions.

---

## ⚙️ Configuration

Copy the example and tweak as needed (it works without changes; everything auto-detects by default):
```bash
cp config.example.sh config.sh
```

| Option | Default | Description |
|---|---|---|
| `IPAD_NAME` | empty (auto-detect) | iPad device name; set it explicitly if you have multiple iPads |
| `POLL_INTERVAL` | `5` | Daemon poll interval (seconds) |
| `DISABLE_BUILTIN` | `auto` | `auto`/`off`: whether to script-disconnect the internal screen |
| `BUILTIN_UUID` | empty (auto-detect) | Internal-screen UUID; fill in manually if auto-detection is off |
| `SIDECAR_WIRED` | `on` | Whether to force wired Sidecar (more stable) |
| `NOTIFY` | `on` | Whether to pop a macOS notification on success / failure |
| `MAX_LOG_BYTES` | `1048576` | Log-rotation threshold (bytes) |
| `BACKOFF_MAX` | `60` | Upper bound for connection-failure backoff (seconds) |
| `FAIL_LIMIT` | `5` | Consecutive failures before entering cooldown and warning |
| `SIDECAR_SHA256` / `BD_SHA256` | empty | Optional: verify dependency-binary integrity at install time |

> `config.sh` contains your personal info; it's ignored by `.gitignore` and never uploaded.

---

## 🛠 How it runs under the hood (for developers)

```
headless-sidecar/
├── install.sh                 # one-command install: deps + config + autostart + self-check
├── uninstall.sh               # remove autostart, restore internal screen
├── config.example.sh          # config template (users cp it to config.sh)
├── vendor/
│   └── SidecarLauncher/        # audited, frozen upstream source (main.swift) + LICENSE + NOTICE; compiled locally at install
├── launchagent/
│   └── com.headless-sidecar.daemon.plist.template  # autostart template (with placeholders)
└── src/
    ├── common.sh              # shared functions + auto-detection (iPad name / internal UUID / paths)
    ├── daemon.sh              # daemon loop: detect → connect → set primary
    ├── arrange.sh             # set iPad as primary + disconnect internal screen
    └── doctor.sh              # read-only self-check
```

**Key auto-detection logic (`src/common.sh`)**
- `detect_ipad_name`: reads `config.sh` first, otherwise takes the first device from `SidecarLauncher devices`.
- `detect_sidecar_uuid`: from `BetterDisplay get --identifiers`, finds the UUID of the display whose name/productName contains `Sidecar`.
- `detect_builtin_uuid`: matches internal-panel traits — registryLocation contains `disp0@` and not `dispext`, or productName is `Color LCD`, or the name contains `Built-in`.
- The parsing above prefers `jq` (wrapping the output in `[]` to form a valid JSON array) and falls back to `awk` when `jq` is absent.
- `ipad_plugged`: `ioreg -p IOUSB` matching `USB Product Name` containing iPad precisely (to avoid false hits on hub/reader descriptions).
- `sidecar_active` / `sidecar_is_main`: both judged by the Sidecar display's UUID, not by name.

**Launch at login**: `install.sh` replaces `__DAEMON_PATH__` / `__LOG_DIR__` in the template with real paths, writes
`~/Library/LaunchAgents/com.headless-sidecar.daemon.plist`, and prefers the modern `launchctl bootstrap gui/$UID` (falling back to the legacy `launchctl load`). `RunAtLoad + KeepAlive` keep it resident after login.

**Why not AppleScript clicking Control Center?** Granting osascript "Accessibility" permission under launchd is very unreliable (macOS rejects with `-1719 Not allowed to send Apple events`). Using the SidecarLauncher binary, initiating a connection needs no UI permission at all.

**Contributing**: PRs welcome. After changing scripts, make sure `bash -n` and `shellcheck` pass (CI runs `.github/workflows/ci.yml`), and run `./src/doctor.sh` on real hardware once. Compatibility reports across models / macOS versions are especially welcome (please attach `sw_vers`, `uname -m`, `hw.model`).

---

## ❓ FAQ

**Q: Can the login screen itself be shown on the iPad at boot?**
A: No. Sidecar is a post-login capability — that's an Apple limitation no software can get around. For full visibility use a real external display / dongle / AR glasses.

**Q: SidecarLauncher won't run / connection fails?**
A: It uses a private API and may break across major macOS versions. Watch its [upstream repo](https://github.com/Ocasio-J/SidecarLauncher) for updates; this tool prefers the version under your `bin/`.

**Q: The iPad connected but the primary display didn't switch?**
A: Most likely BetterDisplay isn't running in the background. Open it and enable Launch at login; or run `./src/doctor.sh` for hints.

**Q: The internal screen isn't recognized / not disconnected?**
A: Run `BetterDisplay get --identifiers`, find the internal screen's UUID, and put it in `config.sh`'s `BUILTIN_UUID`; or just use BetterDisplay's "auto-disconnect built-in screen" switch (Apple Silicon).

**Q: Does it work on Intel Macs?**
A: Yes. Sidecar connection and setting the primary both work, but "auto-disconnect internal screen" behaves differently on Intel — use a dongle or script disconnect.

**Q: Is it power-hungry? Will it harm the device?**
A: No. `ioreg` checks are extremely light, once every 5s, with negligible battery impact and no effect on hardware lifespan.

---

## 🧹 Uninstall
```bash
./uninstall.sh
```
It stops and removes launch-at-login, ends the daemon, tries to restore the internal-screen connection, and clears logs. `BetterDisplay.app` and `bin/SidecarLauncher` are **not** deleted — remove them manually if you want.

---

## 🙏 Acknowledgements & dependencies
- [Ocasio-J/SidecarLauncher](https://github.com/Ocasio-J/SidecarLauncher) — command-line Sidecar connection (MIT, © 2023 Jovany Ocasio). Its source is vendored at a pinned commit under `vendor/SidecarLauncher/` (original LICENSE kept, unmodified) and compiled locally at install time.
- [waydabber/BetterDisplay](https://github.com/waydabber/BetterDisplay) — display management / internal-screen disconnect
- Similar approaches for reference: [wberry9813/SideLinker](https://github.com/wberry9813/SideLinker), [raonehere/sidecar-autoconnect](https://github.com/raonehere/sidecar-autoconnect)

This project only orchestrates the tools above; it does not modify or redistribute their source. Copyrights belong to their respective authors.

---

## 📄 License
MIT License, see [LICENSE](LICENSE).

> Disclaimer: This tool is provided "as is". Third-party components that rely on private APIs may break. Assess the risk yourself; the author is not liable for any data loss or device issues.
