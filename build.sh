#!/bin/sh
set -eu
cd "$(dirname "$0")"
[ "$(uname -s)" != Linux ] || exec ./tools/build-linux.sh "$@"
[ "$(uname -s)" = Darwin ] && [ "$(uname -m)" = arm64 ] || { echo 'Requires Apple silicon macOS and Xcode command-line tools.' >&2; exit 1; }
mode=${1:-debug}
case "$mode" in debug|release|test) ;; *) echo 'Usage: ./build.sh [debug|release|test]' >&2; exit 1 ;; esac
mkdir -p build/obj build/Oogabooga.app/Contents/MacOS build/Oogabooga.app/Contents/Resources
./tools/generate-metadata.sh
flags='-arch arm64 -mmacosx-version-min=12.0'
objects="build/obj/core.o"
xcrun clang $flags -g -c src/core.s -o build/obj/core.o
for source in src/mac/*.s src/engine/*.s; do
    object="build/obj/$(basename "$(dirname "$source")")_$(basename "$source" .s).o"
    xcrun clang $flags -g -c "$source" -o "$object"
    objects="$objects $object"
done
xcrun clang $flags $objects -framework Cocoa -framework CoreText -framework ImageIO -framework WebKit -lsqlite3 -o build/oogabooga
[ "$mode" != release ] || strip -x build/oogabooga
cp build/oogabooga build/Oogabooga.app/Contents/MacOS/oogabooga.new
mv -f build/Oogabooga.app/Contents/MacOS/oogabooga.new build/Oogabooga.app/Contents/MacOS/oogabooga
cp build/metadata/Info.plist build/Oogabooga.app/Contents/Info.plist
cp LICENSE CHANGELOG.md build/Oogabooga.app/Contents/Resources/
./tools/build-mac-icon.sh
codesign --force --sign - build/Oogabooga.app
if [ "$mode" = test ]; then
    xcrun clang $flags -g -c tests/engine-abi.s -o build/engine-abi.o
    xcrun clang $flags -Wall -Wextra -Werror tests/engine-abi.c build/engine-abi.o -o build/engine-abi-test
    build/engine-abi-test
    xcrun clang $flags -Wall -Wextra -Werror tests/history.c build/obj/core.o -lsqlite3 -o build/history-test
    build/history-test
    xcrun clang $flags -Wall -Wextra -Werror tests/engine.c build/obj/engine_*.o -o build/engine-test
    build/engine-test
    xcrun clang $flags -Wall -Wextra -Werror tests/dom.c build/obj/engine_*.o -o build/dom-test
    build/dom-test
    xcrun clang $flags -Wall -Wextra -Werror tests/css.c build/obj/engine_*.o -o build/css-test
    build/css-test
    xcrun clang $flags -Wall -Wextra -Werror tests/imports.c build/obj/engine_*.o -o build/imports-test
    build/imports-test
    xcrun clang $flags -Wall -Wextra -Werror tests/fonts.c build/obj/engine_*.o -o build/fonts-test
    build/fonts-test
    xcrun clang $flags -Wall -Wextra -Werror tests/display-list.c build/obj/engine_*.o -o build/display-list-test
    build/display-list-test
    xcrun clang $flags -Wall -Wextra -Werror tests/scene.c build/obj/engine_*.o -o build/scene-test
    build/scene-test
    test_objects="build/obj/core.o"
    for source in src/mac/*.s src/engine/*.s; do
        [ "$source" = src/mac/start.s ] || test_objects="$test_objects build/obj/$(basename "$(dirname "$source")")_$(basename "$source" .s).o"
    done
    xcrun clang $flags -Wall -Wextra -Werror -fobjc-arc tests/mac-url.m $test_objects -framework Cocoa -framework CoreText -framework ImageIO -framework WebKit -lsqlite3 -o build/mac-url-test
    build/mac-url-test
    xcrun clang $flags -Wall -Wextra -Werror -fobjc-arc tests/mac-charset.m $test_objects -framework Cocoa -framework CoreText -framework ImageIO -framework WebKit -lsqlite3 -o build/mac-charset-test
    build/mac-charset-test
    xcrun clang $flags -Wall -Wextra -Werror -fobjc-arc tests/mac-delegates.m $test_objects -framework Cocoa -framework CoreText -framework ImageIO -framework WebKit -lsqlite3 -o build/mac-delegates-test
    build/mac-delegates-test
    xcrun clang $flags -Wall -Wextra -Werror -fobjc-arc tests/mac-shortcuts.m $test_objects -framework Cocoa -framework CoreText -framework ImageIO -framework WebKit -lsqlite3 -o build/mac-shortcuts-test
    build/mac-shortcuts-test
    xcrun clang $flags -Wall -Wextra -Werror -fobjc-arc tests/mac-inline.m $test_objects -framework Cocoa -framework CoreText -framework ImageIO -framework WebKit -lsqlite3 -o build/mac-inline-test
    build/mac-inline-test
    sh ./tools/probe-mac-layout.sh
    xcrun clang $flags -Wall -Wextra -Werror -fobjc-arc tests/mac-engine.m $test_objects -framework Cocoa -framework CoreText -framework ImageIO -framework WebKit -lsqlite3 -o build/mac-engine-test
    build/mac-engine-test
    xcrun clang $flags -Wall -Wextra -Werror -fobjc-arc tests/mac-svg.m $test_objects -framework Cocoa -framework CoreText -framework ImageIO -framework WebKit -lsqlite3 -o build/mac-svg-test
    build/mac-svg-test
    ./tools/benchmark-page.sh --reference
    sh ./tools/compatibility-report.sh
fi
printf 'Built %s/build/Oogabooga.app\n' "$PWD"
