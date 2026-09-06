-- Allow the server-side API-Football cache to retain player season statistics.
-- This extends the existing factual-source allowlist only; no client access or
-- business rule is changed.

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
  '/odds',
  '/players'
));
