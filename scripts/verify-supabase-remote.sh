#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

SUPABASE_URL="${SUPABASE_URL:-https://wxlfukoozmuwslppmkaf.supabase.co}"
ANON_KEY="${SUPABASE_ANON_KEY:-}"
REQUIRE_DISCONNECT_RPC="${REQUIRE_DISCONNECT_RPC:-0}"

if [[ -z "$ANON_KEY" ]]; then
  ANON_KEY="$(rg -o 'eyJ[^" ]+' Tanjjet/Services/SupabaseService.swift | head -n 1)"
fi

if [[ -z "$ANON_KEY" ]]; then
  echo "Could not find a Supabase anon key. Set SUPABASE_ANON_KEY and retry." >&2
  exit 1
fi

failures=0

check_rpc() {
  local rpc_name="$1"
  local payload="$2"
  local required="$3"
  local body_file
  local http_code

  body_file="$(mktemp)"
  http_code="$(
    curl -sS -o "$body_file" -w '%{http_code}' \
      -X POST "$SUPABASE_URL/rest/v1/rpc/$rpc_name" \
      -H "apikey: $ANON_KEY" \
      -H "Authorization: Bearer $ANON_KEY" \
      -H 'Content-Type: application/json' \
      -d "$payload"
  )"

  if [[ "$http_code" == "200" ]]; then
    echo "OK: $rpc_name RPC exists and responded."
    rm -f "$body_file"
    return 0
  elif [[ "$required" == "1" ]]; then
    echo "ERROR: $rpc_name RPC check failed with HTTP $http_code." >&2
    cat "$body_file" >&2
    echo >&2
    failures=1
  else
    echo "WARN: $rpc_name RPC check failed with HTTP $http_code." >&2
    cat "$body_file" >&2
    echo >&2
  fi

  rm -f "$body_file"
  return 1
}

check_function_gateway() {
  local slug="$1"
  local body_file
  local http_code

  body_file="$(mktemp)"
  http_code="$(
    curl -sS -o "$body_file" -w '%{http_code}' \
      -X POST "$SUPABASE_URL/functions/v1/$slug" \
      -H "apikey: $ANON_KEY" \
      -H 'Content-Type: application/json' \
      -d '{}'
  )"

  if [[ "$http_code" == "401" ]]; then
    echo "OK: $slug Edge Function is reachable and rejects unauthenticated requests."
  else
    echo "ERROR: $slug Edge Function gateway check returned HTTP $http_code." >&2
    cat "$body_file" >&2
    echo >&2
    failures=1
  fi

  rm -f "$body_file"
}

check_rpc "join_couple" '{"input_code":"000000","joining_user_id":"00000000-0000-0000-0000-000000000000"}' "1" || true
if ! check_rpc "disconnect_couple" '{"disconnecting_user_id":"00000000-0000-0000-0000-000000000000"}' "$REQUIRE_DISCONNECT_RPC"; then
  if [[ "$REQUIRE_DISCONNECT_RPC" != "1" ]]; then
    echo "WARN: App disconnect uses the disconnect-couple Edge Function fallback, but apply the SQL migration before final App Store submission." >&2
  fi
fi
check_function_gateway "send-push-notification"
check_function_gateway "delete-account"
check_function_gateway "disconnect-couple"

if [[ "$failures" -ne 0 ]]; then
  cat >&2 <<'EOF'

Supabase remote verification failed.
If disconnect-couple is missing, deploy it with:
  supabase functions deploy disconnect-couple --project-ref wxlfukoozmuwslppmkaf --use-api
If an RPC failed, run supabase/migrations/20260505041000_pairing_push_account_hardening.sql
in the Supabase SQL editor, or run SUPABASE_DB_PASSWORD=... scripts/apply-supabase-db.sh.
EOF
  exit 1
fi

echo "Supabase remote verification passed."
