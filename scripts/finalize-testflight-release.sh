#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PROJECT_REF="wxlfukoozmuwslppmkaf"
MIGRATION_PATH="supabase/migrations/20260505041000_pairing_push_account_hardening.sql"
# shellcheck source=scripts/load-release-env.sh
source scripts/load-release-env.sh

run_step() {
  echo
  echo "==> $*"
  "$@"
}

require_clean_worktree() {
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    return
  fi

  if [[ "${ALLOW_DIRTY_RELEASE:-0}" == "1" ]]; then
    return
  fi

  if [[ -n "$(git status --porcelain)" ]]; then
    cat >&2 <<'EOF'
Working tree is not clean.
Commit or stash local changes before final TestFlight release, or set ALLOW_DIRTY_RELEASE=1 to override.
EOF
    git status --short >&2
    exit 1
  fi
}

ensure_supabase_strict_state() {
  echo
  echo "==> Checking Supabase strict remote state"
  if REQUIRE_DISCONNECT_RPC=1 scripts/verify-supabase-remote.sh; then
    return
  fi

  if [[ -n "${SUPABASE_DB_PASSWORD:-}" ]]; then
    run_step scripts/apply-supabase-db.sh
    return
  fi

  cat >&2 <<EOF

Supabase strict verification failed, and SUPABASE_DB_PASSWORD is not set.
Apply the migration manually in the Supabase SQL editor:
  $MIGRATION_PATH

Then rerun this script, or provide the DB password:
  SUPABASE_DB_PASSWORD=... scripts/finalize-testflight-release.sh

Project ref: $PROJECT_REF
EOF
  exit 1
}

ensure_app_store_connect_ready() {
  local key_path="${APP_STORE_CONNECT_API_KEY_PATH:-${ASC_KEY_PATH:-}}"
  local key_id="${APP_STORE_CONNECT_API_KEY_ID:-${ASC_KEY_ID:-}}"
  local issuer_id="${APP_STORE_CONNECT_ISSUER_ID:-${ASC_ISSUER_ID:-}}"

  if [[ -n "$key_path" || -n "$key_id" || -n "$issuer_id" ]]; then
    if [[ -z "$key_path" || -z "$key_id" || -z "$issuer_id" ]]; then
      cat >&2 <<'EOF'
App Store Connect API key environment is incomplete.
Set APP_STORE_CONNECT_API_KEY_PATH, APP_STORE_CONNECT_API_KEY_ID, and APP_STORE_CONNECT_ISSUER_ID together.
EOF
      exit 1
    fi

    if [[ ! -f "$key_path" ]]; then
      echo "App Store Connect API key file not found: $key_path" >&2
      exit 1
    fi

    return
  fi

  if [[ "${ASSUME_XCODE_ACCOUNT_READY:-0}" == "1" ]]; then
    return
  fi

  if [[ -f build/testflight-upload.log ]] && grep -Eq "App Store Connect access|Failed to Use Accounts|Failed to find an account" build/testflight-upload.log; then
    cat >&2 <<'EOF'
The latest TestFlight upload failed because Xcode had no App Store Connect account access.
Set the App Store Connect API key values in .env.release, or sign in to Xcode with the right team and rerun with:
  ASSUME_XCODE_ACCOUNT_READY=1 scripts/finalize-testflight-release.sh
EOF
    exit 1
  fi
}

load_tanjjet_release_env
require_clean_worktree
ensure_app_store_connect_ready
ensure_supabase_strict_state
run_step scripts/verify-release.sh
run_step scripts/archive-testflight.sh
run_step scripts/upload-testflight.sh
run_step scripts/release-readiness-audit.sh

cat <<'EOF'

TestFlight release pipeline completed.
Open App Store Connect, wait for build processing, then run the manual QA plan in docs/testflight-qa-plan.md.
EOF
