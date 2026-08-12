# Refonte du moteur de lecture football et des opportunités

## 1. Objectif

Ce document formalise la prochaine refonte du moteur de décision.

L’objectif n’est pas de créer directement de nouveaux marchés ou de nouveaux tickets. Il s’agit de structurer le moteur autour de quatre niveaux clairement séparés :

```text
Données brutes et snapshots
        ↓
Lectures football élémentaires
        ↓
Opportunities combinées
        ↓
Picks éligibles et tickets optimisés
```

Cette séparation doit permettre :

- d’expliquer chaque recommandation ;
- de faire évoluer les règles sans casser l’ensemble du moteur ;
- de réutiliser les mêmes lectures dans « Pour moi », le détail d’un match et le générateur de tickets ;
- d’ajouter de nouvelles données, comme les xG, sans réécrire toutes les thèses ;
- de préparer le futur moteur de contraintes.

---

## 2. Architecture cible

```text
SNAPSHOTS API-FOOTBALL
        │
        ▼
Football Analyzer
        │
        ├── métriques calculées
        ├── lectures élémentaires
        └── contradictions
        │
        ▼
Opportunity Engine
        │
        ├── combinaison de lectures
        ├── validation des conditions minimales
        └── génération d’arguments et de preuves
        │
        ▼
Profile Filter
        │
        ├── compétitions activées
        ├── opportunityProfiles activés
        └── marchés autorisés
        │
        ▼
Pick Engine
        │
        ├── marchés compatibles
        ├── marché recommandé
        └── pick éligible
        │
        ▼
POOL UNIQUE DE PICKS
        │
        ├── écran « Pour moi »
        ├── détail d’un match
        ├── construction manuelle d’un ticket
        └── Ticket Generator
                │
                ▼
        Constraint Solver
                │
                ▼
        Tickets optimisés
```

### Principe fondamental

Le Football Analyzer ne produit pas directement un pick.

Il produit une lecture du match.

L’Opportunity Engine transforme plusieurs lectures convergentes en une Opportunity.

Le Pick Engine traduit ensuite cette Opportunity en marché concret.

Le Ticket Generator ne réanalyse jamais le football. Il consomme uniquement les picks éligibles issus des Opportunities.

---

## 3. Données disponibles à intégrer

L’audit API-Football a confirmé que les familles de données suivantes sont réellement exploitables :

- contexte du match ;
- standings ;
- statistiques de saison ;
- splits domicile/extérieur ;
- résultats précédents ;
- forme sur les cinq derniers matchs ;
- H2H ;
- blessures ;
- compositions ;
- statistiques joueurs ;
- événements ;
- statistiques post-match ;
- expected goals post-match ;
- cotes pré-match lorsqu’elles sont capturées avant le coup d’envoi.

### Contrainte temporelle

Toute donnée utilisée pour une lecture pré-match doit provenir d’un snapshot horodaté avec un champ `asOf`.

Il est interdit d’utiliser rétroactivement :

- un classement final ;
- des statistiques de saison mises à jour après le match ;
- une composition publiée après la génération initiale ;
- des xG du match en cours ;
- une cote qui n’a pas été capturée avant le coup d’envoi.

---

## 4. Intégration des xG

API-Football retourne les expected goals dans `/fixtures/statistics`.

Chemin JSON :

```text
response[].statistics[].type = "expected_goals"
response[].statistics[].value
```

Exemple vérifié :

```text
Manchester City : 1.34 xG
Aston Villa : 1.77 xG
```

Les xG sont post-match. Ils ne prédisent donc pas directement un match futur.

Ils doivent servir à construire des historiques glissants :

```text
rollingXgFor5
rollingXgAgainst5
rollingXgDifference5
seasonXgForAverage
seasonXgAgainstAverage
goalsMinusXg
goalsConcededMinusXgConceded
```

### Nouvelles lectures xG

- `high_xg_creation` : l’équipe produit régulièrement beaucoup d’occasions de qualité.
- `low_xg_creation` : l’équipe génère peu d’occasions dangereuses.
- `offensive_underperformance` : elle marque moins que ce que sa production xG suggère.
- `offensive_overperformance` : elle marque davantage que ce que sa production xG suggère.
- `high_xg_conceded` : elle concède régulièrement beaucoup d’occasions de qualité.
- `defensive_underperformance` : elle encaisse davantage que les xG concédés.
- `defensive_overperformance` : elle encaisse moins que les xG concédés.
- `misleading_result` : le résultat final ne reflète pas suffisamment la qualité réelle des occasions.

### Précaution

Les notions de surperformance et sous-performance ne doivent jamais être présentées comme une garantie de « retour à la moyenne ».

Elles décrivent une divergence entre production et résultat. Elles constituent un argument ou un point de vigilance, pas une prédiction automatique.

---

## 5. Lectures football élémentaires

Une lecture élémentaire décrit un seul phénomène mesurable.

```dart
class FootballReading {
  final String id;
  final String subjectTeamId;
  final ReadingStatus status;
  final ReadingStrength strength;
  final List<ReadingEvidence> evidence;
  final List<ReadingWarning> warnings;
  final DateTime asOf;
  final int sampleSize;
}
```

### 5.1 Hiérarchie

- `ranking_superiority`
- `balanced_hierarchy`
- `structural_level_gap`

### 5.2 Dynamique

- `positive_streak`
- `negative_streak`
- `improving_form`
- `declining_form`

### 5.3 Domicile et extérieur

- `strong_home_team`
- `weak_home_team`
- `strong_away_team`
- `weak_away_team`
- `home_away_mismatch`

### 5.4 Production offensive

- `prolific_attack`
- `attack_in_form`
- `scoring_difficulty`
- `high_xg_creation`
- `low_xg_creation`
- `offensive_underperformance`
- `offensive_overperformance`

### 5.5 Défense

- `solid_defense`
- `fragile_defense`
- `declining_defense`
- `frequent_clean_sheet`
- `high_xg_conceded`
- `defensive_underperformance`
- `defensive_overperformance`

### 5.6 Profil de buts

- `open_match_profile`
- `closed_match_profile`
- `frequent_btts`
- `frequent_over_25`
- `frequent_under_25`

### 5.7 Qualité des adversaires récents

- `soft_schedule_form`
- `strong_schedule_form`

### 5.8 Effectif et compositions

- `key_absence`
- `lineup_strength_change`

Ces lectures ne sont activées que si leur impact est objectivement démontrable.

### 5.9 Contradictions

- `false_favorite`
- `weakened_favorite`
- `conflicting_signals`
- `insufficient_data`
- `misleading_result`

---

## 6. Opportunities combinées

Une Opportunity ne doit jamais être le simple renommage d’une statistique.

Elle doit résulter d’une combinaison cohérente de plusieurs lectures.

```dart
class Opportunity {
  final String id;
  final String fixtureId;
  final List<String> matchedProfileIds;
  final List<FootballReading> supportingReadings;
  final List<FootballReading> contradictoryReadings;
  final List<CopilotArgument> arguments;
  final List<CompatibleMarket> compatibleMarkets;
  final CompatibleMarket? recommendedMarket;
  final DateTime asOf;
}
```

### 6.1 `expected_domination`

```text
structural_level_gap
+ positive_streak
+ strong_home_team
+ weak_away_team
```

> L’équipe possède une supériorité structurelle, une meilleure dynamique et un contexte domicile/extérieur favorable.

### 6.2 `favorite_with_protection`

```text
ranking_superiority
+ solid_defense
+ une contradiction légère
```

> Le favori reste supérieur, mais certains éléments invitent à privilégier une couverture plutôt qu’une victoire sèche.

### 6.3 `convergent_open_match`

```text
high_xg_creation
+ fragile_defense
+ frequent_over_25
+ frequent_btts
```

> Plusieurs indicateurs convergent vers une rencontre favorable aux buts.

### 6.4 `convergent_closed_match`

```text
solid_defense
+ scoring_difficulty
+ closed_match_profile
+ frequent_clean_sheet
```

> Les deux profils suggèrent une rencontre avec peu d’occasions et peu de buts.

### 6.5 `credible_outsider`

```text
balanced_hierarchy ou écart modéré
+ strong_home_team
+ positive_streak
+ adversaire en dégradation
```

> L’outsider possède plusieurs arguments objectifs qui réduisent l’écart théorique.

### 6.6 `team_in_serious_difficulty`

```text
negative_streak
+ scoring_difficulty
+ fragile_defense
+ weak_away_team
```

> L’équipe cumule plusieurs signaux défavorables dans les résultats, la production offensive et la solidité défensive.

### 6.7 `controlled_favorite`

```text
ranking_superiority
+ solid_defense
+ adversaire en difficulté offensive
+ closed_match_profile
```

> Le favori possède les moyens de contrôler la rencontre sans qu’un scénario très ouvert soit nécessaire.

### 6.8 `both_sides_can_score`

```text
high_xg_creation des deux équipes
+ défenses fragiles
+ frequent_btts
```

### 6.9 `one_sided_scoring`

```text
attaque prolifique
+ défense adverse fragile
+ attaque adverse en difficulté
+ défense du favori solide
```

### 6.10 `team_better_than_results`

```text
negative_streak ou declining_form
+ positive_xg_differential
+ offensive_underperformance
```

> Les résultats sont faibles, mais la qualité des occasions créées reste supérieure à ce que les scores laissent penser.

### 6.11 `team_worse_than_results`

```text
positive_streak
+ negative_xg_differential
+ offensive_overperformance
+ defensive_overperformance
```

> Les résultats récents sont positifs, mais leur solidité statistique paraît limitée.

### 6.12 `avoid_match`

```text
balanced_hierarchy
+ conflicting_signals
+ insufficient_data ou forte instabilité
```

Aucun marché ne doit être proposé automatiquement si la thèse n’est pas suffisamment claire.

---

## 7. Arguments, preuves et contradictions

L’interface ne doit jamais présenter une statistique brute comme information principale.

Ordre obligatoire :

```text
Interprétation
→ Argument
→ Preuve
→ Données complètes repliées
```

Exemple :

```text
Défense fragile

L’équipe a concédé au moins 1,5 xG lors de quatre de ses cinq derniers matchs.

Preuves :
- xG concédés moyens sur 5 matchs : 1,82
- 9 buts encaissés
- 1 clean sheet
```

Une contradiction doit être explicite :

```text
Point de vigilance

L’équipe affiche une série de trois victoires, mais son différentiel xG sur cette période reste négatif.
```

Il ne faut pas afficher de pourcentage de confiance ou de probabilité de réussite.

L’écran peut afficher :

```text
4 arguments
1 point de vigilance
```

---

## 8. Impact sur l’onboarding

L’onboarding demande quels profils d’opportunités l’utilisateur souhaite rechercher.

Cette question reste pertinente, mais elle doit être mieux expliquée.

### Question proposée

## « Quelles situations souhaitez-vous que Copilot recherche ? »

Texte d’introduction :

> Copilot analyse les rencontres à partir du classement, de la forme, des performances domicile/extérieur, des buts, des xG et d’autres données disponibles. Choisissez les types de situations que vous souhaitez retrouver dans « Pour moi ».

### Cartes proposées

#### Favoris solides

> Équipes dont la supériorité est soutenue par plusieurs éléments : classement, dynamique, attaque, défense et contexte domicile/extérieur.

#### Écarts de niveau

> Rencontres dans lesquelles plusieurs indicateurs montrent une différence structurelle entre les équipes.

#### Outsiders crédibles

> Équipes moins attendues par le marché, mais soutenues par leur forme, leur contexte ou la fragilité de l’adversaire.

#### Matchs ouverts

> Rencontres dans lesquelles les attaques, les défenses et la production xG convergent vers un scénario favorable aux buts.

#### Matchs fermés

> Rencontres dans lesquelles les défenses, la faible création offensive et les historiques récents suggèrent peu de buts.

#### Équipes en difficulté

> Équipes qui cumulent mauvais résultats, faible création offensive et fragilité défensive.

#### Attaques prolifiques

> Équipes qui marquent ou produisent régulièrement beaucoup d’occasions de qualité.

#### Défenses fragiles

> Équipes qui encaissent beaucoup ou concèdent régulièrement des occasions dangereuses.

#### Séries positives

> Équipes qui obtiennent de bons résultats récemment, avec une indication lorsque cette série est confirmée ou fragilisée par les xG.

#### Séries négatives

> Équipes en mauvaise dynamique, avec une distinction entre difficultés réelles et résultats potentiellement trompeurs.

### Recommandation UX

Ne pas exposer les identifiants techniques des lectures.

L’utilisateur choisit uniquement des familles d’Opportunities compréhensibles.

Les lectures élémentaires restent internes au moteur.

---

## 9. Meilleure exploitation pour l’utilisateur

### Dans « Pour moi »

Une rencontre apparaît une seule fois et peut correspondre à plusieurs profils.

```text
Arsenal — Tottenham

4 lectures détectées

Favori solide
Écart de niveau
Défense adverse fragile
Série positive

Marché recommandé :
Double chance 1X · 1.42
```

La carte doit afficher :

1. les équipes ;
2. le titre principal de l’Opportunity ;
3. le nombre d’arguments ;
4. les principaux profils détectés ;
5. un résumé court ;
6. le marché recommandé éventuel ;
7. l’action « Voir l’analyse ».

Une Opportunity sans marché recommandé reste visible.

### Dans le détail d’un match

Ordre cible :

```text
Header
→ Lecture Copilot
→ Arguments
→ Points de vigilance
→ Marché recommandé
→ Autres marchés compatibles
→ Vérifier les données
```

Les arguments doivent permettre d’ouvrir leurs preuves :

- voir le classement ;
- voir la forme ;
- voir les résultats ;
- voir les xG récents ;
- voir les splits domicile/extérieur ;
- voir les absences.

### Dans le Ticket Generator

Le générateur consomme uniquement les picks issus des Opportunities.

Il peut utiliser comme critères internes :

- nombre d’arguments ;
- nombre de contradictions ;
- diversité des profils ;
- qualité de l’échantillon ;
- fraîcheur des données ;
- conformité à la stratégie ;
- cohérence entre lectures et marché recommandé.

Il ne doit pas utiliser un score opaque visible par l’utilisateur.

---

## 10. Seuils et calibration

Aucun seuil ne doit être ajouté arbitrairement sans documentation.

Chaque lecture doit définir :

```text
- métriques requises ;
- taille minimale d’échantillon ;
- fenêtre statistique ;
- seuil minimal ;
- seuil fort ;
- split domicile/extérieur ;
- contradictions ;
- règle de neutralisation ;
- message utilisateur ;
- preuve affichable.
```

```dart
class ReadingRule {
  final String id;
  final int minimumSampleSize;
  final Duration freshnessLimit;
  final List<MetricRequirement> requiredMetrics;
  final List<ThresholdRule> thresholds;
  final List<String> contradictionReadingIds;
  final ReadingExplanationTemplate explanation;
}
```

Les seuils doivent être externalisés dans un catalogue métier et testés indépendamment.

---

## 11. Première version recommandée

### Lectures prioritaires

```text
ranking_superiority
balanced_hierarchy
structural_level_gap
positive_streak
negative_streak
improving_form
declining_form
strong_home_team
weak_away_team
prolific_attack
scoring_difficulty
solid_defense
fragile_defense
frequent_btts
frequent_over_25
frequent_clean_sheet
high_xg_creation
low_xg_creation
high_xg_conceded
offensive_underperformance
offensive_overperformance
defensive_overperformance
misleading_result
conflicting_signals
insufficient_data
```

### Opportunities prioritaires

```text
expected_domination
favorite_with_protection
convergent_open_match
convergent_closed_match
credible_outsider
team_in_serious_difficulty
controlled_favorite
both_sides_can_score
one_sided_scoring
team_better_than_results
team_worse_than_results
avoid_match
```

---

## 12. Plan de migration

### Étape 1 — Protéger l’existant

- conserver les tests actuels ;
- documenter les thèses existantes ;
- ne supprimer aucune règle avant d’avoir une projection équivalente.

### Étape 2 — Introduire les métriques normalisées

Créer des read-models :

```text
FixtureContext
StandingContext
RecentFormContext
HomeAwayContext
GoalProfileContext
ExpectedGoalsContext
AvailabilityContext
MarketSnapshot
```

### Étape 3 — Créer le Football Analyzer

Il produit uniquement des `FootballReading`.

### Étape 4 — Créer l’Opportunity Engine V2

Il combine les lectures et produit une seule Opportunity par match.

### Étape 5 — Adapter le Profile Filter

Il filtre les Opportunities selon les profils activés.

### Étape 6 — Adapter le Pick Engine

Il sélectionne les marchés compatibles sans réanalyser les statistiques.

### Étape 7 — Adapter les écrans

- « Pour moi » consomme les Opportunities V2 ;
- le détail affiche arguments et contradictions ;
- le générateur consomme le pool de picks.

---

## 13. Checklist obligatoire

### Données

- [ ] snapshots horodatés avec `asOf` ;
- [ ] aucune donnée postérieure utilisée en pré-match ;
- [ ] xG stockés après chaque match ;
- [ ] cotes stockées avant coup d’envoi ;
- [ ] distinction données factuelles / predictions API ;
- [ ] taille d’échantillon disponible.

### Football Analyzer

- [ ] lectures élémentaires indépendantes ;
- [ ] aucune sélection de marché ;
- [ ] preuves attachées ;
- [ ] contradictions attachées ;
- [ ] données insuffisantes gérées ;
- [ ] tests unitaires par lecture.

### Opportunity Engine

- [ ] combinaisons explicites ;
- [ ] une seule Opportunity par rencontre ;
- [ ] plusieurs profils possibles ;
- [ ] aucune duplication ;
- [ ] Opportunity possible sans marché ;
- [ ] `avoid_match` possible.

### xG

- [ ] `expected_goals` parsé ;
- [ ] xG pour et contre attribués correctement ;
- [ ] agrégats sur cinq matchs ;
- [ ] agrégats saison ;
- [ ] divergences buts/xG ;
- [ ] aucun usage futuriste des xG ;
- [ ] absence de xG gérée sans erreur.

### Onboarding

- [ ] question reformulée ;
- [ ] descriptions courtes ;
- [ ] familles compréhensibles ;
- [ ] aucune lecture technique exposée ;
- [ ] profils non supportés désactivés ou masqués ;
- [ ] modification après onboarding possible.

### UI

- [ ] arguments avant statistiques ;
- [ ] contradictions visibles ;
- [ ] aucune confiance en pourcentage ;
- [ ] preuves consultables ;
- [ ] Opportunity sans marché affichée ;
- [ ] une seule carte par match.

### Régression

- [ ] `dart format` ;
- [ ] `flutter analyze` ;
- [ ] `flutter test` ;
- [ ] aucun changement silencieux des règles existantes ;
- [ ] documentation des seuils ;
- [ ] rapport de migration.

---

## 14. Rapport attendu de l’agent

À la fin de l’itération, fournir :

1. architecture réellement mise en place ;
2. contrats créés ou modifiés ;
3. métriques disponibles ;
4. lectures implémentées ;
5. Opportunities implémentées ;
6. règles non encore supportées ;
7. mapping lecture → Opportunity ;
8. mapping Opportunity → marchés compatibles ;
9. modifications de l’onboarding ;
10. captures de « Pour moi » et du détail d’un match ;
11. résultat détaillé de la checklist ;
12. tests exécutés ;
13. limites et éléments reportés.

---

## 15. Interdictions

Ne pas ajouter :

- de score prédictif visible ;
- de pourcentage de réussite ;
- d’IA conversationnelle ;
- de nouvelles disciplines ;
- de pari système ;
- de seuils non documentés ;
- d’argument reposant sur une donnée postérieure au snapshot ;
- de « joueur clé » subjectif ;
- de conclusion football non traçable vers des preuves.

Le produit doit rester explicable :

> Chaque Opportunity doit pouvoir répondre à la question « Pourquoi ce match apparaît-il dans Pour moi ? » avec des arguments précis, vérifiables et horodatés.
