-- Immutable pre-match announcements and post-match evidence for the global Bilan.
alter table public.daily_football_sync_runs
  add column result_response jsonb not null default '{}'::jsonb
    check (jsonb_typeof(result_response) = 'object');

create table public.match_result_snapshots (
  id uuid primary key default gen_random_uuid(),
  fixture_id integer not null,
  league_id integer not null,
  fixture_date date not null,
  kickoff_at timestamptz not null,
  status text not null check (status in ('FT', 'AET', 'PEN')),
  home_team_id integer not null,
  away_team_id integer not null,
  home_team_name text not null,
  away_team_name text not null,
  home_goals integer check (home_goals >= 0),
  away_goals integer check (away_goals >= 0),
  halftime_home_goals integer check (halftime_home_goals >= 0),
  halftime_away_goals integer check (halftime_away_goals >= 0),
  score jsonb not null default '{}'::jsonb,
  source_payload jsonb not null,
  content_hash text not null check (length(content_hash) = 64),
  captured_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (fixture_id, content_hash)
);

create index match_result_snapshots_date_idx
  on public.match_result_snapshots (fixture_date desc, league_id);
create index match_result_snapshots_fixture_idx
  on public.match_result_snapshots (fixture_id, captured_at desc);

create table public.match_reading_announcements (
  id uuid primary key default gen_random_uuid(),
  announcement_key text not null unique,
  fixture_id integer not null,
  source_snapshot_id uuid not null references public.match_feed_snapshots(id),
  league_id integer not null,
  kickoff_at timestamptz not null,
  announced_at timestamptz not null,
  engine_version text not null,
  reading_id text not null,
  reading_label text not null,
  subject_side text not null check (subject_side in ('match', 'home', 'away')),
  subject_team_id text,
  player_id integer,
  evidence jsonb not null default '[]'::jsonb
    check (jsonb_typeof(evidence) = 'array'),
  sample_size integer not null default 0 check (sample_size >= 0),
  outcome_rule text check (outcome_rule in ('over_25', 'under_25', 'btts')),
  rule_version integer not null default 1,
  created_at timestamptz not null default now(),
  check (announced_at < kickoff_at)
);

create index match_reading_announcements_fixture_idx
  on public.match_reading_announcements (fixture_id);
create index match_reading_announcements_reading_idx
  on public.match_reading_announcements (reading_id, announced_at desc);

create table public.match_reading_evaluations (
  id uuid primary key default gen_random_uuid(),
  announcement_id uuid not null references public.match_reading_announcements(id),
  result_snapshot_id uuid not null references public.match_result_snapshots(id),
  rule_version integer not null,
  verdict text not null check (verdict in
    ('confirmed', 'contradicted', 'not_evaluable', 'context_only')),
  observed_value jsonb not null default '{}'::jsonb,
  explanation text not null,
  evaluated_at timestamptz not null default now(),
  unique (announcement_id, result_snapshot_id, rule_version)
);

create index match_reading_evaluations_announcement_idx
  on public.match_reading_evaluations (announcement_id, evaluated_at desc);

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
    a.id, new.id, a.rule_version,
    case
      when a.outcome_rule is null then 'context_only'
      when new.status <> 'FT' or new.home_goals is null or new.away_goals is null then 'not_evaluable'
      when a.outcome_rule = 'over_25' and new.home_goals + new.away_goals >= 3 then 'confirmed'
      when a.outcome_rule = 'under_25' and new.home_goals + new.away_goals <= 2 then 'confirmed'
      when a.outcome_rule = 'btts' and new.home_goals > 0 and new.away_goals > 0 then 'confirmed'
      else 'contradicted'
    end,
    jsonb_build_object(
      'home_goals', new.home_goals,
      'away_goals', new.away_goals,
      'status', new.status,
      'score_basis', 'provider_fulltime'
    ),
    case
      when a.outcome_rule is null then 'Constat établi avant match ; le score seul ne le valide pas.'
      when new.status <> 'FT' then 'Le score des 90 minutes doit être vérifié séparément.'
      when new.home_goals is null or new.away_goals is null then 'Score final indisponible.'
      when a.outcome_rule = 'over_25' then 'Au moins 3 buts au score final fourni par API-Football.'
      when a.outcome_rule = 'under_25' then 'Au plus 2 buts au score final fourni par API-Football.'
      else 'Les deux équipes marquent au score final fourni par API-Football.'
    end
  from public.match_reading_announcements a
  where a.fixture_id = new.fixture_id
    and a.announced_at < new.kickoff_at;
  return new;
end;
$$;

create trigger evaluate_match_result_snapshot_after_insert
after insert on public.match_result_snapshots
for each row execute function public.evaluate_match_result_snapshot();

create view public.match_reading_bilan as
select distinct on (a.id)
  a.id as announcement_id,
  a.fixture_id,
  a.league_id,
  a.kickoff_at,
  a.announced_at,
  a.reading_id,
  a.reading_label,
  a.subject_side,
  a.subject_team_id,
  a.player_id,
  a.evidence,
  a.sample_size,
  a.outcome_rule,
  e.verdict,
  e.observed_value,
  e.explanation,
  r.home_team_name,
  r.away_team_name,
  r.home_goals,
  r.away_goals,
  r.status as match_status,
  r.captured_at as result_captured_at
from public.match_reading_announcements a
left join public.match_reading_evaluations e on e.announcement_id = a.id
left join public.match_result_snapshots r on r.id = e.result_snapshot_id
order by a.id, r.captured_at desc nulls last, r.created_at desc nulls last;

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
  pending bigint
)
language sql
stable
security invoker
set search_path = public
as $$
  select b.reading_id, max(b.reading_label) as reading_label,
    count(*) as total,
    count(*) filter (where b.verdict = 'confirmed') as confirmed,
    count(*) filter (where b.verdict = 'contradicted') as contradicted,
    count(*) filter (where b.verdict = 'not_evaluable') as not_evaluable,
    count(*) filter (where b.verdict = 'context_only') as context_only,
    count(*) filter (where b.verdict is null) as pending
  from public.match_reading_bilan b
  where b.kickoff_at >= p_since and b.kickoff_at <= p_until
  group by b.reading_id;
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
    new.id, latest_result.id, new.rule_version,
    case
      when new.outcome_rule is null then 'context_only'
      when latest_result.status <> 'FT' or latest_result.home_goals is null
        or latest_result.away_goals is null then 'not_evaluable'
      when new.outcome_rule = 'over_25'
        and latest_result.home_goals + latest_result.away_goals >= 3 then 'confirmed'
      when new.outcome_rule = 'under_25'
        and latest_result.home_goals + latest_result.away_goals <= 2 then 'confirmed'
      when new.outcome_rule = 'btts'
        and latest_result.home_goals > 0 and latest_result.away_goals > 0 then 'confirmed'
      else 'contradicted'
    end,
    jsonb_build_object('home_goals', latest_result.home_goals,
      'away_goals', latest_result.away_goals, 'status', latest_result.status,
      'score_basis', 'provider_fulltime'),
    'Évaluation de la lecture annoncée avant le coup d’envoi.'
  );
  return new;
end;
$$;

create trigger evaluate_late_reading_announcement_after_insert
after insert on public.match_reading_announcements
for each row execute function public.evaluate_late_reading_announcement();

create trigger prevent_match_result_snapshots_update
before update or delete on public.match_result_snapshots
for each row execute function public.prevent_snapshot_mutation();
create trigger prevent_match_reading_announcements_update
before update or delete on public.match_reading_announcements
for each row execute function public.prevent_snapshot_mutation();
create trigger prevent_match_reading_evaluations_update
before update or delete on public.match_reading_evaluations
for each row execute function public.prevent_snapshot_mutation();

alter table public.match_result_snapshots enable row level security;
alter table public.match_reading_announcements enable row level security;
alter table public.match_reading_evaluations enable row level security;
alter table public.match_result_snapshots force row level security;
alter table public.match_reading_announcements force row level security;
alter table public.match_reading_evaluations force row level security;

revoke insert, update, delete on public.match_result_snapshots,
  public.match_reading_announcements, public.match_reading_evaluations
  from anon, authenticated;
grant select on public.match_result_snapshots,
  public.match_reading_announcements, public.match_reading_evaluations
  to anon, authenticated;
grant insert on public.match_result_snapshots,
  public.match_reading_announcements, public.match_reading_evaluations
  to service_role;
grant select on public.match_reading_bilan to anon, authenticated;
grant execute on function public.match_reading_bilan_summary(timestamptz, timestamptz)
  to anon, authenticated;

create policy match_result_snapshots_public_select
on public.match_result_snapshots for select to anon, authenticated using (true);
create policy match_reading_announcements_public_select
on public.match_reading_announcements for select to anon, authenticated using (true);
create policy match_reading_evaluations_public_select
on public.match_reading_evaluations for select to anon, authenticated using (true);
