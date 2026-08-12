# Backend Lot 1B - Repositories distants et fallback local

Date : 2026-08-10

## Objectif

Le Lot 1B remplace progressivement les stores locaux par des repositories
capables de lire/ecrire dans Supabase, sans changer les ecrans ni les contrats
produit.

Regle centrale :

```text
Les ecrans consomment les memes objets Dart.
Seule la source de persistance change.
```

## Perimetre

Inclus :

- profil/onboarding utilisateur ;
- strategies de tickets ;
- favoris de rencontres ;
- tickets sauvegardes ;
- selections de tickets ;
- declaration "joue" et changement de statut ;
- migration opportuniste localStorage -> Supabase.

Exclus :

- API-Football ;
- snapshots sportifs ;
- synchronisation de matches ;
- reglement automatique ;
- analytics ;
- paiement/offres premium.

## Principe de source

La source distante est utilisee seulement si :

- Supabase est configure ;
- l'initialisation Supabase reussit ;
- un utilisateur est connecte.

Sinon, le repository doit utiliser le store local existant.

Ce comportement est volontaire pour permettre :

- developpement offline ;
- recette front sans backend ;
- non-regression des tests actuels ;
- migration utilisateur progressive.

## Interfaces a stabiliser

### Decision profile

Contrat actuel :

```dart
Future<DecisionProfile?> load();
Future<void> save(DecisionProfile profile);
```

Repository cible :

```dart
abstract interface class DecisionProfileRepository {
  Future<DecisionProfile?> load();
  Future<void> save(DecisionProfile profile);
}
```

Source distante :

- table `profiles`;
- ligne active de l'utilisateur ;
- `compiled_profile` ou payload profile selon l'etape d'integration retenue.

Decision verrouillee avant push : le backend stocke les deux formes.

- `decision_profile jsonb` : reponses brutes de l'onboarding, utilisees pour
  reprendre et modifier le formulaire sans perte ;
- `compiled_profile jsonb` : profil compile consomme par les moteurs et futur
  read model serveur.

### Ticket strategies

Contrat actuel :

```dart
Future<List<TicketStrategy>> load();
Future<void> save(List<TicketStrategy> strategies);
```

Repository cible :

```dart
abstract interface class TicketStrategyRepository {
  Future<List<TicketStrategy>> load();
  Future<void> saveAll(List<TicketStrategy> strategies);
}
```

Source distante :

- table `ticket_strategies`;
- upsert par `(user_id, id)`;
- suppression distante des strategies absentes ou operation explicite delete.

### Match favorites

Contrat actuel :

```dart
Future<Set<String>> load();
Future<void> save(Set<String> favoriteIds);
```

Repository cible :

```dart
abstract interface class MatchFavoritesRepository {
  Future<Set<String>> load();
  Future<void> save(Set<String> favoriteIds);
}
```

Source distante :

- table `match_favorites`;
- remplacement atomique du set utilisateur ou diff insert/delete.

### Saved tickets

Contrat actuel :

```dart
Future<List<SavedTicket>> load();
Future<void> saveAll(List<SavedTicket> tickets);
Future<void> upsert(SavedTicket ticket);
Future<void> delete(String ticketId);
```

Repository cible :

```dart
abstract interface class SavedTicketRepository {
  Future<List<SavedTicket>> load();
  Future<void> saveAll(List<SavedTicket> tickets);
  Future<void> upsert(SavedTicket ticket);
  Future<void> delete(String ticketId);
}
```

Source distante :

- `saved_tickets`;
- `saved_ticket_selections`;
- upsert du ticket puis remplacement de ses selections ;
- suppression cascade des selections.

## Migration localStorage -> Supabase

Le premier chargement connecte doit pouvoir migrer les donnees locales.

Sequence implementee :

1. charger le distant ;
2. charger le local ;
3. si le distant est vide et le local non vide, pousser le local ;
4. si le local est vide et le distant non vide, hydrater le cache local ;
5. si les deux existent, fusionner sans suppression silencieuse ;
6. pousser le resultat fusionne vers Supabase ;
7. ecrire le resultat fusionne dans le cache local ;
8. ne jamais supprimer le local automatiquement dans cette iteration.

Regles de fusion :

- `DecisionProfile` : le profil local contenant de vraies reponses
  d'onboarding est prioritaire au moment de la connexion invite -> compte. Si le
  local ne contient qu'une coquille vide, le profil distant est retenu.
- `TicketStrategy` : fusion par `id`, l'element avec le `updatedAt` le plus
  recent gagne en cas de conflit, puis tri par `priority`.
- `SavedTicket` : fusion par `id`, l'element avec le `updatedAt` le plus recent
  gagne en cas de conflit, puis tri chronologique descendant.
- `MatchFavorites` : union des ids locaux et distants.

Objectif : eviter toute perte de donnees pendant la transition.

## Tests sans backend reel

Tests a ajouter pendant le Lot 1B :

- mappers Dart -> payload Supabase -> Dart ;
- fallback local quand Supabase absent ;
- fallback local quand aucun utilisateur connecte ;
- upsert de strategies conserve les bornes nullable ;
- upsert de ticket conserve selections, statuts et modifications ;
- migration local -> distant appelle les operations attendues ;
- aucune UI ne depend directement de Supabase.

## Implementation actuelle sans Docker

Les ecrans continuent d'utiliser les stores existants :

- `SavedDecisionProfileStore`;
- `SavedTicketStrategyStore`;
- `SavedMatchFavoritesStore`;
- `SavedTicketStore`.

Sur web, ces stores :

1. lisent d'abord le cache local ;
2. utilisent Supabase uniquement si un client est initialise et si
   `auth.currentUser` existe ;
3. fusionnent local et distant selon les regles ci-dessus ;
4. synchronisent le resultat fusionne vers Supabase quand necessaire ;
5. synchronisent le cache local quand necessaire ;
6. conservent le local comme fallback dev/offline.

Les repositories Supabase ajoutes sont :

- `SupabaseDecisionProfileRepository`;
- `SupabaseTicketStrategyRepository`;
- `SupabaseMatchFavoritesRepository`;
- `SupabaseSavedTicketRepository`.

Ils ne sont pas importes par les ecrans.

Les helpers de fusion testables hors web sont :

- `local_remote_profile_sync.dart`;
- `local_remote_ticket_sync.dart`;
- `local_remote_favorites_sync.dart`.

## Garde-fous

- Les ecrans ne doivent pas importer `supabase_flutter`.
- La cle anon Supabase reste cote client, jamais la cle service role.
- Les writes user-owned doivent toujours utiliser `auth.uid()` via RLS.
- Les repositories distants ne doivent pas assouplir les contraintes metier.
- Le localStorage reste un fallback, pas une deuxieme source de verite produit
  quand l'utilisateur est connecte et que le distant est disponible.
