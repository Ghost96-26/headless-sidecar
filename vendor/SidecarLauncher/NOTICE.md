# Vendored: SidecarLauncher

This directory contains a **frozen, audited copy** of the source of
[Ocasio-J/SidecarLauncher](https://github.com/Ocasio-J/SidecarLauncher),
included here so that `install.sh` can **build the binary locally from source**
instead of downloading a prebuilt artifact.

## Why vendored

Initiating a Sidecar connection requires Apple's **private** `SidecarCore`
framework — there is no public/official API. Any tool that does this must use
that private API. To minimise the trust surface we:

1. **Do not download any prebuilt binary** (no "trust a stranger's artifact").
2. **Freeze the source at a reviewed commit** in this repo, so future
   upstream changes / repo compromise cannot affect our users.
3. **Compile locally** with Apple's own Swift toolchain at install time.

The remaining risk is inherent and unavoidable for *any* Sidecar automation:
the private API may change or be removed by a future macOS version. If that
happens the build still succeeds but the binary may stop working — see the
project README for fully-official alternatives (real external display, or
Apple Screen Sharing + a display dongle).

## Provenance

- Upstream: https://github.com/Ocasio-J/SidecarLauncher
- Pinned commit: `092242edf68217b0c40545fdecede773a9cf251b`
- License: MIT (see `LICENSE`, © 2023 Jovany Ocasio)
- File vendored: `SidecarLauncher/main.swift` → `main.swift` (verbatim, unmodified)
- `main.swift` sha256: `fae6395bc283dada7ba61cbe179c91ec1632e4f8b6b00a5057ece00705a9a35a`

## Audit summary (what the source does)

170 lines, `import Foundation` only. It:
- parses argv (`devices` / `connect <name> [-wired]` / `disconnect <name>`);
- `dlopen`s `/System/Library/PrivateFrameworks/SidecarCore.framework/SidecarCore`;
- via the Obj-C runtime calls `SidecarDisplayManager.sharedManager`, `devices`,
  `connectToDevice:completion:` / `connectToDevice:withConfig:completion:` /
  `disconnectFromDevice:completion:`;
- prints device names / `connected` / `disconnected` and sets exit codes.

It performs **no** network access, **no** file writes, **no** shell execution,
**no** persistence, and reads **no** environment/secrets. It only calls the
local Sidecar API.

## Updating

To bump the vendored source: replace `main.swift` from a specific upstream
commit, re-audit it, then update the pinned commit and sha256 above.
