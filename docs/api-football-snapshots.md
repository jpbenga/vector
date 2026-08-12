# Snapshots API-Football V1

## Objectif

Les snapshots permettent de tester l'application avec des réponses API-Football
sauvegardées, sans dépendre du réseau, des quotas ou de la disponibilité des
championnats.

Flutter ne doit pas appeler API-Football directement avec une clé embarquée. Le
mode `snapshot` charge uniquement des JSON locaux ou des données déjà stockées
par le backend.

Le contrat serveur correspondant est defini dans :

```text
docs/backend-lot-3a-snapshot-contract.md
docs/backend-lot-3b-snapshot-builder.md
```

Le payload serveur `match_feed_snapshots.payload` doit rester compatible avec
le format local V1 decrit ci-dessous.

Le Lot 3B fournit la fonction serveur `build-match-feed-snapshot`, qui transforme
le cache brut `api_football_cached_responses` en payload V1 immuable. Cette
fonction ne contacte pas API-Football directement.

## Format

Le fichier V1 conserve une enveloppe stable :

```json
{
  "schema_version": 1,
  "source": "api-football",
  "captured_at": "2026-07-30T08:00:00Z",
  "timezone": "Europe/Paris",
  "window_start": "2026-07-30",
  "window_end": "2026-08-03",
  "date_window": ["2026-07-30", "2026-07-31"],
  "bookmaker": {
    "id": 8,
    "name": "Demo Bookmaker"
  },
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

`raw.fixtures`, `raw.odds`, `raw.standings` et `raw.team_statistics` gardent une
forme proche des réponses API-Football. `raw.recent_league_matches` et
`raw.expected_goals` sont des projections construites par le backend a partir de
donnees factuelles cachees. `raw.predictions` reste reserve a une collecte
future explicitement marquee comme non factuelle.

L'adaptateur est responsable de convertir ces blocs vers les modèles internes :

- `NormalizedFixture`
- `CompetitionInfo`
- `TeamInfo`
- `FixtureVenue`
- `MarketOdds`
- `MatchMarket`
- `TeamStandingSnapshot`
- `TeamStatisticsSnapshot`
- `TeamRecentMatchSnapshot`
- `TeamExpectedGoalsSnapshot`
- `MatchAnalysisData`
- `MatchBoardItem`

## Règles V1

- Le snapshot contient les données observées au moment de la capture.
- `captured_at` est obligatoire pour raisonner sur des lectures pré-match.
- `window_start` et `window_end` décrivent la fenêtre calendaires couverte.
- Les identifiants API-Football sont conservés lorsqu'ils existent.
- Les IDs internes restent stables et indépendants du libellé affiché.
- Les champs manquants doivent produire une donnée incomplète mais affichable.
- La compatibilité et les signaux ne sont pas calculés par l'adaptateur API.
  Ils seront produits par le moteur après normalisation.
- Si le snapshot est absent, vide, obsolète ou hors fenêtre pour le jour
  affiché, l'interface doit l'indiquer au lieu de basculer silencieusement sur
  une autre source.

## Stratégie de fraîcheur en développement

Le snapshot de développement doit être généré avec une fenêtre courte :

- début : le jour J ;
- fin : le dimanche de la semaine courante ;
- horodatage : `captured_at` au moment de la génération ;
- source : fichiers d'exploration API-Football sauvegardés localement.

Commande par défaut :

```sh
dart run tool/build_match_feed_snapshot.dart
```

La commande cherche d'abord `var/api_football_exploration/latest`, puis le
dossier `focus_*` le plus récent. La fenêtre par défaut est automatiquement
`aujourd'hui -> dimanche`.

Options utiles :

```sh
dart run tool/build_match_feed_snapshot.dart \
  --exploration-dir var/api_football_exploration/focus_2026_08_08 \
  --from 2026-08-08 \
  --until 2026-08-09 \
  --output assets/snapshots/focused_match_feed_latest.json
```

Pour une recette locale plus longue :

```sh
dart run tool/build_match_feed_snapshot.dart --from 2026-08-08 --days 7
```

Le front reste volontairement offline en mode `snapshot`. Il n'appelle pas
API-Football directement et ne remplace pas une cote ou une rencontre absente
par une donnée issue d'un autre snapshot.

## Fichier de démonstration

Le snapshot local actuel est :

```text
assets/snapshots/api_football_match_feed_v1.json
```

Un snapshot réel Conference League, issu de l'exploration du `2026-07-30`, est
également disponible :

```text
assets/snapshots/conference_league_2026_07_30.json
```

Le snapshot de recette actuel de l'onglet `Tous les matchs` est multi-dates et
multi-compétitions :

```text
assets/snapshots/focused_match_feed_2026_07_30.json
```

Il couvre la période `2026-07-30` -> `2026-08-03` et sert à valider :

- les onglets de date ;
- les groupes pays -> compétition -> rencontre ;
- les assets équipes, pays et compétitions ;
- les cotes 1N2 avec priorité bookmaker MVP ;
- les classements de ligue lorsque l'endpoint `/standings` fournit des lignes
  exploitables pour la saison ;
- les statistiques d'équipe lorsque l'endpoint `/teams/statistics` fournit des
  réponses exploitables pour les équipes du snapshot ;
- les états de cotes indisponibles lorsque l'API ne fournit pas de ligne odds
  pour une fixture.

En développement, l'application utilise désormais `MATCH_FEED_SOURCE=auto` par
défaut. Ce mode charge le dernier snapshot Supabase couvrant le jour courant
quand Supabase est configuré, puis revient au snapshot local si la donnée
distante est indisponible. La source `demo` ne doit être utilisée qu'en la
demandant explicitement avec `--dart-define=MATCH_FEED_SOURCE=demo`.

Pour lancer explicitement l'application sur ce snapshot :

```sh
flutter run \
  --dart-define=APP_ENV=development \
  --dart-define=MATCH_FEED_SOURCE=snapshot
```

Pour lancer le comportement cible du Lot 4 :

```sh
flutter run \
  --dart-define=APP_ENV=development \
  --dart-define=MATCH_FEED_SOURCE=auto
```

Il couvre volontairement le minimum utile pour recetter le pipeline :

```text
fixtures API-Football
  -> odds API-Football
  -> ApiFootballMatchAdapter
  -> MatchBoardItem
  -> MatchFeedRepository(snapshot)
```
