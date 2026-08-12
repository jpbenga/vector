# Backend Lot 4 - Branchement front vers les snapshots Supabase

Date : 2026-08-12

## Objectif

Le Lot 4 branche l'application Flutter sur le read model serveur
`match_feed_snapshots`, sans modifier le moteur de lecture football.

Le backend fournit une enveloppe JSON V1 compatible avec
`ApiFootballMatchAdapter`. Le front ne consomme donc pas les reponses brutes
API-Football : il lit un snapshot produit deja construit, horodate et
immutabilise.

## Architecture

```text
Supabase match_feed_snapshots.payload
  -> SupabaseMatchFeedSnapshotRepository
  -> MatchFeedRepositoryLoader
  -> SnapshotMatchFeedRepository
  -> ApiFootballMatchAdapter
  -> MatchBoardItem
  -> Football Analyzer / lectures / tickets
```

Le point important est que les ecrans ne savent pas si le snapshot vient de
Supabase ou d'un fichier local. Ils continuent de consommer
`MatchFeedRepository`.

## Fichiers

```text
lib/features/matches/data/supabase_match_feed_snapshot_repository.dart
lib/features/matches/data/match_feed_repository_loader.dart
lib/features/matches/presentation/matches_home_page.dart
lib/core/di/service_locator.dart
lib/core/config/app_config.dart
```

## Modes de source

`MATCH_FEED_SOURCE` accepte :

- `auto` : mode par defaut. Charge Supabase si la configuration existe, sinon
  le snapshot local.
- `supabase`, `remote` ou `api` : tente Supabase, puis fallback local en cas
  d'echec.
- `snapshot`, `local` ou `local_snapshot` : force le snapshot local.
- `demo` : force les donnees de demonstration.

## Selection du snapshot distant

Le loader demande d'abord le dernier snapshot dont la fenetre couvre le jour
courant :

```text
window_start <= today <= window_end
order by as_of desc
limit 1
```

Si aucun snapshot ne couvre le jour courant, il charge le dernier snapshot
disponible. L'interface conserve alors ses controles de fraicheur : le
calendrier reste positionne sur le jour J et les etats de snapshot hors fenetre
ou obsolete restent visibles.

## Fallback local

Le fallback local est obligatoire pour :

- developper sans reseau ;
- travailler sans Supabase configure ;
- conserver une experience exploitable si Supabase est temporairement
  indisponible ;
- eviter une page blanche.

Snapshot local utilise :

```text
assets/snapshots/focused_match_feed_latest.json
```

## Securite

Les snapshots sont des donnees produit non personnelles. La lecture est autorisee
aux roles `anon` et `authenticated` par les policies RLS du Lot 3A.

Le client ne peut pas creer, modifier ou supprimer les snapshots.

## Hors perimetre

Le Lot 4 ne fait pas encore :

- de migration du Football Analyzer cote serveur ;
- d'appel direct API-Football depuis Flutter ;
- de selection avancee de snapshot par utilisateur ;
- de job planifie ;
- de prechargement offline persistant du dernier snapshot distant.

