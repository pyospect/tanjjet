#!/usr/bin/env bash
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

ARCHIVE_PATH="${ARCHIVE_PATH:-build/Tanjjet.xcarchive}"
SUPPORT_URL="${SUPPORT_URL:-https://pyospect.github.io/tanjjet/support.html}"
PRIVACY_URL="${PRIVACY_URL:-https://pyospect.github.io/tanjjet/privacy-policy.html}"

failures=0
blockers=0
warnings=0

ok() {
  printf 'OK: %s\n' "$*"
}

warn() {
  warnings=$((warnings + 1))
  printf 'WARN: %s\n' "$*" >&2
}

fail() {
  failures=$((failures + 1))
  printf 'FAIL: %s\n' "$*" >&2
}

block() {
  blockers=$((blockers + 1))
  printf 'BLOCKED: %s\n' "$*" >&2
}

have_command() {
  command -v "$1" >/dev/null 2>&1
}

check_clean_worktree() {
  if ! git diff --quiet || ! git diff --cached --quiet || [[ -n "$(git ls-files --others --exclude-standard)" ]]; then
    block "Working tree has uncommitted changes. Commit, stash, or discard intentional local changes before a release upload."
    return
  fi

  ok "Working tree is clean."
}

check_required_files() {
  local files=(
    "project.yml"
    "exportOptions-testflight.plist"
    "Tanjjet/PrivacyInfo.xcprivacy"
    "TanjjetWidget/PrivacyInfo.xcprivacy"
    "docs/app-store-connect-metadata.md"
    "docs/testflight-checklist.md"
    "docs/testflight-qa-plan.md"
    "docs/privacy-policy.html"
    "docs/support.html"
  )

  local file
  for file in "${files[@]}"; do
    if [[ -f "$file" ]]; then
      ok "$file exists."
    else
      fail "$file is missing."
    fi
  done
}

check_device_family() {
  if grep -q 'TARGETED_DEVICE_FAMILY: "1"' project.yml; then
    ok "project.yml targets iPhone only."
  else
    fail "project.yml should set TARGETED_DEVICE_FAMILY to \"1\" unless iPad screenshots and QA are added."
  fi

  if [[ -f Tanjjet.xcodeproj/project.pbxproj ]]; then
    local build_settings
    build_settings="$(xcodebuild -project Tanjjet.xcodeproj -scheme Tanjjet -showBuildSettings -configuration Release 2>/dev/null || true)"

    if [[ "$build_settings" == *"PRODUCT_BUNDLE_IDENTIFIER = com.pyospect.tanjjet"* &&
          "$build_settings" == *"TARGETED_DEVICE_FAMILY = 1"* &&
          "$build_settings" != *"TARGETED_DEVICE_FAMILY = 1,2"* ]]; then
      ok "Generated Tanjjet scheme targets iPhone only."
    else
      fail "Generated Tanjjet scheme should target iPhone only. Run xcodegen generate after editing project.yml."
    fi
  else
    warn "Tanjjet.xcodeproj is missing; run xcodegen generate before archiving."
  fi
}

check_screenshots() {
  local screenshots=(
    "screenshots/screenshot_1_lockscreen.png"
    "screenshots/screenshot_2_pairing.png"
    "screenshots/screenshot_3_message.png"
  )

  local screenshot
  for screenshot in "${screenshots[@]}"; do
    if [[ ! -s "$screenshot" ]]; then
      fail "$screenshot is missing or empty."
      continue
    fi

    if ! have_command sips; then
      warn "sips is not available; skipping screenshot dimension check for $screenshot."
      continue
    fi

    local width
    local height
    width="$(sips -g pixelWidth "$screenshot" 2>/dev/null | awk '/pixelWidth:/ {print $2}')"
    height="$(sips -g pixelHeight "$screenshot" 2>/dev/null | awk '/pixelHeight:/ {print $2}')"

    if [[ "$width" == "1242" && "$height" == "2688" ]]; then
      ok "$screenshot is 1242 x 2688."
    else
      warn "$screenshot is ${width:-unknown} x ${height:-unknown}; expected 1242 x 2688 for the current iPhone screenshot set."
    fi
  done
}

check_privacy_manifests() {
  if plutil -lint Tanjjet/PrivacyInfo.xcprivacy TanjjetWidget/PrivacyInfo.xcprivacy >/dev/null; then
    ok "App and widget privacy manifests pass plutil."
  else
    fail "Privacy manifest lint failed."
  fi

  local app_privacy
  app_privacy="$(plutil -p Tanjjet/PrivacyInfo.xcprivacy 2>/dev/null || true)"
  local required_data_types=(
    "NSPrivacyCollectedDataTypeUserID"
    "NSPrivacyCollectedDataTypeName"
    "NSPrivacyCollectedDataTypeOtherUserContent"
    "NSPrivacyCollectedDataTypeDeviceID"
  )

  local data_type
  for data_type in "${required_data_types[@]}"; do
    if [[ "$app_privacy" == *"$data_type"* ]]; then
      ok "App privacy manifest declares $data_type."
    else
      fail "App privacy manifest is missing $data_type."
    fi
  done

  if [[ "$app_privacy" == *"NSPrivacyCollectedDataTypePurposeAppFunctionality"* ]]; then
    ok "App privacy manifest declares app functionality as the data collection purpose."
  else
    fail "App privacy manifest should declare app functionality as the data collection purpose."
  fi
}

check_archive() {
  if [[ ! -d "$ARCHIVE_PATH" ]]; then
    block "Archive not found at $ARCHIVE_PATH. Run scripts/archive-testflight.sh after scripts/verify-release.sh."
    return
  fi

  local bundle_id
  local signing_identity
  bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :ApplicationProperties:CFBundleIdentifier' "$ARCHIVE_PATH/Info.plist" 2>/dev/null || true)"
  signing_identity="$(/usr/libexec/PlistBuddy -c 'Print :ApplicationProperties:SigningIdentity' "$ARCHIVE_PATH/Info.plist" 2>/dev/null || true)"

  if [[ "$bundle_id" == "com.pyospect.tanjjet" ]]; then
    ok "Archive bundle id is com.pyospect.tanjjet."
  else
    fail "Archive bundle id is '${bundle_id:-unknown}', expected com.pyospect.tanjjet."
  fi

  if [[ -n "$signing_identity" ]]; then
    ok "Archive signing identity: $signing_identity."
    if [[ "$signing_identity" == Apple\ Development:* ]]; then
      warn "Archive is development-signed; App Store export should re-sign automatically once App Store Connect access is available."
    fi
  else
    warn "Archive signing identity was not found in $ARCHIVE_PATH/Info.plist."
  fi
}

check_app_store_connect_auth() {
  local key_path="${APP_STORE_CONNECT_API_KEY_PATH:-${ASC_KEY_PATH:-}}"
  local key_id="${APP_STORE_CONNECT_API_KEY_ID:-${ASC_KEY_ID:-}}"
  local issuer_id="${APP_STORE_CONNECT_ISSUER_ID:-${ASC_ISSUER_ID:-}}"

  if [[ -n "$key_path" || -n "$key_id" || -n "$issuer_id" ]]; then
    if [[ -n "$key_path" && -n "$key_id" && -n "$issuer_id" && -f "$key_path" ]]; then
      ok "App Store Connect API key environment is complete."
      return
    fi

    block "App Store Connect API key environment is incomplete. Set key path, key id, and issuer id together."
    return
  fi

  if [[ -f build/testflight-upload.log ]] && grep -q "Failed to Use Accounts" build/testflight-upload.log; then
    block "Latest TestFlight upload failed because Xcode has no App Store Connect account access for team 4Q2Q7M7G5X."
    return
  fi

  warn "No App Store Connect API key env is configured. Xcode account access may still work; run scripts/upload-testflight.sh to verify."
}

check_supabase_strict() {
  local output_file
  output_file="$(mktemp)"

  if REQUIRE_DISCONNECT_RPC=1 scripts/verify-supabase-remote.sh >"$output_file" 2>&1; then
    ok "Supabase strict remote verification passed."
  else
    block "Supabase strict remote verification failed. Apply the SQL migration before final App Store submission."
    sed 's/^/  /' "$output_file" >&2
  fi

  rm -f "$output_file"
}

check_docs_urls() {
  if curl -fsSIL "$SUPPORT_URL" >/dev/null; then
    ok "Support URL is reachable: $SUPPORT_URL."
  else
    warn "Support URL is not reachable yet: $SUPPORT_URL."
  fi

  if curl -fsSIL "$PRIVACY_URL" >/dev/null; then
    ok "Privacy policy URL is reachable: $PRIVACY_URL."
  else
    warn "Privacy policy URL is not reachable yet: $PRIVACY_URL."
  fi
}

check_pr_state() {
  if ! have_command gh; then
    warn "gh is not installed; skipping PR state check."
    return
  fi

  local pr_json
  pr_json="$(gh pr view --json isDraft,mergeStateStatus,url,baseRefName,headRefName 2>/dev/null || true)"
  if [[ -z "$pr_json" ]]; then
    warn "No GitHub PR found for the current branch."
    return
  fi

  if [[ "$pr_json" == *'"isDraft":true'* ]]; then
    warn "Current PR is still a draft; merge to master before final App Store submission so GitHub Pages publishes the latest docs."
  else
    ok "Current PR is ready for review."
  fi

  if [[ "$pr_json" == *'"mergeStateStatus":"CLEAN"'* ]]; then
    ok "Current PR merge state is clean."
  else
    warn "Current PR merge state is not clean. Inspect with gh pr view."
  fi
}

cat <<'EOF'
Tanjjet release readiness audit
EOF

check_clean_worktree
check_required_files
check_device_family
check_screenshots
check_privacy_manifests
check_archive
check_app_store_connect_auth
check_supabase_strict
check_docs_urls
check_pr_state

cat <<EOF

Audit summary: $failures failure(s), $blockers blocker(s), $warnings warning(s).
EOF

if [[ "$failures" -ne 0 || "$blockers" -ne 0 ]]; then
  exit 1
fi
