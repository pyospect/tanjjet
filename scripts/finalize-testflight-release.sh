#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PROJECT_REF="wxlfukoozmuwslppmkaf"
MIGRATION_PATH="supabase/migrations/20260505041000_pairing_push_account_hardening.sql"
MIN_FREE_SPACE_MB="${MIN_FREE_SPACE_MB:-4096}"
# shellcheck source=scripts/load-release-env.sh
source scripts/load-release-env.sh

run_step() {
  echo
  echo "==> $*"
  "$@"
}

remove_repo_build_cache() {
  local path="$1"
  if [[ -d "$path" && "$path" == "$ROOT_DIR"/build/* ]]; then
    echo "Removing rebuildable cache: $path"
    rm -rf "$path"
  fi
}

is_placeholder_asc_value() {
  local value="$1"

  case "$value" in
    "" | "XXXXXX" | "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" | "/absolute/path/to/AuthKey_XXXXXX.p8")
      return 0
      ;;
  esac

  [[ "$value" == *"AuthKey_XXXXXX.p8"* || "$value" == "/absolute/path/"* ]]
}

ensure_disk_space() {
  local free_space_mb
  free_space_mb="$(df -Pm "$ROOT_DIR" | awk 'NR == 2 {print $4}')"

  if [[ -z "$free_space_mb" || ! "$free_space_mb" =~ ^[0-9]+$ ]]; then
    echo "Could not determine available disk space." >&2
    return 1
  fi

  if (( free_space_mb < MIN_FREE_SPACE_MB )); then
    cat >&2 <<EOF
Only ${free_space_mb}MB is available.
Free at least ${MIN_FREE_SPACE_MB}MB before the final release pipeline, or set MIN_FREE_SPACE_MB to override intentionally.
EOF
    return 1
  fi

  echo "Disk space preflight passed: ${free_space_mb}MB available."
  return 0
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
    return 0
  fi

  if [[ -n "${SUPABASE_DB_PASSWORD:-}" ]]; then
    if ! run_step scripts/apply-supabase-db.sh; then
      return 1
    fi

    REQUIRE_DISCONNECT_RPC=1 scripts/verify-supabase-remote.sh
    return $?
  fi

  cat >&2 <<EOF

Supabase strict verification failed, and SUPABASE_DB_PASSWORD is not set.
Apply the migration manually in the Supabase SQL editor:
  $MIGRATION_PATH

Then rerun this script, or provide the DB password:
  SUPABASE_DB_PASSWORD=... scripts/finalize-testflight-release.sh

Project ref: $PROJECT_REF
EOF
  return 1
}

ensure_app_store_connect_ready() {
  local key_path="${APP_STORE_CONNECT_API_KEY_PATH:-${ASC_KEY_PATH:-}}"
  local key_id="${APP_STORE_CONNECT_API_KEY_ID:-${ASC_KEY_ID:-}}"
  local issuer_id="${APP_STORE_CONNECT_ISSUER_ID:-${ASC_ISSUER_ID:-}}"
  local raw_key_path="$key_path"
  local raw_key_id="$key_id"
  local raw_issuer_id="$issuer_id"

  if is_placeholder_asc_value "$key_path"; then
    key_path=""
  fi

  if is_placeholder_asc_value "$key_id"; then
    key_id=""
  fi

  if is_placeholder_asc_value "$issuer_id"; then
    issuer_id=""
  fi

  if [[ -n "$raw_key_path$raw_key_id$raw_issuer_id" &&
        -z "$key_path$key_id$issuer_id" ]]; then
    echo "App Store Connect API key values still contain example placeholders; treating them as unset." >&2
  fi

  if [[ -n "$key_path" || -n "$key_id" || -n "$issuer_id" ]]; then
    if [[ -z "$key_path" || -z "$key_id" || -z "$issuer_id" ]]; then
      cat >&2 <<'EOF'
App Store Connect API key environment is incomplete.
Set APP_STORE_CONNECT_API_KEY_PATH, APP_STORE_CONNECT_API_KEY_ID, and APP_STORE_CONNECT_ISSUER_ID together.
EOF
      return 1
    fi

    if [[ ! -f "$key_path" ]]; then
      echo "App Store Connect API key file not found: $key_path" >&2
      return 1
    fi

    return 0
  fi

  if [[ "${ASSUME_XCODE_ACCOUNT_READY:-0}" == "1" ]]; then
    return 0
  fi

  if [[ -f build/testflight-upload.log ]] && grep -Eq "App Store Connect access|Failed to Use Accounts|Failed to find an account" build/testflight-upload.log; then
    cat >&2 <<'EOF'
The latest TestFlight upload failed because Xcode had no App Store Connect account access.
Set the App Store Connect API key values in .env.release, or sign in to Xcode with the right team and rerun with:
  ASSUME_XCODE_ACCOUNT_READY=1 scripts/finalize-testflight-release.sh
EOF
    return 1
  fi

  return 0
}

load_tanjjet_release_env
require_clean_worktree

preflight_blockers=0
ensure_disk_space || preflight_blockers=$((preflight_blockers + 1))
ensure_supabase_strict_state || preflight_blockers=$((preflight_blockers + 1))
ensure_app_store_connect_ready || preflight_blockers=$((preflight_blockers + 1))

if [[ "$preflight_blockers" -ne 0 ]]; then
  cat >&2 <<EOF

Final TestFlight pipeline stopped before long-running build/upload steps.
Resolve the preflight blocker(s) above, then rerun:
  scripts/finalize-testflight-release.sh
EOF
  exit 1
fi

run_step scripts/verify-release.sh
remove_repo_build_cache "$ROOT_DIR/build/DerivedData"
run_step scripts/archive-testflight.sh
remove_repo_build_cache "$ROOT_DIR/build/ArchiveDerivedData"
run_step scripts/upload-testflight.sh
run_step scripts/release-readiness-audit.sh

cat <<'EOF'

TestFlight release pipeline completed.
Open App Store Connect, wait for build processing, then run the manual QA plan in docs/testflight-qa-plan.md.
EOF
