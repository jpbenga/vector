-- Outcome contracts shared by the server feed and the immutable Bilan.
alter table public.match_reading_announcements
  drop constraint if exists match_reading_announcements_outcome_rule_check;
alter table public.match_reading_announcements
  add constraint match_reading_announcements_outcome_rule_check
  check (outcome_rule is null or outcome_rule in (
    'over_25', 'under_25', 'btts',
    'team_win', 'team_not_lose', 'team_loss',
    'team_scores', 'team_no_score', 'team_clean_sheet', 'team_concedes',
    'first_half_scores', 'first_half_concedes',
    'second_half_scores', 'second_half_concedes',
    'player_decisive'
  ));

alter table public.match_reading_announcements
  drop constraint if exists match_reading_announcements_announcement_kind_check;
alter table public.match_reading_announcements
  add constraint match_reading_announcements_announcement_kind_check
  check (announcement_kind in ('reading', 'scenario', 'nuance')),
  add column parent_announcement_key text;

create index match_reading_announcements_parent_idx
  on public.match_reading_announcements (parent_announcement_key)
  where parent_announcement_key is not null;

alter table public.match_reading_evaluations
  drop constraint if exists match_reading_evaluations_verdict_check;
alter table public.match_reading_evaluations
  add constraint match_reading_evaluations_verdict_check
  check (verdict in (
    'confirmed', 'contradicted', 'not_evaluable', 'context_only',
    'caution_confirmed', 'caution_not_confirmed'
  ));

create or replace function public.match_reading_verdict(
  p_outcome_rule text,
  p_subject_side text,
  p_status text,
  p_home_goals integer,
  p_away_goals integer,
  p_halftime_home_goals integer default null,
  p_halftime_away_goals integer default null,
  p_player_id integer default null,
  p_source_payload jsonb default '{}'::jsonb
)
returns text
language plpgsql
immutable
set search_path = public
as $$
declare
  second_half_home integer;
  second_half_away integer;
  player_is_decisive boolean;
begin
  if p_outcome_rule is null then return 'context_only'; end if;
  if p_status <> 'FT' or p_home_goals is null or p_away_goals is null then
    return 'not_evaluable';
  end if;
  if p_outcome_rule = 'over_25' then return case when p_home_goals + p_away_goals >= 3 then 'confirmed' else 'contradicted' end; end if;
  if p_outcome_rule = 'under_25' then return case when p_home_goals + p_away_goals <= 2 then 'confirmed' else 'contradicted' end; end if;
  if p_outcome_rule = 'btts' then return case when p_home_goals > 0 and p_away_goals > 0 then 'confirmed' else 'contradicted' end; end if;
  if p_outcome_rule = 'team_win' then return case when (p_subject_side = 'home' and p_home_goals > p_away_goals) or (p_subject_side = 'away' and p_away_goals > p_home_goals) then 'confirmed' else 'contradicted' end; end if;
  if p_outcome_rule = 'team_not_lose' then return case when (p_subject_side = 'home' and p_home_goals >= p_away_goals) or (p_subject_side = 'away' and p_away_goals >= p_home_goals) then 'confirmed' else 'contradicted' end; end if;
  if p_outcome_rule = 'team_loss' then return case when (p_subject_side = 'home' and p_home_goals < p_away_goals) or (p_subject_side = 'away' and p_away_goals < p_home_goals) then 'confirmed' else 'contradicted' end; end if;
  if p_outcome_rule = 'team_scores' then return case when (p_subject_side = 'home' and p_home_goals > 0) or (p_subject_side = 'away' and p_away_goals > 0) then 'confirmed' else 'contradicted' end; end if;
  if p_outcome_rule = 'team_no_score' then return case when (p_subject_side = 'home' and p_home_goals = 0) or (p_subject_side = 'away' and p_away_goals = 0) then 'confirmed' else 'contradicted' end; end if;
  if p_outcome_rule = 'team_clean_sheet' then return case when (p_subject_side = 'home' and p_away_goals = 0) or (p_subject_side = 'away' and p_home_goals = 0) then 'confirmed' else 'contradicted' end; end if;
  if p_outcome_rule = 'team_concedes' then return case when (p_subject_side = 'home' and p_away_goals > 0) or (p_subject_side = 'away' and p_home_goals > 0) then 'confirmed' else 'contradicted' end; end if;
  if p_halftime_home_goals is null or p_halftime_away_goals is null then return 'not_evaluable'; end if;
  if p_outcome_rule = 'first_half_scores' then return case when (p_subject_side = 'home' and p_halftime_home_goals > 0) or (p_subject_side = 'away' and p_halftime_away_goals > 0) then 'confirmed' else 'contradicted' end; end if;
  if p_outcome_rule = 'first_half_concedes' then return case when (p_subject_side = 'home' and p_halftime_away_goals > 0) or (p_subject_side = 'away' and p_halftime_home_goals > 0) then 'confirmed' else 'contradicted' end; end if;
  second_half_home := p_home_goals - p_halftime_home_goals;
  second_half_away := p_away_goals - p_halftime_away_goals;
  if p_outcome_rule = 'second_half_scores' then return case when (p_subject_side = 'home' and second_half_home > 0) or (p_subject_side = 'away' and second_half_away > 0) then 'confirmed' else 'contradicted' end; end if;
  if p_outcome_rule = 'second_half_concedes' then return case when (p_subject_side = 'home' and second_half_away > 0) or (p_subject_side = 'away' and second_half_home > 0) then 'confirmed' else 'contradicted' end; end if;
  -- Player results require goals/assists from the final provider payload.
  if p_outcome_rule = 'player_decisive' then
    player_is_decisive := coalesce(p_source_payload #>> array['computed','player_decisive', coalesce(p_player_id::text, '')], 'false')::boolean;
    return case when player_is_decisive then 'confirmed' else 'contradicted' end;
  end if;
  return 'not_evaluable';
end;
$$;

create or replace function public.evaluate_match_result_snapshot()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  insert into public.match_reading_evaluations (
    announcement_id, result_snapshot_id, rule_version, verdict,
    observed_value, explanation
  )
  select a.id, new.id, a.rule_version,
    case when a.announcement_kind = 'nuance' then
      case public.match_reading_verdict(p.outcome_rule, p.subject_side, new.status, new.home_goals, new.away_goals, new.halftime_home_goals, new.halftime_away_goals, p.player_id, new.source_payload)
        when 'contradicted' then 'caution_confirmed'
        when 'confirmed' then 'caution_not_confirmed'
        else 'not_evaluable'
      end
    else public.match_reading_verdict(a.outcome_rule, a.subject_side, new.status, new.home_goals, new.away_goals, new.halftime_home_goals, new.halftime_away_goals, a.player_id, new.source_payload) end,
    jsonb_build_object('home_goals', new.home_goals, 'away_goals', new.away_goals, 'halftime_home_goals', new.halftime_home_goals, 'halftime_away_goals', new.halftime_away_goals, 'status', new.status, 'score_basis', 'provider_fulltime'),
    case when a.announcement_kind = 'nuance' then 'La nuance est pertinente si la lecture parent est invalidée dans le sens signalé.' else 'Évaluation de la lecture annoncée avant le coup d’envoi.' end
  from public.match_reading_announcements a
  left join public.match_reading_announcements p on p.announcement_key = a.parent_announcement_key
  where a.fixture_id = new.fixture_id and a.announced_at < new.kickoff_at;
  return new;
end;
$$;

create or replace function public.evaluate_late_reading_announcement()
returns trigger language plpgsql security definer set search_path = public
as $$
declare latest_result public.match_result_snapshots%rowtype; parent_row public.match_reading_announcements%rowtype; verdict_value text;
begin
  select * into latest_result from public.match_result_snapshots where fixture_id = new.fixture_id order by captured_at desc, created_at desc limit 1;
  if latest_result.id is null then return new; end if;
  select * into parent_row from public.match_reading_announcements where announcement_key = new.parent_announcement_key;
  verdict_value := case when new.announcement_kind = 'nuance' then
    case public.match_reading_verdict(parent_row.outcome_rule, parent_row.subject_side, latest_result.status, latest_result.home_goals, latest_result.away_goals, latest_result.halftime_home_goals, latest_result.halftime_away_goals, parent_row.player_id, latest_result.source_payload)
      when 'contradicted' then 'caution_confirmed' when 'confirmed' then 'caution_not_confirmed' else 'not_evaluable' end
    else public.match_reading_verdict(new.outcome_rule, new.subject_side, latest_result.status, latest_result.home_goals, latest_result.away_goals, latest_result.halftime_home_goals, latest_result.halftime_away_goals, new.player_id, latest_result.source_payload) end;
  insert into public.match_reading_evaluations (announcement_id, result_snapshot_id, rule_version, verdict, observed_value, explanation)
  values (new.id, latest_result.id, new.rule_version, verdict_value, jsonb_build_object('home_goals', latest_result.home_goals, 'away_goals', latest_result.away_goals, 'status', latest_result.status), 'Évaluation de la lecture annoncée avant le coup d’envoi.');
  return new;
end;
$$;

create or replace view public.match_reading_bilan as
select distinct on (a.id)
  a.id as announcement_id, a.fixture_id, a.league_id, a.kickoff_at, a.announced_at,
  a.reading_id, a.reading_label, a.subject_side, a.subject_team_id, a.player_id,
  a.evidence, a.sample_size, a.outcome_rule, e.verdict, e.observed_value,
  e.explanation, r.home_team_name, r.away_team_name, r.home_goals, r.away_goals,
  r.status as match_status, r.captured_at as result_captured_at,
  a.announcement_kind, a.required_reading_ids, a.parent_announcement_key
from public.match_reading_announcements a
left join public.match_reading_evaluations e on e.announcement_id = a.id
left join public.match_result_snapshots r on r.id = e.result_snapshot_id
order by a.id, r.captured_at desc nulls last, r.created_at desc nulls last;

drop function if exists public.match_reading_bilan_summary(timestamptz, timestamptz);
create function public.match_reading_bilan_summary(
  p_since timestamptz,
  p_until timestamptz
)
returns table (
  reading_id text,
  reading_label text,
  total bigint,
  confirmed bigint,
  contradicted bigint,
  not_evaluable bigint,
  context_only bigint,
  caution_confirmed bigint,
  caution_not_confirmed bigint,
  pending bigint
)
language sql stable security invoker set search_path = public
as $$
  select b.reading_id, max(b.reading_label) as reading_label,
    count(*) as total,
    count(*) filter (where b.verdict = 'confirmed') as confirmed,
    count(*) filter (where b.verdict = 'contradicted') as contradicted,
    count(*) filter (where b.verdict = 'not_evaluable') as not_evaluable,
    count(*) filter (where b.verdict = 'context_only') as context_only,
    count(*) filter (where b.verdict = 'caution_confirmed') as caution_confirmed,
    count(*) filter (where b.verdict = 'caution_not_confirmed') as caution_not_confirmed,
    count(*) filter (where b.verdict is null) as pending
  from public.match_reading_bilan b
  where b.kickoff_at >= p_since and b.kickoff_at <= p_until
  group by b.reading_id;
$$;
grant execute on function public.match_reading_bilan_summary(timestamptz, timestamptz)
  to anon, authenticated;
