#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
[ "$(uname -s)" = Darwin ] && [ "$(uname -m)" = arm64 ] || { echo 'Requires Apple silicon macOS.' >&2; exit 1; }
[ -f build/obj/mac_display.o ] || { echo 'Run ./build.sh first.' >&2; exit 1; }
objects=build/obj/core.o
for source in src/mac/*.s src/engine/*.s; do
    [ "$source" = src/mac/start.s ] || objects="$objects build/obj/$(basename "$(dirname "$source")")_$(basename "$source" .s).o"
done
xcrun clang -arch arm64 -O2 -Wall -Wextra -Werror -fobjc-arc tests/bench-page.m $objects -framework Cocoa -framework CoreText -framework ImageIO -framework WebKit -lsqlite3 -o build/bench-page
exec build/bench-page "$@"
