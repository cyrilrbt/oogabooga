#!/bin/sh
# Live static-page screenshots from the custom renderer and system WebKit.
set -eu
cd "$(dirname "$0")/.."
[ "$#" -ge 1 ] && [ "$#" -le 2 ] || { echo 'Usage: sh tools/compare-page.sh URL [OUTPUT_DIRECTORY]' >&2; exit 2; }
[ "$(uname -s)" = Darwin ] && [ "$(uname -m)" = arm64 ] || { echo 'Requires Apple silicon macOS.' >&2; exit 1; }
[ -f build/obj/mac_display.o ] || { echo 'Run ./build.sh first.' >&2; exit 1; }
objects=build/obj/core.o
for source in src/mac/*.s src/engine/*.s; do
    [ "$source" = src/mac/start.s ] || objects="$objects build/obj/$(basename "$(dirname "$source")")_$(basename "$source" .s).o"
done
xcrun clang -arch arm64 -O2 -Wall -Wextra -Werror -fobjc-arc tests/compare-page.m $objects \
    -framework Cocoa -framework CoreText -framework ImageIO -framework WebKit -lsqlite3 -o build/compare-page
exec build/compare-page "$1" "${2:-build/page-comparison}"
