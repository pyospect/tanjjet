#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# shellcheck source=scripts/load-release-env.sh
source scripts/load-release-env.sh

issues=0
MIN_FREE_SPACE_MB="${MIN_FREE_SPACE_MB:-4096}"

ok() {
  printf 'OK: %s\n' "$*"
}

warn() {
  printf 'WARN: %s\n' "$*" >&2
}

block() {
  issues=$((issues + 1))
  printf 'BLOCKED: %s\n' "$*" >&2
}

available_space_mb() {
  df -Pm "$ROOT_DIR" | awk 'NR == 2 {print $4}'
}

free_space_mb="$(available_space_mb)"
if [[ -n "$free_space_mb" && "$free_space_mb" =~ ^[0-9]+$ ]]; then
  if (( free_space_mb >= MIN_FREE_SPACE_MB )); then
    ok "Disk space is sufficient: ${free_space_mb}MB available."
  else
    block "Only ${free_space_mb}MB is available. Free at least ${MIN_FREE_SPACE_MB}MB before the final release pipeline, or set MIN_FREE_SPACE_MB to override intentionally."
  fi
else
  warn "Could not determine available disk space."
fi

if [[ -n "${RELEASE_ENV_FILE:-}" ]]; then
  if [[ -f "$RELEASE_ENV_FILE" ]]; then
    ok "Release env file exists: $RELEASE_ENV_FILE"
  else
    block "Release env file not found: $RELEASE_ENV_FILE"
  fi
elif [[ -f .env.release ]]; then
  ok "Release env file exists: .env.release"
else
  warn ".env.release is missing. Copy .env.release.example to .env.release before the final pipeline if you want to use env-file credentials."
fi

load_tanjjet_release_env

if [[ -n "${SUPABASE_DB_PASSWORD:-}" ]]; then
  ok "SUPABASE_DB_PASSWORD is set for CLI migration."
else
  block "SUPABASE_DB_PASSWORD is not set. Either set it before running the final pipeline or apply supabase/migrations/20260505041000_pairing_push_account_hardening.sql manually in the Supabase SQL editor."
fi

key_path="${APP_STORE_CONNECT_API_KEY_PATH:-${ASC_KEY_PATH:-}}"
key_id="${APP_STORE_CONNECT_API_KEY_ID:-${ASC_KEY_ID:-}}"
issuer_id="${APP_STORE_CONNECT_ISSUER_ID:-${ASC_ISSUER_ID:-}}"

if [[ -n "$key_path" || -n "$key_id" || -n "$issuer_id" ]]; then
  if [[ -z "$key_path" || -z "$key_id" || -z "$issuer_id" ]]; then
    block "App Store Connect API key values are incomplete. Set key path, key id, and issuer id together."
  elif [[ ! -f "$key_path" ]]; then
    block "App Store Connect API key file not found: $key_path"
  else
    ok "App Store Connect API key environment is complete."
  fi
elif [[ "${ASSUME_XCODE_ACCOUNT_READY:-0}" == "1" ]]; then
  ok "ASSUME_XCODE_ACCOUNT_READY=1 is set; final upload will rely on the signed-in Xcode account."
elif [[ -f build/testflight-upload.log ]] && grep -Eq "App Store Connect access|Failed to Use Accounts|Failed to find an account" build/testflight-upload.log; then
  block "Latest TestFlight upload failed for App Store Connect account access. Set the API key values or sign in to Xcode and rerun the final pipeline with ASSUME_XCODE_ACCOUNT_READY=1."
else
  warn "No App Store Connect API key is configured. Xcode account access may work, but this script cannot prove it before upload."
fi

if [[ "$issues" -ne 0 ]]; then
  cat >&2 <<'EOF'

Release credential preflight is not ready.
Resolve the blocker(s) above, then run:
  scripts/check-release-credentials.sh
  scripts/finalize-testflight-release.sh
EOF
  exit 1
fi

cat <<'EOF'

Release credential preflight passed.
Next command:
  scripts/finalize-testflight-release.sh
EOF
