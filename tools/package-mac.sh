#!/bin/sh
# Package an already-built app without modifying its signed contents.
set -eu
cd "$(dirname "$0")/.."
app=build/Oogabooga.app
out=build/dist
[ -d "$app" ] || { echo 'Run ./build.sh release first.' >&2; exit 1; }
codesign --verify --deep --strict "$app"
plutil -lint "$app/Contents/Info.plist"
mkdir -p "$out"
stage=$(mktemp -d "${TMPDIR:-/tmp}/oogabooga-dmg.XXXXXX")
trap '/usr/bin/find "$stage" -depth -delete' EXIT
# ditto preserves the executable bit and macOS bundle metadata in the ZIP.
ditto -c -k --sequesterRsrc --keepParent "$app" "$out/Oogabooga-macos-arm64.app.zip"
ditto "$app" "$stage/Oogabooga.app"
ln -s /Applications "$stage/Applications"
hdiutil create -volname Oogabooga -srcfolder "$stage" -ov -format UDZO "$out/Oogabooga-macos-arm64.dmg"
hdiutil verify "$out/Oogabooga-macos-arm64.dmg"
(
    cd "$out"
    shasum -a 256 Oogabooga-macos-arm64.app.zip Oogabooga-macos-arm64.dmg > SHA256SUMS
)
printf 'Packages: %s/%s\n' "$PWD" "$out"
