---
title: Install
layout: default
nav_order: 2
permalink: /install/
---

# Install

Two install paths depending on who you are:

| If you are… | Use this |
|--------------|------------|
| An end user who wants to run ttyx_ | [Flatpak](#flatpak-recommended) — signed bundle with checksum verification |
| A distro packager, or a developer building from source | [Source build](#source-build) via Meson or Dub |

---

## Flatpak (recommended)

Flatpak is the supported direct-user distribution channel. Each release ships a signed `.flatpak` bundle and a detached GPG signature over the SHA-256 checksums, so you can verify integrity end-to-end.

### 1. Download the latest release

Grab `ttyx-<version>_x86_64.flatpak` and `ttyx-<version>_SHA256SUMS.asc` from the [latest release](https://github.com/gwelr/ttyx_/releases/latest).

### 2. Verify the bundle

```bash
# Verify the signature on the checksum file
gpg --verify ttyx-<version>_SHA256SUMS.asc

# Verify the bundle's checksum matches
sha256sum -c ttyx-<version>_SHA256SUMS.asc 2>/dev/null
```

Both commands must exit with success before installing.

### 3. Install

```bash
flatpak install --user ttyx-<version>_x86_64.flatpak
```

### 4. Run

Launch from your desktop environment's application menu, or run:

```bash
flatpak run io.github.gwelr.ttyx
```

---

## Source build

For distro packagers, Flatpak maintainers, or developers.

### Requirements

- GTK 3.18+
- VTE 0.46+ (0.76+ recommended — some features like triggers depend on newer VTE releases)
- dconf / GSettings
- A D compiler (LDC recommended for release builds, DMD also supported)

### With Meson (primary, used in CI)

The Meson build resolves the GtkD bindings (`gtkd-3`, `vted-3`) via pkg-config, so those must be installed separately. On distros that still package them, apt covers everything. **Debian Testing / Sid** dropped GtkD from their archive — on those you have to build GtkD from source.

**Debian Stable / Ubuntu:**

```bash
sudo apt-get install libgtk-3-dev libvte-2.91-dev libatk1.0-dev \
  libcairo2-dev libpango1.0-dev librsvg2-dev libglib2.0-dev \
  libsecret-1-dev libgtksourceview-3.0-dev libpeas-dev dh-dlang \
  libgtkd-3-dev libvted-3-dev
```

**Debian Testing / Sid** (no `libgtkd-3-dev` / `libvted-3-dev` in archive):

```bash
sudo apt-get install libgtk-3-dev libvte-2.91-dev libatk1.0-dev \
  libcairo2-dev libpango1.0-dev librsvg2-dev libglib2.0-dev \
  libsecret-1-dev libgtksourceview-3.0-dev libpeas-dev dh-dlang
```

Then build and install GtkD v3.x from source. The CI helper at [.github/ci/make-install-deps-extern.sh](https://github.com/gwelr/ttyx_/blob/master/.github/ci/make-install-deps-extern.sh) has the exact commands.

**Build, install, test:**

```bash
meson setup builddir --buildtype=release
ninja -C builddir
sudo ninja -C builddir install

# Optional: run the unit test suite
meson test -C builddir --print-errorlogs
```

### With Dub

Simpler for development, doesn't need GtkD installed system-wide (Dub pulls the bindings from the registry).

```bash
dub build --build=release --compiler=ldc2

# or with DMD:
dub build --build=release --compiler=dmd

# Unit tests:
dub test --compiler=ldc2
```

---

## First launch

On first run:

- If you previously used Tilix, ttyx_ [automatically migrates]({{ site.baseurl }}/migrating/) your session files and reads existing saved passwords.
- The terminal opens with the default profile. Preferences live under **Hamburger menu → Preferences** (or `Ctrl+,`).
- Security options are consolidated under **Preferences → Advanced → Security**.

---

## Troubleshooting

If the app icon appears as a broken placeholder after a Flatpak install, the likely cause is a stale icon cache. See the [Troubleshooting section in the README](https://github.com/gwelr/ttyx_#troubleshooting) for the one-line fix and for Wayland Quake-mode notes.
