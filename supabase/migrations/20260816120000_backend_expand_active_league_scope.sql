-- Backend - Expand active league runtime scope.
--
-- Scope:
-- - add active summer and Asian leagues requested for the MVP feed;
-- - keep the same read-only observability contract;
-- - cron jobs are regenerated separately by tool/generate_supabase_cron_sql.dart.

create or replace view public.api_football_mvp_leagues
with (security_invoker = true)
as
select *
from (
  values
    (39, 'Premier League'),
    (61, 'Ligue 1'),
    (140, 'La Liga'),
    (78, 'Bundesliga'),
    (135, 'Serie A'),
    (94, 'Liga Portugal'),
    (95, 'Liga Portugal 2'),
    (88, 'Eredivisie'),
    (144, 'Jupiler Pro'),
    (179, 'Premiership'),
    (203, 'Super Lig'),
    (197, 'Super League GRE'),
    (119, 'Superliga DAN'),
    (207, 'Super League SUI'),
    (218, 'Bundesliga AUT'),
    (40, 'Championship'),
    (62, 'Ligue 2'),
    (136, 'Serie B'),
    (79, '2. Bundesliga'),
    (141, 'La Liga 2'),
    (106, 'Ekstraklasa'),
    (210, 'HNL'),
    (209, 'Czech Liga'),
    (283, 'Liga I'),
    (253, 'MLS'),
    (71, 'Brasileiro A'),
    (128, 'Liga Prof'),
    (262, 'Liga MX'),
    (307, 'Saudi Pro'),
    (98, 'J1 League'),
    (188, 'A-League'),
    (103, 'Eliteserien'),
    (113, 'Allsvenskan'),
    (164, 'Besta deild karla'),
    (169, 'Chinese Super League'),
    (244, 'Veikkausliiga'),
    (292, 'K League 1')
) as leagues(api_football_league_id, league_name);

comment on view public.api_football_mvp_leagues is
  'Expected API-Football league scope for the Lector MVP data pipeline.';

grant select on public.api_football_mvp_leagues
  to service_role;
