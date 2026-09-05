#!/bin/bash
# Installs the sway-desktop-stats waybar panel for the current user.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WAYBAR_DIR="$HOME/.config/waybar"
SWAY_SCRIPTS_DIR="$HOME/.config/sway/scripts"
SWAY_CONFIG="$HOME/.config/sway/config"
EXEC_LINE='exec ~/.config/sway/scripts/desktop-stats-widget.sh'

echo "==> Checking dependencies"

if ! command -v waybar >/dev/null 2>&1; then
  echo "ERROR: waybar is not installed. This panel is a second waybar instance," >&2
  echo "       so waybar itself is required." >&2
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

echo "==> Installing panel files to $WAYBAR_DIR"
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

echo "==> Installing the Sway launch guard to $SWAY_SCRIPTS_DIR"
mkdir -p "$SWAY_SCRIPTS_DIR"
cp "$SCRIPT_DIR/sway/desktop-stats-widget.sh" "$SWAY_SCRIPTS_DIR/desktop-stats-widget.sh"
chmod +x "$SWAY_SCRIPTS_DIR/desktop-stats-widget.sh"
echo "  installed sway/scripts/desktop-stats-widget.sh"
echo "  (this exists because unlike Hyprland's exec-once, Sway re-runs a plain"
echo "   \`exec\` line on every \`sway reload\` - the guard prevents duplicate panels)"

echo "==> Wiring up Sway's exec"
if [ -f "$SWAY_CONFIG" ]; then
  if grep -qF "desktop-stats-widget.sh" "$SWAY_CONFIG"; then
    echo "  sway config already references desktop-stats-widget.sh, leaving it alone"
  else
    printf '\n%s\n' "$EXEC_LINE" >> "$SWAY_CONFIG"
    echo "  added exec line to $SWAY_CONFIG"
  fi
else
  echo "  WARNING: $SWAY_CONFIG not found."
  echo "  Add this line to your Sway config manually:"
  echo "    $EXEC_LINE"
fi

echo "==> Adjusting output name(s) in desktop-stats.jsonc"
echo "  The shipped config targets outputs named 'eDP-1' and 'HDMI-A-2' (this"
echo "  author's laptop + external monitor). Check your own output names with:"
echo "    swaymsg -t get_outputs"
echo "  and edit the \"output\" fields in $WAYBAR_DIR/desktop-stats.jsonc to match"
echo "  (an output block for a monitor that isn't connected is simply skipped,"
echo "  so it's safe to leave extra blocks in for monitors you only use sometimes)."

echo "==> Starting the panel now"
pkill -f "waybar -c .*desktop-stats.jsonc" 2>/dev/null || true
sleep 0.5
setsid waybar -c "$WAYBAR_DIR/desktop-stats.jsonc" -s "$WAYBAR_DIR/desktop-stats.css" >/dev/null 2>&1 &
disown

echo "==> Done. The panel should now be visible."
echo "    Config: $WAYBAR_DIR/desktop-stats.jsonc / .css"
echo "    Overrides: copy $WAYBAR_DIR/desktop-stats.conf.example to desktop-stats.conf"
