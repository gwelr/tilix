---
title: Memory baseline
layout: default
nav_order: 99
permalink: /memory-baseline/
---

# Memory baseline

This page records ttyx_'s memory footprint and GC allocation profile as of each
measurement. Use it to detect regressions: if the numbers climb significantly
between releases, investigate before shipping.

## How to read this

| Metric | What it tells you |
|---|---|
| **RSS at startup** | Resident set size after the app finishes initialising (one terminal, idle). Includes GTK, VTE, and all shared-library pages that are resident. |
| **GC summary (unit tests)** | D garbage-collector stats at the end of the full `dub test` run. Shows total D heap used and how often the GC had to collect. |

A large jump in RSS (> 20 MB between releases) warrants a look at new GTK
widget allocations or unreleased object references. A large jump in GC heap
(> 2× without a known feature addition) suggests an unintentional reference
keeping objects alive.

## Current baseline

Measured on 2026-04-23, commit `523597d2`, Debian Trixie, LDC 1.36.0.

### RSS at startup

| Configuration | RSS |
|---|---|
| One terminal, idle, `--new-process` flag | **72 MB** |

### GC profile (unit tests)

```
GC summary:    5 MB,    2 GC    0 ms, Pauses    0 ms <    0 ms
```

Collected twice during 29 test modules. Total D heap at exit: 5 MB.
GC pause time is negligible.

## How to re-measure locally

### RSS

```bash
# Build first (system ldc2, meson):
meson setup builddir --wipe && ninja -C builddir

# Then launch and measure:
glib-compile-schemas data/gsettings/
mkdir -p builddir/data/ttyx/resources
ln -sf "$(pwd)/builddir/data/ttyx.gresource" builddir/data/ttyx/resources/ttyx.gresource

Xvfb :98 -screen 0 1024x768x24 &
DISPLAY=:98 \
GSETTINGS_BACKEND=memory \
GSETTINGS_SCHEMA_DIR=$(pwd)/data/gsettings/ \
XDG_DATA_DIRS=$(pwd)/builddir/data:/usr/local/share:/usr/share \
./builddir/ttyx --new-process &
TTYX_PID=$!
sleep 6
ps -o pid=,rss= -p $TTYX_PID
kill $TTYX_PID
```

For a realistic multi-terminal session, use `monitor-rss.sh` instead:
```bash
./monitor-rss.sh 60   # sample every 60 seconds
```

### GC profile

```bash
export PATH="/path/to/ldc/bin:$PATH"
dub test -- --DRT-gcopt=profile:1 2>&1 | grep "GC summary"
```

## CI integration

The **Ubuntu LTS** CI job runs `measure-memory.sh` after the test suite on every
PR. Results appear in the GitHub Actions job summary. The step is
`continue-on-error: true` — it never blocks a merge, it only reports.

The **Dub** CI job runs `dub test` with `--DRT-gcopt=profile:1` on both DMD and
LDC and writes the GC summary line to the job summary.
