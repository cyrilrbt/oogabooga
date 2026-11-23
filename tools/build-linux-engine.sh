#!/bin/sh
# Native x86-64 library built from the shared handwritten engine assembly.
set -eu
cd "$(dirname "$0")/.."
[ "$(uname -s)" = Linux ] && [ "$(uname -m)" = x86_64 ] || { echo 'Engine build requires x86-64 Linux.' >&2; exit 1; }
mode=${1:-debug}
case "$mode" in debug|release|test) ;; *) echo 'Usage: tools/build-linux-engine.sh [debug|release|test]' >&2; exit 1 ;; esac
cc=${CC:-cc}
flags=-g
[ "$mode" != release ] || flags=
mkdir -p build/linux/engine
python3 tools/asm/engine_x86.py build/linux/engine/core.s
"$cc" $flags -c build/linux/engine/core.s -o build/linux/engine/core.o
"$cc" $flags -c src/linux/engine/runtime.s -o build/linux/engine/runtime.o
ar rcs build/linux/engine/liboogabooga-engine.a build/linux/engine/core.o build/linux/engine/runtime.o
"$cc" $flags -pie -Wl,-z,relro,-z,now,-z,noexecstack src/linux/engine/inspect.s build/linux/engine/liboogabooga-engine.a -lm -o build/linux/engine-inspect
if [ "$mode" = test ]; then
    python3 tools/asm/test_engine_x86.py
    python3 -c 'import sys;sys.path.insert(0,"tools/asm");from engine_x86 import Backend;from pathlib import Path;Path("build/linux/engine/abi.s").write_text(Backend().generate(["tests/engine-abi.s"]))'
    "$cc" -g -D_GNU_SOURCE -Wall -Wextra -Werror tests/engine-abi.c build/linux/engine/abi.s -o build/linux/engine/abi-test -lm
    build/linux/engine/abi-test
    for name in engine dom js css imports fonts display-list scene linux-engine-profile; do
        "$cc" -g -D_GNU_SOURCE -Wall -Wextra -Werror "tests/$name.c" build/linux/engine/liboogabooga-engine.a -o "build/linux/engine/$name-test" -lm
        timeout 90 "build/linux/engine/$name-test"
    done
    build/linux/engine-inspect tests/fixtures/compat-docs-page.html 80 > build/linux/engine/inspect.txt
    grep -q 'Build the browser' build/linux/engine/inspect.txt
    grep -q 'Unicode survives: café' build/linux/engine/inspect.txt
    if build/linux/engine-inspect tests/fixtures/acid1.html 0 2>/dev/null; then
        echo 'FAIL: engine-inspect accepted invalid column count' >&2
        exit 1
    fi
fi
[ "$mode" != release ] || strip build/linux/engine-inspect
printf 'Built %s/build/linux/engine/liboogabooga-engine.a\n' "$PWD"
