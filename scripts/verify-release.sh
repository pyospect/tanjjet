#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

xcodegen generate

if [[ -z "${SIMULATOR_DESTINATION:-}" ]]; then
  if command -v jq >/dev/null 2>&1; then
    SIMULATOR_ID="$(
      xcrun simctl list devices available -j \
        | jq -r '
          ([.devices[][] | select(.name | startswith("iPhone")) | select(.state == "Booted")][0].udid)
          // ([.devices[][] | select(.name | startswith("iPhone"))][-1].udid)
          // empty
        '
    )"
  else
    SIMULATOR_ID="$(
      xcrun simctl list devices available \
        | sed -nE 's/^[[:space:]]*iPhone[^()]* \(([0-9A-F-]{36})\) \(Booted\).*$/\1/p' \
        | head -n 1
    )"

    if [[ -z "$SIMULATOR_ID" ]]; then
      SIMULATOR_ID="$(
        xcrun simctl list devices available \
          | sed -nE 's/^[[:space:]]*iPhone[^()]* \(([0-9A-F-]{36})\) \(Shutdown\).*$/\1/p' \
          | tail -n 1
      )"
    fi
  fi

  if [[ -z "$SIMULATOR_ID" ]]; then
    echo "No available iPhone simulator found. Set SIMULATOR_DESTINATION manually." >&2
    exit 1
  fi

  SIMULATOR_DESTINATION="platform=iOS Simulator,id=${SIMULATOR_ID}"
fi

xcodebuild test \
  -project Tanjjet.xcodeproj \
  -scheme Tanjjet \
  -destination "$SIMULATOR_DESTINATION" \
  -configuration Debug

xcodebuild \
  -project Tanjjet.xcodeproj \
  -scheme Tanjjet \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Release \
  build

xcodebuild \
  -project Tanjjet.xcodeproj \
  -scheme Tanjjet \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO \
  build

plutil -lint Tanjjet/PrivacyInfo.xcprivacy TanjjetWidget/PrivacyInfo.xcprivacy
