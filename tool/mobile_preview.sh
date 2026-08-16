#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

port="${1:-8099}"
mode="${2:-release}"

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

find_lan_ip() {
  local interface ip

  for interface in en0 en1; do
    ip="$(ipconfig getifaddr "$interface" 2>/dev/null || true)"
    if [[ -n "$ip" ]]; then
      printf '%s\n' "$ip"
      return 0
    fi
  done

  interface="$(route -n get default 2>/dev/null | awk '/interface:/{print $2; exit}')"
  if [[ -n "$interface" ]]; then
    ip="$(ipconfig getifaddr "$interface" 2>/dev/null || true)"
    if [[ -n "$ip" ]]; then
      printf '%s\n' "$ip"
      return 0
    fi
  fi

  return 1
}

case "$mode" in
  debug|profile|release)
    ;;
  *)
    echo "Invalid mode '$mode'. Use debug, profile, or release." >&2
    exit 1
    ;;
esac

if lsof -tiTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1; then
  echo "Port $port is already in use:" >&2
  lsof -nP -iTCP:"$port" -sTCP:LISTEN >&2
  echo >&2
  echo "Stop it with:" >&2
  echo "kill \$(lsof -tiTCP:$port -sTCP:LISTEN)" >&2
  exit 1
fi

lan_ip="$(find_lan_ip)"
mobile_url="http://$lan_ip:$port/"
qr_svg="var/mobile-preview-qr.svg"
url_file="var/mobile-preview-url.txt"

supabase_url="$(read_env_value SUPABASE_URL)"
supabase_anon_key="$(read_env_value SUPABASE_ANON_KEY)"
match_feed_source="${MATCH_FEED_SOURCE:-$(read_env_value MATCH_FEED_SOURCE)}"

if [[ -z "${supabase_url:-}" ]]; then
  echo "SUPABASE_URL is empty in .env." >&2
  exit 1
fi

if [[ -z "${supabase_anon_key:-}" ]]; then
  echo "SUPABASE_ANON_KEY is empty in .env." >&2
  exit 1
fi

if [[ -z "${match_feed_source:-}" ]]; then
  match_feed_source="auto"
fi

mkdir -p var
printf '%s\n' "$mobile_url" > "$url_file"

cat <<EOF

Mobile preview build
--------------------
URL mobile : $mobile_url
Mode : $mode
Source matches : $match_feed_source

Je compile d'abord l'app. Le QR code s'ouvrira quand le serveur sera pret.

EOF

flutter build web "--$mode" --pwa-strategy=none \
  --dart-define=SUPABASE_URL="$supabase_url" \
  --dart-define=SUPABASE_ANON_KEY="$supabase_anon_key" \
  --dart-define=APP_PUBLIC_URL="$mobile_url" \
  --dart-define=MATCH_FEED_SOURCE="$match_feed_source"

if command -v pbcopy >/dev/null 2>&1; then
  printf '%s' "$mobile_url" | pbcopy
fi

if command -v qrencode >/dev/null 2>&1; then
  qrencode -t SVG -o "$qr_svg" "$mobile_url"
elif command -v curl >/dev/null 2>&1; then
  if ! curl -fsSLG "https://quickchart.io/qr" \
    --data-urlencode "text=$mobile_url" \
    --data "size=640" \
    --data "margin=2" \
    --data "format=svg" \
    -o "$qr_svg" >/dev/null; then
    qr_svg=""
  fi
else
  qr_svg=""
fi

cat <<EOF

Mobile preview ready
--------------------
URL mobile : $mobile_url
Copie presse-papiers : $([[ -x "$(command -v pbcopy 2>/dev/null || true)" ]] && echo "oui" || echo "non")
QR code : ${qr_svg:-non genere}

Ton telephone doit etre sur le meme Wi-Fi que ce Mac.
Garde ce terminal ouvert pendant le test.

EOF

if [[ -n "$qr_svg" ]] && command -v open >/dev/null 2>&1; then
  open "$qr_svg" >/dev/null 2>&1 || true
fi

if command -v python3 >/dev/null 2>&1; then
  python3 - "$port" build/web <<'PY'
import functools
import http.server
import os
import socketserver
import sys
import urllib.parse

port = int(sys.argv[1])
directory = sys.argv[2]


class NoCacheHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        target = self.translate_path(parsed.path)
        basename = os.path.basename(parsed.path)
        if not os.path.exists(target) and "." not in basename:
            query = f"?{parsed.query}" if parsed.query else ""
            self.path = f"/index.html{query}"
        super().do_GET()

    def end_headers(self):
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        super().end_headers()


handler = functools.partial(NoCacheHandler, directory=directory)

with socketserver.TCPServer(("0.0.0.0", port), handler) as httpd:
    httpd.allow_reuse_address = True
    print(f"Serving {directory} on http://0.0.0.0:{port}/ with no-cache headers")
    httpd.serve_forever()
PY
else
  echo "python3 is required to serve build/web locally." >&2
  exit 1
fi
