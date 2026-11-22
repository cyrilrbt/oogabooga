#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
if [ "$(uname -s)" = Linux ]; then
    [ -f build/linux/engine/liboogabooga-engine.a ] || ./tools/build-linux-engine.sh
    "${CC:-cc}" -O2 -Wall -Wextra -Werror tests/bench-layout.c build/linux/engine/liboogabooga-engine.a -o build/linux/bench-layout -lm
    exec build/linux/bench-layout
fi
[ "$(uname -s)" = Darwin ] && [ "$(uname -m)" = arm64 ] || { echo 'Requires Apple silicon macOS.' >&2; exit 1; }
[ -f build/obj/engine_floats.o ] || { echo 'Run ./build.sh first.' >&2; exit 1; }
xcrun clang -arch arm64 -O2 -Wall -Wextra -Werror tests/bench-layout.c build/obj/engine_*.o -o build/bench-layout
exec build/bench-layout
