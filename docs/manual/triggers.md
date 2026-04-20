---
title: Triggers
parent: Manual
nav_order: 3
layout: default
---

*Historically, trigger support required a [Tilix-specific patch](https://github.com/gnunn1/tilix/blob/master/experimental/vte/alternate-screen.patch) on top of GTK VTE (Arch users installed the [vte3-tilix-git](https://aur.archlinux.org/packages/vte3-tilix-git) package). Recent VTE releases include the alternate-screen support needed for triggers to work without a custom patch.*

## Overview

ttyx_ supports triggers: regular expressions defined by the user that, when matched against text output by the terminal, execute an action. A trigger consists of a regular expression, the action to execute, and a parameter string. Depending on the action, the parameter may not be used at all, may be a single string, or may be a semicolon-delimited list of `name=value` pairs.

Capture groups in the regular expression are available as tokens in the parameter. ttyx_ substitutes these tokens before executing the action:

- `$0` — the complete regular expression match.
- `$1`, `$2`, `$3`, … — the individual capture groups when defined.

## Supported actions

| Action | Parameter | Description |
|--------|-----------|-------------|
| Update State | `username=…;hostname=…;directory=…` | Updates the internal state ttyx_ keeps about the terminal. Used by features like titles, the path-aware working directory, and profile switching. Any subset of `username`, `hostname`, `directory` may be provided. |
| Execute Command | shell command | Spawns the given command in the shell. |
| Send Notification | `title=…;body=…` | Sends a desktop notification. Both keys are optional; if `body` is omitted, the full regex match (`$0`) is used as the body. |
| Update Badge | text | Sets the terminal's badge overlay to the substituted text. See [Badges]({{ site.baseurl }}/manual/badges/). |
| Update Title | text | Sets the terminal's override title (same as the Layout Options override). |
| Play Bell | — | Plays the terminal bell. No parameter. |
| Send Text | text | Sends the substituted text to the terminal as if typed. |
| Insert Password | — | Opens the password manager so you can pick an entry to insert. |
| Run Process | command | Runs the given command outside the terminal (detached), without sending any output back to the shell. |

## Trigger-line limit

ttyx_ limits the number of lines checked for triggers by default. This keeps performance steady on slower hardware when a large block of output arrives (e.g. `cat` on a big file).

Every change in the terminal is delivered to ttyx_ as a block of text. A block might be a single keystroke, or it might be thousands of lines at once. When the trigger-line limit is active, only the last N lines of each block are scanned; so if a 20,000-line block arrives and the limit is 256, only the trailing 256 lines get trigger-matched.

If you need triggers to fire on every line regardless of block size, disable the limit from Preferences. Doing so can have a noticeable performance cost during bulk output.

## Example

| Regular expression | Action | Parameter | Description |
|-------------------|--------|-----------|-------------|
| `^\[(?P<user>.*)@(?P<host>[-a-zA-Z0-9]*)` | Update State | `username=$1;hostname=$2` | Parses the username and hostname from a Linux prompt formatted as `[user@host directory]$`. |

## How it works

ttyx_ relies on GTK's VTE component to perform the actual terminal emulation. When VTE's buffer changes, it signals ttyx_ but does not include information about what changed. ttyx_ records the current row/column position on each signal so that it can compute the delta the next time a change arrives, and runs triggers only against that delta.

One consequence: the **grouping of changes is entirely up to VTE**. When typing, VTE signals after each character, so triggers run against individual characters, not full commands. When outputting large amounts of text (e.g. `cat`-ing a large file), VTE batches changes in very large chunks — this keeps framerate stable by coalescing updates. If the scrollback buffer overflows during one of these bursts, the overflowing text has already scrolled out of range and is no longer matchable.

To maximize trigger coverage on large output: raise the scrollback buffer (`scrollback-lines`, maximum 999,999 in ttyx_) and disable the trigger-line limit. The unlimited-scrollback option from upstream Tilix was removed for [memory-safety reasons]({{ site.baseurl }}/security/#in-memory-only-scrollback), so 999,999 is the current ceiling.