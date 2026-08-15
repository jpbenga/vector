-- Backend - League-scoped match feed snapshots.
--
-- The global snapshot builder can exceed the Edge Function limits on the MVP
-- Supabase plan. Snapshots are now scoped so one immutable snapshot can be
-- produced per league, then merged client-side by the Flutter read model.

alter table public.match_feed_snapshots
  add column if not exists scope text not null default 'global';

alter table public.match_feed_snapshots
  add column if not exists scope_key text not null default 'global';

alter table public.match_feed_snapshots
  add column if not exists league_ids integer[] not null default '{}'::integer[];

alter table public.match_feed_snapshots
  drop constraint if exists match_feed_snapshots_scope_check;

alter table public.match_feed_snapshots
  add constraint match_feed_snapshots_scope_check
  check (scope in ('global', 'league'));

drop index if exists public.match_feed_snapshots_identity_idx;

create unique index match_feed_snapshots_identity_idx
  on public.match_feed_snapshots (
    source,
    schema_version,
    scope_key,
    season,
    timezone,
    window_start,
    window_end,
    as_of
  );

create index if not exists match_feed_snapshots_scope_window_idx
  on public.match_feed_snapshots (
    scope,
    scope_key,
    window_start,
    window_end,
    as_of desc
  );

comment on column public.match_feed_snapshots.scope is
  'Snapshot scope. global is the historical full-feed shape; league is the MVP runtime shape.';

comment on column public.match_feed_snapshots.scope_key is
  'Stable unique scope key, for example global or league:61.';

comment on column public.match_feed_snapshots.league_ids is
  'API-Football league ids represented by this immutable snapshot.';
