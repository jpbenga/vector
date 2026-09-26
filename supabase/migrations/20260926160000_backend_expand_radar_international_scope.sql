-- Backend - expand the active API-Football scope to the 76 competitions, including Radar internationals.
--
-- The Flutter runtime catalog and the cron generator use the same provider IDs.
-- This view keeps service-role health reporting complete for every scheduled
-- competition, including cups and women's competitions.

create or replace view public.api_football_mvp_leagues
with (security_invoker = true)
as
select *
from (
  values
    (2, 'UEFA Champions League'),
    (3, 'UEFA Europa League'),
    (848, 'UEFA Europa Conference League'),
    (39, 'Premier League'),
    (61, 'Ligue 1'),
    (140, 'La Liga'),
    (78, 'Bundesliga'),
    (135, 'Serie A'),
    (94, 'Liga Portugal'),
    (95, 'Liga Portugal 2'),
    (88, 'Eredivisie'),
    (144, 'Jupiler Pro League'),
    (179, 'Premiership'),
    (203, 'Süper Lig'),
    (197, 'Super League 1'),
    (119, 'Superliga'),
    (207, 'Super League Suisse'),
    (218, 'Bundesliga Autriche'),
    (40, 'Championship'),
    (62, 'Ligue 2'),
    (136, 'Serie B'),
    (79, '2. Bundesliga'),
    (141, 'La Liga 2'),
    (106, 'Ekstraklasa'),
    (210, 'HNL'),
    (209, 'Schweizer Cup'),
    (283, 'Liga I'),
    (253, 'Major League Soccer'),
    (71, 'Serie A Brésil'),
    (128, 'Liga Profesional Argentina'),
    (262, 'Liga MX'),
    (307, 'Saudi Pro League'),
    (98, 'J1 League'),
    (188, 'A-League'),
    (103, 'Eliteserien'),
    (113, 'Allsvenskan'),
    (164, 'Úrvalsdeild'),
    (169, 'Super League Chine'),
    (244, 'Veikkausliiga'),
    (292, 'K League 1'),
    (531, 'UEFA Super Cup'),
    (45, 'FA Cup'),
    (48, 'League Cup'),
    (528, 'Community Shield'),
    (66, 'Coupe de France'),
    (526, 'Trophée des Champions'),
    (81, 'DFB Pokal'),
    (529, 'Super Cup Allemagne'),
    (96, 'Taça de Portugal'),
    (550, 'Super Cup Portugal'),
    (143, 'Copa del Rey'),
    (556, 'Super Cup Espagne'),
    (137, 'Coppa Italia'),
    (547, 'Super Cup Italie'),
    (90, 'KNVB Beker'),
    (543, 'Super Cup Pays-Bas'),
    (147, 'Coupe de Belgique'),
    (519, 'Super Cup Belgique'),
    (181, 'FA Cup Écosse'),
    (185, 'League Cup Écosse'),
    (551, 'Super Cup Turquie'),
    (1, 'Coupe du Monde'),
    (32, 'Qualifications Coupe du Monde Europe'),
    (4, 'Euro'),
    (5, 'UEFA Nations League'),
    (38, 'Euro U21'),
    (10, 'Matchs amicaux internationaux'),
    (9, 'Copa America'),
    (6, 'Coupe d’Afrique des Nations'),
    (7, 'Coupe d’Asie'),
    (22, 'CONCACAF Gold Cup'),
    (536, 'CONCACAF Nations League'),
    (64, 'Première Ligue féminine'),
    (525, 'UEFA Champions League Women'),
    (1191, 'UEFA Europa Cup Women'),
    (8, 'Coupe du Monde féminine')
) as leagues(api_football_league_id, league_name);

comment on view public.api_football_mvp_leagues is
  'Expected API-Football scope for the 76 approved Lector competitions.';

grant select on public.api_football_mvp_leagues to service_role;
