#!/bin/sh
# Print the single source of truth for stable SemVer releases.
set -eu
root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
version=$(cat "$root/VERSION")
case "$version" in
    ''|*[!0-9.]*) echo 'VERSION must contain a stable SemVer number (MAJOR.MINOR.PATCH).' >&2; exit 1 ;;
esac
printf '%s\n' "$version" | grep -Eq '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$' || {
    echo 'VERSION must contain MAJOR.MINOR.PATCH without leading zeroes.' >&2
    exit 1
}
printf '%s\n' "$version"
