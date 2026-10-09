#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
port="${1:-8191}"
mode="${2:-release}"
sport_port="${SPORT_PREVIEW_PORT:-8110}"
command -v deno >/dev/null || { echo "Deno est nécessaire pour la collecte NHL locale." >&2; exit 1; }
command -v python3 >/dev/null || { echo "Python 3 est nécessaire pour vérifier la publication hockey locale." >&2; exit 1; }
command -v lsof >/dev/null || { echo "lsof est nécessaire pour vérifier les ports locaux." >&2; exit 1; }
[[ -f .env ]] || { echo "Le fichier .env du projet est nécessaire." >&2; exit 1; }

for candidate in "$port" "$sport_port"; do
  if [[ ! "$candidate" =~ ^[0-9]+$ ]] || ((10#$candidate < 1024 || 10#$candidate > 65535)); then
    echo "Port local invalide : $candidate (1024 à 65535 attendus)." >&2
    exit 1
  fi
done
if [[ "$port" == "$sport_port" ]]; then
  echo "L'application et la source hockey doivent utiliser deux ports différents." >&2
  exit 1
fi
case "$mode" in debug|profile|release) ;; *) echo "Mode invalide : $mode." >&2; exit 1 ;; esac

port_in_use() { lsof -nP -iTCP:"$1" -sTCP:LISTEN -t >/dev/null 2>&1; }
if port_in_use "$port"; then
  echo "Le port de l'application $port est déjà utilisé. Fermez son ancien lancement avant de relancer ce script." >&2
  echo "Adresse : http://localhost:$port/sports/hockey" >&2
  exit 1
fi

publication_ready() {
  # Validate the actual response, not only HTTP 200 from another process.
  python3 - "$sport_port" <<'PY'
import json, sys, urllib.request
from pathlib import Path
try:
    with urllib.request.urlopen('http://127.0.0.1:'+sys.argv[1]+'/sports/hockey/feed', timeout=2) as response:
        if response.status != 200:
            raise ValueError('No publication')
        received = json.load(response)
    retained = json.loads(Path('var/sports/hockey/published.json').read_text())
    assert received['sport'] == 'hockey' and received['schemaVersion'] == 1
    assert isinstance(received['items'], list)
    assert isinstance(received['competitions'], list) and received['competitions']
    assert received == retained
except Exception:
    sys.exit(1)
PY
}

launch_app() {
  python3 tool/sports/publish_sport_feed.py
  echo "Application : http://localhost:$port/sports/hockey"
  # A local run must return OAuth to the same origin, even when .env contains
  # an old LAN address or a production APP_PUBLIC_URL.
  LECTOR_GENERATOR_ENDPOINT=lector-generator-workshop WEB_HOSTNAME=localhost APP_PUBLIC_URL="http://localhost:$port/" \
    SPORT_FEED_BASE_URL="http://127.0.0.1:$sport_port/" \
    bash tool/run_web_with_env.sh "$port" "$mode"
}

if port_in_use "$sport_port"; then
  if publication_ready; then
    echo "Source hockey existante réutilisée sur $sport_port : aucune nouvelle collecte API."
    launch_app
    exit $?
  fi
  echo "Le port hockey $sport_port est occupé, mais ne sert pas la publication de ce projet. Aucune collecte lancée." >&2
  exit 1
fi

# Only own and stop a collector that this invocation started.
deno run --allow-read=.env,var/sports --allow-write=var/sports \
  --allow-net=v1.hockey.api-sports.io,127.0.0.1,ednvvxxvlawaagjyshkj.supabase.co \
  tool/sports/nhl_local.ts "--port=$sport_port" &
collector_pid=$!
trap 'kill "$collector_pid" 2>/dev/null || true; wait "$collector_pid" 2>/dev/null || true' EXIT
for ((attempt=0; attempt<1800; attempt++)); do
  kill -0 "$collector_pid" 2>/dev/null || { echo "La collecte NHL a échoué ; consulter le message ci-dessus." >&2; exit 1; }
  if publication_ready; then
    launch_app
    exit $?
  fi
  sleep 1
done
echo "La publication NHL locale n’est pas disponible après 30 minutes." >&2
exit 1
