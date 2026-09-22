#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"
readonly label="local.mute-on-lock"
readonly destination="$HOME/Library/Application Support/Mute on lock"
readonly agent="$HOME/Library/LaunchAgents/$label.plist"

if ! command -v xcrun >/dev/null 2>&1 || ! xcrun --find swiftc >/dev/null 2>&1; then
    echo "Xcode Command Line Tools are required. Run: xcode-select --install" >&2
    exit 1
fi

mkdir -p build
xcrun swiftc -O -module-cache-path build/module-cache \
    -framework CoreAudio -framework CoreGraphics main.swift -o build/mute-on-lock
mkdir -p "$destination" "$HOME/Library/LaunchAgents" "$HOME/Library/Logs/Mute on lock"
chmod 700 "$destination" "$HOME/Library/Logs/Mute on lock"
launchctl bootout "gui/$(id -u)/$label" 2>/dev/null || true
install -m 755 build/mute-on-lock "$destination/mute-on-lock"
if [ ! -f "$destination/config.json" ]; then
    "$destination/mute-on-lock" --set-idle-minutes 15
fi
chmod 600 "$destination/config.json"
touch "$HOME/Library/Logs/Mute on lock/service.log"
chmod 600 "$HOME/Library/Logs/Mute on lock/service.log"
/usr/bin/python3 - "$agent" "$destination/mute-on-lock" "$HOME/Library/Logs/Mute on lock/service.log" <<'PY'
import plistlib, sys
with open(sys.argv[1], 'wb') as output:
    plistlib.dump({
        'Label': 'local.mute-on-lock',
        'ProgramArguments': [sys.argv[2]],
        'RunAtLoad': True,
        'KeepAlive': True,
        'ThrottleInterval': 10,
        'ProcessType': 'Background',
        'LimitLoadToSessionType': 'Aqua',
        'StandardOutPath': sys.argv[3],
        'StandardErrorPath': sys.argv[3],
    }, output)
PY
plutil -lint "$agent"
launchctl bootstrap "gui/$(id -u)" "$agent"
echo "Mute on Lock is installed and running."
"$destination/mute-on-lock" --status
