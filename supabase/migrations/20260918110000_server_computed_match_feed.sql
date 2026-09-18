-- Compact, immutable read model generated from the private raw API-Football
-- snapshot. Mobile clients read this table, never the historical raw payload.
create table public.match_feed_analysis_snapshots (
  id uuid primary key default gen_random_uuid(),
  source_snapshot_id uuid not null unique
    references public.match_feed_snapshots(id) on delete restrict,
  schema_version integer not null default 1 check (schema_version >= 1),
  source text not null default 'api-football' check (source = 'api-football'),
  scope text not null check (scope in ('global', 'league')),
  scope_key text not null,
  league_ids integer[] not null default '{}'::integer[],
  timezone text not null default 'Europe/Paris',
  window_start date not null,
  window_end date not null,
  captured_at timestamptz not null,
  as_of timestamptz not null,
  payload jsonb not null check (jsonb_typeof(payload) = 'object'),
  coverage_summary jsonb not null default '{}'::jsonb
    check (jsonb_typeof(coverage_summary) = 'object'),
  created_at timestamptz not null default now(),
  check (window_end >= window_start),
  check (payload ? 'schema_version'),
  check (payload ? 'raw'),
  check (payload ? 'computed')
);

comment on table public.match_feed_analysis_snapshots is
  'Immutable compact mobile feed: fixture presentation data plus server-computed readings and scenarios. Raw historical API-Football inputs remain private in match_feed_snapshots.';

create index match_feed_analysis_snapshots_window_idx
  on public.match_feed_analysis_snapshots (window_start, window_end, as_of desc);
create index match_feed_analysis_snapshots_scope_idx
  on public.match_feed_analysis_snapshots (scope, scope_key, as_of desc);

create trigger prevent_match_feed_analysis_snapshots_update
before update or delete on public.match_feed_analysis_snapshots
for each row execute function public.prevent_snapshot_mutation();

alter table public.match_feed_analysis_snapshots enable row level security;
alter table public.match_feed_analysis_snapshots force row level security;
revoke insert, update, delete on public.match_feed_analysis_snapshots
  from anon, authenticated;
grant select on public.match_feed_analysis_snapshots to anon, authenticated;
grant insert on public.match_feed_analysis_snapshots to service_role;
create policy match_feed_analysis_snapshots_public_select
on public.match_feed_analysis_snapshots for select to anon, authenticated using (true);
