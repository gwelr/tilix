---
title: Badges
parent: Manual
nav_order: 5
layout: default
---


![Example of a terminal badge displaying text overlaid on the terminal background]({{site.baseurl}}/assets/images/manual/badges.png)

## Overview

Badges are text overlays displayed in the background of the terminal. They can act as visual reminders (e.g. environment name, pod name), or as a way to show the terminal title when the title bar is disabled.

## Configuration

Badges are configured at the **Profile** level and are per-profile.

- **Text and position** are set on the **General** tab of Profile preferences. Position is one of the four corners of the terminal (top-left, top-right, bottom-left, bottom-right) plus a centered option.
- **Color** is set on the **Colors** tab of Profile preferences, under the **Advanced** popup. The badge color can also be specified in a theme file — see the [`badge-color`]({{ site.baseurl }}/manual/themes/) field.

## Variables

Badges support the full set of variables described on the [Titles]({{ site.baseurl }}/manual/title/) page. Common examples:

| Badge text | Result |
|------------|--------|
| `${title}` | The terminal's current title |
| `${hostname}` | The hostname reported by the shell (requires a configured trigger or VTE script) |
| `${directory}` | The current working directory |
| `${id}` | The numeric terminal ID |
| `PROD — ${username}@${hostname}` | Freeform text combined with substitutions |

Triggers can also update the badge dynamically via the [Update Badge]({{ site.baseurl }}/manual/triggers/#supported-actions) action — useful for displaying state extracted from terminal output.
