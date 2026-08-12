-- Backend Lot 2 - API-Football server-side collection foundation.
--
-- Scope:
-- - server-only raw API-Football cache;
-- - sync run logs with provenance and quotas;
-- - no immutable pre-match snapshots yet;
-- - no Football Analyzer migration;
-- - no public/client writes.

create table public.api_football_sync_runs (
  id uuid primary key default gen_random_uuid(),
  kind text not null default 'match_feed_window'
    check (kind in ('match_feed_window')),
  status text not null default 'running'
    check (status in ('running', 'succeeded', 'failed', 'partial')),
  season integer not null
    check (season between 2000 and 2100),
  timezone text not null default 'Europe/Paris'
    check (length(btrim(timezone)) > 0),
  window_start date not null,
  window_end date not null,
  league_ids integer[] not null
    check (cardinality(league_ids) > 0),
  bookmaker_id integer,
  include_team_statistics boolean not null default true,
  request_payload jsonb not null default '{}'::jsonb,
  response_summary jsonb not null default '{}'::jsonb,
  error_message text,
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  created_at timestamptz not null default now(),
  check (window_end >= window_start)
);

comment on table public.api_football_sync_runs is
  'Server-side API-Football sync executions. Used for logs, replayability and quota auditing.';

create index api_football_sync_runs_started_at_idx
  on public.api_football_sync_runs (started_at desc);

create index api_football_sync_runs_status_idx
  on public.api_football_sync_runs (status, started_at desc);

create table public.api_football_cached_responses (
  source text not null default 'api-football'
    check (source = 'api-football'),
  endpoint text not null
    check (endpoint in (
      '/leagues',
      '/fixtures',
      '/standings',
      '/teams/statistics',
      '/odds'
    )),
  query_hash text not null
    check (length(query_hash) = 64),
  query_params jsonb not null,
  request_url text not null,
  response_status integer not null
    check (response_status between 100 and 599),
  response_body jsonb not null,
  rate_limit jsonb not null default '{}'::jsonb,
  sync_run_id uuid references public.api_football_sync_runs(id)
    on delete set null,
  fetched_at timestamptz not null,
  as_of timestamptz not null,
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (source, endpoint, query_hash),
  check (expires_at is null or expires_at >= fetched_at)
);

comment on table public.api_football_cached_responses is
  'Idempotent server-only cache of raw API-Football responses. Lot 3 will derive immutable pre-match snapshots from these rows.';

create index api_football_cached_responses_endpoint_fetched_idx
  on public.api_football_cached_responses (endpoint, fetched_at desc);

create index api_football_cached_responses_expires_idx
  on public.api_football_cached_responses (expires_at)
  where expires_at is not null;

create trigger set_api_football_cached_responses_updated_at
before update on public.api_football_cached_responses
for each row
execute function public.set_updated_at();

alter table public.api_football_sync_runs enable row level security;
alter table public.api_football_cached_responses enable row level security;

alter table public.api_football_sync_runs force row level security;
alter table public.api_football_cached_responses force row level security;

revoke all on table public.api_football_sync_runs
  from anon, authenticated;
revoke all on table public.api_football_cached_responses
  from anon, authenticated;
