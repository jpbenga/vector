-- Backend data observability for the API-Football MVP pipeline.
--
-- Scope:
-- - one SQL source of truth for the MVP leagues;
-- - service-role health views for latest sync and latest league snapshot;
-- - no writes, no secrets, no cron side effects.

create or replace view public.api_football_mvp_leagues
with (security_invoker = true)
as
select *
from (
  values
    (39, 'Premier League'),
    (61, 'Ligue 1'),
    (140, 'La Liga'),
    (78, 'Bundesliga'),
    (135, 'Serie A'),
    (94, 'Liga Portugal'),
    (95, 'Liga Portugal 2'),
    (88, 'Eredivisie'),
    (144, 'Jupiler Pro'),
    (179, 'Premiership'),
    (203, 'Super Lig'),
    (197, 'Super League GRE'),
    (119, 'Superliga DAN'),
    (207, 'Super League SUI'),
    (218, 'Bundesliga AUT'),
    (40, 'Championship'),
    (62, 'Ligue 2'),
    (136, 'Serie B'),
    (79, '2. Bundesliga'),
    (141, 'La Liga 2'),
    (106, 'Ekstraklasa'),
    (210, 'HNL'),
    (209, 'Czech Liga'),
    (283, 'Liga I'),
    (253, 'MLS'),
    (71, 'Brasileiro A'),
    (128, 'Liga Prof'),
    (262, 'Liga MX'),
    (307, 'Saudi Pro'),
    (98, 'J1 League'),
    (188, 'A-League'),
    (103, 'Eliteserien'),
    (113, 'Allsvenskan'),
    (164, 'Besta deild karla'),
    (169, 'Chinese Super League'),
    (244, 'Veikkausliiga'),
    (292, 'K League 1')
) as leagues(api_football_league_id, league_name);

comment on view public.api_football_mvp_leagues is
  'Expected API-Football league scope for the Lector MVP data pipeline.';

create or replace view public.api_football_latest_league_sync_health
with (security_invoker = true)
as
with latest_sync as (
  select distinct on (league_id)
    league_id,
    run.id as sync_run_id,
    run.status,
    run.started_at,
    run.finished_at,
    run.window_start,
    run.window_end,
    (run.response_summary -> 'leagueSeasons' ->> league_id::text)::integer
      as resolved_season,
    coalesce((run.response_summary ->> 'fixtures')::integer, 0) as fixtures,
    coalesce((run.response_summary ->> 'odds')::integer, 0) as odds,
    coalesce((run.response_summary ->> 'standings')::integer, 0) as standings,
    coalesce((run.response_summary ->> 'teamStatistics')::integer, 0)
      as team_statistics,
    coalesce((run.response_summary ->> 'recentFixtureRows')::integer, 0)
      as recent_fixture_rows,
    coalesce((run.response_summary ->> 'cachedResponses')::integer, 0)
      as cached_responses,
    run.error_message
  from public.api_football_sync_runs run
  cross join lateral unnest(run.league_ids) as league_id
  order by league_id, run.started_at desc
)
select
  expected.api_football_league_id,
  expected.league_name,
  latest_sync.sync_run_id,
  latest_sync.status,
  latest_sync.started_at,
  latest_sync.finished_at,
  latest_sync.window_start,
  latest_sync.window_end,
  latest_sync.resolved_season,
  latest_sync.fixtures,
  latest_sync.odds,
  latest_sync.standings,
  latest_sync.team_statistics,
  latest_sync.recent_fixture_rows,
  latest_sync.cached_responses,
  latest_sync.error_message,
  case
    when latest_sync.sync_run_id is null then 'missing_sync'
    when latest_sync.status = 'running'
      and latest_sync.started_at < now() - interval '30 minutes'
      then 'stale_running'
    when latest_sync.status <> 'succeeded' then 'sync_not_succeeded'
    when latest_sync.resolved_season is null then 'missing_resolved_season'
    else 'ok'
  end as health_status
from public.api_football_mvp_leagues expected
left join latest_sync
  on latest_sync.league_id = expected.api_football_league_id
order by expected.api_football_league_id;

comment on view public.api_football_latest_league_sync_health is
  'Latest API-Football collection health by MVP league, including resolved season per league.';

create or replace view public.api_football_latest_league_snapshot_health
with (security_invoker = true)
as
with latest_snapshot as (
  select distinct on (league_id)
    league_id,
    snapshot.id as snapshot_id,
    snapshot.scope_key,
    snapshot.window_start,
    snapshot.window_end,
    snapshot.as_of,
    snapshot.snapshot_created_at,
    (snapshot.payload -> 'season_by_league' ->> league_id::text)::integer
      as resolved_season,
    coalesce((snapshot.coverage_summary ->> 'fixtures')::integer, 0)
      as fixtures,
    coalesce((snapshot.coverage_summary ->> 'odds')::integer, 0) as odds,
    coalesce((snapshot.coverage_summary ->> 'standings')::integer, 0)
      as standings,
    coalesce((snapshot.coverage_summary ->> 'team_statistics')::integer, 0)
      as team_statistics,
    coalesce(
      (snapshot.coverage_summary ->> 'recent_league_matches')::integer,
      0
    ) as recent_league_matches,
    coalesce((snapshot.coverage_summary ->> 'expected_goals')::integer, 0)
      as expected_goals,
    coalesce(
      (snapshot.coverage_summary -> 'missing' ->> 'odds')::integer,
      0
    ) as missing_odds,
    coalesce(
      (snapshot.coverage_summary -> 'missing' ->> 'team_statistics')::integer,
      0
    ) as missing_team_statistics,
    coalesce(
      (snapshot.coverage_summary -> 'missing' ->> 'recent_form')::integer,
      0
    ) as missing_recent_form,
    coalesce(
      (snapshot.coverage_summary -> 'missing' ->> 'expected_goals')::integer,
      0
    ) as missing_expected_goals
  from public.match_feed_snapshots snapshot
  cross join lateral unnest(snapshot.league_ids) as league_id
  where snapshot.scope = 'league'
  order by league_id, snapshot.snapshot_created_at desc
)
select
  expected.api_football_league_id,
  expected.league_name,
  latest_snapshot.snapshot_id,
  latest_snapshot.scope_key,
  latest_snapshot.window_start,
  latest_snapshot.window_end,
  latest_snapshot.as_of,
  latest_snapshot.snapshot_created_at,
  latest_snapshot.resolved_season,
  latest_snapshot.fixtures,
  latest_snapshot.odds,
  latest_snapshot.standings,
  latest_snapshot.team_statistics,
  latest_snapshot.recent_league_matches,
  latest_snapshot.expected_goals,
  latest_snapshot.missing_odds,
  latest_snapshot.missing_team_statistics,
  latest_snapshot.missing_recent_form,
  latest_snapshot.missing_expected_goals,
  case
    when latest_snapshot.snapshot_id is null then 'missing_snapshot'
    when latest_snapshot.resolved_season is null then 'missing_resolved_season'
    when latest_snapshot.window_end < (now() at time zone 'UTC')::date
      then 'stale_window'
    else 'ok'
  end as health_status
from public.api_football_mvp_leagues expected
left join latest_snapshot
  on latest_snapshot.league_id = expected.api_football_league_id
order by expected.api_football_league_id;

comment on view public.api_football_latest_league_snapshot_health is
  'Latest league-scoped snapshot health by MVP league, including coverage and missing data counters.';

create or replace view public.api_football_pipeline_health
with (security_invoker = true)
as
select
  leagues.api_football_league_id,
  leagues.league_name,
  sync.status as sync_status,
  sync.health_status as sync_health_status,
  snapshot.health_status as snapshot_health_status,
  coalesce(snapshot.resolved_season, sync.resolved_season) as resolved_season,
  sync.window_start as sync_window_start,
  sync.window_end as sync_window_end,
  snapshot.window_start as snapshot_window_start,
  snapshot.window_end as snapshot_window_end,
  sync.fixtures as sync_fixtures,
  snapshot.fixtures as snapshot_fixtures,
  snapshot.odds as snapshot_odds,
  snapshot.team_statistics as snapshot_team_statistics,
  snapshot.recent_league_matches as snapshot_recent_league_matches,
  snapshot.missing_odds,
  snapshot.missing_team_statistics,
  snapshot.missing_recent_form,
  snapshot.missing_expected_goals,
  case
    when sync.health_status <> 'ok' then sync.health_status
    when snapshot.health_status <> 'ok' then snapshot.health_status
    else 'ok'
  end as health_status
from public.api_football_mvp_leagues leagues
left join public.api_football_latest_league_sync_health sync
  on sync.api_football_league_id = leagues.api_football_league_id
left join public.api_football_latest_league_snapshot_health snapshot
  on snapshot.api_football_league_id = leagues.api_football_league_id
order by leagues.api_football_league_id;

comment on view public.api_football_pipeline_health is
  'One-row-per-league operational health summary for the Lector API-Football pipeline.';

grant select on public.api_football_mvp_leagues
  to service_role;

grant select on public.api_football_latest_league_sync_health
  to service_role;

grant select on public.api_football_latest_league_snapshot_health
  to service_role;

grant select on public.api_football_pipeline_health
  to service_role;
