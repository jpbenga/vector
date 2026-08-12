-- Backend Lot 3C - Snapshot enrichment raw endpoints.
--
-- Scope:
-- - allow immutable pre-match snapshots to reference factual historical
--   fixture statistics collected server-side;
-- - keep the raw API-Football cache server-only;
-- - no client access or analyzer migration.

alter table public.api_football_cached_responses
drop constraint if exists api_football_cached_responses_endpoint_check;

alter table public.api_football_cached_responses
add constraint api_football_cached_responses_endpoint_check
check (endpoint in (
  '/leagues',
  '/fixtures',
  '/standings',
  '/teams/statistics',
  '/fixtures/statistics',
  '/odds'
));
