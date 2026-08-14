# omarchy-desktop-stats

A conky-style system stats widget for [Omarchy](https://omarchy.org/) (Hyprland) that
actually stays **behind** your application windows.

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

- CPU temperature (package + per-core, if your hardware exposes it)
- CPU / RAM / Swap / Disk usage, each with a color-coded progress bar
  (green / orange / red based on load)
- Uptime
- Wi-Fi SSID, local IP, public IP, Tailscale IP, network throughput
- Running Docker containers

Everything is optional and degrades gracefully: if you don't have Docker,
Tailscale, a Wi-Fi card, or an Intel/AMD temperature sensor, that row is
either hidden or shown with a clear fallback instead of breaking the panel.

## Requirements

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

## Install

```sh
git clone https://github.com/<you>/omarchy-desktop-stats.git
cd omarchy-desktop-stats
./install.sh
```

This copies the panel files into `~/.config/waybar/`, adds an `exec-once`
line to `~/.config/hypr/autostart.conf` (only if one isn't already there),
and starts the panel immediately so you don't need to log out.

## Configure

Copy the example config and edit it:

```sh
cp ~/.config/waybar/desktop-stats.conf.example ~/.config/waybar/desktop-stats.conf
```

It lets you override the color thresholds, colors, which disk path is
reported, which network interface is used (auto-detected by default via the
default route), and the public-IP lookup service/cache time. See the
comments in the file for details.

To change position, size, or opacity, edit `desktop-stats.jsonc` (layer
margin, panel background) and `desktop-stats.css` (font size, padding,
colors) directly.

## Uninstall

```sh
./uninstall.sh
```

## How the "reaches the edge" progress bars work

The bars are plain monospace text (`▄` half-block glyphs), not a real GTK
widget — waybar custom modules only render Pango-marked-up text. Each
refresh, the script measures the longest line it's about to print (across
every section, including the Docker container list) and sizes every bar to
that exact character width, so the bars start and end flush with the rest
of the content instead of trailing off early.

## License

MIT, see [LICENSE](LICENSE).
