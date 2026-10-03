-- Restore the public read contract of the compact mobile feed.
--
-- `match_feed_analysis_snapshots` is the deliberately reduced presentation
-- model consumed by Flutter. Provider cache and the raw historical snapshot
-- remain separate tables and are not granted here. This migration is
-- idempotent so it repairs policy drift caused by manual SQL changes.

alter table public.match_feed_analysis_snapshots enable row level security;
alter table public.match_feed_analysis_snapshots force row level security;

revoke insert, update, delete on public.match_feed_analysis_snapshots
  from anon, authenticated;
grant select on public.match_feed_analysis_snapshots to anon, authenticated;
grant insert on public.match_feed_analysis_snapshots to service_role;

drop policy if exists match_feed_analysis_snapshots_public_select
  on public.match_feed_analysis_snapshots;
create policy match_feed_analysis_snapshots_public_select
on public.match_feed_analysis_snapshots
for select
to anon, authenticated
using (true);
