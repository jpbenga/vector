#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
# No credentials are read. The editor bundle is built from the tested sources.
deno bundle supabase/functions/sync-hockey-live/index.ts -o /tmp/lector-sync-hockey-live.js
