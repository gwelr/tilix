---
title: Splits and pane layout
layout: default
parent: Manual
nav_order: 11
permalink: /manual/splits/
---

# Splits and pane layout

## Equal-size panes (auto-equalize)

By default, ttyx_ automatically redistributes pane space whenever you split or close a terminal. Each pane in a same-orientation chain ends up with an equal share of the available space:

- Three horizontal splits → 33% / 33% / 33%
- Closing one of three equal panes → 50% / 50%

This mirrors the behaviour of tiling window managers such as Sway and i3.

### Disabling auto-equalize

If you prefer to manage sizes manually, turn off **Equalize panes on split and close** in **Preferences → Appearance**. With this option disabled:

- Each new split halves the pane being divided ("halve the latest" behaviour).
- Pane sizes you set by dragging a splitter are preserved across subsequent splits and closes.

### Notes

- Auto-equalize only affects panes that share the same split orientation. A vertical group and a horizontal group within the same session are redistributed independently.
- Any manual drag on a splitter is overwritten the next time a split or close occurs while auto-equalize is enabled.
