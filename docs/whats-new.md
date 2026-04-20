---
title: What's new vs Tilix
layout: default
nav_order: 3
permalink: /whats-new/
---

# What's new in ttyx_ vs Tilix

ttyx_ is a fork of [Tilix](https://github.com/gnunn1/tilix) that picks up where upstream development stalled. This page summarizes what has changed: new features, security hardening, bug fixes, and infrastructure work.

For version-by-version release notes, see the [changelog]({{ site.baseurl }}/changelog/).

## Security hardening

The headline difference. ttyx_ adds a **Preferences → Advanced → Security** panel and ships the following protections; none of them exist in upstream Tilix.

### Paste protection

- **Bracketed paste escape stripping** silently removes `ESC[200~` / `ESC[201~` sequences that could break out of the shell's paste-mode and inject commands. Always active, no option to disable.
- **Multi-line paste review** shows a review dialog before pasting multi-line content, so you can inspect and edit before the text reaches the shell. Default: on.
- **Dangerous command detection** flags pastes containing `sudo`, `su`, `rm -rf`, `curl | bash`, `dd if=`, `mkfs`, `chmod 777`, fork bombs, and similar patterns.
- **Per-paste warnings** — the unsafe-paste warning now appears every time, not just once per session.

### Clipboard protection

- **Clipboard auto-clear** — automatically clears the clipboard after a configurable 5–300 s timeout following a copy from the terminal, preventing sensitive data like passwords and tokens from lingering. Only clears if the clipboard still holds the content you copied. Default: off, 30 s.

### Visual indicators

- **Root indicator** — red tint and "as root" label when any process in the terminal is running with elevated privileges.
- **SSH indicator** — blue tint and "ssh" label when connected via ssh, scp, sftp, mosh, or sshfs.

### Memory protection

- **Core dump protection** — the process is marked non-dumpable via `prctl(PR_SET_DUMPABLE, 0)`, blocking `/proc/pid/mem` reads and core-dump generation. Disable from preferences if you need to attach GDB.
- **In-memory-only scrollback** — the unlimited scrollback option was removed; the scrollback is capped at 256–999,999 lines and kept entirely in memory. VTE never writes history to disk.
- **Secure Clear** (`Ctrl+Shift+L`) — on-demand wipe of the scrollback buffer, available in the hamburger menu and the right-click context menu.

### Logging hygiene

- Sensitive environment variables (proxy URLs, tokens, passwords, secrets) are redacted before being written to trace logs.
- Command-line arguments and clicked-hyperlink traces have their URL userinfo stripped before logging.
- When file logging is enabled, the log file is written to `$XDG_RUNTIME_DIR/ttyx.log` (mode 0700 by systemd convention) instead of world-readable `/tmp/ttyx.log`.

## Fixed bugs carried over from upstream

Upstream Tilix development stalled with known issues unresolved. ttyx_ ships fixes for:

- **Crash on malformed OSC 7 URIs** and drag-and-drop payloads.
- **Color schemes incorrectly shown as "Custom"** when `use-theme-colors` was enabled.
- **Title bar markup rendering** using `setText` instead of `setMarkup`.
- **Focus stealing on terminal restart.**
- **Proxy host protocol prefix duplication** in generated env vars.
- **Preferences dialog segfaults** when changing profiles or closing the dialog, including a GC-interaction crash on GLib 2.84+ (Flatpak).
- **Empty clipboard after whitespace stripping.**
- **Root/SSH indicators not clearing** when the foreground process exits.
- **Password-manager delete** silently failing for legacy-schema entries and claiming success even when the keyring operation failed.
- **Malformed proxy URL** with a redundant leading `@`, plus unencoded credentials that broke the URL if they contained `@`, `:`, or `/`.
- **`https_proxy` never received authentication credentials** even when configured.
- **Symlink-attack susceptibility** during the Tilix → ttyx_ config migration.

## New features and quality-of-life improvements

- **New tabs open next to the current tab** (not at the end).
- **Strip trailing whitespace on copy** — optional toggle.
- **`~` and `@` added to default word-select characters** — double-click selects full paths and email-like tokens.
- **8 new color schemes** ship in-box: Catppuccin (Latte, Mocha), Dracula, Gruvbox (Dark, Light), Nord, One Dark, Tokyo Night.

## Performance

- **ProcessMonitor optimization** cut idle CPU from 1.4% to 0.1% by replacing full `/proc` scans with targeted foreground-process lookups.
- **Release build optimizations** — proper `-O3`, `-release`, `-inline`, `-boundscheck=off` flags for both Meson and Dub; binary size dropped from 17 MB (debug) to 3.3 MB (release, stripped).

## Infrastructure

- **Unit test suite** — from zero to more than 119 tests covering security, clipboard, rendering, process monitoring, and the extracted utility modules. Test count continues to grow with each refactor.
- **Major `terminal.d` decomposition** — `ClipboardHandler`, `TerminalRenderer`, `ProcessQuery`, `SpawnHandler`, `FlatpakHostCommands`, and geometry / string / proc helpers were extracted from what was originally a 178 KB monolithic widget file.
- **PreferenceRegistry pattern** replaces the switch-based preference dispatch.
- **CI coverage** across Debian Stable, Debian Testing, and Ubuntu LTS via Podman containers, plus Dub builds with both DMD and LDC.

## Identity and migration

- ttyx_ uses its own schema identifier (`io.github.gwelr.ttyx`) for GSettings.
- libsecret entries use `io.github.gwelr.ttyx.Password`; legacy entries stored under `com.gexperts.tilix.Password` are still read on first run.
- Shells inside terminals get both `TTYX_ID` and `TILIX_ID` set, so existing shell-integration scripts continue to work.
- On first run, `~/.config/tilix/` is copied to `~/.config/ttyx/`; the original is left in place as a backup.

See [Migrating from Tilix](https://github.com/gwelr/ttyx_#migrating-from-tilix) for the full migration checklist.
