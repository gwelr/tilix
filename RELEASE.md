ttyx_ Release Process
=====================

## Pre-release

1. Ensure `master` branch is up to date:
   ```
   git checkout master && git pull
   ```

2. Verify all CI checks pass on the latest commit.

3. Update version number in both:
   - `meson.build` (project version field)
   - `source/gx/tilix/constants.d` (`APPLICATION_VERSION`)

4. Write NEWS entries:
   ```
   git shortlog <previous-tag>.. | grep -i -v trivial | grep -v Merge > NEWS.new
   ```
   Then manually edit `NEWS` following this format:
   ```
   Version X.Y.Z
   ~~~~~~~~~~~~~~
   Released: YYYY-MM-DD

   Features:

   Bugfixes:

   Build & Performance:

   Security:
   ```

5. Run `extract-strings.sh` to update translation templates.

6. Commit all release prep changes:
   ```
   git commit -a -m "Release version X.Y.Z"
   git push
   ```

## Build release artifact

7. Build the release binary:
   ```
   meson setup builddir-release --buildtype=release -Dstrip=true --wipe
   ninja -C builddir-release
   meson test -C builddir-release --print-errorlogs
   ```

8. Assemble the tarball:
   ```
   mkdir -p /tmp/ttyx-package
   cp builddir-release/ttyx /tmp/ttyx-package/
   cp -r data/schemes /tmp/ttyx-package/
   cp -r data/icons /tmp/ttyx-package/
   cp data/gsettings/io.github.gwelr.ttyx.gschema.xml /tmp/ttyx-package/
   cp data/dbus/io.github.gwelr.ttyx.service /tmp/ttyx-package/
   cp data/pkg/desktop/io.github.gwelr.ttyx.desktop.in /tmp/ttyx-package/io.github.gwelr.ttyx.desktop
   cp data/scripts/ttyx_int.sh /tmp/ttyx-package/
   cp builddir-release/data/ttyx.gresource /tmp/ttyx-package/
   cp data/man/ttyx.1 /tmp/ttyx-package/
   cp LICENSE README.md /tmp/ttyx-package/
   cd /tmp && tar czf ttyx-X.Y.Z_x86_64-linux-gnu.tar.gz -C ttyx-package .
   ```

## Build Flatpak bundle

9. Update the Flatpak manifest tag to the new version:
   - `flatpak/io.github.gwelr.ttyx.yaml` (change `tag: vX.Y.Z`)

10. Build the Flatpak (requires `flatpak-builder`, GNOME 48 SDK):
    ```
    flatpak-builder --user --install-deps-from=flathub --force-clean \
      builddir-flatpak flatpak/io.github.gwelr.ttyx.yaml
    flatpak build-bundle ~/.local/share/flatpak/repo \
      /tmp/ttyx-X.Y.Z_x86_64.flatpak io.github.gwelr.ttyx
    ```

    See `flatpak/README.md` for prerequisites and theme integration notes.

## Sign and checksum

11. Generate signed checksums (include both tarball and Flatpak):
    ```
    sha256sum /tmp/ttyx-X.Y.Z_x86_64-linux-gnu.tar.gz \
              /tmp/ttyx-X.Y.Z_x86_64.flatpak \
              > /tmp/ttyx-X.Y.Z_SHA256SUMS
    gpg --clearsign /tmp/ttyx-X.Y.Z_SHA256SUMS
    ```

## Publish

12. Create the GitHub release **with all assets in one shot** (do NOT
    upload assets after creation — GitHub's immutable releases will
    block subsequent uploads):
    ```
    gh release create vX.Y.Z -R gwelr/ttyx_ \
      --title "ttyx_ vX.Y.Z" \
      --target master \
      --notes-file /path/to/release-notes.md \
      /tmp/ttyx-X.Y.Z_x86_64-linux-gnu.tar.gz \
      /tmp/ttyx-X.Y.Z_x86_64.flatpak \
      /tmp/ttyx-X.Y.Z_SHA256SUMS.asc
    ```

## Post-release

13. Bump version to next development version in:
    - `meson.build`
    - `source/gx/tilix/constants.d`

14. Commit and push:
    ```
    git commit -a -m "chore: Post-release version bump to X.Y.Z+1"
    git push
    ```

## Verify

Users can verify release integrity with:
```
# Check file integrity
sha256sum -c ttyx-X.Y.Z_SHA256SUMS.asc 2>/dev/null

# Verify GPG signature
gpg --verify ttyx-X.Y.Z_SHA256SUMS.asc
```

Users can install the Flatpak bundle with:
```
flatpak install --user ttyx-X.Y.Z_x86_64.flatpak
```

## Notes

- All commits and tags are GPG-signed (key: `2CAAD12074F3C056`)
- CI Actions are pinned to commit SHAs (not mutable tags)
- Never create a release then try to add assets — always include them at creation time
- Flatpak builds require GNOME 48 SDK; see `flatpak/README.md` for details
