#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
[ "$(uname -s)" = Darwin ] && [ "$(uname -m)" = arm64 ] || { echo 'Requires Apple silicon macOS.' >&2; exit 1; }
[ -f build/obj/engine_floats.o ] || { echo 'Run ./build.sh first.' >&2; exit 1; }
xcrun clang -arch arm64 -O2 -Wall -Wextra -Werror tests/bench-layout.c build/obj/engine_*.o -o build/bench-layout
exec build/bench-layout
