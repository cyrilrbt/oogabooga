#!/bin/sh
set -eu
cd "$(dirname "$0")"
[ "$(uname -s)" != Linux ] || exec ./tools/build-linux.sh "$@"
[ "$(uname -s)" = Darwin ] && [ "$(uname -m)" = arm64 ] || { echo 'Requires Apple silicon macOS and Xcode command-line tools.' >&2; exit 1; }
mode=${1:-debug}
case "$mode" in debug|release|test) ;; *) echo 'Usage: ./build.sh [debug|release|test]' >&2; exit 1 ;; esac
mkdir -p build/obj build/asm build/Oogabooga.app/Contents/MacOS
flags='-arch arm64 -mmacosx-version-min=12.0'
opt='-O0 -g'
[ "$mode" != release ] || opt='-O2'
xcrun clang $flags $opt -Wall -Wextra -Wno-unused-parameter -Werror -fobjc-arc -S src/Browser.m -o build/asm/Browser.s
xcrun clang $flags -c build/asm/Browser.s -o build/obj/Browser.o
xcrun clang $flags -g -c src/core.s -o build/obj/core.o
xcrun clang $flags build/obj/core.o build/obj/Browser.o -framework Cocoa -framework WebKit -lsqlite3 -o build/oogabooga
[ "$mode" != release ] || strip -x build/oogabooga
cp build/oogabooga build/Oogabooga.app/Contents/MacOS/oogabooga.new
mv -f build/Oogabooga.app/Contents/MacOS/oogabooga.new build/Oogabooga.app/Contents/MacOS/oogabooga
./tools/generate-metadata.sh
cp build/metadata/Info.plist build/Oogabooga.app/Contents/Info.plist
codesign --force --sign - build/Oogabooga.app
if [ "$mode" = test ]; then
    xcrun clang $flags -Wall -Wextra -Werror tests/history.c build/obj/core.o -lsqlite3 -o build/history-test
    build/history-test
fi
printf 'Built %s/build/Oogabooga.app\n' "$PWD"
