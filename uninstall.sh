#!/bin/bash
set -euo pipefail

launchctl bootout "gui/$(id -u)/local.mute-on-lock" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/local.mute-on-lock.plist"
rm -f "$HOME/Library/Application Support/Mute on lock/mute-on-lock"
rmdir "$HOME/Library/Application Support/Mute on lock" 2>/dev/null || true
echo "Mute on lock uninstalled. Current audio settings are unchanged."
