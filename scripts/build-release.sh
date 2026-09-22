#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
readonly output_dir="dist"
readonly module_cache="build/module-cache"
readonly minimum_macos="13.0"

mkdir -p "$output_dir" "$module_cache"

xcrun swiftc -O -warnings-as-errors \
    -module-cache-path "$module_cache" \
    -target "arm64-apple-macos$minimum_macos" \
    -framework CoreAudio -framework CoreGraphics \
    main.swift -o "$output_dir/mute-on-lock"
codesign --force --sign - --identifier local.mute-on-lock "$output_dir/mute-on-lock"
chmod 755 "$output_dir/mute-on-lock"

(cd "$output_dir" && shasum -a 256 mute-on-lock > mute-on-lock.sha256)
file "$output_dir/mute-on-lock"
codesign --verify --strict --verbose=2 "$output_dir/mute-on-lock"
echo "Release assets written to $output_dir/."
