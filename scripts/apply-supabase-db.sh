#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -z "${SUPABASE_DB_PASSWORD:-}" ]]; then
  cat >&2 <<'EOF'
Set SUPABASE_DB_PASSWORD before running this script.
If you prefer the Supabase SQL editor, run:
  supabase/migrations/20260505041000_pairing_push_account_hardening.sql
Then verify with:
  scripts/verify-supabase-remote.sh
EOF
  exit 1
fi

supabase db push --password "$SUPABASE_DB_PASSWORD"
scripts/verify-supabase-remote.sh
