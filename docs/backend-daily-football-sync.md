# Backend Daily Football Sync MVP

Date : 2026-08-13

## Objectif

Automatiser une mise a jour journaliere des donnees football sans proposer de
live.

Le MVP doit :

- mettre a jour les resultats recents ;
- preparer les rencontres futures sur une fenetre glissante de 4 jours ;
- mettre a jour les cotes pre-match disponibles ;
- construire un read model compatible avec le front ;
- rester poli avec API-Football ;
- surveiller la taille de la base Supabase.

## Strategie temporelle

Cron quotidien :

```text
00:00 UTC
```

Ce choix correspond a environ 02:00 en France en aout et laisse le temps a une
grande partie des matchs tardifs de se terminer. Si les resultats d'Amerique
latine arrivent trop tard dans les donnees API, on pourra decaler a 04:00 UTC.

Fenetre technique par defaut :

```text
Resultats : J-2 -> J-1
Feed front : J -> J+3
Collecte API : J-2 -> J+3
```

La collecte couvre donc les resultats recents et les 4 jours a venir, mais le
snapshot expose au front reste centre sur les matchs a venir.

## Saison courante

La saison n'est pas configuree comme une variable globale Vercel.

Chaque ligue peut changer de saison a une date differente. Le backend resout
donc la saison active ligue par ligue via :

```text
/leagues?id=<league_id>
```

La saison retenue n'est pas choisie en fonction de l'annee courante ni
uniquement du champ `current`. Le backend inspecte les dates
`coverage.fixtures.start` / `coverage.fixtures.end` renvoyees par API-Football
et choisit la saison dont la couverture chevauche la fenetre demandee.

Cette regle est obligatoire pour les championnats decales : par exemple une
rencontre jouee en 2026 peut appartenir a une saison API-Football `2027`.

Puis le backend utilise cette saison verifiee pour les endpoints dependants :

```text
/standings
/fixtures
/odds
/teams/statistics
```

La colonne historique `season` dans les tables de logs/snapshots reste une
saison de reference technique pour compatibilite. La vraie information
auditable est conservee dans les payloads/provenances via `season_by_league`.

## Architecture

```text
Supabase Cron
  -> collecte api-football-sync par ligue
  -> api_football_cached_responses
  -> build-match-feed-snapshot par ligue
  -> match_feed_snapshots scopes league:<id>
  -> Flutter read model fusionne les snapshots par ligue
```

Vercel heberge l'application web, mais ne porte pas le cron data.
La collecte peut depasser le timeout d'une fonction Vercel, surtout avec le
throttle volontaire entre appels API-Football.

La cle API-Football reste uniquement dans les secrets Supabase.

Important : le scope complet MVP ne doit pas etre execute dans un seul appel
`daily-football-sync`.

Le test reel du 2026-08-13 a montre que 30 ligues dans une seule Edge Function
peuvent provoquer :

```text
WORKER_RESOURCE_LIMIT
```

La strategie retenue est donc :

1. une collecte par ligue via `api-football-sync` ;
2. cache brut idempotent dans `api_football_cached_responses` ;
3. un snapshot par ligue via `build-match-feed-snapshot`.

Le front reconstruit le feed global en fusionnant les derniers snapshots de
chaque ligue pour la date demandee. Cette strategie evite de depasser les
limites de calcul Supabase Edge avec un snapshot global trop gros.

## Fichiers

```text
supabase/functions/daily-football-sync/index.ts
supabase/functions/api-football-sync/index.ts
supabase/functions/build-match-feed-snapshot/index.ts
supabase/migrations/20260813080000_backend_daily_football_sync.sql
```

## Consommation API-Football

Le plan Pro permet 300 requetes/minute, mais le MVP applique une limite interne
plus prudente.

Valeur par defaut :

```text
API_FOOTBALL_REQUEST_DELAY_MS=750
```

Soit environ 80 requetes/minute maximum en pratique, avant meme de compter le
temps reseau et Supabase.

La collecte reste sequentielle :

- pas de fan-out agressif ;
- pas d'appel API-Football depuis le front ;
- retries/backoff avances a ajouter plus tard si necessaire ;
- logs par run dans `api_football_sync_runs` et `daily_football_sync_runs`.

## Monitoring stockage

Supabase Free doit rester sous la limite de base de donnees.

La migration ajoute :

```text
daily_football_sync_runs.database_size_bytes
daily_football_sync_runs.database_size_limit_bytes
daily_football_sync_runs.database_size_ratio
daily_football_sync_runs.storage_warning_level
```

Seuils :

```text
< 80%  -> ok
>= 80% -> warning_80
>= 90% -> warning_90
>= 95% -> critical_95
```

Le MVP stocke d'abord cette alerte dans Supabase. Une notification email/Slack
pourra etre ajoutee plus tard.

## Variables Supabase

A configurer dans Supabase Edge Functions :

```text
API_FOOTBALL_KEY
API_FOOTBALL_SYNC_SECRET
API_FOOTBALL_REQUEST_DELAY_MS=750
SUPABASE_SERVICE_ROLE_KEY
SUPABASE_URL
```

Detail :

- `API_FOOTBALL_KEY` : ta cle API-Football Pro. Elle vient du dashboard
  API-Sports / API-Football. Elle ne doit exister que cote Supabase.
- `API_FOOTBALL_SYNC_SECRET` : secret que tu inventes toi-meme, long et
  aleatoire. Il sert a autoriser l'execution des fonctions de synchronisation.
  La meme valeur doit etre mise dans Supabase et Vercel.
- `API_FOOTBALL_REQUEST_DELAY_MS` : delai volontaire entre deux appels
  API-Football. `750` garde environ 80 requetes/minute maximum.
- `SUPABASE_SERVICE_ROLE_KEY` : cle Supabase `service_role`. Elle se trouve
  dans Settings -> API Keys -> Legacy anon, service_role API keys. Elle permet
  aux fonctions serveur d'ecrire dans les tables protegees par RLS.
- `SUPABASE_URL` : URL du projet Supabase, par exemple
  `https://ednvvxxvlawaagjyshkj.supabase.co`.

Important : `SUPABASE_SERVICE_ROLE_KEY` et `API_FOOTBALL_KEY` ne doivent jamais
etre exposees cote Flutter, Vercel client ou Git.

## Variables Vercel

A configurer dans Vercel :

```text
SUPABASE_URL
API_FOOTBALL_TIMEZONE=Europe/Paris
API_FOOTBALL_LEAGUE_IDS=39,61,140,78,135,94,88,144,179,203,197,119,207,218,40,62,136,79,141,106,210,209,283,253,71,128,262,307,98,188
API_FOOTBALL_BOOKMAKER_ID=16
API_FOOTBALL_RESULTS_DAYS_BACK=2
API_FOOTBALL_FUTURE_DAYS=3
API_FOOTBALL_REQUEST_DELAY_MS=750
SUPABASE_DATABASE_SIZE_LIMIT_BYTES=524288000
```

Ces variables Vercel ne sont plus utilisees pour declencher le cron data. Elles
restent utiles si on ajoute plus tard une interface admin web ou un endpoint de
diagnostic court. Le cron officiel du MVP est cote Supabase.

Variables deja necessaires au front Vercel :

```text
SUPABASE_ANON_KEY
APP_PUBLIC_URL=https://lector-sports.vercel.app/
MATCH_FEED_SOURCE=auto
```

## Deploiement Supabase

Appliquer la migration :

```sh
npx supabase db push
```

Deployer les fonctions :

```sh
npx supabase functions deploy api-football-sync --no-verify-jwt
npx supabase functions deploy build-match-feed-snapshot --no-verify-jwt
npx supabase functions deploy daily-football-sync --no-verify-jwt
```

## Cron Supabase

Planifier l'appel quotidien depuis Supabase, pas depuis Vercel.

Pour un test court, `daily-football-sync` reste utile avec 1 ou 2 ligues.
Pour le scope complet MVP, utiliser des jobs Supabase Cron separes :

```text
00:00 UTC -> api-football-sync ligue 1
00:03 UTC -> build-match-feed-snapshot ligue 1
00:04 UTC -> api-football-sync ligue 2
00:07 UTC -> build-match-feed-snapshot ligue 2
...
01:56 UTC -> api-football-sync ligue 30
01:59 UTC -> build-match-feed-snapshot ligue 30
```

`00:00 UTC` correspond a environ `02:00` en France en aout.

L'espacement de 4 minutes entre chaque ligue evite le fan-out agressif et garde
la consommation API tres largement sous la limite Pro de 300 requetes/minute.

Chaque job appelle une Edge Function en `POST` avec les headers :

```text
Authorization: Bearer <API_FOOTBALL_SYNC_SECRET>
Content-Type: application/json
```

Body commun aux collectes :

```json
{
  "window_start": "YYYY-MM-DD",
  "window_end": "YYYY-MM-DD",
  "bookmaker_id": 16,
  "api_request_delay_ms": 750,
  "include_team_statistics": true,
  "include_recent_form": true,
  "include_expected_goals": true
}
```

Le backend resout la saison active par ligue au moment de chaque lot en
comparant la fenetre demandee avec la couverture de fixtures de chaque saison.
Ne pas ajouter `season` dans les crons quotidiens : ce champ est uniquement un
override manuel de diagnostic. Le fonctionnement normal doit laisser
`api-football-sync` resoudre `leagueSeasons` ligue par ligue.

Body commun aux snapshots de ligue :

```json
{
  "league_ids": [61],
  "bookmaker_id": 16,
  "window_start": "YYYY-MM-DD",
  "window_end": "YYYY-MM-DD",
  "force_rebuild": false,
  "recent_form_days_back": 180,
  "recent_form_matches": 5
}
```

Le builder complete `season_by_league` depuis les reponses `/leagues` en cache
avec la meme logique de couverture de fenetre que la collecte.
Chaque snapshot porte un `scope_key` du type `league:61`. L'ancien scope global
reste supporte pour compatibilite, mais il ne doit plus etre utilise pour le
cron complet MVP.

`force_rebuild: true` est reserve aux corrections de builder ou aux reprises
manuelles. Il cree un nouveau snapshot immuable avec un nouvel `as_of` au lieu
de reutiliser le snapshot existant.

## Invocation manuelle

Depuis la racine du projet :

```sh
set -a
source .env
set +a

curl -X POST \
  "$SUPABASE_URL/functions/v1/daily-football-sync" \
  -H "Authorization: Bearer $API_FOOTBALL_SYNC_SECRET" \
  -H "Content-Type: application/json" \
  -d '{
    "league_ids": [61, 62],
    "bookmaker_id": 16,
    "results_days_back": 2,
    "future_days": 3,
    "api_request_delay_ms": 750
  }'
```

Validation attendue :

- `ok: true` ou `status: succeeded` ;
- une ligne dans `daily_football_sync_runs` ;
- une ligne liee dans `api_football_sync_runs` ;
- des lignes dans `api_football_cached_responses` ;
- un nouveau snapshot dans `match_feed_snapshots` ;
- `database_size_ratio` renseigne.

## Invocation manuelle du scope complet par lots

Le scope complet MVP ne doit pas etre teste a la main ligue par ligue.
Generer plutot le SQL Cron complet :

```sh
dart run tool/generate_supabase_cron_sql.dart
open -a TextEdit /tmp/lector_api_football_cron.sql
pbcopy < /tmp/lector_api_football_cron.sql
```

Puis coller le SQL dans Supabase SQL Editor.

Le SQL genere :

- supprime les anciens jobs `api-football-*` ;
- cree 30 jobs `api-football-league-<id>` ;
- cree 30 jobs `api-football-league-<id>-snapshot` ;
- calcule les fenetres `J-2 -> J+3` et `J -> J+3` au moment de
  l'execution cron, en UTC ;
- utilise `API_FOOTBALL_SYNC_SECRET` depuis `.env`.

Important : le SQL genere contient `API_FOOTBALL_SYNC_SECRET` en clair dans la
commande Cron. Ne pas le commiter ni le partager.

Le generateur cree aussi un SQL d'execution immediate :

```sh
pbcopy < /tmp/lector_api_football_run_now.sql
```

Ce SQL planifie 60 jobs temporaires `api-football-run-now-*` :

- 30 collectes, une par ligue ;
- 30 snapshots, un par ligue ;
- meme cadence que le cron quotidien ;
- chaque job temporaire s'auto-supprime apres execution.

Verification SQL :

```sql
select *
from public.api_football_pipeline_health
where health_status <> 'ok'
order by api_football_league_id;

select
  api_football_league_id,
  league_name,
  resolved_season,
  sync_status,
  sync_window_start,
  sync_window_end,
  snapshot_window_start,
  snapshot_window_end,
  snapshot_fixtures,
  snapshot_odds,
  snapshot_team_statistics,
  snapshot_recent_league_matches,
  missing_odds,
  missing_team_statistics,
  missing_recent_form,
  missing_expected_goals,
  health_status
from public.api_football_pipeline_health
order by api_football_league_id;

select count(*) as distinct_league_snapshots
from public.api_football_latest_league_snapshot_health
where snapshot_id is not null;

select *
from public.api_football_latest_league_sync_health
where health_status <> 'ok'
order by api_football_league_id;
```

Ces vues sont creees par
`supabase/migrations/20260815123000_backend_data_observability.sql`.
Elles sont destinees au diagnostic backend via SQL Editor/service role, pas a
l'interface publique.

## Limites MVP

- Pas de live.
- Pas de settlement automatique temps reel.
- Pas de notifications externes pour stockage a 90%.
- Pas de moteur Football Analyzer cote serveur.
- Pas de nettoyage/retention automatique des anciens snapshots.

## Suite

Lots suivants recommandes :

1. politique de retention des caches/snapshots ;
2. backoff/retry structure sur erreurs API temporaires ;
3. rapport admin lisible dans l'app ou Supabase ;
4. notifications de seuil stockage ;
5. optimisation des ligues et endpoints selon consommation reelle.
