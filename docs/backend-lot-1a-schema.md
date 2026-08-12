# Backend Lot 1A - Schema Supabase et persistance produit

Date : 2026-08-10

## Objectif

Le Lot 1A met en place le socle backend produit sans connecter API-Football.

Le backend ne redefine pas le produit. Il persiste les contrats stabilises par le
front/local :

- profil utilisateur compile ;
- strategies de tickets ;
- favoris de rencontres ;
- tickets sauvegardes ;
- selections de tickets ;
- statuts de tickets.

Tous les objets applicatifs sont rattaches a `auth.users` et proteges par RLS
avec `auth.uid()`.

## Migration

Fichier source :

- `supabase/migrations/20260809224753_init_backend_lot_1a.sql`

Cette migration cree uniquement des tables applicatives dans `public`.
Elle ne contient :

- aucune table API-Football ;
- aucun snapshot sportif ;
- aucun job de synchronisation ;
- aucune donnee demo ;
- aucune logique de moteur football.

## Tables

### `public.user_profiles`

Profil applicatif minimal lie a Supabase Auth.

Colonnes principales :

- `id uuid primary key references auth.users(id)`;
- `display_name text`;
- `created_at timestamptz`;
- `updated_at timestamptz`.

Role : disposer d'une ligne applicative user-owned sans toucher a `auth.users`.

### `public.profiles`

Persistance du `CompiledDecisionProfile`.

Colonnes principales :

- `id uuid primary key`;
- `user_id uuid references auth.users(id)`;
- `is_active boolean`;
- `profile_schema_version integer`;
- `onboarding_version text`;
- `configuration_state text`;
- `decision_profile jsonb`;
- `compiled_profile jsonb`;
- `compatibility jsonb`;
- `created_at timestamptz`;
- `updated_at timestamptz`.

Contrainte importante :

- un seul profil actif par utilisateur via index partiel unique.

Le payload `decision_profile` conserve les reponses brutes de l'onboarding afin
de pouvoir rouvrir et modifier exactement le formulaire depuis un autre appareil.

Le payload `compiled_profile` garde la version compilee consommee par les
moteurs. Des colonnes indexables pourront etre ajoutees plus tard si une requete
serveur le necessite.

### `public.ticket_strategies`

Persistance du `TicketStrategy` courant.

Colonnes principales :

- `user_id uuid references auth.users(id)`;
- `id text`;
- `schema_version integer`;
- `name text`;
- `is_active boolean`;
- `pick_types text[]`;
- `minimum_individual_odds numeric(8, 2)`;
- `maximum_individual_odds numeric(8, 2) null`;
- `minimum_selections integer`;
- `maximum_selections integer`;
- `minimum_total_odds numeric(12, 2)`;
- `maximum_total_odds numeric(12, 2) null`;
- `priority integer`;
- `created_at timestamptz`;
- `updated_at timestamptz`.

Cle primaire :

- `(user_id, id)`.

Raisons :

- les ids existants cote front sont des ids metier en texte ;
- la collision entre utilisateurs est evitee par la cle composite ;
- les bornes nullable conservent les bornes ouvertes.

Contraintes :

- `pick_types` non vide et limite a `prudent`, `normal`, `audacious`;
- cote individuelle minimale `>= 1.01`;
- max individuel absent ou `>= min`;
- minimum de selections `> 0`;
- max selections `>= min`;
- cote totale minimale `>= 1`;
- max total absent ou `>= min`.

### `public.match_favorites`

Favoris de rencontres.

Colonnes :

- `user_id uuid references auth.users(id)`;
- `match_id text`;
- `created_at timestamptz`.

Cle primaire :

- `(user_id, match_id)`.

Le front actuel persiste uniquement un `Set<String>` de match ids. Le schema ne
rajoute donc pas de modele metier invente.

### `public.saved_tickets`

Memoire des tickets sauvegardes.

Colonnes principales :

- `user_id uuid references auth.users(id)`;
- `id text`;
- `schema_version integer`;
- `source text`;
- `status text`;
- `name text`;
- `strategy_id text`;
- `strategy_name text`;
- `total_odds numeric(12, 2)`;
- `planned_stake numeric(12, 2)`;
- `played_bookmaker text`;
- `played_stake numeric(12, 2)`;
- `played_actual_total_odds numeric(12, 2)`;
- `played_at timestamptz`;
- `main_combined_reading_id text`;
- `main_combined_reading_label text`;
- `opportunity_ids text[]`;
- `modification_summary text`;
- `modification_details text[]`;
- `created_at timestamptz`;
- `updated_at timestamptz`.

Enums representes par `text` contraint :

- `source in ('copilot', 'copilotModified', 'manual')`;
- `status in ('saved', 'played', 'won', 'lost', 'cancelled')`.

Les informations de declaration de jeu sont gardees sur `saved_tickets` pour ce
lot afin de rester simple. Elles pourront etre extraites plus tard si le cycle de
vie devient plus riche.

### `public.saved_ticket_selections`

Selections rattachees a un ticket sauvegarde.

Colonnes principales :

- `user_id uuid references auth.users(id)`;
- `ticket_id text`;
- `id text`;
- `position integer`;
- `match_id text`;
- `home_team text`;
- `away_team text`;
- `competition_name text`;
- `market_id text`;
- `market_label text`;
- `selection_id text`;
- `selection_label text`;
- `odds numeric(8, 2)`;
- `home_logo_url text`;
- `away_logo_url text`;
- `bookmaker_name text`;
- `opportunity_id text`;
- `created_at timestamptz`.

Contraintes :

- cle primaire `(user_id, ticket_id, id)`;
- foreign key `(user_id, ticket_id)` vers `saved_tickets`;
- `unique (user_id, ticket_id, position)`;
- `unique (user_id, ticket_id, match_id)`.

La derniere contrainte conserve la regle produit : un meme match ne peut pas
apparaitre deux fois dans un ticket.

## RLS

RLS est activee et forcee sur toutes les tables :

- `user_profiles`;
- `profiles`;
- `ticket_strategies`;
- `match_favorites`;
- `saved_tickets`;
- `saved_ticket_selections`.

Chaque table possede des policies user-owned :

- `select` : ligne visible si elle appartient a `auth.uid()`;
- `insert` : insertion autorisee uniquement avec l'id utilisateur courant ;
- `update` : ancienne et nouvelle ligne doivent appartenir a `auth.uid()`;
- `delete` : suppression autorisee uniquement sur ses propres lignes.

Exception volontaire : `match_favorites` n'a pas de policy `update`, car le
contrat actuel est un set d'ajouts/suppressions.

## Validation sans Docker

Docker n'est pas utilise pour le moment. Les validations disponibles sont donc :

- relecture SQL ;
- tests Dart statiques sur la migration ;
- verification des contrats Dart ;
- execution distante plus tard via Supabase Cloud.

Commande de test locale sans Docker :

```sh
flutter test test/backend/supabase_lot_1a_migration_test.dart
```

Commande distante a utiliser plus tard, quand on accepte de pousser vers le
projet Supabase lie :

```sh
npx supabase db push --dry-run
npx supabase db push
```

Ne pas utiliser `db push` tant que la migration n'a pas ete relue et validee
fonctionnellement.

## Prochaine etape : Lot 1B

Le Lot 1B doit ajouter des repositories distants sans changer les contrats
produit consommes par l'interface.

Principe :

```text
UI existante
  -> store/repository produit
  -> source distante si Supabase configure et utilisateur connecte
  -> fallback localStorage en dev/offline
```

Les ecrans ne doivent pas connaitre si la source est locale ou distante.
