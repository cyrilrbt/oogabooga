#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
[ -x build/linux/oogabooga ] || { echo 'Run ./build.sh release on Linux first.' >&2; exit 1; }
mkdir -p build/dist
stage=$(mktemp -d)
trap 'find "$stage" -depth -delete' EXIT
mkdir -p "$stage/Oogabooga-linux-x86_64"
install -m755 build/linux/oogabooga "$stage/Oogabooga-linux-x86_64/oogabooga"
install -m644 VERSION README.md assets/oogabooga.desktop "$stage/Oogabooga-linux-x86_64/"
tar -C "$stage" -czf build/dist/Oogabooga-linux-x86_64.tar.gz Oogabooga-linux-x86_64
