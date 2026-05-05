#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PROJECT_REF="wxlfukoozmuwslppmkaf"
MIGRATION_PATH="supabase/migrations/20260505041000_pairing_push_account_hardening.sql"
DEFAULT_ENV_FILE=".env.release"

load_release_env() {
  local env_file="${RELEASE_ENV_FILE:-}"
  if [[ -z "$env_file" && -f "$DEFAULT_ENV_FILE" ]]; then
    env_file="$DEFAULT_ENV_FILE"
  fi

  if [[ -z "$env_file" ]]; then
    return
  fi

  if [[ ! -f "$env_file" ]]; then
    echo "Release env file not found: $env_file" >&2
    exit 1
  fi

  set -a
  # shellcheck disable=SC1090
  source "$env_file"
  set +a
}

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

load_release_env
require_clean_worktree
ensure_supabase_strict_state
run_step scripts/verify-release.sh
run_step scripts/archive-testflight.sh
run_step scripts/upload-testflight.sh
run_step scripts/release-readiness-audit.sh

cat <<'EOF'

TestFlight release pipeline completed.
Open App Store Connect, wait for build processing, then run the manual QA plan in docs/testflight-qa-plan.md.
EOF
