-- Keep the raw-response allowlist aligned with the historical event and
-- pre-match injury endpoints collected by api-football-sync.

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
  '/injuries',
  '/odds',
  '/players'
));
