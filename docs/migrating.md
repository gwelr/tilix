---
title: Migrating from Tilix
layout: default
nav_order: 5
permalink: /migrating/
---

# Migrating from Tilix

If you already use [Tilix](https://github.com/gnunn1/tilix), ttyx_ migrates your configuration automatically on first run. You shouldn't need to do anything by hand; this page describes what happens under the hood and how to verify the migration worked.

## What ttyx_ migrates automatically

On first launch, if ttyx_ detects `~/.config/tilix/` and no pre-existing `~/.config/ttyx/`, it performs the following:

- **Session files**: `~/.config/tilix/` is copied (not moved) to `~/.config/ttyx/`. The original directory is left in place as a backup until you decide to remove it.
- **Saved passwords**: existing entries stored in libsecret under the old Tilix schema (`com.gexperts.tilix.Password`) are still readable by the password manager. New passwords you save from ttyx_ go under the new schema (`io.github.gwelr.ttyx.Password`), and deleting an entry removes it from whichever schema it was stored in.
- **Shell integration**: terminals spawned by ttyx_ set both `TTYX_ID` and `TILIX_ID` environment variables, so existing shell-integration scripts (e.g. `tilix_int.sh`, now shipped as [`ttyx_int.sh`]({{ site.baseurl }}/manual/profileswitch/#remote-configuration) for new installs) continue to work during the transition.

The migration is idempotent: if `~/.config/ttyx/` already exists, ttyx_ leaves everything alone and starts normally.

## Security: symlink safety

The migration refuses to follow symlinks during the copy. If a file in the source tree is a symlink (whether into or out of `~/.config/tilix/`), that entry is skipped and a warning is logged. This avoids a class of symlink-swap attacks where an attacker could redirect the migration to write outside your config directory.

If you've set up legitimate symlinks inside `~/.config/tilix/` — for example syncing a subset of files via Syncthing — those entries will not be migrated. Either dereference them before first launch, or recreate them manually inside `~/.config/ttyx/` after launch.

## What is *not* migrated

- **GSettings preferences** (keybindings, profiles, global app settings). ttyx_ uses its own schema at `io.github.gwelr.ttyx` rather than `com.gexperts.Tilix`, and GSettings does not provide an automatic migration path between schemas. **Configure preferences in ttyx_ directly** on first launch. If you had an unusual setup under Tilix, keep a Tilix window open side-by-side to mirror the settings.
- **Desktop entry overrides**: if you had a customized `~/.local/share/applications/com.gexperts.Tilix.desktop`, those changes don't carry over; ttyx_ ships its own desktop file under `io.github.gwelr.ttyx.desktop`.

## Verifying the migration

After first launch:

```bash
# Config dir is populated
ls ~/.config/ttyx/

# Original Tilix config is still in place
ls ~/.config/tilix/

# Saved passwords are readable (open the password manager and check the list)
# Shell inside a ttyx_ terminal:
echo "TTYX_ID=$TTYX_ID TILIX_ID=$TILIX_ID"
```

Both `TTYX_ID` and `TILIX_ID` should be set to the same UUID. Your saved passwords should be visible in **Preferences → Password Manager**.

## Rolling back

If something looks wrong and you want to revert to Tilix:

1. Close ttyx_.
2. Your original Tilix config is still at `~/.config/tilix/` — launch `tilix` and it will pick up from where it was.
3. Optionally delete `~/.config/ttyx/` if you want a clean slate before trying ttyx_ again.

Because migration only copies and never modifies the source, there is nothing to "undo" on the Tilix side.

## Removing the old Tilix config

Once you've confirmed ttyx_ is working the way you want, the Tilix backup is safe to remove:

```bash
rm -rf ~/.config/tilix/
```

You can do this at any time — ttyx_ no longer reads from `~/.config/tilix/` after the initial migration.

## Uninstalling Tilix itself

ttyx_ and Tilix can coexist on the same system; their binaries, icons, desktop files, and GSettings schemas don't collide. If you don't want Tilix installed anymore, uninstall it however your distro or package manager prefers (`apt remove tilix`, `flatpak uninstall com.gexperts.Tilix`, etc.) — that's independent of the ttyx_ migration.
