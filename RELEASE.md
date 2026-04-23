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
   - `source/gx/ttyx/constants.d` (`APPLICATION_VERSION`)

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

   Miscellaneous:
   ```
   Note: `appstreamcli news-to-metainfo` only accepts standard section names
   (Features, Bugfixes, Miscellaneous, Notes, Contributors). Use `Features:`
   for security items prefixed with "Security:".

5. Run `extract-strings.sh` to update translation templates.

6. Commit all release prep changes:
   ```
   git commit -a -m "Release version X.Y.Z"
   git push
   ```

## Build Flatpak bundle

7. Update the Flatpak manifest tag to the new version:
   - `flatpak/io.github.gwelr.ttyx.yaml` (change `tag: vX.Y.Z`)

8. Build the Flatpak (requires `flatpak-builder`, GNOME 48 SDK):
    ```
    flatpak-builder --user --install-deps-from=flathub --force-clean \
      builddir-flatpak flatpak/io.github.gwelr.ttyx.yaml
    flatpak build-bundle ~/.local/share/flatpak/repo \
      /tmp/ttyx-X.Y.Z_x86_64.flatpak io.github.gwelr.ttyx
    ```

    See `flatpak/README.md` for prerequisites and theme integration notes.

## Sign and checksum

9. Generate signed checksums:
    ```
    sha256sum /tmp/ttyx-X.Y.Z_x86_64.flatpak > /tmp/ttyx-X.Y.Z_SHA256SUMS
    gpg --clearsign /tmp/ttyx-X.Y.Z_SHA256SUMS
    ```

## Publish

10. Create the GitHub release **with all assets in one shot** (do NOT
    upload assets after creation — GitHub's immutable releases will
    block subsequent uploads):
    ```
    gh release create vX.Y.Z -R gwelr/ttyx_ \
      --title "ttyx_ vX.Y.Z" \
      --target master \
      --notes-file /path/to/release-notes.md \
      /tmp/ttyx-X.Y.Z_x86_64.flatpak \
      /tmp/ttyx-X.Y.Z_SHA256SUMS.asc
    ```

## Post-release

11. Bump version to next development version in:
    - `meson.build`
    - `source/gx/ttyx/constants.d`

12. Commit and push:
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
