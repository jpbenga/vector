-- The initial form announcements were derived from only three recent matches.
-- Replace future pre-match form readings with the five-match form and
-- trajectory model while retaining every announced or evaluated past reading.
alter table public.match_reading_announcements
  disable trigger prevent_match_reading_announcements_update;

delete from public.match_reading_announcements
where kickoff_at > now()
  and reading_id in (
    'positive_streak',
    'negative_streak',
    'improving_form',
    'declining_form',
    'form_advantage'
  );

alter table public.match_reading_announcements
  enable trigger prevent_match_reading_announcements_update;
