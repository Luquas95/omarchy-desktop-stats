# omarchy-desktop-stats

Conky-style desktop stats widget for Omarchy (Hyprland) — that actually stays behind your windows.

[![Release](https://img.shields.io/github/v/release/Luquas95/omarchy-desktop-stats)](https://github.com/Luquas95/omarchy-desktop-stats/releases)
[![Platform](https://img.shields.io/badge/platform-Omarchy%20%2F%20Hyprland-blue?logo=linux&logoColor=white)](https://omarchy.org/)
[![Shell](https://img.shields.io/badge/language-bash-green)](https://www.gnu.org/software/bash/)
[![License](https://img.shields.io/badge/license-MIT-yellow)](https://opensource.org/license/MIT)
[![Stars](https://img.shields.io/github/stars/Luquas95/omarchy-desktop-stats?style=social)](https://github.com/Luquas95/omarchy-desktop-stats)

![screenshot](docs/screenshot.png)

## Why this exists

Conky renders through XWayland, and under Hyprland an XWayland floating
window always draws *above* native Wayland toplevels, no matter what window
rules you throw at it (`float`, `pin`, `no_focus`, `alterzorder bottom`,
`own_window_type = desktop` — none of it works). This project sidesteps the
problem entirely: it's a **second waybar instance** running as a
[wlr-layer-shell](https://wayland.app/protocols/wlr-layer-shell-unstable-v1)
surface on the `bottom` layer, which the Wayland protocol itself guarantees
stays under every normal application window.

## What it shows

- **CPU temperature** — package/overall + per-core (Intel `coretemp`, AMD `k10temp`/`zenpower`, or a thermal-zone fallback)
- **CPU / RAM / Swap / Disk** — usage with color-coded bars (green / orange / red by load)
- **Uptime**
- **Wi-Fi** — SSID, local IP, public IP, Tailscale IP, live ↑/↓ throughput
- **Docker** — currently running containers
- **Top processes** — 3 most CPU-hungry processes on the system

All panels update every second. Every data source above is optional and
degrades gracefully — if you don't have Docker, Tailscale, a Wi-Fi card, or
a supported temperature sensor, that row is hidden or shown with a clear
fallback instead of breaking the panel.

## Requirements

- Omarchy (Hyprland) — this relies on wlr-layer-shell and Omarchy's waybar/Hyprland config layout
- **waybar** (required — this *is* a waybar instance)

Everything else is optional; missing tools just mean that row shows a
fallback instead of real data:

| Tool | Used for |
|---|---|
| `docker` | running containers list |
| `tailscale` | Tailscale IP row |
| `curl` | public IP ("VPS" row) |
| `iwctl` (iwd) or `nmcli` (NetworkManager) | Wi-Fi SSID |
| Intel `coretemp` / AMD `k10temp` / `zenpower` hwmon driver | CPU temperature |

## Installation

```bash
git clone https://github.com/Luquas95/omarchy-desktop-stats.git
cd omarchy-desktop-stats
./install.sh
```

This copies the panel files into `~/.config/waybar/`, adds an `exec-once`
line to `~/.config/hypr/autostart.conf` (only if one isn't already there),
and starts the panel immediately so you don't need to log out.

To remove it again:

```bash
./uninstall.sh
```

## Configure

Copy the example config and edit it:

```bash
cp ~/.config/waybar/desktop-stats.conf.example ~/.config/waybar/desktop-stats.conf
```

| Setting | Default | Meaning |
|---|---|---|
| `WARN_THRESHOLD` / `CRIT_THRESHOLD` | `60` / `85` | percent thresholds where a bar turns orange / red |
| `COLOR_OK` / `COLOR_WARN` / `COLOR_CRIT` / `COLOR_LABEL` / `COLOR_DIM` | green/orange/red/dim-green/gray | bar and text colors |
| `DISK_PATH` | `/` | filesystem path the "Disk" row reports on |
| `NET_IFACE` | auto (default route) | force a specific network interface |
| `PUBLIC_IP_TTL` | `300` | seconds between public-IP lookups |
| `PUBLIC_IP_URL` | `https://icanhazip.com` | service used for the public-IP lookup |

To change position, size, or opacity, edit `desktop-stats.jsonc` (layer
margin) and `desktop-stats.css` (font size, padding, colors) directly in
`~/.config/waybar/`.

## Why not conky?

Because it doesn't work — see [Why this exists](#why-this-exists) above.
`omarchy-desktop-stats` is a thin waybar-based replacement that only
covers the always-on-desktop-widget use case, not conky's full Lua
scripting engine.

## Contributors

- [Luquas95](https://github.com/Luquas95) — creator & maintainer

## License

MIT, see [LICENSE](LICENSE).
