#!/bin/bash
# Removes the omarchy-desktop-stats waybar panel for the current user.
set -euo pipefail

WAYBAR_DIR="$HOME/.config/waybar"
AUTOSTART="$HOME/.config/hypr/autostart.conf"

echo "==> Stopping the panel"
pkill -f "waybar -c .*desktop-stats.jsonc" 2>/dev/null || true

echo "==> Removing installed files"
rm -f "$WAYBAR_DIR/desktop-stats.jsonc" \
      "$WAYBAR_DIR/desktop-stats.css" \
      "$WAYBAR_DIR/desktop-stats.conf.example" \
      "$WAYBAR_DIR/scripts/sysstats.sh"
echo "  removed panel files (desktop-stats.conf, if you made one, was left in place)"

if [ -f "$AUTOSTART" ] && grep -qF "desktop-stats.jsonc" "$AUTOSTART"; then
  cp "$AUTOSTART" "$AUTOSTART.bak.$(date +%s)"
  grep -vF "desktop-stats.jsonc" "$AUTOSTART" > "$AUTOSTART.tmp"
  mv "$AUTOSTART.tmp" "$AUTOSTART"
  echo "==> Removed the exec-once line from $AUTOSTART (backup saved alongside it)"
fi

echo "==> Done."
