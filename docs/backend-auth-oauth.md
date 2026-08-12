# Auth Supabase OAuth - Lector Sport

Ce document décrit le socle d'authentification minimal du Lot Backend 1B.

## Objectif

L'authentification ne redéfinit pas le produit. Elle sert uniquement à rattacher les données déjà stabilisées côté front/local à un utilisateur Supabase :

- profil de décision compilé ;
- stratégies de tickets ;
- favoris de matchs ;
- tickets sauvegardés ;
- sélections d'un ticket sauvegardé.

L'application reste utilisable en mode local si Supabase n'est pas configuré ou si l'utilisateur n'est pas connecté.

## Providers retenus

Le MVP utilise une authentification sociale via Supabase Auth :

- Google ;
- Apple.

Ce choix évite un parcours email/mot de passe plus long et correspond au standard attendu sur mobile.

## Configuration requise

Dans Supabase Dashboard :

1. activer le provider Google ;
2. activer le provider Apple ;
3. renseigner les secrets OAuth côté Supabase ;
4. ajouter les URLs de redirection utilisées par l'application web et mobile.

Côté application, seules les variables publiques suivantes sont utilisées :

```sh
SUPABASE_URL
SUPABASE_ANON_KEY
APP_PUBLIC_URL
```

Aucune clé `service_role` ne doit être embarquée dans le client Flutter.

Pour un déploiement web, `APP_PUBLIC_URL` doit être l'origine publique de
l'application, par exemple :

```sh
APP_PUBLIC_URL=https://lector-sports.vercel.app/
```

Cette valeur est injectée au build et utilisée comme `redirectTo` OAuth. Elle
évite qu'un callback Google/Supabase revienne vers une URL de développement
comme `localhost`.

Dans Supabase `Authentication -> URL Configuration`, la production doit aussi
utiliser :

```text
Site URL:
https://lector-sports.vercel.app

Redirect URLs:
https://lector-sports.vercel.app
https://lector-sports.vercel.app/**
```

Les URLs locales peuvent rester dans la liste des redirect URLs pour le
développement, mais elles ne doivent pas être la `Site URL` de production.

## Comportement applicatif

Le bouton de compte est disponible dans le header principal.
Il ouvre un panel brandé `Lector Sport` / `Read the Game.` avec trois chemins :

- connexion Google ;
- connexion Apple ;
- continuation en local.

Si Supabase n'est pas configuré :

- l'application affiche le mode local ;
- les boutons Google et Apple sont désactivés ;
- aucun appel réseau Supabase n'est tenté.

Si Supabase est configuré mais que l'utilisateur n'est pas connecté :

- l'utilisateur peut se connecter avec Google ou Apple ;
- après connexion, les stores relisent les données persistées ;
- les repositories distants prennent le relais via les mêmes interfaces.

Si l'utilisateur est connecté :

- les données sont sauvegardées localement puis synchronisées vers Supabase ;
- la déconnexion est possible depuis le même panneau ;
- le moteur de lectures, le Pick Engine et le Ticket Generator restent inchangés.

## Stratégie local vers distant

Les stores web conservent le comportement suivant :

- lecture locale en premier pour garder un démarrage rapide ;
- lecture distante si Supabase est configuré et si l'utilisateur est connecté ;
- si la donnée distante est vide et qu'une donnée locale existe, la donnée locale est poussée vers Supabase ;
- en cas d'erreur distante, le local reste le fallback.

Cette stratégie permet de connecter un compte sans perdre le profil déjà créé localement.

## Sécurité

La sécurité des données utilisateur repose sur :

- `auth.users` comme source d'identité ;
- tables applicatives dans `public` ;
- colonnes `user_id uuid not null references auth.users(id)` ;
- RLS activée et forcée ;
- politiques `auth.uid() = user_id`.

Le schéma SQL correspondant est défini dans :

- `supabase/migrations/20260809224753_init_backend_lot_1a.sql`

## Limites volontaires

Ce lot ne contient pas encore :

- appel API-Football côté backend ;
- synchronisation de snapshots sportifs ;
- règlement automatique des tickets ;
- migration du Football Analyzer côté serveur ;
- écran de gestion avancée du compte.
