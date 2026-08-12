# Architecture du projet

## Objectif

Vector est une application Flutter mobile-first qui sert de copilote de decision
football. Le front actuel permet de valider le produit en local avant backend :
onboarding, lectures, opportunites, tickets, historique et themes.

L'application ne cherche pas a predire un resultat. Elle organise des donnees,
detecte des lectures simples, construit des lectures combinees, propose un
marche compatible et explique les raisons de cette lecture.

## Principes structurants

- Le moteur de decision est deterministe.
- L'IA ne participe pas aux calculs, classements ou generations de tickets.
- Aucune promesse de gain, de probabilite ou de score predictif ne doit etre
  affichee.
- Toute lecture doit etre explicable par des arguments et des points de
  vigilance.
- Les tickets sont construits uniquement depuis les opportunites et les
  strategies persistées.
- Le front local ne remplace pas le backend : snapshots, stockage local et
  donnees demo servent uniquement a la validation MVP.

## Organisation des dossiers

- `lib/main.dart` : bootstrap de l'application.
- `lib/app` : composition Flutter, router, theme et navigation.
- `lib/core` : configuration, injection de dependances, theme et infrastructure.
- `lib/features/onboarding` : onboarding V3, compilation du profil et stockage
  local de developpement.
- `lib/features/matches` : flux des rencontres, lectures football, opportunites,
  ecrans "Pour moi", "Toutes les rencontres" et "Detail rencontre".
- `lib/features/opportunities` : objet metier `Opportunity`.
- `lib/features/tickets` : strategies, generateur, ticket courant, sauvegarde
  locale et historique.
- `lib/l10n` : traductions FR/EN.
- `tool` : scripts de generation et exploration de snapshots.
- `docs` : documentation technique et produit.

## Donnees et environnements

La configuration passe par `--dart-define`.

```sh
flutter run --dart-define=APP_ENV=development
```

Le repository de rencontres supporte trois modes conceptuels :

- `demo` : donnees embarquees pour tests rapides ;
- `snapshot` : donnees API-Football normalisees depuis un fichier local ;
- `api` : reserve au backend securise futur.

En developpement, le snapshot est la source de validation principale. Il doit
etre horodate, centre sur le jour courant et couvrir une fenetre utile de jours.
En production, les appels API-Football devront passer par un backend.

## Onboarding et profil

L'onboarding principal est le parcours V3 compact.

Il permet de configurer :

- competitions suivies ;
- marches joues ;
- profils de lectures/opportunites recherches ;
- strategies de tickets.

Le profil compile ne contient pas de preference de construction de ticket. Les
strategies sont des objets separes et persistés localement en MVP.

Un profil incomplet bloque la personnalisation dans "Pour moi". Un profil
complet sans strategie permet les lectures personnalisees mais ne genere aucun
ticket automatique.

## Lectures et opportunites

Le pipeline front est :

```text
Donnees normalisees
  -> lectures simples
  -> lectures combinees
  -> marche recommande compatible
  -> Opportunity
  -> Pick
  -> Ticket
```

Une lecture simple est un signal structure : dynamique, hierarchie, domicile,
defense, attaque, buts, xG ou vigilance.

Une lecture combinee existe lorsque plusieurs lectures simples racontent une
histoire coherente pour une rencontre.

Une `Opportunity` est l'unite metier canonique consommee par "Pour moi" et par
le generateur de tickets. Une opportunite peut exister sans marche recommande.

## Tickets

Le composant "Mon ticket" est la source de verite du ticket courant :

- un seul ticket courant partage entre les ecrans ;
- ajout/retrait en temps reel ;
- interdiction de plusieurs selections du meme match ;
- cote totale recalculee ;
- sauvegarde locale ;
- declaration joue/gagne/perdu/annule/non joue.

Le `TicketGenerator` consomme uniquement :

- les opportunites du jour cible ;
- les `TicketStrategy` actives persistées ;
- les contraintes strictes de chaque strategie.

Il ne melange jamais plusieurs jours dans un meme ticket et n'assouplit jamais
silencieusement une contrainte.

## Historique

L'historique est une memoire locale produit. Il distingue :

- tickets Copilot ;
- tickets Copilot modifies ;
- tickets manuels.

Les KPI, filtres, statuts et details sont calcules depuis les tickets sauvegardes
localement. La persistance distante sera ajoutee avec le backend.

## Theme

Le theme est centralise autour de `VectorThemeTokens` et de ThemeExtensions.

Themes disponibles :

- Vector Dark ;
- Vector Light ;
- Vector Gold ;
- Vector Aurora.

Les widgets doivent consommer `Theme.of(context)` et les extensions de theme. Les
couleurs metier des lectures passent par `AppOpportunityPalette` et ses styles
de badges.

## Hors perimetre front local

Les elements suivants restent volontairement hors backend pour cette fondation :

- authentification utilisateur reelle ;
- base distante des profils, strategies, favoris et tickets ;
- synchronisation API-Football de production ;
- stockage immuable des cotes et snapshots ;
- reglement automatique des tickets ;
- notifications ;
- analytics ;
- paiements ou offres premium.
