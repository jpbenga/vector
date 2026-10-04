#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
port="${1:-8099}"
mode="${2:-release}"
sport_port="${SPORT_PREVIEW_PORT:-8100}"
command -v deno >/dev/null || { echo "Deno est nécessaire pour la collecte NHL locale." >&2; exit 1; }
[[ -f .env ]] || { echo "Le fichier .env du projet est nécessaire." >&2; exit 1; }
# Start the collector before Flutter so no empty, unconfigured hockey preview opens.
deno run --allow-read=.env,var/sports --allow-write=var/sports \
  --allow-net=v1.hockey.api-sports.io,127.0.0.1 \
  tool/sports/nhl_local.ts "--port=$sport_port" &
collector_pid=$!
trap 'kill "$collector_pid" 2>/dev/null || true; wait "$collector_pid" 2>/dev/null || true' EXIT
for ((attempt=0; attempt<90; attempt++)); do
  kill -0 "$collector_pid" 2>/dev/null || { echo "La collecte NHL a échoué ; consulter le message ci-dessus." >&2; exit 1; }
  if curl --silent --fail "http://127.0.0.1:$sport_port/sports/hockey/feed" >/dev/null; then
    SPORT_FEED_BASE_URL="http://127.0.0.1:$sport_port/" \
      bash tool/run_web_with_env.sh "$port" "$mode"
    exit $?
  fi
  sleep 1
done
echo "La publication NHL locale n’est pas disponible après 90 secondes." >&2
exit 1
