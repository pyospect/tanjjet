#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

xcodegen generate

xcodebuild test \
  -project Tanjjet.xcodeproj \
  -scheme Tanjjet \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
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
