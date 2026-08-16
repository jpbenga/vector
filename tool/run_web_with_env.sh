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
web_hostname="${WEB_HOSTNAME:-localhost}"
app_public_url="${APP_PUBLIC_URL:-$(read_env_value APP_PUBLIC_URL)}"
match_feed_source="${MATCH_FEED_SOURCE:-$(read_env_value MATCH_FEED_SOURCE)}"

if [[ -z "${app_public_url:-}" ]]; then
  app_public_url="http://localhost:$port/"
fi

if [[ -z "${match_feed_source:-}" ]]; then
  match_feed_source="auto"
fi

case "$mode" in
  debug|profile|release)
    ;;
  *)
    echo "Invalid mode '$mode'. Use debug, profile, or release." >&2
    exit 1
    ;;
esac

flutter run -d chrome "--$mode" \
  --web-hostname "$web_hostname" \
  --web-port "$port" \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --dart-define=APP_PUBLIC_URL="$app_public_url" \
  --dart-define=MATCH_FEED_SOURCE="$match_feed_source"
