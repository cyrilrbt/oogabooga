#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
version=$(./tools/version.sh)
release_date=$(date -u +%Y-%m-%d)
mkdir -p build/metadata
cat > build/metadata/app-titles.inc <<EOF
.globl _ooga_app_title, _ooga_web_title_suffix, _ooga_engine_title_suffix, _ooga_popup_title
_ooga_app_title: .asciz "Oogabooga $version"
_ooga_web_title_suffix: .asciz " — Oogabooga $version"
_ooga_engine_title_suffix: .asciz " — Assembly · Oogabooga $version"
_ooga_popup_title: .asciz "Oogabooga $version — New Window"
EOF
sed "s/@VERSION@/$version/g" assets/Info.plist > build/metadata/Info.plist
sed -e "s/@VERSION@/$version/g" -e "s/@RELEASE_DATE@/$release_date/g" \
    assets/dev.oogabooga.Browser.metainfo.xml > build/metadata/dev.oogabooga.Browser.metainfo.xml
