-- Backend - Guard API-Football empty snapshots.
--
-- Scope:
-- - surface published but empty league snapshots as unhealthy;
-- - keep the same service-role observability contract.

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
    when latest_snapshot.fixtures = 0
      and latest_snapshot.odds = 0
      and latest_snapshot.standings = 0
      and latest_snapshot.team_statistics = 0
      and latest_snapshot.recent_league_matches = 0
      and latest_snapshot.expected_goals = 0
      then 'empty_snapshot'
    else 'ok'
  end as health_status
from public.api_football_mvp_leagues expected
left join latest_snapshot
  on latest_snapshot.league_id = expected.api_football_league_id
order by expected.api_football_league_id;

comment on view public.api_football_latest_league_snapshot_health is
  'Latest league-scoped snapshot health by MVP league, including coverage, missing data counters and empty snapshot detection.';

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

grant select on public.api_football_latest_league_snapshot_health
  to service_role;

grant select on public.api_football_pipeline_health
  to service_role;
