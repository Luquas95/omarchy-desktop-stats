#!/bin/bash
# Removes the sway-desktop-stats waybar panel for the current user.
set -euo pipefail

WAYBAR_DIR="$HOME/.config/waybar"
SWAY_SCRIPTS_DIR="$HOME/.config/sway/scripts"
SWAY_CONFIG="$HOME/.config/sway/config"

echo "==> Stopping the panel"
pkill -f "waybar -c .*desktop-stats.jsonc" 2>/dev/null || true

echo "==> Removing installed files"
rm -f "$WAYBAR_DIR/desktop-stats.jsonc" \
      "$WAYBAR_DIR/desktop-stats.css" \
      "$WAYBAR_DIR/desktop-stats.conf.example" \
      "$WAYBAR_DIR/scripts/sysstats.sh" \
      "$SWAY_SCRIPTS_DIR/desktop-stats-widget.sh"
echo "  removed panel files (desktop-stats.conf, if you made one, was left in place)"

if [ -f "$SWAY_CONFIG" ] && grep -qF "desktop-stats-widget.sh" "$SWAY_CONFIG"; then
  cp "$SWAY_CONFIG" "$SWAY_CONFIG.bak.$(date +%s)"
  grep -vF "desktop-stats-widget.sh" "$SWAY_CONFIG" > "$SWAY_CONFIG.tmp"
  mv "$SWAY_CONFIG.tmp" "$SWAY_CONFIG"
  echo "==> Removed the exec line from $SWAY_CONFIG (backup saved alongside it)"
fi

echo "==> Done."
