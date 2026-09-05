#!/bin/sh
# Starts the second waybar instance (see README) from Sway's `exec`. Needs a
# pgrep guard because unlike Hyprland's `exec-once`, Sway re-runs every plain
# `exec` line on `sway reload` — without the guard you'd get a second waybar
# process stacking on top of the first one every time you reload the config.
# Keep the guard in its own script file, not inline in the `exec` command:
# inline, `pgrep -f` matches the wrapping "sh -c" process's own cmdline
# (which literally contains the same waybar command text as a fallback) and
# always thinks the widget is already running, even when it isn't.
pgrep -f "[w]aybar -c .*desktop-stats\.jsonc" >/dev/null || \
  exec waybar -c ~/.config/waybar/desktop-stats.jsonc -s ~/.config/waybar/desktop-stats.css
