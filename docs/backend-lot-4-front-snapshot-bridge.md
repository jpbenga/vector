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

Les ecrans consomment `MatchFeedRepository`. En mode connecté, le loader ne
consulte plus de fichier local et n'accepte que la période demandée.

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

- `auto` : mode par défaut. Charge uniquement un snapshot Supabase qui couvre
  le jour demandé. Si Supabase est absent ou qu'aucun snapshot ne couvre ce
  jour, le chargement affiche une erreur au lieu de servir des données datées.
- `supabase`, `remote` ou `api` : même règle, sans repli vers des données
  locales ou vers un snapshot hors période.
- `demo` : force les donnees de demonstration.

## Selection du snapshot distant

Le loader demande d'abord le dernier snapshot dont la fenetre couvre le jour
courant :

```text
window_start <= today <= window_end
order by as_of desc
limit 1
```

Si aucun snapshot ne couvre le jour courant, le chargement échoue avec un
message explicite. Aucun instantané ancien n'est présenté comme donnée du jour.
Les exports manuels de recette sont écrits dans `output/` et ne sont pas
embarqués ni utilisés par l'application.

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
