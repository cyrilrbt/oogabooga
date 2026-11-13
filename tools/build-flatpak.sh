#!/bin/sh
# CI's GNOME image already contains the SDK/runtime. Do not update its layered OSTree install.
set -eu
cd "$(dirname "$0")/.."
mkdir -p build/dist
flatpak-builder \
    --arch=x86_64 \
    --disable-rofiles-fuse \
    --force-clean \
    --default-branch=stable \
    --repo=build/flatpak-repo \
    build/flatpak-app flatpak/dev.oogabooga.Browser.json
flatpak build-bundle \
    --arch=x86_64 \
    --runtime-repo=https://flathub.org/repo/flathub.flatpakrepo \
    build/flatpak-repo build/dist/Oogabooga-linux-x86_64.flatpak \
    dev.oogabooga.Browser stable
