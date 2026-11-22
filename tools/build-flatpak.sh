#!/bin/sh
# CI's GNOME image already contains the SDK/runtime. Do not update its layered OSTree install.
set -eu
cd "$(dirname "$0")/.."
# Xvfb belongs to the CI container, not the SDK sandbox. Flatpak's test-args
# expose this display only while tests run. Re-enter once with a live display.
if [ -z "${DISPLAY:-}" ]; then
    command -v xvfb-run >/dev/null 2>&1 || {
        echo 'Install xvfb and xauth to run Flatpak GUI tests.' >&2
        exit 1
    }
    exec xvfb-run -a "$0" "$@"
fi
version=$(./tools/version.sh)
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
    build/flatpak-repo "build/dist/Oogabooga-${version}-linux-x86_64.flatpak" \
    dev.oogabooga.Browser stable
