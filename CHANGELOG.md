# Changelog

All notable changes to **ttyx_** are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **OSC 11 (dynamic background color) support** — apps like neovim and theme-switching scripts can now change the terminal background at runtime via `printf '\033]11;#rrggbb\007'`; reset with `printf '\033]111\007'`. ttyx_ no longer disables VTE's native background painting, so OSC 11 is honoured natively. The badge draw signal moved from the BEFORE phase to AFTER so badges still render on top of the terminal output (#47).
- Documentation site at <https://gwelr.github.io/ttyx_/> — built with Jekyll + just-the-docs, manual content adapted from upstream Tilix under MPL-2.0 (#59, #60, #61, #63, #64).
- Unit test coverage for the password manager row-removal path, extracted as `removeRowById` (#54).
- Unit tests for the proxy URL builder, sensitive-value redaction, and process introspection helpers (#55, #56, #58).

### Changed
- **`TerminalRegex` converted to a tagged union over `BuiltinRegex` / `CustomRegex`** — the previous flat struct carried a `command` field that was "only used for custom regex", a conditionally-meaningful field that nothing enforced at the type level. Splitting the two variants makes it impossible at compile time to attach a command to a builtin URL regex or to construct a custom-link regex without one (the `CustomRegex` constructor's `in` contracts require a non-empty pattern and a non-null command). The custom-link click handler in `Terminal.openURI` now dispatches via `match!` — the `command` access is reachable only inside the `CustomRegex` branch. UFCS accessors (`pattern`, `caseless`, `flavor`) keep call-site code at consumers that only need shared fields unchanged. Wire format and runtime behaviour unchanged. Mirrors the same pattern as #33's `SyncInputEvent` SumType conversion (#87).
- **Synchronized-input event payload converted to a tagged union** — `SyncInputEvent` is now a `std.sumtype.SumType` of `SyncKeyPressEvent`, `SyncTextEvent`, `SyncInsertTerminalNumberEvent`, `SyncResetEvent`, and `SyncResetAndClearEvent`. Each variant carries exactly the fields it needs and rejects null payloads via `in` contracts, so it is now impossible at compile time to construct a key-press event without an `Event` or a text event without a payload. The consumer in `Terminal.handleSyncInput` dispatches via `match!`, which is exhaustive at compile time — adding a future variant without handling it will fail to compile (#33).
- **Terminal serialisation centralised on a typed `TerminalSnapshot` struct** — replaces the ad-hoc JSON building that was scattered between `session.d` and `terminal.d`. Adding a persisted field is now a single struct change instead of coordinated edits in two files. Wire format unchanged; `Nullable!string` makes optional override fields explicit; the dead per-terminal `width`/`height` writes (never read on the per-terminal deserialise path) are dropped from the format. Lenient deserialisation: missing keys default-initialise, unknown keys are ignored. Verified by a golden-JSON roundtrip test (#34).
- **`enable-wide-handle` now defaults to `true`** — the splitter between split terminals is now wide by default, making it easier to see and grab on dark themes and HiDPI displays. Existing users who have explicitly toggled this preference are unaffected; only fresh installs and users who never touched it pick up the new default. Set to `false` to restore the previous 1-pixel splitter (#48).
- Extracted pure helpers out of the terminal widget module to reduce complexity and unlock testing: `pointInTriangle` → `gx.util.geometry`, `parsePairs` → `gx.util.string`, process introspection → `gx.util.proc` (#57, #58).
- Process root detection now goes through a single `readProcStatus` helper; the `/proc/[pid]/status` parser was previously duplicated across `monitor.d` and `activeprocess.d` (#58).
- Debug log path resolution now prefers `$XDG_RUNTIME_DIR/ttyx.log` over `/tmp/ttyx.log` when file logging is enabled (#55).

### Fixed
- **Triggers with an unrecognised action name are now skipped instead of silently rewritten to UpdateState** — the `TerminalTrigger` constructor used to fall through to `default: break;` on any unknown action name, leaving `action` at its enum init value (`UPDATE_STATE`). A typo, a stale config from a different fork, or a future schema migration with renamed actions would silently rewrite the user's trigger to a working-but-wrong UpdateState. The constructor now throws `UnknownTriggerActionException`; the loader in `Terminal.loadTriggers` catches and logs `Skipping trigger entry with unknown action 'X' (pattern 'Y')`. Note: this only affects users who have triggers configured (the trigger UI is gated behind a Tilix-patched VTE — see #95) (#88).
- **Trigger templates: `$0` now substitutes the whole match (not the first capture group)** — `replaceMatchTokens` had a `size_t` off-by-one underflow (`i - 1` on the first iteration wrapped to `size_t.max`), which silently shifted every token by one: `$0` got the first capture group, `$1` got the second, and the whole match was never substitutable. The function now iterates in reverse to also handle `$10`/`$1` correctly (without reverse iteration the `$1` pass would corrupt the start of `$10`, `$11`, ...). User-configured triggers that relied on the bugged behaviour will need their template indices shifted up by one (#84).
- **Maximized terminal not restored on session load** — loading a saved session whose JSON has `maximized: true` on a child no longer leaves the user looking at the half-empty Paned. Root cause: `gtk_stack_set_visible_child` is a silent no-op when the target child has never been shown, and on the restore path `parseSession` runs before `nb.showAll()` cascades show to the stack pages. Fixed by explicitly calling `show()` on the maximized stack page before switching to it; idempotent in the user-triggered Ctrl+Shift+X path. Pre-existing since the upstream Tilix 2017 implementation; surfaced in #91 during the #89 refactor smoke test (#91).
- **Password manager delete silently failed** — the delete button claimed success even when the keyring operation failed, and legacy-schema entries from the Tilix migration couldn't be deleted at all (#50, #54).
- **Proxy URL malformed** — the generated `http_proxy` URL had a redundant leading `@` before userinfo, which strict RFC-3986 parsers reject; credentials were also not percent-encoded, so passwords containing `@`, `:`, `/` broke the URL entirely (#51, #55).
- **`https_proxy` missing authentication** — the auth block was gated on `scheme == "http"` so the HTTPS proxy never received credentials even when configured (#51, #55).
- **Debian Testing CI build** — GtkD bindings were removed from Debian Testing's apt archive; CI now builds GtkD from source on that image (#49).
- **CI: LDC compiler installed from upstream tarball** — `ldc` is currently missing from Debian Testing during a transition. All container-based CI images (Debian Stable, Debian Testing, Ubuntu Noble) now install LDC 1.40.0 from the official `ldc-developers` GitHub release tarball instead of apt, so CI is no longer coupled to any one distro's apt archive. Same mitigation pattern as the GtkD-from-source fix from #49.

### Security
- **Config migration hardened against symlink attacks** — `migrateConfigBetween` now refuses to follow symlinks and skips existing target files during the Tilix → ttyx_ first-run migration (#49).
- **Sensitive values redacted in trace logs** — environment variables whose keys contain `password`/`token`/`secret`/`auth` are replaced with `[redacted]`; proxy URLs have their userinfo stripped before logging (#51, #55, #56).
- **Command-line arguments and hyperlink traces redacted** — URL userinfo is stripped from argv and from terminal hyperlink click events before they reach any log sink (#56).

## [1.1.1] — 2026-04-18

Maintenance release focused on identity: ttyx_ became its own project, with automatic migration for users coming from Tilix.

### Added
- **Automatic migration from Tilix on first run**: `~/.config/tilix/` is copied to `~/.config/ttyx/` (original kept as backup); libsecret entries stored under the old Tilix schema are still read and new passwords are written to the ttyx schema; both `TTYX_ID` and `TILIX_ID` are set in shells so existing shell integrations keep working.
- New "Migrating from Tilix" section in README.
- New "Troubleshooting" section covering stale icon caches and Wayland Quake-mode limitations.
- `ROADMAP.md` documenting vision and phase plan.

### Changed
- Renamed user-visible Tilix references in the Nautilus menu, shortcuts window, GSettings descriptions, icon filenames, and log/temp paths.
- Rewrote the man page under ttyx_ identity.
- Dropped 30 stale translation files that still carried Tilix-branded source strings.
- Release process simplified: ship only the Flatpak bundle with signed checksums. The hand-assembled binary tarball was dropped — distro packagers should build from source, Flatpak covers direct users.

### Fixed
- Color scheme list no longer shows duplicates when the same scheme exists in both user config and system data dirs (user config wins).
- Post-install script writes a minimal `index.theme` at the install prefix so `gtk-update-icon-cache` can generate a valid icon cache.
- AppStream metadata no longer includes stale Tilix release entries.

## [1.1.0] — 2026-04-15

A major security and performance release. ttyx_ positioned itself as a security-conscious tiling terminal emulator for Linux.

### Added
- **Paste protection** — bracketed-paste escape stripping (blocks `ESC[200~` / `ESC[201~` injection), multi-line paste review dialog, dangerous-command detection (`sudo`, `su`, `rm -rf`, `curl | bash`, `dd if=`, `mkfs`, `chmod 777`, fork bombs), per-paste warnings that appear every time rather than once per session.
- **Clipboard auto-clear** — clears clipboard after a configurable 5–300 s timeout to prevent sensitive data from lingering.
- **SSH session indicator** — blue tint and label when connected via ssh, scp, sftp, mosh, or sshfs.
- **Root indicator** — red tint and label when running with elevated privileges.
- **Core-dump protection** — `prctl(PR_SET_DUMPABLE, 0)` blocks `/proc/pid/mem` reads and core-dump generation; toggleable for debugging.
- **In-memory-only scrollback** — removed the unlimited scrollback option; capped at 256–999,999 lines, never written to disk.
- **Secure Clear** (`Ctrl+Shift+L`) — on-demand wipe of the scrollback buffer.
- 119 unit tests covering security, clipboard, rendering, and process-monitor modules.
- Security options consolidated under **Preferences → Advanced → Security** with descriptive labels.

### Changed
- **ProcessMonitor optimization** — idle CPU reduced from 1.4% to 0.1% by replacing full `/proc` scans with targeted foreground-process lookups.
- **Major terminal.d decomposition** — `terminal.d` (178 KB) had `ClipboardHandler`, `TerminalRenderer`, `ProcessQuery`, `SpawnHandler`, `FlatpakHostCommands` extracted.
- PreferenceRegistry pattern replaced the switch-based preference dispatch.

### Fixed
- GC crash when opening preferences on GLib 2.84+ (Flatpak environments).
- SSH and root indicators not clearing when the foreground process exits.
- Color scheme test when schemes are not installed in XDG paths.

## [1.0.2] — 2026-04-07

First release under the ttyx_ name.

### Added
- New tabs open next to the current tab (not at the end).
- Option to strip trailing whitespace on copy.
- Visual indicator when terminal is running as root.
- `~` and `@` added to default word-select characters.
- 8 new built-in color schemes: Catppuccin (Latte, Mocha), Dracula, Gruvbox (Dark, Light), Nord, One Dark, Tokyo Night.
- Comprehensive unit test suite across utility and core modules.

### Changed
- Release build optimizations: proper `-O3`, `-release`, `-inline`, `-boundscheck=off` flags for both meson and dub. Binary size dropped from 17 MB (debug) to 3.3 MB (release, stripped).

### Fixed
- Crash on malformed URIs in OSC 7 and drag-and-drop.
- Color schemes with `use-theme-colors` incorrectly shown as "Custom".
- Title bar markup rendering (`setText` instead of `setMarkup`).
- Focus stealing on terminal restart.
- Proxy host protocol prefix duplication.
- Empty clipboard text after stripping whitespace.
- Preferences dialog segfaults when changing profiles or closing the dialog.

## Attribution

ttyx_ is a fork of [Tilix](https://github.com/gnunn1/tilix) by Gerald Nunn, licensed under [MPL-2.0](LICENSE). Release history before 1.0.2 is part of the upstream Tilix project.
