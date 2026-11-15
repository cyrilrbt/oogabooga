#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p build
xcrun clang -arch arm64 -mmacosx-version-min=12.0 -Wall -Wextra -Werror \
    -fobjc-arc tests/mac-layout-probe.m -framework Cocoa -o build/mac-layout-probe
build/mac-layout-probe "$@"
