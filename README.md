# Dotfiles

Arch Linux + Hyprland (`~/.config`). Only an allowlist is tracked (see `.gitignore`); everything else in `~/.config` is ignored.

- `hypr/` Hyprland (Lua config) and hyprlock
- `quickshell/` the shell: bar, app launcher (`SUPER+R`), clipboard history (`SUPER+SHIFT+V`), emoji picker (`SUPER+.`), power menu, notifications, Claude usage limits
- `kitty/`, `btop/`, `fastfetch/`, `mpv/`, `waypaper/`, `Thunar/`, `xfce4/`, `pipewire/`, `wireplumber/`, `autostart/`

Neovim lives in its own repo: https://github.com/tcvdh/init.lua

## Quickshell dependencies

`quickshell jq curl cliphist wl-clipboard hyprlock pavucontrol waypaper` and a Nerd Font (`ttf-jetbrains-mono-nerd`).
