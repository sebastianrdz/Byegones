#!/usr/bin/env bash
# Capture raw App Store screenshots (EN + ES) from the iPhone 17 Pro Max simulator.
# Output: marketing/screenshots/raw/<lang>/<n>-<scene>.png
# Env: SIM_NAME (default "iPhone 17 Pro Max"), PHOTO_DIR (use your own license-free images
#      instead of generated ones), PHOTO_COUNT (default 36), SETTLE (seconds, default 2).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SIM_NAME="${SIM_NAME:-iPhone 17 Pro Max}"
SETTLE="${SETTLE:-2}"
DERIVED="build/wp8"
OUT="marketing/screenshots/raw"
SCENES=(onboarding swipe keep favorite undo trash celebration)

UDID="$(xcrun simctl list devices available | awk -v n="$SIM_NAME" 'index($0, n " (") {match($0, /[0-9A-F]{8}-[0-9A-F-]{27}/); print substr($0, RSTART, RLENGTH); exit}')"
[[ -n "$UDID" ]] || { echo "Simulator '$SIM_NAME' not found" >&2; exit 1; }

echo "== Build for simulator =="
xcodebuild -project PhotoCleaner.xcodeproj -scheme PhotoCleaner -configuration Debug \
  -destination "platform=iOS Simulator,id=$UDID" -derivedDataPath "$DERIVED" \
  CODE_SIGNING_ALLOWED=NO build -quiet
APP="$DERIVED/Build/Products/Debug-iphonesimulator/PhotoCleaner.app"
[[ -d "$APP" ]] || { echo "Built app not found at $APP" >&2; exit 1; }
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist")"

echo "== Boot simulator $UDID =="
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null
xcrun simctl ui "$UDID" appearance light
xcrun simctl status_bar "$UDID" override --time 9:41 --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3
trap 'xcrun simctl status_bar "$UDID" clear || true; xcrun simctl ui "$UDID" appearance light || true' EXIT

echo "== Seed sample photos =="
# A freshly created simulator has no library, so generate abstract images (no real photos, no EXIF).
PHOTOS="${PHOTO_DIR:-build/wp8-sample-photos}"
if [[ -z "${PHOTO_DIR:-}" ]]; then
  rm -rf "$PHOTOS"
  swift scripts/make-sample-photos.swift "$PHOTOS" "${PHOTO_COUNT:-36}"
fi
find "$PHOTOS" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.heic' \) -print0 | xargs -0 xcrun simctl addmedia "$UDID"

echo "== Install and grant Photos access =="
xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl install "$UDID" "$APP"
# simctl privacy grant is unreliable for the iOS 26 Photos prompt (the system alert still appears),
# so a tiny standalone UI test taps "Allow Full Access" once. It lives in scripts/grant-photos and
# is not part of the app project. Parallel testing is off because clones lose the permission.
xcrun simctl privacy "$UDID" reset photos "$BUNDLE_ID" || true
TEST_RUNNER_BUNDLE_ID="$BUNDLE_ID" xcodebuild test -project scripts/grant-photos/Grant.xcodeproj -scheme GrantUITests \
  -destination "platform=iOS Simulator,id=$UDID" -derivedDataPath build/wp8-grant \
  -parallel-testing-enabled NO -quiet >/dev/null
xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true

capture() { # lang scene n outname [locale-args...]
  local lang="$1" scene="$2" file="$3"; shift 3
  mkdir -p "$OUT/$lang"
  xcrun simctl launch --terminate-running-process "$UDID" "$BUNDLE_ID" \
    -screenshotMode YES -screenshotScene "$scene" "$@" >/dev/null
  sleep "$SETTLE"
  xcrun simctl io "$UDID" screenshot --type=png "$OUT/$lang/$file" >/dev/null
  echo "  $OUT/$lang/$file"
}

for lang in en es; do
  if [[ "$lang" == es ]]; then LOCALE=(-AppleLanguages "(es)" -AppleLocale es_MX); else LOCALE=(-AppleLanguages "(en)" -AppleLocale en_US); fi
  echo "== $lang =="
  xcrun simctl ui "$UDID" appearance light
  n=0
  for scene in "${SCENES[@]}"; do
    n=$((n + 1))
    capture "$lang" "$scene" "$n-$scene.png" "${LOCALE[@]}"
  done
  xcrun simctl ui "$UDID" appearance dark
  capture "$lang" swipe "$((n + 1))-swipe-dark.png" "${LOCALE[@]}"
done

xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
echo "Done. Raw captures in $OUT"
