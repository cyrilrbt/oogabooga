#!/bin/sh
set -eu
cd "$(dirname "$0")"
[ "$(uname -s)" != Linux ] || exec ./tools/build-linux.sh "$@"
[ "$(uname -s)" = Darwin ] && [ "$(uname -m)" = arm64 ] || { echo 'Requires Apple silicon macOS and Xcode command-line tools.' >&2; exit 1; }
mode=${1:-debug}
case "$mode" in debug|release|test) ;; *) echo 'Usage: ./build.sh [debug|release|test]' >&2; exit 1 ;; esac
mkdir -p build/obj build/Oogabooga.app/Contents/MacOS
flags='-arch arm64 -mmacosx-version-min=12.0'
objects="build/obj/core.o"
xcrun clang $flags -g -c src/core.s -o build/obj/core.o
for source in src/mac/*.s src/engine/*.s; do
    object="build/obj/$(basename "$(dirname "$source")")_$(basename "$source" .s).o"
    xcrun clang $flags -g -c "$source" -o "$object"
    objects="$objects $object"
done
xcrun clang $flags $objects -framework Cocoa -framework WebKit -lsqlite3 -o build/oogabooga
[ "$mode" != release ] || strip -x build/oogabooga
cp build/oogabooga build/Oogabooga.app/Contents/MacOS/oogabooga.new
mv -f build/Oogabooga.app/Contents/MacOS/oogabooga.new build/Oogabooga.app/Contents/MacOS/oogabooga
./tools/generate-metadata.sh
cp build/metadata/Info.plist build/Oogabooga.app/Contents/Info.plist
codesign --force --sign - build/Oogabooga.app
if [ "$mode" = test ]; then
    xcrun clang $flags -Wall -Wextra -Werror tests/history.c build/obj/core.o -lsqlite3 -o build/history-test
    build/history-test
    xcrun clang $flags -Wall -Wextra -Werror tests/engine.c build/obj/engine_*.o -o build/engine-test
    build/engine-test
    xcrun clang $flags -Wall -Wextra -Werror tests/css.c build/obj/engine_*.o -o build/css-test
    build/css-test
    test_objects="build/obj/core.o"
    for source in src/mac/*.s src/engine/*.s; do
        [ "$source" = src/mac/start.s ] || test_objects="$test_objects build/obj/$(basename "$(dirname "$source")")_$(basename "$source" .s).o"
    done
    xcrun clang $flags -Wall -Wextra -Werror -fobjc-arc tests/mac-url.m $test_objects -framework Cocoa -framework WebKit -lsqlite3 -o build/mac-url-test
    build/mac-url-test
    xcrun clang $flags -Wall -Wextra -Werror -fobjc-arc tests/mac-charset.m $test_objects -framework Cocoa -framework WebKit -lsqlite3 -o build/mac-charset-test
    build/mac-charset-test
    xcrun clang $flags -Wall -Wextra -Werror -fobjc-arc tests/mac-delegates.m $test_objects -framework Cocoa -framework WebKit -lsqlite3 -o build/mac-delegates-test
    build/mac-delegates-test
    xcrun clang $flags -Wall -Wextra -Werror -fobjc-arc tests/mac-engine.m $test_objects -framework Cocoa -framework WebKit -lsqlite3 -o build/mac-engine-test
    build/mac-engine-test
fi
printf 'Built %s/build/Oogabooga.app\n' "$PWD"
