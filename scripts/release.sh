#!/usr/bin/env bash
# Archive and upload Byegones to App Store Connect.
#
# Usage: scripts/release.sh [--dry-run] [--bump]
#   --dry-run  run pre-flight checks and print the commands without running them
#   --bump     increment CURRENT_PROJECT_VERSION before archiving
#
# Env (all optional):
#   TEAM_ID          overrides DEVELOPMENT_TEAM from the project
#   ASC_KEY_PATH     path to the App Store Connect API key (.p8), kept outside the repo
#   ASC_KEY_ID       API key ID
#   ASC_ISSUER_ID    API issuer ID
# Without the ASC_* trio, Xcode's signed-in account is used.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PROJECT="PhotoCleaner.xcodeproj"
SCHEME="PhotoCleaner"
ARCHIVE="build/Byegones.xcarchive"
EXPORT_DIR="build/export"
EXPORT_TEMPLATE="scripts/ExportOptions.plist"
EXPORT_GENERATED="build/ExportOptions.generated.plist"
PBXPROJ="$PROJECT/project.pbxproj"
ICON="PhotoCleaner/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png"

DRY=0
BUMP=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY=1 ;;
    --bump) BUMP=1 ;;
    -h|--help) sed -n '2,14p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "Unknown flag: $arg" >&2; exit 2 ;;
  esac
done

FAILS=()
fail() { FAILS+=("$1"); echo "PRE-FLIGHT FAIL: $1" >&2; }
ok() { echo "pre-flight ok:   $1"; }

# --- Pre-flight -------------------------------------------------------------
SETTINGS="$(xcodebuild -project "$PROJECT" -target "$SCHEME" -configuration Release -showBuildSettings 2>/dev/null || true)"
setting() { printf '%s\n' "$SETTINGS" | awk -F' = ' -v k="$1" '$1 ~ "^[[:space:]]*"k"$" {print $2; exit}'; }

TEAM="${TEAM_ID:-$(setting DEVELOPMENT_TEAM)}"
BUNDLE_ID="$(setting PRODUCT_BUNDLE_IDENTIFIER)"
BUILD_NO="$(setting CURRENT_PROJECT_VERSION)"

if [[ -n "$TEAM" ]]; then ok "team set"; else
  fail "No development team. Sign in to Xcode and set the Team on the target, or run with TEAM_ID=<your 10-char team id>."
fi
if [[ -z "$BUNDLE_ID" ]]; then
  fail "Could not read PRODUCT_BUNDLE_IDENTIFIER from xcodebuild."
elif [[ "$BUNDLE_ID" == com.example.* ]]; then
  fail "Bundle ID is still the placeholder ($BUNDLE_ID). Set the final bundle ID on the target."
else ok "bundle id $BUNDLE_ID"; fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  fail "Not a git repository; cannot verify the tree is clean."
elif [[ -n "$(git status --porcelain)" ]]; then
  fail "Git tree is not clean. Commit or stash changes first."
else ok "git tree clean"; fi

if [[ ! -f "$ICON" ]]; then
  fail "AppIcon.png not found at $ICON"
else
  alpha="$(sips -g hasAlpha "$ICON" | awk '/hasAlpha/ {print $2}')"
  if [[ "$alpha" != "no" ]]; then
    fail "AppIcon.png has an alpha channel; App Store Connect rejects it."
  else ok "AppIcon.png has no alpha"; fi
fi

ASC_ARGS=()
if [[ -n "${ASC_KEY_PATH:-}${ASC_KEY_ID:-}${ASC_ISSUER_ID:-}" ]]; then
  if [[ -n "${ASC_KEY_PATH:-}" && -n "${ASC_KEY_ID:-}" && -n "${ASC_ISSUER_ID:-}" ]]; then
    if [[ "$ASC_KEY_PATH" == "$ROOT"/* ]]; then
      fail "ASC_KEY_PATH is inside the repo; keep API keys outside it."
    elif [[ ! -f "$ASC_KEY_PATH" && $DRY -eq 0 ]]; then
      fail "ASC_KEY_PATH does not exist."
    else
      ASC_ARGS=(-authenticationKeyPath "$ASC_KEY_PATH" -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID")
      ok "using App Store Connect API key"
    fi
  else
    fail "Set all of ASC_KEY_PATH, ASC_KEY_ID and ASC_ISSUER_ID, or none (falls back to the Xcode account)."
  fi
else
  echo "pre-flight note: no ASC_* env set; using the account signed in to Xcode."
fi

plutil -lint "$EXPORT_TEMPLATE" >/dev/null || fail "$EXPORT_TEMPLATE is not a valid plist."

# --- Commands ---------------------------------------------------------------
NEXT_BUILD=$(( ${BUILD_NO:-0} + 1 ))
TEAM_ARGS=()
[[ -n "$TEAM" ]] && TEAM_ARGS=(DEVELOPMENT_TEAM="$TEAM")

run() {
  printf '+'; printf ' %q' "$@"; printf '\n'
  if [[ $DRY -eq 0 ]]; then "$@"; fi
}

echo
echo "== Release plan (dry-run=$DRY, bump=$BUMP) =="

if [[ ${#FAILS[@]} -gt 0 && $DRY -eq 0 ]]; then
  echo "${#FAILS[@]} pre-flight check(s) failed; aborting." >&2
  exit 1
fi

if [[ $BUMP -eq 1 ]]; then
  # agvtool needs VERSIONING_SYSTEM = apple-generic, which this project does not set; edit with sed instead.
  if grep -q 'VERSIONING_SYSTEM = apple-generic' "$PBXPROJ"; then
    run agvtool new-version -all "$NEXT_BUILD"
  else
    run sed -i '' -E "s/CURRENT_PROJECT_VERSION = [0-9]+;/CURRENT_PROJECT_VERSION = $NEXT_BUILD;/" "$PBXPROJ"
  fi
fi

run mkdir -p build
run rm -rf "$ARCHIVE" "$EXPORT_DIR"
run xcodebuild archive -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$ARCHIVE" -allowProvisioningUpdates \
  ${ASC_ARGS[@]+"${ASC_ARGS[@]}"} ${TEAM_ARGS[@]+"${TEAM_ARGS[@]}"}

# Fill teamID into a generated copy; the committed template stays empty.
echo "+ cp $EXPORT_TEMPLATE $EXPORT_GENERATED && /usr/libexec/PlistBuddy -c 'Set :teamID <TEAM_ID>' $EXPORT_GENERATED"
if [[ $DRY -eq 0 ]]; then
  cp "$EXPORT_TEMPLATE" "$EXPORT_GENERATED"
  /usr/libexec/PlistBuddy -c "Set :teamID $TEAM" "$EXPORT_GENERATED"
  plutil -lint "$EXPORT_GENERATED"
fi

run xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$EXPORT_GENERATED" -allowProvisioningUpdates \
  ${ASC_ARGS[@]+"${ASC_ARGS[@]}"}

echo
if [[ ${#FAILS[@]} -gt 0 ]]; then
  echo "DRY RUN: ${#FAILS[@]} pre-flight check(s) would block a real run (see above)." >&2
  exit 1
fi
if [[ $DRY -eq 1 ]]; then echo "DRY RUN complete: pre-flight clean, nothing executed."; else
  echo "Uploaded. Build $( [[ $BUMP -eq 1 ]] && echo "$NEXT_BUILD" || echo "$BUILD_NO") should appear in App Store Connect > TestFlight after processing."
  echo "Rollback: nothing is released by upload. Remove/ignore the build in App Store Connect, bump the build number and re-run."
fi
