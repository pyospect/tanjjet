#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -z "${SUPABASE_DB_PASSWORD:-}" ]]; then
  echo "Set SUPABASE_DB_PASSWORD before running this script." >&2
  exit 1
fi

supabase db push --password "$SUPABASE_DB_PASSWORD"

ANON_KEY="$(rg -o 'eyJ[^" ]+' Tanjjet/Services/SupabaseService.swift | head -n 1)"
curl -fsS \
  -X POST https://wxlfukoozmuwslppmkaf.supabase.co/rest/v1/rpc/disconnect_couple \
  -H "apikey: $ANON_KEY" \
  -H "Authorization: Bearer $ANON_KEY" \
  -H 'Content-Type: application/json' \
  -d '{"disconnecting_user_id":"00000000-0000-0000-0000-000000000000"}'

echo
echo "Supabase DB migration applied and disconnect_couple endpoint responded."
