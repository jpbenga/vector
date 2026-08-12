# Backend Lot 3B - Construction des snapshots pre-match

Date : 2026-08-11

## Objectif

Le Lot 3B transforme le cache brut du Lot 2 en snapshots pre-match immuables
compatibles avec le front actuel.

La fonction ne collecte pas de donnees sportives. Elle ne contacte jamais
API-Football et ne lit pas `API_FOOTBALL_KEY`. Elle reconstruit uniquement un
read model depuis les reponses brutes deja presentes dans le cache serveur.

```text
api-football-sync
  -> api_football_cached_responses
  -> build-match-feed-snapshot
  -> match_feed_snapshots
  -> match_feed_snapshot_fixtures
  -> match_feed_snapshot_sources
```

## Fonction Edge

Fichier :

```text
supabase/functions/build-match-feed-snapshot/index.ts
```

La fonction accepte uniquement `POST` et exige le meme secret d'execution que
le job de collecte :

```http
Authorization: Bearer <API_FOOTBALL_SYNC_SECRET>
```

Elle doit etre deployee sans verification JWT Supabase, car l'autorisation est
portee par ce secret serveur :

```sh
npx supabase functions deploy build-match-feed-snapshot --no-verify-jwt
```

## Payload

Payload minimal :

```json
{
  "season": 2026,
  "timezone": "Europe/Paris",
  "window_start": "2026-08-11",
  "window_end": "2026-08-16",
  "league_ids": [2, 3, 62, 88],
  "bookmaker_id": 16
}
```

Champs :

- `season` : saison sportive ;
- `timezone` : timezone de presentation, `Europe/Paris` par defaut ;
- `window_start` / `window_end` : fenetre calendrier, maximum 7 jours ;
- `league_ids` : ligues API-Football, maximum 40 ;
- `bookmaker_id` : optionnel, permet de reprendre uniquement le cache odds du
  bookmaker cible ;
- `bookmaker_priority` : optionnel, remplace la priorite bookmaker par defaut ;
- `as_of` : optionnel, force l'identite temporelle du snapshot ;
- `recent_form_days_back` : optionnel, fenetre historique utilisee par le job de
  collecte, `180` par defaut ;
- `recent_form_matches` : optionnel, nombre de matchs recents retenus par equipe,
  `5` par defaut.

Si `as_of` est absent, la fonction utilise le plus recent `as_of` des reponses
cachees selectionnees. Relancer la fonction avec les memes donnees et le meme
`as_of` renvoie le snapshot existant au lieu d'en creer un nouveau.

## Donnees lues

La fonction lit uniquement `api_football_cached_responses` pour les endpoints :

- `/leagues`
- `/standings`
- `/fixtures`
- `/odds`
- `/teams/statistics`
- `/fixtures/statistics`

Les filtres sont bases sur :

- `source = api-football` ;
- `endpoint` ;
- `query_params` ;
- `response_status` entre `200` et `299`.

## Donnees ecrites

### match_feed_snapshots

La fonction insere une enveloppe V1 :

```json
{
  "schema_version": 1,
  "source": "api-football",
  "captured_at": "2026-08-11T08:00:00.000Z",
  "timezone": "Europe/Paris",
  "window_start": "2026-08-11",
  "window_end": "2026-08-16",
  "date_window": ["2026-08-11", "2026-08-12"],
  "bookmaker_priority": [],
  "raw": {
    "fixtures": [],
    "odds": [],
    "standings": [],
    "team_statistics": [],
    "recent_league_matches": [],
    "expected_goals": [],
    "predictions": []
  }
}
```

`raw.fixtures`, `raw.odds`, `raw.standings` et `raw.team_statistics` gardent
une forme proche des reponses API-Football, afin de rester compatibles avec
`ApiFootballMatchAdapter`.

`raw.recent_league_matches` est derive depuis les caches `/fixtures` appeles
avec `team + from + to`. La fonction conserve les derniers matchs termines par
equipe, dans la limite de `recent_form_matches`.

`raw.expected_goals` est derive depuis les caches `/fixtures/statistics` des
matchs recents deja termines. Ces xG sont factuels et historiques : ils ne sont
jamais des predictions du match a venir.

`raw.predictions` reste volontairement vide tant que les predictions API ne sont
pas collectees et isolees comme donnees non factuelles.

### match_feed_snapshot_fixtures

La fonction cree un index de rencontres avec :

- ids API-Football ;
- competition, pays, equipes ;
- date et heure ;
- statut ;
- flags de couverture : cotes, classement, statistiques equipes, forme recente,
  xG, predictions.

Cet index permet ensuite au front de charger rapidement une journee ou une
competition sans inspecter tout le JSON.

### match_feed_snapshot_sources

Chaque reponse cachee utilisee est reliee au snapshot par :

```text
snapshot_id + source + endpoint + query_hash
```

Cette table constitue la provenance exploitable pour l'audit et les futures
analyses IA.

## Immutabilite et idempotence

Les tables du Lot 3A restent append-only.

La fonction ne fait pas d'upsert sur `match_feed_snapshots`, car un upsert
impliquerait une mutation bloquee par les triggers. Elle verifie d'abord si un
snapshot existe deja pour :

```text
source + schema_version + season + timezone + window_start + window_end + as_of
```

Si oui, elle renvoie :

```json
{
  "ok": true,
  "reused": true,
  "snapshotId": "...",
  "summary": {}
}
```

Sinon, elle cree un nouveau snapshot.

## Invocation manuelle

```sh
set -a
source .env
set +a

curl -X POST \
  "https://<project-ref>.functions.supabase.co/build-match-feed-snapshot" \
  -H "Authorization: Bearer $API_FOOTBALL_SYNC_SECRET" \
  -H "Content-Type: application/json" \
  -d '{
    "season": 2026,
    "timezone": "Europe/Paris",
    "window_start": "2026-08-11",
    "window_end": "2026-08-16",
    "league_ids": [61, 62],
    "bookmaker_id": 16
  }'
```

## Validation attendue

Avant de brancher le front sur les snapshots distants :

1. lancer `api-football-sync` sur une fenetre courte ;
2. lancer `build-match-feed-snapshot` avec les memes parametres ;
3. verifier qu'une ligne apparait dans `match_feed_snapshots` ;
4. verifier les fixtures indexees dans `match_feed_snapshot_fixtures` ;
5. verifier la provenance dans `match_feed_snapshot_sources` ;
6. relancer la meme commande et verifier `reused: true`.

Validation initiale effectuee le 2026-08-11 :

- fonction `build-match-feed-snapshot` deployee avec `--no-verify-jwt` ;
- appel minimal sur le cache Lot 2 existant termine avec succes ;
- snapshot cree : `3e0443aa-6296-47e9-b746-787fdf546904` ;
- reponses sources rattachees : `4` ;
- relance identique validee avec `reused: true`.

## Hors perimetre

- Pas de bascule du front vers la source distante dans ce lot.
- Pas de migration du Football Analyzer cote serveur.
- Pas de settlement de tickets.
- Pas de collecte de predictions API.
- Pas de migration des lectures, du Football Analyzer ou du solveur de tickets
  cote serveur.
