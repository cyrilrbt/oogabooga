#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
directory=${1:-build/compatibility}
status=0
./tools/benchmark-page.sh --report "$directory" tests/fixtures/compatibility.json || status=$?
if [ -f "$directory/results.json" ]; then
    python3 tools/compatibility-report.py "$directory"
fi
exit "$status"
