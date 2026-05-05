#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TEAM_ID="${DEVELOPMENT_TEAM:-4Q2Q7M7G5X}"
ARCHIVE_PATH="${ARCHIVE_PATH:-build/Tanjjet.xcarchive}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/build/ArchiveDerivedData}"

if [[ "$ARCHIVE_PATH" != /* ]]; then
  ARCHIVE_PATH="$ROOT_DIR/$ARCHIVE_PATH"
fi

mkdir -p "$(dirname "$ARCHIVE_PATH")"

if [[ "$ARCHIVE_PATH" == "$ROOT_DIR"/build/* ]]; then
  rm -rf "$ARCHIVE_PATH"
fi

if [[ "$DERIVED_DATA_PATH" == "$ROOT_DIR"/build/* ]]; then
  rm -rf "$DERIVED_DATA_PATH"
fi

mkdir -p "$DERIVED_DATA_PATH"

xcodegen generate

xcodebuild \
  -project Tanjjet.xcodeproj \
  -scheme Tanjjet \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE_PATH" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  -allowProvisioningUpdates \
  archive

echo "Archive created at $ARCHIVE_PATH"
