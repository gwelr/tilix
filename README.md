![Build Status](https://github.com/gwelr/tilix/workflows/Build%20Test/badge.svg)

<p align="center">
  <img src="data/hey-ttyx.svg" alt="ttyx_ logo" width="128">
</p>

# ttyx_

**Tilix, but with a pulse.**

ttyx_ is an actively maintained fork of [Tilix](https://github.com/gnunn1/tilix), the tiling terminal emulator for Linux. The original project did amazing work but with development stalled and a growing list of unaddressed bugs, ttyx_ picks up where it left off.

Same great terminal. Fresh fixes, new features, and someone actually reading the issues (maybe).

## What's new since Tilix

- Crash fix for malformed OSC 7 URIs
- Fix for color schemes incorrectly shown as "Custom"
- New tabs open next to the current tab (not at the end)
- Strip trailing whitespace on copy (optional)
- Visual indicator when running as root
- Fixed title bar markup rendering
- Fixed focus stealing on terminal restart
- Fixed proxy host protocol duplication
- Added `~` and `@` to word-select characters
- Preferences dialog segfault fixes
- 8 new color schemes: Catppuccin (Latte, Mocha), Dracula, Gruvbox (Dark, Light), Nord, Solarized (Dark, Light)
- Release build optimizations (proper `-O3` and `-release` flags)
- Comprehensive unit test suite (119 tests)
- **Security hardening** (see below)

## Security features

ttyx_ is designed to be a security-conscious terminal. All security options are in **Preferences > Advanced > Security**.

### Paste protection
Pasting content from the clipboard can be dangerous — a malicious website could place harmful commands in your clipboard. ttyx_ protects you with:

- **Bracketed paste escape stripping** — silently removes `ESC[200~`/`ESC[201~` sequences that could break out of the shell's paste mode and inject commands. Always active, no option to disable.
- **Multi-line paste review** — shows a review dialog before pasting multi-line content, letting you inspect and edit before it reaches the shell. *(Default: on)*
- **Dangerous command detection** — flags pastes containing `sudo`, `su`, `rm -rf`, `curl | bash`, `dd if=`, `mkfs`, `chmod 777`, fork bombs, and other dangerous patterns.

### Clipboard protection
- **Auto-clear** — automatically clears the clipboard after a configurable timeout (5–300 seconds) following a copy from the terminal. Prevents sensitive data like passwords and tokens from lingering. Only clears if the clipboard still holds the content you copied (won't wipe something another app put there). *(Default: off, 30 seconds)*

### Visual indicators
- **Root indicator** — red tint and "as root" label when any process in the terminal is running with elevated privileges. *(Default: on)*
- **SSH indicator** — blue tint and "ssh" label when connected via ssh, scp, sftp, mosh, or sshfs. *(Default: on)*

### Memory protection
- **Core dump protection** — marks the process as non-dumpable via `prctl(PR_SET_DUMPABLE, 0)`, preventing `/proc/pid/mem` reads and core dump generation. Disable in preferences if you need to attach GDB. *(Default: on)*
- **In-memory-only scrollback** — scrollback is capped at 256–999,999 lines and kept entirely in memory. VTE never writes history to disk.
- **Secure Clear** (`Ctrl+Shift+L`) — wipe the scrollback buffer when sensitive data has been displayed. Available in the hamburger menu and right-click context menu.

## Features

* Tile terminals any way you like — split horizontally, vertically, go wild
* Drag and drop terminals within and between windows
* Synchronized input across terminals
* Save and restore terminal layouts
* Custom titles, color schemes, and hyperlinks
* Transparent backgrounds
* [Quake-mode](https://github.com/gnunn1/tilix/wiki/Quake-Mode) (drop-down terminal)
* Automatic profile switching based on hostname/directory
* Trigger support and badges (with compatible VTE)

## Requirements

* GTK 3.18+
* VTE 0.46+ (0.76+ recommended)
* dconf / GSettings

## Building

ttyx_ is written in [D](https://dlang.org/) using GTK 3 and the GtkD bindings.

### With Meson (recommended)

```bash
# Install dependencies (Debian/Ubuntu)
sudo apt-get install libgtk-3-dev libvte-2.91-dev libatk1.0-dev \
  libcairo2-dev libpango1.0-dev librsvg2-dev libglib2.0-dev \
  libsecret-1-dev libgtksourceview-3.0-dev libpeas-dev dh-dlang

# Build
meson setup builddir --buildtype=release
ninja -C builddir

# Install
sudo ninja -C builddir install

# Run tests
meson test -C builddir --print-errorlogs
```

### With Dub

```bash
dub build --build=release --compiler=ldc2
```

## Migrating from Tilix

ttyx_ automatically migrates your configuration on first run:

- **Session files**: `~/.config/tilix/` is copied to `~/.config/ttyx/` (the original is kept as backup)
- **Saved passwords**: existing passwords stored under the old Tilix schema are read automatically; new passwords are saved under the ttyx schema
- **Environment variable**: `TILIX_ID` is still set for backwards compatibility alongside the new `TTYX_ID`
- **GSettings**: ttyx_ uses its own schema (`io.github.gwelr.ttyx`). Tilix settings are not migrated — configure preferences in ttyx_ directly

After verifying ttyx_ works correctly, you can remove `~/.config/tilix/` manually.

## Troubleshooting

### App icon shows as a broken placeholder

This typically means a stale icon cache from a previous install (often Flatpak). Clear the user-level cache and let GTK regenerate it:

```bash
rm -f ~/.local/share/flatpak/exports/share/icons/hicolor/icon-theme.cache
gtk-update-icon-cache -f ~/.local/share/flatpak/exports/share/icons/hicolor/
```

Then relaunch ttyx_.

### Quake mode doesn't position correctly (Wayland)

Quake mode relies on X11 window positioning APIs that Wayland compositors don't expose to applications. On Wayland, behavior is compositor-dependent — GNOME Shell in particular cannot position windows from the application side.

**Workaround**: use ttyx_ under an X11 session if you need Quake mode. On wlroots-based compositors (Sway, Hyprland), support may be added in a future release via the `wlr-layer-shell` protocol.

## Contributing

This is a freetime project. I work on what interests me, when I have time.

**Issues** must include: what happened, what was expected, steps to reproduce, and environment details (distro, VTE version, etc.). Incomplete issues will be closed without review.

**Pull requests** are the best way to get something changed. That said, PRs may be declined if they don't fit the project direction — no hard feelings. If you disagree, fork it. That's how this project started too.

No support is provided.

## Credits

ttyx_ is built on the shoulders of [Tilix](https://github.com/gnunn1/tilix) by Gerald Nunn and its contributors. Huge thanks to everyone who made the original project what it is.

## License

[MPL-2.0](LICENSE)
