#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TEAM_ID="${DEVELOPMENT_TEAM:-4Q2Q7M7G5X}"
ARCHIVE_PATH="${ARCHIVE_PATH:-build/Tanjjet.xcarchive}"

xcodegen generate

xcodebuild \
  -project Tanjjet.xcodeproj \
  -scheme Tanjjet \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE_PATH" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  -allowProvisioningUpdates \
  archive

echo "Archive created at $ARCHIVE_PATH"
