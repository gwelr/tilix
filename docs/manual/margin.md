---
title: Margin
parent: Manual
nav_order: 8
layout: default
---

## Overview

Many style guides require lines to stay under a fixed column width (typically 80 or 100 characters) to keep code readable. When using text-mode editors like `vi`, `emacs`, or `nano`, a visible margin line makes it easy to see when you're about to go over.

## Configuration

Margin width is configured per-profile in **Preferences → Profile → Scrolling**.

| GSetting | Key | Default | Meaning |
|----------|-----|---------|---------|
| Margin column | `draw-margin` | `80` | Column to draw the margin line at; `0` disables the margin entirely |
| Toggle shortcut | `terminal-toggle-margin` | `<Ctrl><Alt>m` | Keyboard shortcut to toggle the margin on and off without changing the profile setting |

The toggle is useful when you want the margin visible while editing but out of the way while reading long output.
