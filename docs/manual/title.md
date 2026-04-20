---
title: Titles
parent: Manual
nav_order: 1
layout: default
---

ttyx_ supports using variables in the various titles and names it allows to be configured. This enables the title to better reflect the current state of the application, session, or currently focused terminal. Variables are available within a particular scope and can always be used in higher scopes. For example, `${title}` is a terminal-scope variable but can be used in session and application titles — there it reflects the currently active terminal.

Variables can be used in the following locations:

* Window title
* Session name
* Terminal title
* Badge
* Custom links
* Triggers

## Terminal scope

These variables are resolved against the currently focused terminal:

| Variable | Description |
|----------|-------------|
| `${title}` | The title of the terminal as reported by the terminal |
| `${iconTitle}` | The icon title of the terminal |
| `${id}` | The numeric terminal ID (e.g. 1, 2, 3, 4) |
| `${directory}` | The current working directory in the terminal |
| `${columns}` | The number of columns in the terminal |
| `${rows}` | The number of rows in the terminal |
| `${hostname}` | The hostname of the current session. Availability depends on having the VTE script configured on remote systems, or on a trigger extracting the value from terminal output |
| `${username}` | The current username. Requires trigger support and an appropriate trigger to be configured |
| `${process}` | The active foreground process name (e.g. `vim`, `ssh`). Requires the process monitor to be enabled in Preferences |
| `${status.readonly}` | `true` if the terminal has input disabled, `false` otherwise |
| `${status.silence}` | `true` if the terminal is being monitored for silence, `false` otherwise |
| `${status.input-sync}` | `true` if the terminal is part of a synchronized-input group, `false` otherwise |

## Session scope

| Variable | Description |
|----------|-------------|
| `${activeTerminalTitle}` | The title of the currently active terminal with all variables substituted |
| `${terminalCount}` | The total number of terminals in the session |
| `${terminalNumber}` | The number of the currently active terminal |

## Application scope

Available in all titles except the per-terminal title.

| Variable | Description |
|----------|-------------|
| `${appName}` | The name of the application — `ttyx_` |
| `${sessionName}` | The name of the session |
| `${sessionCount}` | The total number of sessions |
| `${sessionNumber}` | The number of the current session (e.g. session 2 of 4) |
