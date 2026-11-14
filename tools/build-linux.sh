#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
[ "$(uname -s)" = Linux ] && [ "$(uname -m)" = x86_64 ] || { echo 'Linux build requires x86-64 Linux.' >&2; exit 1; }
mode=${1:-debug}
case "$mode" in debug|release|test) ;; *) echo 'Usage: ./build.sh [debug|release|test]' >&2; exit 1 ;; esac
cc=${CC:-cc}
pkg-config --exists gtk+-3.0 webkit2gtk-4.1 sqlite3 || { echo 'Install GTK 3, WebKitGTK 4.1, and SQLite development packages.' >&2; exit 1; }
./tools/generate-metadata.sh
mkdir -p build/linux/obj
install -m644 assets/oogabooga-512.png build/linux/oogabooga.png
flags='-g'
[ "$mode" != release ] || flags=''
"$cc" $flags -c src/linux/core.s -o build/linux/obj/core.o
"$cc" $flags -c src/linux/browser.s -o build/linux/obj/browser.o
"$cc" -pie -Wl,-z,relro,-z,now,-z,noexecstack build/linux/obj/core.o build/linux/obj/browser.o $(pkg-config --libs gtk+-3.0 webkit2gtk-4.1 sqlite3) -o build/linux/oogabooga
[ "$mode" != release ] || strip build/linux/oogabooga
if [ "$mode" = test ]; then
    "$cc" -Wall -Wextra -Werror tests/history.c build/linux/obj/core.o -lsqlite3 -o build/linux/history-test
    build/linux/history-test
fi
printf 'Built %s/build/linux/oogabooga\n' "$PWD"
