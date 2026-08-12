#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ ! -f .env ]]; then
  echo "Missing .env file. Copy .env.example to .env and fill SUPABASE_URL and SUPABASE_ANON_KEY." >&2
  exit 1
fi

read_env_value() {
  local key="$1"
  awk -F= -v key="$key" '
    $1 == key {
      value = substr($0, index($0, "=") + 1)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      gsub(/^'\''|'\''$/, "", value)
      gsub(/^"|"$/, "", value)
      print value
      exit
    }
  ' .env
}

SUPABASE_URL="$(read_env_value SUPABASE_URL)"
SUPABASE_ANON_KEY="$(read_env_value SUPABASE_ANON_KEY)"

if [[ -z "${SUPABASE_URL:-}" ]]; then
  echo "SUPABASE_URL is empty in .env." >&2
  exit 1
fi

if [[ -z "${SUPABASE_ANON_KEY:-}" ]]; then
  echo "SUPABASE_ANON_KEY is empty in .env." >&2
  exit 1
fi

port="${1:-8099}"
mode="${2:-release}"

case "$mode" in
  debug|profile|release)
    ;;
  *)
    echo "Invalid mode '$mode'. Use debug, profile, or release." >&2
    exit 1
    ;;
esac

flutter run -d chrome "--$mode" --web-port "$port" \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"
