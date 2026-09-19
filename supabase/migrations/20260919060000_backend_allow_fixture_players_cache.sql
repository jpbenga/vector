-- The decisive-player window uses one factual API-Football response per
-- completed fixture. Keep the server-only raw cache allowlist aligned with
-- that endpoint before the new sync function is deployed.

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
  '/fixtures/events',
  '/fixtures/players',
  '/injuries',
  '/odds',
  '/players'
));
