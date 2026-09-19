-- The player identity is part of the compact presentation contract. It lets
-- the client render a player to watch without parsing provider prose.
alter table public.match_reading_announcements
  add column if not exists player_name text;

-- Player form is intentionally refreshed before kick-off. Rebuild only future
-- player signals so the new recurrence-based rule applies to this weekend;
-- historical announcements and their Bilan evaluations remain untouched.
alter table public.match_reading_announcements
  disable trigger prevent_match_reading_announcements_update;

delete from public.match_reading_announcements
where kickoff_at > now()
  and reading_id in ('standout_decisive_player', 'key_player_unavailable');

alter table public.match_reading_announcements
  enable trigger prevent_match_reading_announcements_update;
