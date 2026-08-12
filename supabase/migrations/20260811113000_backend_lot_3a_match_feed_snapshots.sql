-- Backend Lot 3A - Immutable pre-match snapshot contract.
--
-- Scope:
-- - normalized read-model envelope for match feeds;
-- - fixture index for day/league browsing;
-- - provenance links to Lot 2 raw API-Football cache;
-- - append-only semantics enforced by database triggers;
-- - no raw cache transformation job yet;
-- - no Flutter repository switch yet.

create or replace function public.prevent_snapshot_mutation()
returns trigger
language plpgsql
as $$
begin
  raise exception 'Pre-match snapshots are immutable. Create a new snapshot instead.';
end;
$$;

create table public.match_feed_snapshots (
  id uuid primary key default gen_random_uuid(),
  schema_version integer not null default 1
    check (schema_version >= 1),
  source text not null default 'api-football'
    check (source = 'api-football'),
  kind text not null default 'pre_match_feed'
    check (kind in ('pre_match_feed')),
  season integer not null
    check (season between 2000 and 2100),
  timezone text not null default 'Europe/Paris'
    check (length(btrim(timezone)) > 0),
  window_start date not null,
  window_end date not null,
  date_window date[] not null
    check (cardinality(date_window) > 0),
  bookmaker_priority jsonb not null default '[]'::jsonb
    check (jsonb_typeof(bookmaker_priority) = 'array'),
  payload jsonb not null,
  coverage_summary jsonb not null default '{}'::jsonb
    check (jsonb_typeof(coverage_summary) = 'object'),
  provenance jsonb not null default '{}'::jsonb
    check (jsonb_typeof(provenance) = 'object'),
  source_sync_run_ids uuid[] not null default '{}'::uuid[],
  captured_at timestamptz not null,
  as_of timestamptz not null,
  snapshot_created_at timestamptz not null default now(),
  check (window_end >= window_start),
  check (as_of <= snapshot_created_at),
  check (payload ? 'schema_version'),
  check (payload ? 'source'),
  check (payload ? 'captured_at'),
  check (payload ? 'timezone'),
  check (payload ? 'window_start'),
  check (payload ? 'window_end'),
  check (payload ? 'date_window'),
  check (payload ? 'raw')
);

comment on table public.match_feed_snapshots is
  'Immutable pre-match match feed snapshots. Payload keeps the current V1 JSON envelope consumed by ApiFootballMatchAdapter.';

create unique index match_feed_snapshots_identity_idx
  on public.match_feed_snapshots (
    source,
    schema_version,
    season,
    timezone,
    window_start,
    window_end,
    as_of
  );

create index match_feed_snapshots_window_idx
  on public.match_feed_snapshots (window_start, window_end, as_of desc);

create index match_feed_snapshots_created_idx
  on public.match_feed_snapshots (snapshot_created_at desc);

create trigger prevent_match_feed_snapshots_update
before update on public.match_feed_snapshots
for each row
execute function public.prevent_snapshot_mutation();

create trigger prevent_match_feed_snapshots_delete
before delete on public.match_feed_snapshots
for each row
execute function public.prevent_snapshot_mutation();

create table public.match_feed_snapshot_fixtures (
  snapshot_id uuid not null
    references public.match_feed_snapshots(id)
    on delete restrict,
  fixture_id text not null,
  api_football_fixture_id integer,
  api_football_league_id integer,
  season integer not null
    check (season between 2000 and 2100),
  fixture_date date not null,
  kickoff_at timestamptz,
  status text not null,
  competition_id text not null,
  competition_name text not null,
  country_code text not null,
  country_name text not null,
  home_team_id text not null,
  home_team_name text not null,
  away_team_id text not null,
  away_team_name text not null,
  has_odds boolean not null default false,
  has_standings boolean not null default false,
  has_team_statistics boolean not null default false,
  has_recent_form boolean not null default false,
  has_expected_goals boolean not null default false,
  contains_predictions boolean not null default false,
  payload jsonb not null default '{}'::jsonb
    check (jsonb_typeof(payload) = 'object'),
  created_at timestamptz not null default now(),
  primary key (snapshot_id, fixture_id)
);

comment on table public.match_feed_snapshot_fixtures is
  'Immutable fixture index derived from match_feed_snapshots for efficient browsing by day, league and team.';

create index match_feed_snapshot_fixtures_date_idx
  on public.match_feed_snapshot_fixtures (fixture_date, kickoff_at);

create index match_feed_snapshot_fixtures_league_date_idx
  on public.match_feed_snapshot_fixtures (
    api_football_league_id,
    fixture_date,
    kickoff_at
  );

create index match_feed_snapshot_fixtures_home_team_idx
  on public.match_feed_snapshot_fixtures (home_team_id);

create index match_feed_snapshot_fixtures_away_team_idx
  on public.match_feed_snapshot_fixtures (away_team_id);

create trigger prevent_match_feed_snapshot_fixtures_update
before update on public.match_feed_snapshot_fixtures
for each row
execute function public.prevent_snapshot_mutation();

create trigger prevent_match_feed_snapshot_fixtures_delete
before delete on public.match_feed_snapshot_fixtures
for each row
execute function public.prevent_snapshot_mutation();

create table public.match_feed_snapshot_sources (
  snapshot_id uuid not null
    references public.match_feed_snapshots(id)
    on delete restrict,
  source text not null default 'api-football'
    check (source = 'api-football'),
  endpoint text not null,
  query_hash text not null
    check (length(query_hash) = 64),
  sync_run_id uuid references public.api_football_sync_runs(id)
    on delete set null,
  fetched_at timestamptz not null,
  as_of timestamptz not null,
  response_status integer not null
    check (response_status between 100 and 599),
  created_at timestamptz not null default now(),
  primary key (snapshot_id, source, endpoint, query_hash),
  foreign key (source, endpoint, query_hash)
    references public.api_football_cached_responses (
      source,
      endpoint,
      query_hash
    )
    on delete restrict
);

comment on table public.match_feed_snapshot_sources is
  'Provenance links between immutable match feed snapshots and the raw API-Football responses used to build them.';

create index match_feed_snapshot_sources_run_idx
  on public.match_feed_snapshot_sources (sync_run_id);

create index match_feed_snapshot_sources_fetched_idx
  on public.match_feed_snapshot_sources (fetched_at desc);

create trigger prevent_match_feed_snapshot_sources_update
before update on public.match_feed_snapshot_sources
for each row
execute function public.prevent_snapshot_mutation();

create trigger prevent_match_feed_snapshot_sources_delete
before delete on public.match_feed_snapshot_sources
for each row
execute function public.prevent_snapshot_mutation();

alter table public.match_feed_snapshots enable row level security;
alter table public.match_feed_snapshot_fixtures enable row level security;
alter table public.match_feed_snapshot_sources enable row level security;

alter table public.match_feed_snapshots force row level security;
alter table public.match_feed_snapshot_fixtures force row level security;
alter table public.match_feed_snapshot_sources force row level security;

revoke insert, update, delete on table public.match_feed_snapshots
  from anon, authenticated;
revoke insert, update, delete on table public.match_feed_snapshot_fixtures
  from anon, authenticated;
revoke insert, update, delete on table public.match_feed_snapshot_sources
  from anon, authenticated;

grant select on table public.match_feed_snapshots
  to anon, authenticated;
grant select on table public.match_feed_snapshot_fixtures
  to anon, authenticated;
grant select on table public.match_feed_snapshot_sources
  to anon, authenticated;

create policy "match_feed_snapshots_select_public"
on public.match_feed_snapshots
for select
to anon, authenticated
using (true);

create policy "match_feed_snapshot_fixtures_select_public"
on public.match_feed_snapshot_fixtures
for select
to anon, authenticated
using (true);

create policy "match_feed_snapshot_sources_select_public"
on public.match_feed_snapshot_sources
for select
to anon, authenticated
using (true);
