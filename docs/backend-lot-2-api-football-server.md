# Backend Lot 2 - API-Football cote serveur

Date : 2026-08-11

## Objectif

Le Lot 2 sort la cle API-Football du front et pose une collecte serveur
rejouable.

Le backend collecte, met en cache et journalise les reponses API-Football. Il ne
deplace pas encore le moteur de lectures, le generateur de tickets ou la
normalisation finale cote serveur.

## Perimetre

Inclus :

- fonction Edge `api-football-sync` ;
- secret `API_FOOTBALL_KEY` uniquement cote Supabase ;
- secret d'execution `API_FOOTBALL_SYNC_SECRET` ;
- cache raw idempotent des reponses API-Football ;
- logs de synchronisation ;
- provenance `source`, `fetched_at`, `as_of`, `sync_run_id` ;
- limites anti-abus sur la fenetre de dates et le nombre de ligues.
- forme recente factuelle via `/fixtures` filtre `team + from + to` ;
- xG historiques factuels via `/fixtures/statistics` sur les matchs termines.

Exclus :

- appels API-Football depuis Flutter ;
- snapshots pre-match immuables ;
- settlement automatique ;
- migration du Football Analyzer cote serveur ;
- read model serveur consomme par le front.

## Migration

Fichier :

- `supabase/migrations/20260811103000_backend_lot_2_api_football_server.sql`

Tables :

- `api_football_sync_runs` : une ligne par execution de synchronisation ;
- `api_football_cached_responses` : cache idempotent par endpoint + query hash.

Ces tables activent et forcent RLS, mais ne declarent aucune policy pour
`anon` ou `authenticated`. Elles sont serveur uniquement et doivent etre ecrites
par la fonction Edge avec la service role key.

## Fonction Edge

Fichier :

- `supabase/functions/api-football-sync/index.ts`

La fonction accepte uniquement `POST` et exige :

```http
Authorization: Bearer <API_FOOTBALL_SYNC_SECRET>
```

Important : cette fonction doit etre deployee sans verification JWT Supabase,
car elle utilise son propre secret d'execution. Le front ne l'appelle pas
directement.

```sh
npx supabase functions deploy api-football-sync --no-verify-jwt
```

Payload minimal :

```json
{
  "season": 2026,
  "timezone": "Europe/Paris",
  "window_start": "2026-08-11",
  "window_end": "2026-08-16",
  "league_ids": [2, 3, 62, 88],
  "bookmaker_id": 16,
  "include_team_statistics": true,
  "include_recent_form": true,
  "include_expected_goals": true,
  "recent_form_matches": 5
}
```

Endpoints collectes :

- `/leagues`
- `/standings`
- `/fixtures`
- `/odds`
- `/teams/statistics`
- `/fixtures/statistics`

La fonction upsert chaque reponse dans `api_football_cached_responses` avec une
cle stable :

```text
source + endpoint + sha256(endpoint + query triee)
```

Relancer le meme job remplace donc le cache de la meme requete au lieu de
dupliquer les lignes.

Les xG collectes restent historiques et factuels : la fonction ne collecte pas
`/predictions` dans ce lot.

## Secrets Supabase

A configurer cote Supabase, pas dans Flutter :

```sh
npx supabase secrets set API_FOOTBALL_KEY=...
npx supabase secrets set API_FOOTBALL_SYNC_SECRET=...
npx supabase secrets set API_FOOTBALL_BASE_URL=https://v3.football.api-sports.io
```

La fonction utilise aussi les secrets fournis par Supabase :

```text
SUPABASE_URL
SUPABASE_SERVICE_ROLE_KEY
```

Ne jamais exposer `SUPABASE_SERVICE_ROLE_KEY` dans l'application Flutter.

## Invocation manuelle

Exemple apres deploiement :

```sh
curl -X POST \
  "https://<project-ref>.functions.supabase.co/api-football-sync" \
  -H "Authorization: Bearer <API_FOOTBALL_SYNC_SECRET>" \
  -H "Content-Type: application/json" \
  -d '{
    "season": 2026,
    "window_start": "2026-08-11",
    "window_end": "2026-08-16",
    "league_ids": [2, 3, 62, 88],
    "bookmaker_id": 16
  }'
```

Validation initiale effectuee le 2026-08-11 :

- migration distante appliquee ;
- secrets `API_FOOTBALL_KEY`, `API_FOOTBALL_SYNC_SECRET` et
  `API_FOOTBALL_BASE_URL` configures ;
- fonction `api-football-sync` deployee avec `--no-verify-jwt` ;
- appel minimal sur une ligue et une journee termine avec succes ;
- run cree : `aaa108d5-4d6f-4024-9f9e-1a4d67389713` ;
- reponses cachees : `4`.

## Regles de securite

- La cle API-Football reste uniquement dans les secrets Supabase.
- Le front ne doit pas appeler cette fonction directement sans mediation future.
- Les tables de cache n'ont pas de policy client.
- La fonction exige un secret d'execution.
- Le payload limite la fenetre a 7 jours et 40 ligues maximum.

## Transition vers le Lot 3

Le Lot 3 lira ces reponses raw et produira des snapshots pre-match immuables.
Ces snapshots devront etre append-only et porter :

- `source`;
- `fetched_at`;
- `as_of`;
- `snapshot_created_at`;
- `fixture_id`;
- payload normalise compatible avec `ApiFootballMatchAdapter`.
