#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
cc=${CC:-cc}
# Rename only the core's executable entry for the C test harness; shipped objects are unchanged.
objcopy --redefine-sym main=assembly_entry build/linux/obj/core.o build/linux/obj/core-smoke.o
"$cc" -Wall -Wextra -Werror tests/linux-browser.c build/linux/obj/core-smoke.o build/linux/obj/browser.o $(pkg-config --cflags --libs gtk+-3.0 webkit2gtk-4.1 sqlite3) -Wl,--wrap=gtk_main -o build/linux/browser-smoke
state=$(mktemp -d)
server_pid=
cleanup() {
    [ -z "$server_pid" ] || kill "$server_pid" 2>/dev/null || true
    find "$state" -depth -delete
}
trap cleanup EXIT
export XDG_DATA_HOME="$state/data" XDG_CACHE_HOME="$state/cache" XDG_CONFIG_HOME="$state/config"
# Do not disable WebKit's process sandbox for tests.
python3 tests/server.py > "$state/server.log" 2>&1 &
server_pid=$!
python3 - <<'PY'
import time, urllib.request
for i in range(100):
    try:
        urllib.request.urlopen('http://127.0.0.1:8765/').close()
        break
    except OSError:
        time.sleep(.1)
else:
    raise SystemExit('Local fixture did not start')
PY
xvfb-run -a dbus-run-session -- build/linux/browser-smoke
OOGABOOGA_SMOKE_RESTART=1 xvfb-run -a dbus-run-session -- build/linux/browser-smoke
