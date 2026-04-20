---
title: Themes
parent: Manual
nav_order: 4
layout: default
---

## Overview

ttyx_ supports themes for configuring the color scheme of the terminal, one theme per JSON file. Each theme specifies colors for each element and declares whether certain colors should be used or left to the GTK theme. Here is an example of a theme file:

{% highlight json %}
{
    "name": "Orchis",
    "comment": "Tango but using Orchis foreground/background colors",
    "foreground-color": "#EFEFEF",
    "background-color": "#303030",
    "use-theme-colors": false,
    "use-highlight-color": false,
    "highlight-foreground-color": "#ffffff",
    "highlight-background-color": "#a348b1",
    "use-cursor-color": false,
    "cursor-foreground-color": "#ffffff",
    "cursor-background-color": "#efefef",
    "use-badge-color": true,
    "badge-color": "#ac7ea8",
    "palette": [
        "#000000",
        "#CC0000",
        "#4D9A05",
        "#C3A000",
        "#3464A3",
        "#754F7B",
        "#05979A",
        "#D3D6CF",
        "#545652",
        "#EF2828",
        "#89E234",
        "#FBE84F",
        "#729ECF",
        "#AC7EA8",
        "#34E2E2",
        "#EDEDEB"
    ]
}
{% endhighlight %}

## Where themes are loaded from

ttyx_ looks for theme files in two locations, in order:

1. `~/.config/ttyx/schemes/` — user-installed themes. Drop any JSON file here and it will appear in the theme picker.
2. `/usr/share/ttyx/schemes/` — themes shipped with ttyx_.

If a theme with the same name exists in both locations, the user version wins. This fix shipped in v1.1.1; before then, duplicates could appear in the theme picker.

## Bundled themes

ttyx_ ships 17 schemes out of the box, covering the most commonly-requested palettes:

- **Catppuccin** — Latte, Mocha
- **Dracula**
- **Gruvbox** — Dark, Light
- **Nord**
- **Solarized** — Dark, Light
- **Tokyo Night**
- **One Dark**
- **Material**
- **Monokai**
- **Tango**
- **Base16 Twilight (dark)**
- **Linux console**, **Orchis**, **Yaru**

## Installing additional themes

Any JSON file following the structure above works. Two community theme repositories originally built for Tilix use the same format and install into `~/.config/ttyx/schemes/`:

- [**Tilix-Themes**](https://github.com/storm119/Tilix-Themes) — a large collection of pre-built palettes.
- [**gogh-to-tilix**](https://github.com/isacikgoz/gogh-to-tilix) — a converter for the [gogh](https://github.com/Gogh-Co/Gogh) theme ecosystem.

After dropping a new `.json` file into `~/.config/ttyx/schemes/`, it appears in **Preferences → Profile → Color → Color scheme** without a restart.
