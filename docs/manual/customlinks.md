---
title: Custom Hyperlinks
parent: Manual
nav_order: 7
layout: default
---

## Overview

ttyx_ lets you define custom hyperlinks using regular expressions. Any text matching a configured pattern becomes clickable in the terminal; clicking launches a command with the match (or its capture groups) as arguments.

## Configuration

Custom links are configured at the **Profile** level in **Preferences → Profile → Advanced → Custom Links**. Each entry has two fields:

- **Regex** — the pattern to match in terminal output.
- **Command** — the command to run when the match is clicked. Use `$0` for the full match, `$1`, `$2`, … for capture groups.

## Example

To make Python traceback locations clickable, pair the regex `File "([^"]+)", line (\d+)` with the command `gedit +$2 $1`. The two capture groups (file path, line number) are passed to `gedit` via `$1` and `$2`.

Any command on `$PATH` works — common uses:

| Pattern | Matches | Command |
|---------|---------|---------|
| `File "([^"]+)", line (\d+)` | Python tracebacks | `gedit +$2 $1` |
| `([a-zA-Z0-9_/\.-]+\.[a-z]+):(\d+)` | `file:line` style | `$EDITOR +$2 $1` |
| `https?://\S+` | URLs (built in, but you can override) | `xdg-open $0` |
