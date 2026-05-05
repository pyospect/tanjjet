#!/usr/bin/env bash
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# shellcheck source=scripts/load-release-env.sh
source scripts/load-release-env.sh
load_tanjjet_release_env

ARCHIVE_PATH="${ARCHIVE_PATH:-build/Tanjjet.xcarchive}"
UPLOAD_LOG="${UPLOAD_LOG:-build/testflight-upload.log}"
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

release_build_settings() {
  if [[ -z "${RELEASE_BUILD_SETTINGS:-}" ]]; then
    RELEASE_BUILD_SETTINGS="$(xcodebuild -project Tanjjet.xcodeproj -scheme Tanjjet -showBuildSettings -configuration Release 2>/dev/null || true)"
  fi

  printf '%s\n' "$RELEASE_BUILD_SETTINGS"
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
    ".env.release.example"
    ".github/workflows/release-verify.yml"
    "exportOptions-testflight.plist"
    "Tanjjet/PrivacyInfo.xcprivacy"
    "TanjjetWidget/PrivacyInfo.xcprivacy"
    "docs/app-store-connect-metadata.md"
    "docs/completion-audit-ko.md"
    "docs/release-handoff-ko.md"
    "docs/testflight-checklist.md"
    "docs/testflight-qa-plan.md"
    "docs/privacy-policy.html"
    "docs/support.html"
    "scripts/check-release-credentials.sh"
    "scripts/load-release-env.sh"
    "scripts/finalize-testflight-release.sh"
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

check_release_workflow() {
  local workflow=".github/workflows/release-verify.yml"

  if [[ ! -f "$workflow" ]]; then
    fail "$workflow is missing."
    return
  fi

  if rg -q 'uses:[[:space:]]*actions/checkout@v4\b' "$workflow"; then
    fail "Release verification workflow should not use actions/checkout@v4 because it runs on the deprecated Node 20 runtime."
  elif rg -q 'uses:[[:space:]]*actions/checkout@v6(\.|$)' "$workflow"; then
    ok "Release verification workflow uses actions/checkout v6 on the Node 24 runtime."
  else
    warn "Release verification workflow checkout action is not v6; confirm the action runtime before release."
  fi

  if rg -q 'timeout-minutes:[[:space:]]*45' "$workflow" &&
     rg -q 'timeout-minutes:[[:space:]]*30' "$workflow"; then
    ok "Release verification workflow has job and release-step timeouts."
  else
    fail "Release verification workflow should keep both job-level and release-step timeouts."
  fi
}

check_device_family() {
  if grep -q 'TARGETED_DEVICE_FAMILY: "1"' project.yml; then
    ok "project.yml targets iPhone only."
  else
    fail "project.yml should set TARGETED_DEVICE_FAMILY to \"1\" unless iPad screenshots and QA are added."
  fi

  if [[ -f Tanjjet.xcodeproj/project.pbxproj ]]; then
    local build_settings
    build_settings="$(release_build_settings)"

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

check_versions() {
  local build_settings
  build_settings="$(release_build_settings)"

  if [[ "$build_settings" == *"MARKETING_VERSION = 1.0.0"* &&
        "$build_settings" == *"CURRENT_PROJECT_VERSION = 6"* ]]; then
    ok "Release build settings use version 1.0.0 build 6."
  else
    fail "Release build settings should use MARKETING_VERSION 1.0.0 and CURRENT_PROJECT_VERSION 6."
  fi

  if grep -q 'Version: `1.0.0`' docs/app-store-connect-metadata.md &&
     grep -q 'Build: `6`' docs/app-store-connect-metadata.md; then
    ok "App Store Connect metadata matches version 1.0.0 build 6."
  else
    fail "App Store Connect metadata version/build should match project.yml."
  fi
}

check_entitlements() {
  local app_entitlements
  local widget_entitlements
  local build_settings
  app_entitlements="$(plutil -p Tanjjet/Tanjjet.entitlements 2>/dev/null || true)"
  widget_entitlements="$(plutil -p TanjjetWidget/TanjjetWidgetExtension.entitlements 2>/dev/null || true)"
  build_settings="$(release_build_settings)"

  if [[ "$app_entitlements" == *"group.com.pyospect.tanjjet"* &&
        "$widget_entitlements" == *"group.com.pyospect.tanjjet"* ]]; then
    ok "App and widget source entitlements include the shared App Group."
  else
    fail "App and widget source entitlements must include group.com.pyospect.tanjjet."
  fi

  if [[ "$app_entitlements" == *"com.apple.developer.applesignin"* &&
        "$app_entitlements" == *"Default"* ]]; then
    ok "App source entitlements include Sign in with Apple."
  else
    fail "App source entitlements must include Sign in with Apple."
  fi

  if [[ "$app_entitlements" == *'$(APS_ENVIRONMENT)'* &&
        "$build_settings" == *"APS_ENVIRONMENT = production"* ]]; then
    ok "Release push entitlement resolves to production."
  else
    fail "Release push entitlement should resolve APS_ENVIRONMENT to production."
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

check_app_icon() {
  local icon="Tanjjet/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png"
  if [[ ! -s "$icon" ]]; then
    fail "App Store icon is missing at $icon."
    return
  fi

  if ! have_command sips; then
    warn "sips is not available; skipping App Store icon dimension/alpha checks."
    return
  fi

  local width
  local height
  local has_alpha
  width="$(sips -g pixelWidth "$icon" 2>/dev/null | awk '/pixelWidth:/ {print $2}')"
  height="$(sips -g pixelHeight "$icon" 2>/dev/null | awk '/pixelHeight:/ {print $2}')"
  has_alpha="$(sips -g hasAlpha "$icon" 2>/dev/null | awk '/hasAlpha:/ {print $2}')"

  if [[ "$width" == "1024" && "$height" == "1024" && "$has_alpha" == "no" ]]; then
    ok "App Store icon is 1024 x 1024 with no alpha channel."
  else
    fail "App Store icon should be 1024 x 1024 with no alpha channel; found ${width:-unknown} x ${height:-unknown}, alpha ${has_alpha:-unknown}."
  fi
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

check_database_hardening() {
  if rg -q 'CREATE POLICY "Couple members can update couple"' Database supabase/migrations -g '*.sql'; then
    fail "Database SQL should not grant direct user UPDATE access to couples."
  else
    ok "Database SQL does not grant direct user UPDATE access to couples."
  fi

  if rg -q 'SECURITY DEFINER(?! SET search_path = public)' Database supabase/migrations -g '*.sql' -P; then
    fail "SECURITY DEFINER functions should set search_path = public."
  else
    ok "SECURITY DEFINER functions set search_path = public."
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

  if [[ -f "$UPLOAD_LOG" ]]; then
    if grep -Eq "App Store Connect access|Failed to Use Accounts|Failed to find an account" "$UPLOAD_LOG"; then
      block "Latest TestFlight upload failed because Xcode has no App Store Connect account access for team 4Q2Q7M7G5X."
      return
    fi

    if grep -q '\*\* EXPORT SUCCEEDED \*\*' "$UPLOAD_LOG"; then
      ok "Latest TestFlight upload log reports a successful export/upload."
      return
    fi

    warn "Latest TestFlight upload log does not clearly report success. Inspect $UPLOAD_LOG."
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
check_release_workflow
check_device_family
check_versions
check_entitlements
check_screenshots
check_app_icon
check_privacy_manifests
check_database_hardening
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
