-- Direct confrontations are a factual, cache-backed source used only by the
-- match-detail Confrontation tab. Keep the raw server-side cache allowlist in
-- sync with the API-Football collector.

alter table public.api_football_cached_responses
drop constraint if exists api_football_cached_responses_endpoint_check;

alter table public.api_football_cached_responses
add constraint api_football_cached_responses_endpoint_check
check (endpoint in (
  '/leagues',
  '/fixtures',
  '/fixtures/headtohead',
  '/standings',
  '/teams/statistics',
  '/fixtures/statistics',
  '/fixtures/events',
  '/fixtures/players',
  '/injuries',
  '/odds',
  '/players'
));
