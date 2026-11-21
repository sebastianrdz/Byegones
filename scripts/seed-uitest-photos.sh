#!/bin/zsh
# Seeds the simulator's Photos library with generated sample photos for the UI tests.
# The UI tests that delete consume photos, so re-run this before a fresh run.
# Usage: scripts/seed-uitest-photos.sh <simulator-udid> [count]   (default count 24)
set -euo pipefail
udid=${1:?usage: seed-uitest-photos.sh <simulator-udid> [count]}
count=${2:-24}
root=${0:A:h:h}
out="$root/build/qa/uitest-photos"
rm -rf "$out"
swift "$root/scripts/make-sample-photos.swift" "$out" "$count"
xcrun simctl addmedia "$udid" "$out"/*.jpg
echo "seeded $count photos into $udid"
