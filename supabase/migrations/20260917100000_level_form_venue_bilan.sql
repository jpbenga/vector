-- Verdict rules for the directional readings in "Niveau, forme et lieu".
alter table public.match_reading_announcements
  drop constraint if exists match_reading_announcements_outcome_rule_check;

alter table public.match_reading_announcements
  add constraint match_reading_announcements_outcome_rule_check
  check (outcome_rule in (
    'over_25', 'under_25', 'btts',
    'team_win', 'team_not_lose', 'team_loss'
  ));

create or replace function public.match_reading_verdict(
  p_outcome_rule text,
  p_subject_side text,
  p_status text,
  p_home_goals integer,
  p_away_goals integer
)
returns text
language sql
immutable
set search_path = public
as $$
  select case
    when p_outcome_rule is null then 'context_only'
    when p_status <> 'FT' or p_home_goals is null or p_away_goals is null
      then 'not_evaluable'
    when p_outcome_rule = 'over_25' and p_home_goals + p_away_goals >= 3
      then 'confirmed'
    when p_outcome_rule = 'under_25' and p_home_goals + p_away_goals <= 2
      then 'confirmed'
    when p_outcome_rule = 'btts' and p_home_goals > 0 and p_away_goals > 0
      then 'confirmed'
    when p_outcome_rule = 'team_win' and (
      (p_subject_side = 'home' and p_home_goals > p_away_goals) or
      (p_subject_side = 'away' and p_away_goals > p_home_goals)
    ) then 'confirmed'
    when p_outcome_rule = 'team_not_lose' and (
      (p_subject_side = 'home' and p_home_goals >= p_away_goals) or
      (p_subject_side = 'away' and p_away_goals >= p_home_goals)
    ) then 'confirmed'
    when p_outcome_rule = 'team_loss' and (
      (p_subject_side = 'home' and p_home_goals < p_away_goals) or
      (p_subject_side = 'away' and p_away_goals < p_home_goals)
    ) then 'confirmed'
    else 'contradicted'
  end;
$$;

create or replace function public.evaluate_match_result_snapshot()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.match_reading_evaluations (
    announcement_id, result_snapshot_id, rule_version,
    verdict, observed_value, explanation
  )
  select
    a.id,
    new.id,
    a.rule_version,
    public.match_reading_verdict(
      a.outcome_rule, a.subject_side, new.status, new.home_goals, new.away_goals
    ),
    jsonb_build_object(
      'home_goals', new.home_goals,
      'away_goals', new.away_goals,
      'status', new.status,
      'score_basis', 'provider_fulltime'
    ),
    'Évaluation de la lecture annoncée avant le coup d’envoi.'
  from public.match_reading_announcements a
  where a.fixture_id = new.fixture_id
    and a.announced_at < new.kickoff_at;
  return new;
end;
$$;

create or replace function public.evaluate_late_reading_announcement()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  latest_result public.match_result_snapshots%rowtype;
begin
  select * into latest_result
  from public.match_result_snapshots
  where fixture_id = new.fixture_id
  order by captured_at desc, created_at desc
  limit 1;
  if latest_result.id is null then return new; end if;

  insert into public.match_reading_evaluations (
    announcement_id, result_snapshot_id, rule_version,
    verdict, observed_value, explanation
  ) values (
    new.id,
    latest_result.id,
    new.rule_version,
    public.match_reading_verdict(
      new.outcome_rule,
      new.subject_side,
      latest_result.status,
      latest_result.home_goals,
      latest_result.away_goals
    ),
    jsonb_build_object(
      'home_goals', latest_result.home_goals,
      'away_goals', latest_result.away_goals,
      'status', latest_result.status,
      'score_basis', 'provider_fulltime'
    ),
    'Évaluation de la lecture annoncée avant le coup d’envoi.'
  );
  return new;
end;
$$;
