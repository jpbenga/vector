-- Backend Daily Football Sync MVP.
--
-- Scope:
-- - daily orchestration logs for API-Football collection + snapshot build;
-- - storage usage monitoring for the Supabase free tier;
-- - public read access to sync health, no client writes.

create table public.daily_football_sync_runs (
  id uuid primary key default gen_random_uuid(),
  status text not null default 'running'
    check (status in ('running', 'succeeded', 'failed', 'partial')),
  season integer not null
    check (season between 2000 and 2100),
  timezone text not null default 'Europe/Paris'
    check (length(btrim(timezone)) > 0),
  results_window_start date not null,
  results_window_end date not null,
  feed_window_start date not null,
  feed_window_end date not null,
  league_ids integer[] not null
    check (cardinality(league_ids) > 0),
  bookmaker_id integer,
  api_request_delay_ms integer not null default 750
    check (api_request_delay_ms >= 0),
  sync_response jsonb not null default '{}'::jsonb
    check (jsonb_typeof(sync_response) = 'object'),
  snapshot_response jsonb not null default '{}'::jsonb
    check (jsonb_typeof(snapshot_response) = 'object'),
  api_football_sync_run_id uuid references public.api_football_sync_runs(id)
    on delete set null,
  snapshot_id uuid references public.match_feed_snapshots(id)
    on delete set null,
  api_request_count integer not null default 0
    check (api_request_count >= 0),
  database_size_bytes bigint
    check (database_size_bytes is null or database_size_bytes >= 0),
  database_size_limit_bytes bigint not null default 524288000
    check (database_size_limit_bytes > 0),
  database_size_ratio numeric(6, 5)
    check (
      database_size_ratio is null
      or (database_size_ratio >= 0 and database_size_ratio <= 999)
    ),
  storage_warning_level text not null default 'ok'
    check (storage_warning_level in ('ok', 'warning_80', 'warning_90', 'critical_95')),
  error_message text,
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  created_at timestamptz not null default now(),
  check (results_window_end >= results_window_start),
  check (feed_window_end >= feed_window_start)
);

comment on table public.daily_football_sync_runs is
  'Daily backend orchestration runs for result refresh, future feed preparation and storage monitoring.';

create index daily_football_sync_runs_started_at_idx
  on public.daily_football_sync_runs (started_at desc);

create index daily_football_sync_runs_status_idx
  on public.daily_football_sync_runs (status, started_at desc);

create index daily_football_sync_runs_snapshot_idx
  on public.daily_football_sync_runs (snapshot_id)
  where snapshot_id is not null;

create or replace function public.current_database_size_bytes()
returns bigint
language sql
security definer
set search_path = public
as $$
  select pg_database_size(current_database());
$$;

comment on function public.current_database_size_bytes() is
  'Returns the current database size in bytes for backend storage monitoring.';

revoke all on function public.current_database_size_bytes()
  from public;

grant execute on function public.current_database_size_bytes()
  to service_role;

alter table public.daily_football_sync_runs enable row level security;
alter table public.daily_football_sync_runs force row level security;

revoke insert, update, delete on table public.daily_football_sync_runs
  from anon, authenticated;

grant select on table public.daily_football_sync_runs
  to anon, authenticated;

create policy "daily_football_sync_runs_select_public"
on public.daily_football_sync_runs
for select
to anon, authenticated
using (true);
