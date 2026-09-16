# Bilan des lectures : mise en service

## Chaîne de données

1. Le cron `daily-football-sync` collecte le feed à venir et appelle
   `sync-match-results` pour les sept jours précédents. Ce dernier interroge
   `/fixtures` par ligue et par date, sans redemander les cotes. Seuls les
   statuts `FT`, `AET` et `PEN` sont archivés par lots de 20 matchs. Un hash du
   résultat évite de créer une nouvelle version quand il est inchangé.
2. `publish_match_reading_announcements.dart` sélectionne, dans l'index des
   snapshots, la dernière version antérieure au coup d'envoi pour chaque
   match. Il exécute le même `FootballAnalyzer` que l'application et fige les
   lectures détectées, leurs preuves et le hash du code moteur. Son insertion
   est idempotente par match, lecture, équipe et joueur.
3. Les triggers SQL évaluent chaque annonce quand un résultat arrive. Les
   corrections du fournisseur créent une nouvelle version du résultat et de
   l'évaluation. La vue `match_reading_bilan` expose la dernière version.
4. Le quatrième onglet `Bilan` lit les agrégats via
   `match_reading_bilan_summary` et charge les matchs d'une lecture par pages
   de 20. Il n'applique pas les préférences personnelles. La fiche match
   affiche le score et les verdicts disponibles.

## Périmètre initial des verdicts

Les lectures `frequent_over_25`, `frequent_under_25` et `frequent_btts` ont un
critère de résultat explicite et versionné. Seuls les matchs `FT` avec score
final complet produisent `confirmed` ou `contradicted`. `AET` et `PEN` restent
`not_evaluable` tant qu'une définition fiable du score à 90 minutes n'est pas
ajoutée. Toutes les autres lectures apparaissent comme constats
d'avant-match (`context_only`) : une défaite isolée ne contredit pas une forme
historique. Le taux global utilise seulement `confirmed + contradicted` comme
dénominateur.

Les événements minutés, tirs, corners, cartons et joueurs demanderont des
champs de résultat et des règles supplémentaires avant de recevoir un verdict.

## Déploiement, dans cet ordre

1. Appliquer `20260916210000_match_reading_bilan.sql` après les migrations
   existantes. Vérifier les droits `select` publics et les triggers.
2. Déployer `sync-match-results` avec `--no-verify-jwt` (l'authentification
   interne utilise `API_FOOTBALL_SYNC_SECRET`) et les secrets déjà utilisés par
   `api-football-sync` : `API_FOOTBALL_KEY`, `API_FOOTBALL_SYNC_SECRET`,
   `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`.
3. Déployer `daily-football-sync`. Mettre à jour les tâches Supabase Cron
   générées par `tool/generate_supabase_cron_sql.dart` pour que la fenêtre de
   résultats soit de sept jours.
4. Ajouter dans GitHub Actions les secrets `SUPABASE_URL` et
   `SUPABASE_SERVICE_ROLE_KEY`, puis définir la variable
   `READING_BILAN_ENABLED=true`. Le workflow de publication tourne à 04:15 UTC
   avec `TZ=Europe/Paris`, après les cron de snapshots par ligue. La clé de
   service ne doit jamais être placée dans Flutter ou dans un build web.
5. Déployer le front. Vérifier le Bilan avec un match pilote, puis élargir.

Le workflow accepte un lancement manuel avec une date pour reprendre une
journée antérieure. Il ne publie que les lectures dont un snapshot existait
réellement avant le coup d'envoi. Les résultats d'anciens matchs peuvent être
archivés par fenêtres de sept jours, mais ils ne créent pas rétroactivement
une annonce qui n'a jamais existé.
