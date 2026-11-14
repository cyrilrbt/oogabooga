#!/bin/sh
# Package the supplied artwork at native macOS icon resolutions without redrawing it.
set -eu
cd "$(dirname "$0")/.."
source=assets/oogabooga.png
iconset=build/Oogabooga.iconset
output=build/Oogabooga.app/Contents/Resources/Oogabooga.icns
if [ -f "$output" ] && [ "$output" -nt "$source" ] && [ "$output" -nt tools/build-mac-icon.sh ]; then
    exit 0
fi
mkdir -p "$iconset" "$(dirname "$output")"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$source" --out "$iconset/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z "$double" "$double" "$source" --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$iconset" -o "$output"
