-- A scenario is announced from its complete pre-match contract, then judged
-- against its own match outcome. It is intentionally independent from the
-- post-match verdicts of its supporting readings.
alter table public.match_reading_announcements
  add column announcement_kind text not null default 'reading'
    check (announcement_kind in ('reading', 'scenario')),
  add column required_reading_ids jsonb not null default '[]'::jsonb
    check (jsonb_typeof(required_reading_ids) = 'array');

create index match_reading_announcements_kind_idx
  on public.match_reading_announcements (announcement_kind, announced_at desc);

create or replace view public.match_reading_bilan as
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
  r.captured_at as result_captured_at,
  a.announcement_kind,
  a.required_reading_ids
from public.match_reading_announcements a
left join public.match_reading_evaluations e on e.announcement_id = a.id
left join public.match_result_snapshots r on r.id = e.result_snapshot_id
order by a.id, r.captured_at desc nulls last, r.created_at desc nulls last;
