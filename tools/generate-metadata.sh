#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
version=$(./tools/version.sh)
release_date=$(date -u +%Y-%m-%d)
mkdir -p build/metadata
sed "s/@VERSION@/$version/g" assets/Info.plist > build/metadata/Info.plist
sed -e "s/@VERSION@/$version/g" -e "s/@RELEASE_DATE@/$release_date/g" \
    assets/dev.oogabooga.Browser.metainfo.xml > build/metadata/dev.oogabooga.Browser.metainfo.xml
