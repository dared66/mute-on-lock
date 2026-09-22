#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"
readonly label="local.mute-on-lock"
readonly destination="$HOME/Library/Application Support/Mute on lock"
readonly agent="$HOME/Library/LaunchAgents/$label.plist"
readonly release_repository="dared66/mute-on-lock"
readonly release_version="v1.1.0"
readonly release_base="https://github.com/$release_repository/releases/download/$release_version"

download_dir="$(mktemp -d)"
trap 'rm -rf "$download_dir"' EXIT

echo "Downloading Mute on Lock $release_version…"
if ! curl --fail --location --silent --show-error --retry 3 \
    --output "$download_dir/mute-on-lock" "$release_base/mute-on-lock" || \
   ! curl --fail --location --silent --show-error --retry 3 \
    --output "$download_dir/mute-on-lock.sha256" "$release_base/mute-on-lock.sha256"; then
    rm -f "$download_dir/mute-on-lock" "$download_dir/mute-on-lock.sha256"
    if command -v gh >/dev/null 2>&1; then
        echo "Direct download unavailable; trying authenticated GitHub access…"
        gh release download "$release_version" --repo "$release_repository" \
            --pattern mute-on-lock --pattern mute-on-lock.sha256 --dir "$download_dir"
    else
        echo "Download failed. Private repository access requires the GitHub CLI (gh)." >&2
        exit 1
    fi
fi

expected_checksum="$(awk 'NR == 1 { print $1 }' "$download_dir/mute-on-lock.sha256")"
actual_checksum="$(shasum -a 256 "$download_dir/mute-on-lock" | awk '{ print $1 }')"
if [ -z "$expected_checksum" ] || [ "$expected_checksum" != "$actual_checksum" ]; then
    echo "Checksum verification failed; nothing was installed." >&2
    exit 1
fi
codesign --verify --strict "$download_dir/mute-on-lock"

mkdir -p "$destination" "$HOME/Library/LaunchAgents" "$HOME/Library/Logs/Mute on lock"
chmod 700 "$destination" "$HOME/Library/Logs/Mute on lock"
launchctl bootout "gui/$(id -u)/$label" 2>/dev/null || true
install -m 755 "$download_dir/mute-on-lock" "$destination/mute-on-lock"
if [ ! -f "$destination/config.json" ]; then
    "$destination/mute-on-lock" --set-idle-minutes 15
fi
chmod 600 "$destination/config.json"
touch "$HOME/Library/Logs/Mute on lock/service.log"
chmod 600 "$HOME/Library/Logs/Mute on lock/service.log"
rm -f "$agent"
plutil -create xml1 "$agent"
plutil -insert Label -string "$label" "$agent"
plutil -insert ProgramArguments -array "$agent"
plutil -insert ProgramArguments.0 -string "$destination/mute-on-lock" "$agent"
plutil -insert RunAtLoad -bool true "$agent"
plutil -insert KeepAlive -bool true "$agent"
plutil -insert ThrottleInterval -integer 10 "$agent"
plutil -insert ProcessType -string Background "$agent"
plutil -insert LimitLoadToSessionType -string Aqua "$agent"
plutil -insert StandardOutPath -string "$HOME/Library/Logs/Mute on lock/service.log" "$agent"
plutil -insert StandardErrorPath -string "$HOME/Library/Logs/Mute on lock/service.log" "$agent"
plutil -lint "$agent"
launchctl bootstrap "gui/$(id -u)" "$agent"
echo "Mute on Lock is installed and running."
"$destination/mute-on-lock" --status
