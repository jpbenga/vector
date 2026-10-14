#!/usr/bin/env bash
set -euo pipefail

# The principal bundle reads the shared Supabase project on either web domain.
LECTOR_BUILD_ENV="${APP_ENV:-production}"
case "$LECTOR_BUILD_ENV" in
  staging|production) ;;
  *) echo "APP_ENV must be staging or production for a hosted web build." >&2; exit 1 ;;
esac

if [[ -z "${SUPABASE_URL:-}" ]]; then
  echo "Missing SUPABASE_URL." >&2
  exit 1
fi

if [[ -z "${SUPABASE_ANON_KEY:-}" ]]; then
  echo "Missing SUPABASE_ANON_KEY." >&2
  exit 1
fi

if [[ -z "${APP_PUBLIC_URL:-}" && -n "${VERCEL_URL:-}" ]]; then
  APP_PUBLIC_URL="https://${VERCEL_URL}/"
fi

if [[ -z "${APP_PUBLIC_URL:-}" ]]; then
  echo "Missing APP_PUBLIC_URL." >&2
  echo "Set it to the public web origin, for example https://lector-sports.vercel.app/." >&2
  exit 1
fi

# One bundle is promoted to both domains. The workshop endpoint checks the
# authenticated server allowlist and routes other accounts to the old generator.
LECTOR_BUILD_REVISION="${LECTOR_RELEASE_REVISION:-${VERCEL_GIT_COMMIT_SHA:-}}"
if [[ -z "$LECTOR_BUILD_REVISION" ]]; then
  LECTOR_BUILD_REVISION="$(git rev-parse HEAD)"
fi
if [[ ! "$LECTOR_BUILD_REVISION" =~ ^[a-fA-F0-9]{40}$ ]]; then
  echo "The web build requires an immutable 40-character release revision." >&2
  exit 1
fi
if [[ -n "${VERCEL_GIT_COMMIT_SHA:-}" && "$LECTOR_BUILD_REVISION" != "$VERCEL_GIT_COMMIT_SHA" ]]; then
  echo "Release revision differs from the Vercel source revision." >&2
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
if [[ "${LECTOR_SKIP_PUB:-false}" != true ]]; then
  flutter pub get
fi
flutter build web --release --no-pub --no-wasm-dry-run \
  --target=lib/main.dart --output="${LECTOR_BUILD_OUTPUT:-build/web}" \
  --dart-define=APP_ENV="$LECTOR_BUILD_ENV" \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --dart-define=APP_PUBLIC_URL="$APP_PUBLIC_URL" \
  --dart-define=MATCH_FEED_SOURCE="${MATCH_FEED_SOURCE:-auto}" \
  --dart-define=LECTOR_GENERATOR_UI=true \
  --dart-define=LECTOR_GENERATOR_ENDPOINT=lector-generator-workshop \
  --dart-define=LECTOR_RELEASE_REVISION="$LECTOR_BUILD_REVISION"
