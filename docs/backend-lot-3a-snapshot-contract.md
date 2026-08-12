# Backend Lot 3A - Contrat des snapshots pre-match

Date : 2026-08-11

## Objectif

Le Lot 3A definit le contrat serveur des snapshots pre-match immuables.

Il ne transforme pas encore les reponses API-Football brutes. Cette
transformation arrivera au Lot 3B.

Le but est de preparer une source produit stable, lisible par le front et
compatible avec le moteur actuel :

```text
api_football_cached_responses
  -> transformation serveur Lot 3B
  -> match_feed_snapshots
  -> payload V1 compatible ApiFootballMatchAdapter
  -> MatchFeedRepository(api)
  -> Football Analyzer / lectures / tickets
```

## Fichier de migration

```text
supabase/migrations/20260811113000_backend_lot_3a_match_feed_snapshots.sql
```

## Tables

### match_feed_snapshots

Table principale du read model.

Elle stocke une enveloppe JSON complete, volontairement proche du snapshot local
V1 deja consomme par `ApiFootballMatchAdapter`.

Champs structurants :

- `id` : identifiant technique du snapshot ;
- `schema_version` : version du contrat, actuellement `1` ;
- `source` : `api-football` ;
- `kind` : `pre_match_feed` ;
- `season` : saison sportive ;
- `timezone` : timezone de presentation ;
- `window_start` / `window_end` : fenetre calendrier couverte ;
- `date_window` : liste des jours couverts ;
- `bookmaker_priority` : priorite bookmaker appliquee lors de la normalisation ;
- `payload` : enveloppe JSON compatible front ;
- `coverage_summary` : resume des donnees disponibles ;
- `provenance` : resume de provenance ;
- `source_sync_run_ids` : runs Lot 2 utilises ;
- `captured_at` : instant de capture fonctionnel ;
- `as_of` : instant maximal autorise pour les donnees pre-match ;
- `snapshot_created_at` : instant d'insertion serveur.

Unicite :

```text
source + schema_version + season + timezone + window_start + window_end + as_of
```

Cela autorise plusieurs versions successives d'une meme fenetre, mais interdit
les doublons exacts.

### match_feed_snapshot_fixtures

Index par rencontre.

Cette table permet de parcourir rapidement les snapshots par jour, competition
ou equipe sans devoir inspecter tout le JSON.

Elle contient notamment :

- `fixture_id` ;
- `api_football_fixture_id` ;
- `api_football_league_id` ;
- `fixture_date` ;
- `kickoff_at` ;
- competition, pays, equipes ;
- flags de couverture : `has_odds`, `has_standings`,
  `has_team_statistics`, `has_recent_form`, `has_expected_goals`,
  `contains_predictions`.

Le champ `payload` reste disponible pour stocker une representation normalisee
par fixture si necessaire, mais le contrat principal du front reste
`match_feed_snapshots.payload`.

### match_feed_snapshot_sources

Table de provenance.

Chaque ligne relie un snapshot aux reponses brutes du Lot 2 qui ont servi a le
construire :

```text
snapshot_id
source
endpoint
query_hash
sync_run_id
fetched_at
as_of
response_status
```

La cle `(source, endpoint, query_hash)` reference
`api_football_cached_responses`.

## Contrat JSON du payload

`match_feed_snapshots.payload` doit rester compatible avec le snapshot local V1 :

```json
{
  "schema_version": 1,
  "source": "api-football",
  "captured_at": "2026-08-11T08:00:00Z",
  "timezone": "Europe/Paris",
  "window_start": "2026-08-11",
  "window_end": "2026-08-16",
  "date_window": ["2026-08-11", "2026-08-12"],
  "bookmaker_priority": [
    { "id": 16, "name": "Unibet" },
    { "id": 8, "name": "Bet365" }
  ],
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

Les champs `expected_goals` et `predictions` restent optionnels pour le MVP.
Quand ils existent, ils doivent respecter la regle pre-match : aucune donnee
posterieur a `as_of` ne peut participer aux lectures.

## Immutabilite

Les trois tables sont append-only :

- aucune update ;
- aucune delete ;
- toute correction cree un nouveau snapshot avec un nouvel `as_of`.

La migration ajoute des triggers `prevent_snapshot_mutation` pour bloquer les
updates et deletes, y compris si une erreur d'integration essaie de modifier une
ligne existante.

## Acces client

Les snapshots sont des donnees produit non personnelles.

Le client peut les lire :

- `anon` ;
- `authenticated`.

Le client ne peut pas les creer, modifier ou supprimer.

Les ecritures restent reservees aux jobs serveur utilisant la service role key.

Validation initiale effectuee le 2026-08-11 :

- migration distante appliquee ;
- lecture REST avec la cle `anon` validee sur les trois tables ;
- tables encore vides, ce qui est attendu avant le job de transformation Lot 3B.

## Relation avec le Lot 2

Le Lot 2 stocke le raw cache :

```text
api_football_cached_responses
```

Le Lot 3A ne lit pas encore ce cache. Il cree seulement la destination
normalisee.

Le Lot 3B devra :

1. selectionner les reponses raw utiles ;
2. verifier leur fraicheur ;
3. produire `payload` ;
4. inserer `match_feed_snapshots` ;
5. inserer `match_feed_snapshot_fixtures` ;
6. inserer `match_feed_snapshot_sources`.

## Regles produit a respecter au Lot 3B

- un snapshot pre-match porte toujours `captured_at` et `as_of` ;
- aucune mutation retroactive ;
- les donnees manquantes restent visibles comme manquantes ;
- aucune substitution silencieuse de bookmaker ;
- les cotes viennent d'un bookmaker connu ou d'une priorite explicite ;
- le payload reste compatible avec `ApiFootballMatchAdapter` ;
- le moteur ne consomme pas les reponses API-Football brutes directement.
