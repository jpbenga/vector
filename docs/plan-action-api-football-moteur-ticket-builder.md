# Plan d'action — API-Football, moteur et générateur de ticket

## Objectif

Mettre en place une progression testable, sans connecter trop tôt l'interface à
une logique métier instable.

Le fil directeur est :

```text
API-Football
  -> données normalisées
  -> Profile Compiler
  -> profil décisionnel normalisé
  -> moteur déterministe
  -> générateur de ticket
  -> interface explicable
```

Le moteur ne doit jamais connaître les numéros de questions de l'onboarding. Il
travaille uniquement avec un profil métier compilé.

## Phase 1 — Exploration API-Football

But : savoir précisément quels endpoints utiliser, quelles données sont
disponibles selon les championnats et comment gérer les périodes hors saison.

Endpoints à explorer :

- `leagues` : pays, championnats, saisons, coverage disponible.
- `fixtures` : calendrier, matchs passés/futurs, statut, équipes, scores.
- `standings` : classements par championnat/saison.
- `teams/statistics` : statistiques d'équipe sur une compétition.
- `fixtures/statistics` : statistiques d'un match.
- `fixtures/events` : buts, cartons et événements.
- `injuries` : blessés, suspendus, incertains.
- `odds/mapping` : fixtures compatibles avec les cotes.
- `odds/bets` : mapping des marchés prématch.
- `odds/bookmakers` : bookmakers disponibles.
- `odds` : cotes prématch par fixture, ligue, date, bookmaker et marché.
- `odds/live` et `odds/live/bets` : à documenter, mais pas prioritaires pour la
  V1 prématch.
- `predictions` : à explorer avec prudence, comme source informative éventuelle,
  pas comme moteur de décision principal.

Livrable :

- `docs/api-football-exploration.md`
- mapping des IDs API-Football vers nos pays, championnats, équipes, marchés et
  bookmakers ;
- liste des champs réellement utiles au moteur ;
- liste des champs utiles seulement à l'affichage ;
- limites constatées : coverage, saisons, pagination, disponibilité des cotes,
  quotas.

## Phase 2 — Données de test fluides

But : pouvoir tester sans dépendre de la disponibilité immédiate des grands
championnats.

Modes à prévoir :

- `demo` : données codées actuellement dans l'app.
- `snapshot` : réponses API sauvegardées localement après exploration.
- `api` : appels réels via backend/proxy sécurisé.

Règle importante : Flutter ne doit pas appeler API-Football directement avec une
clé embarquée côté client. Les appels réels devront passer par une couche serveur
ou une fonction Supabase.

Livrable :

- schéma des snapshots JSON ;
- `docs/api-football-snapshots.md` comme contrat local des snapshots V1 ;
- stratégie de cache ;
- jeu de données minimal pour recetter pays -> championnat -> calendrier ->
  rencontres -> stats -> cotes.

## Phase 3 — Profile Compiler

But : transformer les réponses d'onboarding en profil métier stable.

À produire :

- `profile_schema_version`
- modèle `CompiledDecisionProfile`
- compilateur déterministe depuis `DecisionProfile`
- tests unitaires de mapping

Le profil compilé doit contenir au minimum :

- compétitions activées, poidsées ;
- marchés activés, poidsés, avec seuil de cote minimum ;
- critères d'analyse et priorités d'affichage ;
- types de rencontres préférés ;
- préférences ticket : tailles et plages de cotes ;
- profondeur d'affichage issue de Q9/Q11 ;
- importance normalisée des cotes ;
- métadonnées comportementales.

Livrable :

- code du compilateur ;
- tests unitaires lisibles.

## Phase 4 — Normalisation des données match

But : isoler l'application du format brut API-Football.

À produire :

- modèles internes : compétition, équipe, fixture, marché, cote, statistique,
  absence, classement ;
- adaptateurs API-Football -> modèles internes ;
- gestion de la coverage manquante.

Le moteur ne consomme jamais la réponse API brute.

## Phase 5 — Moteur déterministe V1

But : produire des recommandations explicables, sans IA et sans formule opaque.

Principe :

- filtrer par compétitions activées ;
- filtrer par marchés activés ;
- filtrer par seuils de cote utilisateur ;
- calculer des signaux métier ;
- appliquer le profil compilé ;
- produire un classement et des explications.

À éviter :

- addition naïve de toutes les réponses onboarding ;
- utilisation directe des numéros Q1, Q2, etc. ;
- interprétation de la cote comme probabilité de réussite.

## Phase 6 — Générateur de ticket V1

But : composer des tickets à partir des recommandations déjà classées.

Le générateur intervient après le ranking.

Contraintes :

- tailles issues de Q6 : `1`, `1-2`, `2-3`, `2-4`, `3-6`, `6+` ;
- plages de cote totale issues de Q7 ;
- marchés éligibles ;
- seuils Q8 ;
- pas de doublons incohérents sur un même match ;
- explication lisible du ticket proposé.

Livrables :

- `docs/ticket-builder-v1.md`
- générateur déterministe ;
- tests sur combinaisons simples ;
- écran de recettage avec ticket principal et alternatives.

## Informations attendues

À fournir dans `.env` :

```text
API_FOOTBALL_KEY=
API_FOOTBALL_BOOKMAKER_ID=
SUPABASE_URL=
SUPABASE_ANON_KEY=
```

À décider ensemble :

- bookmakers MVP : Betfair `3`, Pinnacle `4`, Bwin `6`, Bet365 `8`,
  1xBet `11`, Unibet `16` ;
- championnats prioritaires pour l'exploration ;
- saison cible à explorer pendant la période hors saison ;
- profondeur minimum des données affichées dans l'onglet `Tous les matchs` ;
- règles de composition de ticket à interdire dès la V1.

## Critères de recettage progressif

Chaque phase doit être testable indépendamment :

- exploration API : endpoints documentés avec exemples de payloads ;
- snapshots : l'app fonctionne sans réseau réel ;
- Profile Compiler : profil compilé affichable et testé ;
- données match : l'onglet `Tous les matchs` utilise des modèles normalisés ;
- moteur : chaque recommandation indique pourquoi elle est éligible ;
- ticket builder : chaque ticket indique taille, cote totale, marchés et raison
  de composition.
