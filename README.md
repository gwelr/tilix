![Build Status](https://github.com/gwelr/tilix/workflows/Build%20Test/badge.svg)

# ttylix

**Tilix, but with a pulse.**

ttylix is an actively maintained fork of [Tilix](https://github.com/gnunn1/tilix), the tiling terminal emulator for Linux. The original project did amazing work — but with development stalled and a growing list of unaddressed bugs, ttylix picks up where it left off.

Same great terminal. Fresh fixes, new features, and someone actually reading the issues.

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
- Comprehensive unit test suite

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

ttylix is written in [D](https://dlang.org/) using GTK 3 and the GtkD bindings.

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

## Contributing

This is a freetime project. I work on what interests me, when I have time.

**Issues** must include: what happened, what was expected, steps to reproduce, and environment details (distro, VTE version, etc.). Incomplete issues will be closed without review.

**Pull requests** are the best way to get something changed. That said, PRs may be declined if they don't fit the project direction — no hard feelings. If you disagree, fork it. That's how this project started too.

No support is provided.

## Credits

ttylix is built on the shoulders of [Tilix](https://github.com/gnunn1/tilix) by Gerald Nunn and its contributors. Huge thanks to everyone who made the original project what it is.

## License

[MPL-2.0](LICENSE)
