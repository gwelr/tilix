# Contributing to ttyx_

Thanks for your interest in contributing to ttyx_!

The [online documentation](https://gwelr.github.io/ttyx_/) has install instructions, a user manual, and a changelog. This file covers what you need to **work on ttyx_ itself** — setting up a dev environment, running the test suite, submitting changes.

## Prerequisites

- **D compiler**: [LDC](https://github.com/ldc-developers/ldc) 1.30+ recommended for release builds; DMD 2.100+ also supported. The `dub` package manager ships with both.
- **GTK 3.18+** and **VTE 0.46+** (0.76+ recommended — some features like triggers depend on newer VTE releases) with development headers.
- **GtkD bindings** 3.x. Packaged on Debian Stable and Ubuntu as `libgtkd-3-dev` + `libvted-3-dev`. **Debian Testing / Sid** dropped them from the archive; build GtkD from source following the CI helper at `.github/ci/make-install-deps-extern.sh`.
- **Meson + Ninja**, or **Dub**.

See the [Install page](https://gwelr.github.io/ttyx_/install/) for the full system-dependency list.

## Build

### Meson (primary — matches CI)

```bash
meson setup builddir --buildtype=debug
ninja -C builddir
```

Swap `--buildtype=debug` for `--buildtype=release` for optimized builds.

### Dub (simpler for iteration)

```bash
dub build --compiler=ldc2                     # debug by default
dub build --build=release --compiler=ldc2     # release
```

Dub pulls GtkD bindings from the package registry, so it doesn't require `libgtkd-3-dev` installed system-wide — handy on distros where the package is missing.

## Run from the build dir

The binary under `builddir/ttyx` doesn't know where to find GSettings schemas or the compiled gresource unless you point it at them:

```bash
glib-compile-schemas data/gsettings/
export GSETTINGS_SCHEMA_DIR="$PWD/data/gsettings"

# The app looks for ttyx/resources/ttyx.gresource under each XDG data dir;
# symlink the compiled gresource into that location:
mkdir -p "$PWD/builddir/data/ttyx/resources"
ln -sf "$PWD/builddir/data/ttyx.gresource" \
       "$PWD/builddir/data/ttyx/resources/ttyx.gresource"
export XDG_DATA_DIRS="$PWD/builddir/data:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"

./builddir/ttyx --new-process
```

Or use the bundled wrapper `debug-ttyx.sh`, which does all of the above plus launches the binary under gdb with sensible defaults.

### Using `debug-ttyx.sh`

```bash
./debug-ttyx.sh              # debug run under gdb
./debug-ttyx.sh --rebuild    # rebuild first, then debug
./debug-ttyx.sh --core       # open most recent coredump via coredumpctl
```

ttyx_ is a GTK single-instance application (via D-Bus activation), so the wrapper kills any running `ttyx` before launching under gdb — otherwise the new process would hand off to the existing one and gdb would attach to nothing.

**Gotcha — `ttyx -a <action>` doesn't work against a `debug-ttyx.sh` instance.** The wrapper adds `--new-process`, which disables GApplication's session-bus registration. As a side effect, later `ttyx -a session-add-right …` invocations can't discover the debug instance on the bus, so they fall through to creating a new window and print "No ttyx_ instance registered on the session bus…". If you're testing CLI actions, launch ttyx_ normally (without the wrapper).

## Tests

### Unit tests

```bash
meson test -C builddir --print-errorlogs
# or
dub test --compiler=ldc2
```

Both invocations build a `ttyx_test` binary that links every module with `-unittest`. Tests live alongside the code they test in `unittest { ... }` blocks — see `source/gx/util/*.d` for straightforward examples. The pure-helper modules (`geometry`, `redact`, `proc`, `string`) exist partly to make logic unit-testable without spinning up GTK widgets.

### Validation tests

CI also runs `desktop-file-validate` against the `.desktop` file and `appstream-util validate-relax` against the AppStream metadata. These fire automatically on `meson test`.

## Debugging

`debug-ttyx.sh` launches gdb with:

- `handle SIG32 SIG33 SIG34 SIG35 SIGPIPE nostop noprint pass` — glibc and GLib use these real-time signals internally (thread cancellation, posix timer expirations, async signal delivery, broken pipe). They're not interesting unless you're specifically hunting a signal bug; the handles let gdb pass them straight through to the app.
- `set print pretty on`, `set pagination off`, `set confirm off` for a friendlier session.

Useful gdb commands once you hit a crash:

- `bt` — backtrace
- `bt full` — backtrace with local variables
- `thread apply all bt` — covers all threads, important for threaded crashes
- `info threads` — list threads
- `continue` — resume after a breakpoint

For a post-mortem on a crash that already happened, `./debug-ttyx.sh --core` opens the most recent ttyx_ coredump via `coredumpctl debug`.

## Code style

Enforced by [.editorconfig](.editorconfig) and [dscanner.ini](dscanner.ini). Formatter: [`dfmt`](https://github.com/dlang-community/dfmt).

Key conventions worth knowing:

- **Indentation**: 4 spaces.
- **Brace style**: One True Brace (OTBS).
- **Line length**: 160 soft, 170 hard.
- **Type inference (`auto`)**: default to explicit types. Use `auto` only when the type is already on the RHS (e.g. `auto p = new Process(1);`) or is genuinely unprintable (deep template instantiations). Avoid `auto` for numeric literals (precision mismatches hide behind it), function return values where the callee name doesn't mirror the return type, and associative arrays / slices where the element type carries meaning. Explicit types are documentation the compiler verifies.
- **Comments**: default to none. Add a comment only when the *why* is non-obvious — a hidden constraint, an invariant, a workaround for a specific bug. Don't describe *what* well-named identifiers already express.
- **Tests**: prefer extracting pure testable helpers over integration-heavy fixtures. Many recent refactors lifted pure functions out of GTK-heavy modules specifically to unlock unit tests.

## Submitting changes

1. Fork the repo and create a topic branch off `master`.
2. Make changes, run the test suite, commit.
3. Push and open a PR against `master`.
4. CI runs Meson builds on Debian Stable / Testing / Ubuntu LTS, Dub builds with both DMD and LDC, plus desktop-file and AppStream validation. PRs need green CI before review.

### Commit and PR conventions

- **Commit subject**: `<category>: short description`, where category is one of `feat`, `fix`, `security`, `refactor`, `docs`, `test`, `style`, `chore`, `ci`. Under 72 chars.
- **Commit body**: explain the *why* rather than the *what*. Surface tradeoffs when a decision has them. Reference issues with `#N`.
- **No `Co-Authored-By: Claude` footers**. If a change was AI-assisted, say so in the body (`Assisted by Claude Code.`) — you stay the author of record.
- **PR description**: link the issue the PR addresses (`Closes #N` / `Refs #N`), summarize the change, include a test plan.

## Codebase orientation

- `source/app.d` — entry point.
- `source/gx/ttyx/` — core application logic.
  - `application.d` — GTK Application lifecycle, action registration.
  - `appwindow.d` — main window, paned terminal layout.
  - `session.d` — session/workspace management (JSON serialization).
  - `terminal/terminal.d` — the VTE-wrapping terminal widget (largest file in the repo).
  - `terminal/*` — the rest of the terminal stack (spawn, flatpak host bridge, regex, renderer, monitor, state, …).
  - `prefeditor/` — preferences dialog UI.
- `source/gx/gtk/` — GTK utility wrappers (actions, dialogs, color, clipboard, threads, VTE, X11, resources, …).
- `source/gx/util/` — pure helpers with no GTK dependencies (`string`, `geometry`, `redact`, `proc`, `array`, `path`). Easier to unit-test, and the preferred home for logic that doesn't need widget state.
- `source/secret/`, `source/secretc/` — libsecret D and C bindings.
- `source/x11/` — X11 D bindings.
- `data/` — GSettings schema, color schemes, icons, desktop file, AppStream metadata, scripts.
- `docs/` — Jekyll site content published at <https://gwelr.github.io/ttyx_/>.
- `po/` — gettext translations.

## License

ttyx_ is licensed under [MPL-2.0](LICENSE). Contributions are licensed under the same terms.
