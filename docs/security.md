---
title: Security features
layout: default
nav_order: 7
permalink: /security/
---

# Security features

ttyx_ is designed as a **security-conscious** tiling terminal emulator. This page describes what ttyx_ protects against, how to configure each protection, and — importantly — what it does **not** protect against. Security is defense in depth, not a guarantee.

All security-related preferences are consolidated under **Preferences → Advanced → Security**.

## Threat model

ttyx_'s protections target three broad classes of threat you can realistically defend against from inside a terminal emulator:

1. **Accidental command execution from untrusted input** — pasting content that contains hidden newlines, paste-mode escape sequences, or dangerous commands you didn't notice.
2. **Data lingering after you thought it was gone** — passwords in the clipboard, credentials scrolled back into the buffer, process memory exposed via core dumps.
3. **Lost situational awareness** — forgetting you're on a root shell, or that your terminal is connected to a remote host over SSH.

ttyx_ does **not** try to defend against a compromised shell, a malicious program running inside the terminal, kernel-level attacks, or a hostile OS. Those are outside what a user-space terminal emulator can see.

## Paste protection

### Bracketed-paste escape stripping

Always on, no setting. ttyx_ strips `ESC[200~` / `ESC[201~` sequences from clipboard content before it reaches the shell. These sequences tell the shell's paste-mode where paste content begins and ends; if a malicious webpage puts them into your clipboard, copy-pasting a single line can break out of paste mode and execute subsequent clipboard content as commands.

### Multi-line paste review

When the clipboard contains multi-line content, ttyx_ shows a review dialog before sending anything to the shell. You can inspect, edit, or cancel — no text reaches the shell until you click **Paste**.

- GSetting: `warn-multiline-paste` (boolean)
- Default: **on**

### Dangerous command detection

When the pasted text matches patterns for privilege escalation, destructive file operations, or remote code execution, the unsafe-paste dialog escalates the warning. Patterns include (non-exhaustive):

- Privilege escalation: `sudo`, `su -`, `doas`
- Destructive file operations: `rm -rf`, `rm -fr`, `mkfs`, `dd if=`, `chmod 777`, `chmod -R 777`
- Remote code execution: `curl ... | bash`, `wget ... | sh`, `eval`, fork bombs

Per-paste warning: unlike some terminal emulators that show this warning once per session and then suppress it, ttyx_'s warning fires **every time** a dangerous pattern is detected.

- GSetting: `unsafe-paste-alert` (boolean)
- Default: **on**

## Clipboard protection

### Auto-clear after copy

When enabled, the clipboard is cleared after a configurable timeout following a copy-from-terminal operation. This prevents passwords, tokens, and other sensitive data from lingering in the clipboard long after you pasted it where you meant to.

Important safeguard: ttyx_ only clears the clipboard if it still contains the exact content it copied. If another application overwrote the clipboard in the meantime, ttyx_ leaves it alone — it won't wipe someone else's copied text.

- GSetting: `clipboard-auto-clear` (boolean) — default **off**
- GSetting: `clipboard-auto-clear-timeout` (unsigned int, seconds, range 5–300) — default **30**

Enabling this costs almost nothing; turn it on from Preferences if you frequently copy credentials or tokens.

## Visual session indicators

Both indicators are about situational awareness: forgetting you're root, or forgetting you're on a remote host, are both common sources of destructive mistakes. The indicators are intentionally loud — coloured tint on the title bar, plus a label — so the state is hard to miss.

### Root indicator

Red tint and an "as root" label appear when any process in the terminal tree is running with effective UID 0.

- GSetting: `root-indicator` (boolean)
- Default: **on**

### SSH indicator

Blue tint and an "ssh" label appear when the terminal is running `ssh`, `scp`, `sftp`, `mosh`, or `sshfs`. Detection is based on the foreground process name, not output pattern matching.

- GSetting: `ssh-indicator` (boolean)
- Default: **on**

If both indicators would apply (root over SSH), the SSH indicator takes precedence — you're reminded which host you're on before you're reminded that you're root on that host.

Both indicators require the process monitor to be enabled (`process-monitor`, default **on**). The monitor was rewritten in v1.1.0 to check only the foreground process of monitored terminals rather than scanning all of `/proc`, dropping idle CPU from ~1.4% to ~0.1%.

## Memory protection

### Core-dump protection

On startup, ttyx_ calls `prctl(PR_SET_DUMPABLE, 0)` to mark the process as non-dumpable. This has two effects:

- The kernel refuses to generate a core dump if the process crashes.
- `/proc/pid/mem` and `/proc/pid/maps` become readable only by root, preventing other processes owned by the same user from reading memory (including scrollback contents).

Disable this only if you need to attach GDB or generate core dumps for debugging — and be aware that doing so exposes scrollback to anything that can ptrace ttyx_.

- GSetting: `core-dump-protection` (boolean)
- Default: **on**

### In-memory-only scrollback

The **unlimited** scrollback option from upstream Tilix was removed. Scrollback is capped at 256 to 999,999 lines, and VTE keeps the buffer entirely in RAM — it is never written to disk. Combined with core-dump protection, that makes the scrollback buffer resistant to ordinary disk-forensics attacks and to crash-dump exfiltration.

- GSetting: `scrollback-lines` (int, range 256–999,999)
- Default: **8192**

If you display output you don't want to keep around — a password, a token, a private key — use Secure Clear.

### Secure Clear

Resets the terminal and wipes the scrollback buffer on demand. Available from the hamburger menu, the right-click context menu, and a keyboard shortcut.

- Default shortcut: `Ctrl+Shift+L`
- GSetting (shortcut): `terminal-reset-and-clear`

The reset is the VTE reset sequence (equivalent to `reset`), followed by an explicit scrollback-buffer clear. No part of the previous buffer is recoverable from userland after Secure Clear; a privileged attacker with kernel-level access is still out of scope.

## Triggers and custom links — shell injection from terminal output

ttyx_ supports two user-configurable features that turn terminal content into shell commands:

- **Triggers** (Profile preferences → Advanced) — regular expressions that match against terminal output. The `ExecuteCommand` and `RunProcess` actions run a shell command using a template like `notify-send "Build failed" "$1"`, where `$1` is substituted with a regex capture group.
- **Custom links** (Preferences → Advanced) — clickable regex matches whose template runs through `spawnShell` when the user clicks them.

In both cases the substituted text comes from terminal output. **Under SSH or any remote session, terminal output is attacker-controlled.** A malicious remote host that knows you have a trigger like `^Build failed: (.+)$` → `notify-send "Build failed" "$1"` can emit:

```
Build failed: oops"; rm -rf ~/Documents; #
```

After substitution, `spawnShell` receives `notify-send "Build failed" "oops"; rm -rf ~/Documents; #"` — three commands, the second one destructive. This is the same class of bug that has affected iTerm2, tmux `-CC` mode, and various OSC 8 implementations.

### Status

- ttyx_ ships with **no default triggers and no default custom links**. The attack surface is exactly what you opt into.
- The trigger and custom-link editor dialogs surface the warning at the point of editing.
- ttyx_ does **not** currently shell-quote match-group substitutions. Designing a safe-substitution scheme that doesn't break legitimate templates (where the user intentionally wants `$1` to expand into multiple shell tokens) is open work.

### Recommendations

- Only enable trigger `ExecuteCommand`/`RunProcess` and custom-link templates for hosts you trust.
- Avoid templates where a regex capture group lands in a shell-interpreted position. Prefer templates that pass the captured value to a program via a non-shell channel — for example, by setting an env var rather than embedding `$1` in a shell command string. (Subject to change once safe-substitution lands.)
- Audit any imported trigger configurations the same way you would audit a shell script.

## Log hygiene

ttyx_ writes debug logs only when file logging is explicitly compiled in (`USE_FILE_LOGGING`, default off). Even so, when logging is enabled:

- **Environment variables with sensitive keys** (`password`, `token`, `secret`, `auth`) are replaced with `[redacted]` before they reach any log sink.
- **Proxy URLs have their userinfo segment stripped** — the log shows `http://proxy.example.com:8080/` rather than `http://alice:secret@proxy.example.com:8080/`.
- **Command-line arguments and hyperlink click events** pass through the same URL-userinfo stripper, so launching `ttyx -e "psql postgresql://user:pw@db/app"` or clicking a private-docker-registry URL in terminal output doesn't leak credentials.
- **Log file location** — when `USE_FILE_LOGGING` is enabled, the log file is written to `$XDG_RUNTIME_DIR/ttyx.log` (mode 0700 by systemd convention) in preference to `/tmp/ttyx.log`. The `/tmp` path is retained only as a last-resort fallback on systems where neither `$XDG_RUNTIME_DIR` nor `$HOME` resolves.

## Configuration reference

All keys live under the `io.github.gwelr.ttyx.Settings` schema.

| Feature | GSetting key | Default | Range |
|---------|--------------|---------|-------|
| Unsafe-paste alert | `unsafe-paste-alert` | true | bool |
| Multi-line paste review | `warn-multiline-paste` | true | bool |
| Clipboard auto-clear | `clipboard-auto-clear` | false | bool |
| Clipboard auto-clear timeout | `clipboard-auto-clear-timeout` | 30 | 5–300 s |
| Process monitor | `process-monitor` | true | bool |
| Root indicator | `root-indicator` | true | bool |
| SSH indicator | `ssh-indicator` | true | bool |
| Core-dump protection | `core-dump-protection` | true | bool |
| Scrollback lines | `scrollback-lines` | 8192 | 256–999,999 |
| Secure Clear shortcut | `terminal-reset-and-clear` (Keybindings schema) | `<Ctrl><Shift>L` | string |

Read with `gsettings get io.github.gwelr.ttyx.Settings <key>`; set with `gsettings set io.github.gwelr.ttyx.Settings <key> <value>`.

## Limitations and non-goals

Being explicit so you don't rely on protections that aren't there:

- **No defense against a compromised shell or malicious program running inside the terminal.** Everything that runs under your shell can do anything your user can do. ttyx_ protects the *boundary* (paste, clipboard, memory exposure, indicators) — not the contents.
- **No kernel-level or hardware-level protection.** A root attacker on the local machine, a hypervisor, or anything with ptrace capability is out of scope.
- **Flatpak provides additional sandboxing that ttyx_ benefits from but does not replace.** If sandbox isolation matters for your threat model, run ttyx_ via Flatpak and look into `flatpak-run --env=…` to further restrict its capabilities.
- **No remote-audit features.** ttyx_ doesn't log what you type, what you see, or what you paste — by design. If you need forensic recording, that's a different category of tool.
- **Scrollback is user-memory-only, not locked memory.** A privileged process can still read it before Secure Clear runs. Core-dump protection closes the usual leak path but can't defend against an attacker with `ptrace` or kernel access.

## Reporting security issues

If you find a security-sensitive bug — something that could leak sensitive data, bypass one of the protections listed here, or enable injection attacks — please report it via the [issue tracker](https://github.com/gwelr/ttyx_/issues) with enough detail to reproduce. For vulnerabilities where public disclosure first would put users at risk, reach out via a private channel before filing the issue.

For a per-version summary of security-relevant fixes, see the [changelog]({{ site.baseurl }}/changelog/); for how the feature set compares to upstream Tilix, see [What's new vs Tilix]({{ site.baseurl }}/whats-new/).
