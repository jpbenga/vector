-- Names belong to the announced fixture, even before a final result exists.
-- Keep the existing columns in order for older application versions.
create or replace view public.match_reading_bilan as
select
  a.id as announcement_id, a.fixture_id, a.league_id, a.kickoff_at, a.announced_at,
  a.reading_id, a.reading_label, a.subject_side, a.subject_team_id, a.player_id,
  a.evidence, a.sample_size, a.outcome_rule, e.verdict, e.observed_value,
  e.explanation,
  coalesce(r.home_team_name, f.home_team_name) as home_team_name,
  coalesce(r.away_team_name, f.away_team_name) as away_team_name,
  r.home_goals, r.away_goals,
  r.status as match_status, r.captured_at as result_captured_at,
  a.announcement_kind, a.required_reading_ids, a.parent_announcement_key,
  f.competition_name, f.country_name
from public.match_reading_announcements a
left join public.match_feed_snapshot_fixtures f
  on f.snapshot_id = a.source_snapshot_id
  and f.fixture_id = 'api-fixture-' || a.fixture_id::text
left join lateral (
  select result.*
  from public.match_result_snapshots result
  where result.fixture_id = a.fixture_id
  order by result.captured_at desc, result.created_at desc, result.id desc
  limit 1
) r on true
left join lateral (
  select evaluation.*
  from public.match_reading_evaluations evaluation
  where evaluation.announcement_id = a.id
    and evaluation.result_snapshot_id = r.id
  order by evaluation.evaluated_at desc, evaluation.id desc
  limit 1
) e on true;

-- Keep period filtering on the source table rather than sorting the complete
-- history before filtering. Each lateral join returns at most one row.
create index if not exists match_reading_announcements_bilan_window_idx
  on public.match_reading_announcements (kickoff_at, league_id)
  where announcement_kind = 'reading';

-- One row per reading and competition, computed on the server. The client
-- combines counts, never averages percentages, and never downloads all
-- announcements to build the dashboard. Scenarios and nuances are excluded.
create or replace function public.match_reading_bilan_breakdown(
  p_since timestamptz,
  p_until timestamptz,
  p_subject_side text default null
)
returns table (
  reading_id text, reading_label text, league_id integer,
  competition_name text, country_name text,
  total bigint, confirmed bigint, contradicted bigint,
  not_evaluable bigint, context_only bigint, pending bigint,
  evaluable bigint, confirmation_rate numeric,
  home_evaluable bigint, home_confirmed bigint, home_confirmation_rate numeric,
  away_evaluable bigint, away_confirmed bigint, away_confirmation_rate numeric,
  outcome_rules text[]
)
language sql stable security invoker set search_path = public
as $$
  with grouped as (
    select b.reading_id, max(b.reading_label) as reading_label, b.league_id,
      max(b.competition_name) as competition_name,
      max(b.country_name) as country_name,
      count(*) as total,
      count(*) filter (where b.verdict = 'confirmed') as confirmed,
      count(*) filter (where b.verdict = 'contradicted') as contradicted,
      count(*) filter (where b.verdict = 'not_evaluable') as not_evaluable,
      count(*) filter (where b.verdict = 'context_only') as context_only,
      count(*) filter (where b.verdict is null) as pending,
      count(*) filter (where b.verdict in ('confirmed','contradicted')) as evaluable,
      count(*) filter (where b.subject_side = 'home'
        and b.verdict in ('confirmed','contradicted')) as home_evaluable,
      count(*) filter (where b.subject_side = 'home'
        and b.verdict = 'confirmed') as home_confirmed,
      count(*) filter (where b.subject_side = 'away'
        and b.verdict in ('confirmed','contradicted')) as away_evaluable,
      count(*) filter (where b.subject_side = 'away'
        and b.verdict = 'confirmed') as away_confirmed,
      coalesce(array_agg(distinct b.outcome_rule)
        filter (where b.outcome_rule is not null), '{}'::text[]) as outcome_rules
    from public.match_reading_bilan b
    where b.kickoff_at >= p_since and b.kickoff_at <= p_until
      and b.announcement_kind = 'reading'
      and (p_subject_side is null or b.subject_side = p_subject_side)
    group by b.reading_id, b.league_id
  )
  select g.reading_id, g.reading_label, g.league_id,
    g.competition_name, g.country_name,
    g.total, g.confirmed, g.contradicted, g.not_evaluable, g.context_only,
    g.pending, g.evaluable,
    round(100.0 * g.confirmed / nullif(g.evaluable, 0), 1),
    g.home_evaluable, g.home_confirmed,
    round(100.0 * g.home_confirmed / nullif(g.home_evaluable, 0), 1),
    g.away_evaluable, g.away_confirmed,
    round(100.0 * g.away_confirmed / nullif(g.away_evaluable, 0), 1),
    g.outcome_rules
  from grouped g
  order by g.reading_id, g.league_id;
$$;

revoke all on function public.match_reading_bilan_breakdown(
  timestamptz, timestamptz, text
) from public;
grant execute on function public.match_reading_bilan_breakdown(
  timestamptz, timestamptz, text
) to anon, authenticated, service_role;

notify pgrst, 'reload schema';
