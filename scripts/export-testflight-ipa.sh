#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

ARCHIVE_PATH="${ARCHIVE_PATH:-build/Tanjjet.xcarchive}"
EXPORT_PATH="${EXPORT_PATH:-build/testflight-export-only}"
EXPORT_LOG="${EXPORT_LOG:-build/testflight-export-only.log}"
TEAM_ID="${TEAM_ID:-4Q2Q7M7G5X}"

if [[ ! -d "$ARCHIVE_PATH" ]]; then
  echo "Archive not found at $ARCHIVE_PATH. Run scripts/archive-testflight.sh first." >&2
  exit 1
fi

export_options="$(mktemp "${TMPDIR:-/tmp}/tanjjet-export-options.XXXXXX")"
trap 'rm -f "$export_options"' EXIT

printf '%s\n' \
  '<?xml version="1.0" encoding="UTF-8"?>' \
  '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' \
  '<plist version="1.0"><dict/></plist>' > "$export_options"

/usr/libexec/PlistBuddy -c 'Add :destination string export' "$export_options"
/usr/libexec/PlistBuddy -c 'Add :method string app-store-connect' "$export_options"
/usr/libexec/PlistBuddy -c "Add :teamID string $TEAM_ID" "$export_options"
/usr/libexec/PlistBuddy -c 'Add :signingStyle string automatic' "$export_options"
/usr/libexec/PlistBuddy -c 'Add :stripSwiftSymbols bool true' "$export_options"
/usr/libexec/PlistBuddy -c 'Add :uploadSymbols bool true' "$export_options"
/usr/libexec/PlistBuddy -c 'Add :manageAppVersionAndBuildNumber bool false' "$export_options"

rm -rf "$EXPORT_PATH"
mkdir -p "$(dirname "$EXPORT_LOG")"

set +e
xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$export_options" \
  2>&1 | tee "$EXPORT_LOG"
status=${PIPESTATUS[0]}
set -e

if [[ "$status" -ne 0 ]]; then
  echo "TestFlight IPA export failed. Full export log: $EXPORT_LOG" >&2
  exit "$status"
fi

echo "TestFlight IPA export completed. Output: $EXPORT_PATH"
