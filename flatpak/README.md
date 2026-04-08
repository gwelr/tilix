# ttyx_ Flatpak

## Building

### Prerequisites

```bash
sudo apt-get install -y flatpak-builder
flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install --user flathub org.gnome.Platform//48 org.gnome.Sdk//48
```

### Build and install locally

```bash
flatpak-builder --user --install-deps-from=flathub --install --force-clean \
  builddir-flatpak flatpak/io.github.gwelr.ttyx.yaml
```

### Run

```bash
flatpak run io.github.gwelr.ttyx
```

## Development builds

For testing local changes, the manifest source can be switched from a git tag
to the local tree:

```yaml
# Release (default):
sources:
  - type: git
    url: https://github.com/gwelr/ttyx_.git
    tag: v1.0.2

# Local development:
sources:
  - type: dir
    path: ..
```

## GTK theme integration

The Flatpak sandbox only includes the Adwaita GTK theme by default. If ttyx_
looks different from your native apps, install the matching GTK3 theme
extension. For example, on Ubuntu with Yaru:

```bash
# List available themes
flatpak search org.gtk.Gtk3theme

# Install your theme (example for Yaru variants)
flatpak install --user flathub org.gtk.Gtk3theme.Yaru
flatpak install --user flathub org.gtk.Gtk3theme.Yaru-dark
```

The theme name must match exactly what your desktop reports. Check your current
theme with:

```bash
gsettings get org.gnome.desktop.interface gtk-theme
```

## Architecture notes

- **LDC compiler**: Bundled as a self-contained tarball (statically links LLVM)
  rather than using the `org.freedesktop.Sdk.Extension.ldc` SDK extension,
  which has persistent LLVM version mismatches with the GNOME runtime.

- **VTE**: Built from source (0.76.3, matching Ubuntu 24.04 LTS) since the
  GNOME runtime only ships the GTK4 VTE widget and ttyx_ requires GTK3.

- **D runtime**: The phobos and druntime shared libraries are copied to
  `/app/lib/` before the LDC cleanup stage removes `/app/ldc/`.

- **Host shell**: ttyx_ uses the Flatpak Development D-Bus API to spawn the
  user's host shell, with `ttyx-flatpak-toolbox` providing passwd/PID lookups
  from within the sandbox.
