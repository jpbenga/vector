#!/usr/bin/env bash
# Run the current multisport demo UI against published Supabase data.
# No provider collection, publication writes or OpenAI calls during launch.
set -euo pipefail
cd "$(dirname "$0")/.."
port="${1:-8191}"
mode="${2:-release}"
if [[ ! "$port" =~ ^[0-9]+$ ]] || ((10#$port < 1024 || 10#$port > 65535)); then
  echo "Port invalide : $port (1024 à 65535 attendus)." >&2
  exit 1
fi
if command -v lsof >/dev/null 2>&1 && \
  lsof -nP -iTCP:"$port" -sTCP:LISTEN -t >/dev/null 2>&1; then
  echo "Le port $port est déjà utilisé ; aucun nouveau lancement effectué." >&2
  echo "Application déjà lancée : ouvrir http://localhost:$port/" >&2
  echo "Si ce serveur correspond à une autre application, choisir un autre port." >&2
  exit 1
fi
echo "Démo multisport locale : http://localhost:$port/"
echo "Générateur conversationnel : lector-generator-workshop (serveur démo)."
echo "Données publiées uniquement ; aucune collecte hockey lancée."
echo "Ouvrir cette adresse dans votre navigateur habituel."
LECTOR_WEB_DEVICE="${LECTOR_WEB_DEVICE:-web-server}" \
  APP_ENV=staging LECTOR_GENERATOR_UI=true \
  LECTOR_GENERATOR_ENDPOINT=lector-generator-workshop \
  APP_PUBLIC_URL="http://localhost:$port/" WEB_HOSTNAME=localhost \
  SPORT_FEED_BASE_URL= \
  bash tool/run_web_with_env.sh "$port" "$mode"
