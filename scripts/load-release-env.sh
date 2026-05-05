#!/usr/bin/env bash

load_tanjjet_release_env() {
  local default_env_file=".env.release"
  local env_file="${RELEASE_ENV_FILE:-}"

  if [[ -z "$env_file" && -f "$default_env_file" ]]; then
    env_file="$default_env_file"
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
