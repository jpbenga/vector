-- Replace only future player signals with the three-match, actual-minutes
-- model. Announcements for played fixtures and their Bilan outcomes remain
-- immutable historical evidence.
alter table public.match_reading_announcements
  disable trigger prevent_match_reading_announcements_update;

delete from public.match_reading_announcements
where kickoff_at > now()
  and reading_id in ('standout_decisive_player', 'key_player_unavailable');

alter table public.match_reading_announcements
  enable trigger prevent_match_reading_announcements_update;
