# Neovim config

Portable base config with personal local overrides.

## Overview

This config is organized around a shared public baseline and a private local override layer.

- `lua/config/defaults.lua` contains the public defaults
- `lua/config/local.lua` is private and machine-specific
- `lua/config/local.example.lua` is the template for public overrides
- `lua/accessor.lua` merges defaults with local overrides

Plugin integration setup lives under `lua/integrations` and is loaded explicitly by the boot graph after packages are available. Optional integrations are guarded so missing plugins fail softly instead of crashing startup.

## Requirements

Core:
- Neovim >= 0.12
- git
- curl or wget
- unzip
- tar (GNU tar preferred for some install flows)
- gzip
- a C compiler
- tree-sitter CLI
- ripgrep

Common optional helpers:
- node / npm
- python3
- swift
- jq
- d2
- java / graphviz / plantuml

Some workflows in this config are personal and require extra local setup.

## Theme

`M.theme` in `lua/config/defaults.lua` sets the colorscheme mode:

- `"dark"` (default): `M.theme.dark` (nightfox)
- `"light"`: `M.theme.light` (dawnfox)
- `"system"`: follows macOS appearance and switches live. This is the only mode
  that starts the `sysappear watch` job (`M.bin.sysappear`).

An unknown mode warns and falls back to `"system"`. Override per machine in
`lua/config/local.lua`:

```lua
M.theme = { mode = "system" }
```

## Platform notes

The default assumptions are macOS-oriented, but Linux works through local overrides.

The main system helpers are configured under `M.bin`:

- `open`
- `pbcopy`
- `pbpaste`
- `trash`

On Linux, override them in `lua/config/local.lua`. Example Wayland setup:

```lua
M.bin = {
    open = "xdg-open",
    pbcopy = "wl-copy",
    pbpaste = "wl-paste",
    trash = "trash-put",
}
```
