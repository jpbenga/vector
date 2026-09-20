# Backend Daily Football Sync MVP

Date : 2026-08-13 (mise a jour : 2026-09-16)

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
Resultats : J-7 -> J-1
Feed front : J -> J+3
Collecte feed API : J -> J+3
Collecte resultats API : J-7 -> J-1
```

Les deux collectes sont separees : les cotes et les enrichissements ne sont
pas redemandes pour les jours passes. Les resultats finaux sont archives dans
des snapshots dedoublonnes ; le feed front reste centre sur les matchs a venir.

Les pages joueurs ne sont pas repaginees par le cron glissant quotidien.
Elles sont opt-in dans `api-football-sync` et rafraichies par un second planning
hebdomadaire, reparti sur les sept jours. Cela conserve les statistiques
joueurs sans multiplier leur cout par 40 chaque nuit.

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
Si plusieurs saisons chevauchent la fenetre, la saison dont la couverture
commence le plus tard est prioritaire ; le champ provider `current` ne sert
que de departage secondaire.

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
  -> daily-football-sync par ligue
  -> api-football-sync
  -> api_football_cached_responses
  -> sync-match-results (J-7 a J-1, scores finaux)
  -> match_result_snapshots
  -> build-match-feed-snapshot apres collecte terminee (brut prive)
  -> publish-reading-announcements (Bilan immuable)
  -> analyze-match-feed-snapshot (read model mobile compact)
  -> match_feed_analysis_snapshots scopes league:<id>
  -> Flutter fusionne et filtre les lectures deja calculees
```

Vercel heberge l'application web, mais ne porte pas le cron data.
La collecte peut depasser le timeout d'une fonction Vercel, surtout avec le
throttle volontaire entre appels API-Football.

La cle API-Football reste uniquement dans les secrets Supabase.

## Erreurs API-Football

API-Football peut repondre en HTTP 200 tout en signalant une erreur metier dans
le champ JSON `errors`, par exemple un compte suspendu ou un plan sans acces a
la saison demandee.

`api-football-sync` doit traiter ces payloads comme des echecs, pas comme des
reponses vides valides. La reponse reste cachee pour audit, mais le run passe en
`failed` et `build-match-feed-snapshot` ne doit pas publier un snapshot issu de
ces caches.

Si toutes les familles utiles du snapshot sont vides (`fixtures`, `odds`,
`standings`, `team_statistics`, `recent_league_matches`, `expected_goals`), le
builder renvoie une erreur et refuse d'inserer une ligne dans
`match_feed_snapshots`.

Important : le scope complet MVP ne doit pas etre execute dans un seul appel
`daily-football-sync`.

Le test reel du 2026-08-13 a montre que 30 ligues dans une seule Edge Function
peuvent provoquer :

```text
WORKER_RESOURCE_LIMIT
```

La strategie retenue est donc :

1. un run orchestre par ligue via `daily-football-sync` ;
2. cache brut idempotent dans `api_football_cached_responses` ;
3. un snapshot par ligue via `build-match-feed-snapshot`, seulement apres la
   fin de la collecte.

Le front fusionne uniquement les derniers read models compacts de chaque ligue
pour la date demandee. Il ne reconstruit aucune statistique football. Cette strategie evite de depasser les
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

La migration
`supabase/migrations/20260916170000_backend_api_football_quota_guard.sql`
ajoute en plus une reservation atomique avant chaque appel fournisseur :

- plafond global Ultra de 75 000 requetes par jour UTC ;
- plafond global de 450 requetes sur toute fenetre glissante de 60 secondes ;
- compteur partage entre les crons et les lancements manuels ;
- refus de l'appel avant de contacter API-Football si un plafond est atteint.

Le compteur du jour d'installation est initialise depuis
`api_football_sync_runs.response_summary.cachedResponses`, afin qu'un
deploiement en cours de journee ne remette jamais le budget a zero.

La cadence sequentielle de `750 ms` reste volontairement bien plus basse que
le plafond Ultra : environ 80 requetes/minute par collecteur.

### Confrontations directes

Pour chaque affiche future, `api-football-sync` collecte
`/fixtures/headtohead` une seule fois par paire de clubs, sans tenir compte de
l'ordre domicile/exterieur. La reponse est mise en cache 30 jours : le builder
de snapshot lit exclusivement ce cache et n'appelle jamais API-Football.

Le read model mobile ne conserve que la date, la competition, les deux equipes
et le score. L'ecran **Confrontation** filtre ensuite les rencontres sur
l'identifiant de la competition du match consulte. Une affiche de championnat
ne melange donc ni coupe, ni competition europeenne, ni amical.

Si la fenetre ne contient aucun match a venir, la collecte quotidienne s'arrete
apres les sources de ligue et l'orchestrateur valide le cycle sans publier de
snapshot vide. Cela evite les enrichissements joueurs et matchs historiques
inutiles pour une ligue sans affiche pre-match.

La migration
`supabase/migrations/20260916193000_backend_service_role_snapshot_timeout.sql`
porte a 30 secondes le delai SQL du role serveur pour permettre l'insertion
des gros snapshots immuables, sans modifier le delai des roles clients.

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
API_FOOTBALL_LEAGUE_IDS=2,3,848,39,61,140,78,135,94,95,88,144,179,203,197,119,207,218,40,62,136,79,141,106,210,209,283,253,71,128,262,307,98,188,103,113,164,169,244,292,531,45,48,528,66,526,81,529,96,550,143,556,137,547,90,543,147,519,181,185,551,1,32,4,5,9,6,7,22,536,64,525,1191,8
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
Pour le scope complet MVP, utiliser des jobs Supabase Cron separes par ligue,
mais chaque job doit appeler l'orchestrateur complet :

```text
00:00 UTC -> daily-football-sync ligue 1
00:04 UTC -> daily-football-sync ligue 2
...
02:36 UTC -> daily-football-sync ligue 40
```

`00:00 UTC` correspond a environ `02:00` en France en aout.

L'espacement de 4 minutes entre chaque ligue evite le fan-out agressif et garde
la consommation API tres largement sous la limite Ultra de 450 requetes/minute.

Un second job `api-football-enrichment-<id>` existe pour chaque ligue. Il ne
tourne qu'une fois par semaine avec `include_player_statistics: true`. Les 40
ligues sont reparties entre les sept jours et plusieurs heures afin d'eviter un
pic hebdomadaire. Le job quotidien garde explicitement
`include_player_statistics: false`.

Chaque job appelle une Edge Function en `POST` avec les headers :

```text
Authorization: Bearer <API_FOOTBALL_SYNC_SECRET>
Content-Type: application/json
```

Body commun aux runs orchestres :

```json
{
  "league_ids": [61],
  "results_days_back": 7,
  "future_days": 3,
  "api_request_delay_ms": 750,
  "include_team_statistics": true,
  "include_recent_form": true,
  "include_expected_goals": true,
  "include_player_statistics": false
}
```

Le backend resout la saison active par ligue au moment de chaque lot en
comparant la fenetre demandee avec la couverture de fixtures de chaque saison.
Ne pas ajouter `season` dans les crons quotidiens : ce champ est uniquement un
override manuel de diagnostic. Le fonctionnement normal doit laisser
`api-football-sync` resoudre `leagueSeasons` ligue par ligue.

Body interne envoye par `daily-football-sync` au builder de snapshot :

```json
{
  "league_ids": [61],
  "window_start": "YYYY-MM-DD",
  "window_end": "YYYY-MM-DD",
  "force_rebuild": false,
  "recent_form_days_back": 180,
  "recent_form_matches": 5
}
```

Le builder complete `season_by_league` depuis les reponses `/leagues` en cache
avec la meme logique de couverture de fenetre que la collecte.
Les runs normaux ne filtrent pas `/odds` par bookmaker : une seule requete
recupere les bookmakers disponibles, puis l'adaptateur applique la priorite
Unibet, Bet365, Pinnacle, Betfair, 1xBet et Bwin. `bookmaker_id` reste accepte
uniquement comme override manuel de diagnostic.
Chaque snapshot porte un `scope_key` du type `league:61`. L'ancien scope global
reste supporte pour compatibilite, mais il ne doit plus etre utilise pour le
cron complet MVP.

Ne pas programmer un job `build-match-feed-snapshot` a delai fixe apres
`api-football-sync`. La duree reelle de collecte depend du nombre de fixtures,
des stats recentes et des appels xG; un delai fixe peut publier un snapshot
incomplet et provoquer une absence de propositions pour les matchs du jour.

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
    "results_days_back": 7,
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

Si API-Football renvoie une erreur dans `errors`, la validation attendue devient
un echec explicite du run. Un snapshot vide ne doit pas etre publie comme
`ok`.

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
- cree 40 jobs `api-football-league-<id>` qui appellent
  `daily-football-sync` ;
- cree 40 jobs `api-football-enrichment-<id>` repartis sur la semaine pour les
  statistiques joueurs ;
- laisse `daily-football-sync` calculer les fenetres `J-7 -> J-1` et
  `J -> J+3` ;
- utilise `API_FOOTBALL_SYNC_SECRET` depuis `.env`.

Important : le SQL genere contient `API_FOOTBALL_SYNC_SECRET` en clair dans la
commande Cron. Ne pas le commiter ni le partager.

Le generateur cree aussi un SQL d'execution immediate :

```sh
pbcopy < /tmp/lector_api_football_run_now.sql
```

Ce SQL planifie 40 jobs temporaires `api-football-run-now-*` :

- 40 runs orchestres, un par ligue ;
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
`supabase/migrations/20260815123000_backend_data_observability.sql` puis
`supabase/migrations/20260816120000_backend_expand_active_league_scope.sql`.
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
