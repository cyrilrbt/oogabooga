#!/bin/sh
# C files are assertion harnesses only; production rendering stays assembly.
set -eu
cd "$(dirname "$0")/.."
cc=${CC:-cc}
case "${1:-}" in ''|--existing) ;; *) echo 'Usage: tools/test-linux-renderer.sh [--existing]' >&2; exit 1 ;; esac
./tools/generate-metadata.sh
mkdir -p build/linux/engine
"$cc" -g -c src/linux/core.s -o build/linux/engine/storage.o
objcopy --redefine-sym main=unused_storage_entry build/linux/engine/storage.o
if [ "${1:-}" != --existing ]; then
    python3 tools/asm/engine_x86.py --gtk build/linux/engine/gtk.s
    "$cc" -g -c build/linux/engine/gtk.s -o build/linux/engine/gtk.o
fi
python3 tools/asm/compat_cases.py
for name in renderer session svg compatibility auth acid1 interaction layout dom; do
    "$cc" -g -Wall -Wextra -Werror -Wno-misleading-indentation -Ibuild/linux/engine \
        "tests/linux-$name.c" build/linux/engine/gtk.o src/linux/engine/runtime.s \
        build/linux/engine/storage.o -Wl,--defsym,browser_main=0 -lsqlite3 \
        $(pkg-config --cflags --libs gtk+-3.0 pangocairo libsoup-3.0 fontconfig pangoft2) \
        -lm -o "build/linux/engine/$name-renderer-test"
    xvfb-run -a timeout 90 "build/linux/engine/$name-renderer-test"
done
