#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${SUPABASE_URL:-}" ]]; then
  echo "Missing SUPABASE_URL." >&2
  exit 1
fi

if [[ -z "${SUPABASE_ANON_KEY:-}" ]]; then
  echo "Missing SUPABASE_ANON_KEY." >&2
  exit 1
fi

if [[ -z "${APP_PUBLIC_URL:-}" ]]; then
  echo "Missing APP_PUBLIC_URL." >&2
  echo "Set it to the public web origin, for example https://lector-sports.vercel.app/." >&2
  exit 1
fi

if ! command -v flutter >/dev/null 2>&1; then
  FLUTTER_VERSION="$(grep -o '"flutter"[[:space:]]*:[[:space:]]*"[^"]*"' .fvmrc | sed 's/.*"flutter"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')"
  echo "Flutter SDK not found. Installing Flutter ${FLUTTER_VERSION:-stable} for CI/Vercel..."
  git clone --depth 1 --branch "${FLUTTER_VERSION:-stable}" \
    https://github.com/flutter/flutter.git /tmp/flutter
  export PATH="/tmp/flutter/bin:$PATH"
fi

flutter --version
flutter pub get
flutter build web --release --no-wasm-dry-run \
  --dart-define=APP_ENV=staging \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --dart-define=APP_PUBLIC_URL="$APP_PUBLIC_URL" \
  --dart-define=MATCH_FEED_SOURCE="${MATCH_FEED_SOURCE:-auto}"
