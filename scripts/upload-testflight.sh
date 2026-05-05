#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# shellcheck source=scripts/load-release-env.sh
source scripts/load-release-env.sh
load_tanjjet_release_env

ARCHIVE_PATH="${ARCHIVE_PATH:-build/Tanjjet.xcarchive}"
EXPORT_PATH="${EXPORT_PATH:-build/testflight-upload}"
EXPORT_OPTIONS="${EXPORT_OPTIONS:-exportOptions-testflight.plist}"
UPLOAD_LOG="${UPLOAD_LOG:-build/testflight-upload.log}"
AUTH_KEY_PATH="${APP_STORE_CONNECT_API_KEY_PATH:-${ASC_KEY_PATH:-}}"
AUTH_KEY_ID="${APP_STORE_CONNECT_API_KEY_ID:-${ASC_KEY_ID:-}}"
AUTH_ISSUER_ID="${APP_STORE_CONNECT_ISSUER_ID:-${ASC_ISSUER_ID:-}}"

is_placeholder_asc_value() {
  local value="$1"

  case "$value" in
    "" | "XXXXXX" | "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" | "/absolute/path/to/AuthKey_XXXXXX.p8")
      return 0
      ;;
  esac

  [[ "$value" == *"AuthKey_XXXXXX.p8"* || "$value" == "/absolute/path/"* ]]
}

RAW_AUTH_KEY_PATH="$AUTH_KEY_PATH"
RAW_AUTH_KEY_ID="$AUTH_KEY_ID"
RAW_AUTH_ISSUER_ID="$AUTH_ISSUER_ID"

if is_placeholder_asc_value "$AUTH_KEY_PATH"; then
  AUTH_KEY_PATH=""
fi

if is_placeholder_asc_value "$AUTH_KEY_ID"; then
  AUTH_KEY_ID=""
fi

if is_placeholder_asc_value "$AUTH_ISSUER_ID"; then
  AUTH_ISSUER_ID=""
fi

if [[ -n "$RAW_AUTH_KEY_PATH$RAW_AUTH_KEY_ID$RAW_AUTH_ISSUER_ID" &&
      -z "$AUTH_KEY_PATH$AUTH_KEY_ID$AUTH_ISSUER_ID" ]]; then
  echo "App Store Connect API key values still contain example placeholders; upload will rely on the signed-in Xcode account." >&2
fi

if [[ ! -d "$ARCHIVE_PATH" ]]; then
  echo "Archive not found at $ARCHIVE_PATH. Run scripts/archive-testflight.sh first." >&2
  exit 1
fi

XCODEBUILD_ARGS=(
  -exportArchive
  -archivePath "$ARCHIVE_PATH"
  -exportPath "$EXPORT_PATH"
  -exportOptionsPlist "$EXPORT_OPTIONS"
  -allowProvisioningUpdates
)

if [[ -n "$AUTH_KEY_PATH" || -n "$AUTH_KEY_ID" || -n "$AUTH_ISSUER_ID" ]]; then
  if [[ -z "$AUTH_KEY_PATH" || -z "$AUTH_KEY_ID" || -z "$AUTH_ISSUER_ID" ]]; then
    echo "Set APP_STORE_CONNECT_API_KEY_PATH, APP_STORE_CONNECT_API_KEY_ID, and APP_STORE_CONNECT_ISSUER_ID together." >&2
    exit 1
  fi

  if [[ ! -f "$AUTH_KEY_PATH" ]]; then
    echo "App Store Connect API key file not found: $AUTH_KEY_PATH" >&2
    exit 1
  fi

  XCODEBUILD_ARGS+=(
    -authenticationKeyPath "$AUTH_KEY_PATH"
    -authenticationKeyID "$AUTH_KEY_ID"
    -authenticationKeyIssuerID "$AUTH_ISSUER_ID"
  )
fi

rm -rf "$EXPORT_PATH"
mkdir -p "$(dirname "$UPLOAD_LOG")"

set +e
xcodebuild "${XCODEBUILD_ARGS[@]}" 2>&1 | tee "$UPLOAD_LOG"
status=${PIPESTATUS[0]}
set -e

if [[ "$status" -ne 0 ]]; then
  if grep -Eq "App Store Connect access|Failed to Use Accounts|Failed to find an account" "$UPLOAD_LOG"; then
    cat >&2 <<EOF

Upload blocked by App Store Connect account access for team 4Q2Q7M7G5X.
Sign in to Xcode with an Apple account that has App Store Connect access for this team,
or set APP_STORE_CONNECT_API_KEY_PATH, APP_STORE_CONNECT_API_KEY_ID, and APP_STORE_CONNECT_ISSUER_ID together.

Full export log: $UPLOAD_LOG
EOF
  else
    echo "TestFlight upload failed. Full export log: $UPLOAD_LOG" >&2
  fi
  exit "$status"
fi

echo "TestFlight export/upload completed. Full export log: $UPLOAD_LOG"
