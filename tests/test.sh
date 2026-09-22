#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
mkdir -p build
xcrun swiftc -warnings-as-errors -module-cache-path build/module-cache \
    -framework CoreAudio -framework CoreGraphics \
    main.swift -o build/mute-on-lock-test
build/mute-on-lock-test --help >/dev/null
build/mute-on-lock-test --status >/dev/null
bash -n install.sh uninstall.sh tests/test.sh scripts/build-release.sh
echo "PASS: build, command-line smoke tests, and shell syntax"
