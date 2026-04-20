---
title: Home
layout: home
nav_order: 1
description: "Documentation for ttyx_, a tiling terminal emulator for Linux."
permalink: /
---

<p style="text-align: center; margin-top: 1.5rem;">
  <img src="{{ site.baseurl }}/assets/images/logo.svg" alt="ttyx_ logo" width="120">
</p>

# ttyx_
{: .fs-9 .text-center }

Tilix, but with a pulse.
{: .fs-6 .fw-300 .text-center }

ttyx_ is an actively maintained fork of [Tilix](https://github.com/gnunn1/tilix), the tiling terminal emulator for Linux. The original project did amazing work but, with development stalled and a growing list of unaddressed bugs, ttyx_ picks up where it left off — with a focus on security hardening and responsiveness to modern Linux desktops.
{: .text-center }

<div style="text-align: center; margin: 2rem 0;">
  <a href="https://github.com/gwelr/ttyx_#building" class="btn btn-primary fs-5 mr-2">Install</a>
  <a href="{{ site.baseurl }}/manual/" class="btn fs-5 mr-2">Read the manual</a>
  <a href="https://github.com/gwelr/ttyx_" class="btn fs-5">View on GitHub</a>
</div>

---

## What you get

### Tile terminals any way you like

Split horizontally, vertically, nest arbitrarily. Drag and drop terminals within and between windows. Save and restore layouts as sessions. Synchronize input across terminals when you need to drive several at once. Everything that made Tilix the tiling terminal of choice on Linux is still here.

### Security-conscious by default

Paste from the clipboard with review dialogs, dangerous-command detection, and auto-clear after copy. Clear visual indicators when a session is running as root or over SSH. Core-dump protection, in-memory-only scrollback, and a one-shortcut `Secure Clear` for wiping the scrollback when sensitive data has been displayed.

A dedicated **Security features** page is coming; until then the [project README](https://github.com/gwelr/ttyx_#security-features) has the full list.

### Actively maintained

ttyx_ ships bug fixes (crash on malformed OSC 7 URIs, preferences-dialog segfaults, proxy URL construction, focus stealing on terminal restart, …), new color schemes, release-build optimizations, and a growing test suite. Contributions welcome via pull request; the issue tracker is actually read.

A **What's new vs Tilix** page is in progress; the README has the [full change list](https://github.com/gwelr/ttyx_#whats-new-since-tilix) in the meantime.

---

## Where to next

- [**Installation**](https://github.com/gwelr/ttyx_#building) — Debian/Ubuntu dependencies, Meson and Dub build options.
- [**Manual**]({{ site.baseurl }}/manual/) — topic-by-topic reference: titles, Quake mode, triggers, color schemes, profile switching, and more.
- [**Migrating from Tilix**](https://github.com/gwelr/ttyx_#migrating-from-tilix) — what ttyx_ does with your existing Tilix config on first run.
- [**Report an issue**](https://github.com/gwelr/ttyx_/issues) — bug reports and feature requests.

---

## About this documentation

Much of the manual content originated in Gerald Nunn's [Tilix](https://github.com/gnunn1/tilix) and is reused under [MPL-2.0](https://github.com/gwelr/ttyx_/blob/master/LICENSE). Adaptation is in progress; see the [documentation tracking issue](https://github.com/gwelr/ttyx_/issues/62) for what's done and what's still open.
