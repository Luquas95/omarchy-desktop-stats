#!/bin/bash
# Installs the omarchy-desktop-stats waybar panel for the current user.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WAYBAR_DIR="$HOME/.config/waybar"
AUTOSTART="$HOME/.config/hypr/autostart.conf"
EXEC_LINE='exec-once = waybar -c ~/.config/waybar/desktop-stats.jsonc -s ~/.config/waybar/desktop-stats.css'

echo "==> Checking dependencies"

if ! command -v waybar >/dev/null 2>&1; then
  echo "ERROR: waybar is not installed. This panel is a second waybar instance," >&2
  echo "       so waybar itself is required. Install it first (it ships with Omarchy)." >&2
  exit 1
fi
echo "  waybar: found"

for tool in docker tailscale curl iwctl nmcli; do
  if command -v "$tool" >/dev/null 2>&1; then
    echo "  $tool: found"
  else
    echo "  $tool: not found (optional - that section will just show a fallback)"
  fi
done

echo "==> Installing files to $WAYBAR_DIR"
mkdir -p "$WAYBAR_DIR/scripts"

for f in desktop-stats.jsonc desktop-stats.css; do
  dest="$WAYBAR_DIR/$f"
  if [ -f "$dest" ]; then
    cp "$dest" "$dest.bak.$(date +%s)"
    echo "  backed up existing $f"
  fi
  cp "$SCRIPT_DIR/$f" "$dest"
  echo "  installed $f"
done

cp "$SCRIPT_DIR/scripts/sysstats.sh" "$WAYBAR_DIR/scripts/sysstats.sh"
chmod +x "$WAYBAR_DIR/scripts/sysstats.sh"
echo "  installed scripts/sysstats.sh"

if [ ! -f "$WAYBAR_DIR/desktop-stats.conf" ]; then
  cp "$SCRIPT_DIR/desktop-stats.conf.example" "$WAYBAR_DIR/desktop-stats.conf.example"
  echo "  copied desktop-stats.conf.example (copy it to desktop-stats.conf to customize)"
fi

echo "==> Wiring up autostart"
if [ -f "$AUTOSTART" ]; then
  if grep -qF "desktop-stats.jsonc" "$AUTOSTART"; then
    echo "  autostart.conf already references desktop-stats.jsonc, leaving it alone"
  else
    printf '%s\n' "$EXEC_LINE" >> "$AUTOSTART"
    echo "  added exec-once line to $AUTOSTART"
  fi
else
  echo "  WARNING: $AUTOSTART not found (this doesn't look like a standard Omarchy setup)."
  echo "  Add this line to your Hyprland autostart config manually:"
  echo "    $EXEC_LINE"
fi

echo "==> Starting the panel now"
pkill -f "waybar -c .*desktop-stats.jsonc" 2>/dev/null || true
sleep 0.5
setsid waybar -c "$WAYBAR_DIR/desktop-stats.jsonc" -s "$WAYBAR_DIR/desktop-stats.css" >/dev/null 2>&1 &
disown

echo "==> Done. The panel should now be visible in the top-right corner."
echo "    Config: $WAYBAR_DIR/desktop-stats.jsonc / .css"
echo "    Overrides: copy $WAYBAR_DIR/desktop-stats.conf.example to desktop-stats.conf"
