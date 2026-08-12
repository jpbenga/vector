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
06:00 UTC
```

Ce choix laisse le temps aux matchs tardifs en Amerique latine de se terminer
avant la collecte du matin.

Fenetre technique par defaut :

```text
Resultats : J-2 -> J-1
Feed front : J -> J+3
Collecte API : J-2 -> J+3
```

La collecte couvre donc les resultats recents et les 4 jours a venir, mais le
snapshot expose au front reste centre sur les matchs a venir.

## Architecture

```text
Vercel Cron
  -> /api/daily-football-sync
  -> Supabase Edge Function daily-football-sync
  -> api-football-sync
  -> api_football_cached_responses
  -> build-match-feed-snapshot
  -> match_feed_snapshots
  -> Flutter read model
```

Vercel ne connait pas `API_FOOTBALL_KEY`.
La cle API-Football reste uniquement dans les secrets Supabase.

## Fichiers

```text
api/daily-football-sync.ts
supabase/functions/daily-football-sync/index.ts
supabase/functions/api-football-sync/index.ts
supabase/migrations/20260813080000_backend_daily_football_sync.sql
vercel.json
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

`SUPABASE_SERVICE_ROLE_KEY` ne doit jamais etre expose cote front.

## Variables Vercel

A configurer dans Vercel :

```text
SUPABASE_URL
API_FOOTBALL_SYNC_SECRET
CRON_SECRET
API_FOOTBALL_SEASON=2026
API_FOOTBALL_TIMEZONE=Europe/Paris
API_FOOTBALL_LEAGUE_IDS=2,3,848,39,61,78,135,140,88,103,113
API_FOOTBALL_BOOKMAKER_ID=16
API_FOOTBALL_RESULTS_DAYS_BACK=2
API_FOOTBALL_FUTURE_DAYS=3
API_FOOTBALL_REQUEST_DELAY_MS=750
SUPABASE_DATABASE_SIZE_LIMIT_BYTES=524288000
```

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
    "season": 2026,
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

## Invocation Vercel

Apres deploy Vercel, tester le proxy cron :

```sh
curl -X POST \
  "https://lector-sports.vercel.app/api/daily-football-sync" \
  -H "Authorization: Bearer $CRON_SECRET"
```

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
