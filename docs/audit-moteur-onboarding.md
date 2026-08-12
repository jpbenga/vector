# Audit moteur actuel et onboarding

Date d'audit : 31 juillet 2026

## Résumé

Il existe déjà plusieurs documents sur le moteur, le profil décisionnel et
l'onboarding, mais aucun document unique ne détaille à la fois :

- ce que fait le moteur réellement implémenté aujourd'hui ;
- comment les réponses de l'onboarding sont transformées ;
- la liste complète des questions V1.1 ;
- les écarts entre documentation cible et code actuel.

Le présent document sert donc d'audit consolidé.

## Documents existants

| Document | Couverture | Statut audit |
|---|---|---|
| `docs/Architecture_Moteur_Decision_Profile_Profile_Compiler.md` | Architecture cible moteur, séparation onboarding/profile/moteur, typologie des questions. | Très utile, mais plus conceptuel que descriptif de l'implémentation actuelle. |
| `docs/profile-schema-v1.md` | Contrat `CompiledDecisionProfile` et mapping des marchés. | Aligné avec le code principal. |
| `docs/decision-engine-v0-checklist.md` | Checklist de validation V0. | Utile pour confirmer les intentions, mais ne détaille pas les règles internes. |
| `docs/architecture.md` | Architecture générale et onboarding. | Mis à jour pendant cet audit pour refléter l'existence du moteur V0. |
| `README.md` | Présentation projet et liens docs. | Mis à jour pendant cet audit pour refléter l'existence du moteur V0 et pointer vers ce document. |
| `Copilot V1 — Le Moteur de Décision (1).pdf` | Document produit moteur. | Présent comme source produit, non maintenu dans le flux Markdown. |
| `Copilot V1 — Onboarding et Profil Utilisateur.pdf` | Document produit onboarding/profil. | Présent comme source produit, non maintenu dans le flux Markdown. |

Conclusion : la connaissance existe, mais elle est fragmentée. Le code actuel
va plus loin que certains documents Markdown historiques.

## Architecture réelle actuelle

Le flux actuel est :

```text
OnboardingQuestionnaire V1.1
  -> DecisionProfile
  -> ProfileCompiler
  -> CompiledDecisionProfile schema v1
  -> MatchFeedRepository
  -> MatchInsightEngine
  -> MatchBoardItem personnalisé
```

Les fichiers centraux sont :

- `lib/features/onboarding/data/onboarding_questionnaire.dart`
- `lib/features/onboarding/domain/profile_compiler.dart`
- `lib/features/onboarding/domain/compiled_decision_profile.dart`
- `lib/features/matches/domain/match_insight_engine.dart`
- `lib/features/matches/domain/match_board_item.dart`
- `lib/features/matches/data/match_feed_repository.dart`

Le moteur est déterministe : à données de match et profil identiques, il produit
le même classement, la même thèse et le même marché recommandé.

## Contrat entre onboarding et moteur

Le moteur ne lit pas les réponses brutes de l'onboarding. Il consomme un
`CompiledDecisionProfile`, construit par `ProfileCompiler`.

Le profil compilé contient :

- `onboardingVersion`
- `profileSchemaVersion`
- `competitions`
- `markets`
- `analysisCriteria`
- `decisionInfluences`
- `matchTypes`
- `ticketSelectionCounts`
- `ticketOddsRanges`
- `bettingApproaches`
- `feedDepth`
- `oddsImportance`
- `analysisTimeId`
- `bettingFrequencyId`

Les préférences ordonnées sont transformées en :

| Priorité | Poids |
|---|---:|
| 1 | 1.00 |
| 2 | 0.80 |
| 3 | 0.60 |
| 4 | 0.40 |
| 5+ | 0.20 |

Une option non sélectionnée reste présente dans le profil compilé avec :

```text
enabled = false
priority = null
weight = 0
```

Ce point est important : le catalogue reste stable même quand l'utilisateur
retire une option.

## Ce que fait le moteur actuel

Le moteur actuel est `MatchInsightEngine`.

### 1. Filtrer les compétitions

Dans le flux personnalisé, une rencontre est analysée uniquement si sa
compétition est activée dans le profil :

```text
profile.isCompetitionEnabled(match.competition.id)
```

Une compétition désactivée ne peut donc pas apparaître dans la vue personnalisée.
En revanche, une rencontre hors profil peut toujours être analysée en détail :
elle reçoit alors un statut `outOfProfile`, une compatibilité `0`, et une thèse
éventuelle en surveillance.

### 2. Détecter des thèses sportives

Le moteur cherche plusieurs candidats de thèse, puis les trie par confiance
interne décroissante.

Thèses actuellement codées :

| Thèse | Id | Données utilisées | Marchés visés |
|---|---|---|---|
| Favori solide | `solid_favorite` | Favori 1N2, classement, forme, fiabilité. | `matchResult` |
| Double chance prudente | `cautious_double_chance` | Favori 1N2, classement, forme. | `doubleChance` |
| Écart de niveau | `level_gap` | Rang, points, confirmation éventuelle du marché. | `doubleChance`, puis `matchResult` |
| Match ouvert | `open_match` | Moyennes de buts marqués/encaissés. | `goalsTotal` over 2.5 |
| Match fermé | `closed_match` | Moyennes de buts marqués/encaissés. | `goalsTotal` under 2.5 |
| Outsider crédible | `credible_outsider` | Cote outsider, classement, forme, fiabilité. | `doubleChance`, puis `matchResult` |
| Aucune thèse suffisante | `no_sufficient_thesis` | Cas de repli. | Aucun |

La cote ne crée pas seule une recommandation. Elle peut aider à qualifier une
thèse, mais le moteur exige aussi des signaux sportifs.

### 3. Choisir un marché compatible

Une thèse recommandable expose des intentions de marché. Le moteur ne retient un
marché que si :

- le marché existe dans `match.availableMarkets` ;
- le marché est activé dans le profil compilé ;
- la sélection attendue existe ;
- la cote respecte le seuil minimal utilisateur ;
- la cote ne dépasse pas le plafond interne éventuel de la thèse.

Si une thèse existe mais qu'aucun marché ne respecte ces contraintes, la
rencontre passe en `watchlist` et n'est pas recommandée.

### 4. Calculer la compatibilité

La compatibilité affichée correspond à la confiance de la thèse retenue,
uniquement si :

- la compétition est dans le profil ;
- la thèse est `recommended` ;
- un marché recommandé existe.

Sinon, la compatibilité est `0`.

Le score de confiance est plafonné à `96`.

### 5. Trier et limiter les recommandations

Les recommandations sont triées par :

1. compatibilité décroissante ;
2. date de coup d'envoi croissante si disponible ;
3. nom de l'équipe à domicile.

Le nombre final de recommandations dépend de la question 11 :

| Niveau Q11 | `feedDepth` |
|---:|---:|
| 1 | 5 |
| 2 | 8 |
| 3 | 10 |
| 4 | 15 |
| 5 | 20 |

### 6. Produire des explications auditables

Le moteur produit :

- une `MatchThesis` avec titre, résumé, statut, confiance, preuves, limites et
  marché recommandé éventuel ;
- une liste de `CopilotArgument` structurés par famille ;
- un `MatchSignal` lisible avec les preuves principales.

Les familles d'arguments actuelles sont :

- marché ;
- hiérarchie ;
- performance ;
- défense ;
- attaque ;
- forme ;
- rythme ;
- contradiction.

## Mapping marchés onboarding vers moteur

| Option onboarding | Marché interne |
|---|---|
| `match_result` | `matchResult` |
| `both_teams_score` | `bothTeamsScore` |
| `team_scores` | `teamTotalHome`, `teamTotalAway` |
| `goals_over_under` | `goalsTotal` |
| `corners` | `cornersTotal` |
| `cards` | `cardsTotal` |
| `double_chance` | `doubleChance` |

Point d'audit : seuls `matchResult`, `doubleChance` et `goalsTotal` sont
actuellement utilisés par les thèses du moteur. Les marchés `bothTeamsScore`,
`teamTotalHome`, `teamTotalAway`, `cornersTotal` et `cardsTotal` sont bien
présents dans le profil compilé, mais n'ont pas encore de thèses de
recommandation associées dans le moteur V0.

## Questions d'onboarding V1.1

Le questionnaire contient 13 questions.

| Q | Id | Type | Question FR | Effet actuel |
|---:|---|---|---|---|
| 1 | `competitions` | Sélection multiple ordonnée | Quelles compétitions suivez-vous ? | Filtre dur de la vue personnalisée ; priorité et poids compilés. |
| 2 | `markets` | Sélection multiple ordonnée | Quels marchés jouez-vous le plus souvent ? | Filtre d'éligibilité des marchés ; mapping vers IDs internes. |
| 3 | `analysis_elements` | Sélection multiple ordonnée | Lorsque vous analysez une rencontre, quels éléments regardez-vous en priorité ? | Compilé en `analysisCriteria`; effet moteur direct très limité aujourd'hui. |
| 4 | `final_decision_influences` | Sélection multiple ordonnée | Qu'est-ce qui influence le plus votre décision finale ? | Compilé en `decisionInfluences`; peu exploité par les règles actuelles. |
| 5 | `match_types` | Sélection multiple ordonnée | Quels types de rencontres recherchez-vous le plus souvent ? | Utilisé pour produire des raisons de lien profil sur certaines thèses. |
| 6 | `ticket_selection_counts` | Sélection multiple ordonnée | Combien de sélections aimez-vous généralement mettre dans vos tickets ? | Compilé, mais ticket builder non implémenté. |
| 7 | `ticket_odds_ranges` | Plages de cotes éditables et ordonnées | Quels types de tickets jouez-vous selon leur cote totale ? | Compilé, mais ticket builder non implémenté. |
| 8 | `market_minimum_odds` | Seuils de cote par marché | Pour chacun de vos marchés favoris, à partir de quelle cote ce marché devient-il intéressant pour vous ? | Filtre d'éligibilité des sélections recommandées. |
| 9 | `analysis_time` | Choix unique | Combien de temps consacrez-vous généralement à l'analyse de vos paris ? | Compilé ; sert à limiter le nombre de signaux, même si le moteur produit aujourd'hui un signal principal par thèse. |
| 10 | `betting_frequency` | Choix unique | À quelle fréquence pariez-vous ? | Compilé comme métadonnée comportementale ; pas d'effet moteur direct aujourd'hui. |
| 11 | `match_volume_preference` | Échelle 1-5 | Préférez-vous analyser peu de rencontres en profondeur ou disposer de davantage de possibilités ? | Détermine `feedDepth`, donc le volume de recommandations. |
| 12 | `betting_approaches` | Sélection multiple ordonnée | Si vous deviez résumer votre manière de parier, quelles approches vous ressemblent le plus ? | Utilisé pour produire des raisons de lien profil sur certaines thèses. |
| 13 | `odds_importance` | Échelle 1-5 | Quelle importance la cote a-t-elle dans votre décision finale ? | Compilé en poids normalisé, mais pas encore utilisé dans le choix ou score moteur. |

## Options par question

### Q1 - Compétitions

- `fr_ligue_1` : France - Ligue 1
- `fr_ligue_2` : France - Ligue 2
- `eng_premier_league` : Angleterre - Premier League
- `eng_championship` : Angleterre - Championship
- `esp_laliga` : Espagne - LaLiga
- `esp_laliga_2` : Espagne - LaLiga 2
- `ita_serie_a` : Italie - Serie A
- `ita_serie_b` : Italie - Serie B
- `ger_bundesliga` : Allemagne - Bundesliga
- `ger_2_bundesliga` : Allemagne - 2. Bundesliga
- `por_liga_portugal` : Portugal - Liga Portugal
- `por_liga_2` : Portugal - Liga Portugal 2
- `champions_league` : Champions League
- `europa_league` : Europa League
- `conference_league` : Conference League

### Q2 - Marchés

- `match_result` : 1 N 2
- `both_teams_score` : But pour les 2 équipes
- `team_scores` : But équipe domicile / extérieur
- `goals_over_under` : Over / Under buts
- `corners` : Corners
- `cards` : Cartons
- `double_chance` : Double chance

### Q3 - Éléments d'analyse

- `ranking` : Classement
- `recent_form` : Forme récente
- `home_away_form` : Performances domicile / extérieur
- `injuries_suspensions` : Blessures et suspensions
- `head_to_head` : Confrontations directes
- `offensive_defensive_stats` : Statistiques offensives / défensives
- `motivation_context` : Contexte et motivation
- `schedule_fatigue` : Calendrier et fatigue

### Q4 - Influences de décision

- `match_reading` : Lecture globale du match
- `odds_level` : Niveau de cote
- `risk_feeling` : Ressenti du risque
- `team_reliability` : Fiabilité des équipes
- `market_consistency` : Cohérence du marché
- `ticket_balance` : Équilibre du ticket
- `available_time` : Temps disponible pour vérifier

### Q5 - Types de rencontres

- `solid_favorite` : Favori solide
- `balanced_match` : Match équilibré
- `offensive_match` : Match offensif
- `defensive_match` : Match défensif
- `ranking_gap` : Écart de niveau marqué
- `home_edge` : Avantage domicile fort
- `unstable_match` : Match instable ou imprévisible
- `high_stakes` : Match à enjeu

### Q6 - Nombre de sélections par ticket

- `1_selection` : 1 sélection
- `1_to_2_selections` : 1 à 2 sélections
- `2_to_3_selections` : 2 à 3 sélections
- `2_to_4_selections` : 2 à 4 sélections
- `3_to_6_selections` : 3 à 6 sélections
- `6_plus_selections` : 6 sélections ou plus

### Q7 - Plages de cote totale

- `range_1_20_2_00` : 1.20 - 2.00
- `range_2_00_4_00` : 2.00 - 4.00
- `range_4_00_8_00` : 4.00 - 8.00
- `range_8_00_15_00` : 8.00 - 15.00
- `range_15_plus` : 15.00+

### Q8 - Seuils de cote par marché

Cette question n'a pas d'options propres. Elle dépend des marchés sélectionnés
en Q2 et stocke une cote minimale par marché. La valeur par défaut est `1.30`.

### Q9 - Temps d'analyse

- `less_than_10_minutes` : Moins de 10 minutes
- `10_to_30_minutes` : 10 à 30 minutes
- `30_minutes_to_1_hour` : 30 minutes à 1 heure
- `1_to_2_hours` : 1 à 2 heures
- `more_than_2_hours` : Plus de 2 heures

### Q10 - Fréquence de pari

- `occasionally` : Occasionnellement - quelques fois par mois
- `1_day_per_week` : 1 jour par semaine
- `2_to_3_days_per_week` : 2 à 3 jours par semaine
- `4_to_5_days_per_week` : 4 à 5 jours par semaine
- `almost_every_day` : Presque tous les jours

### Q11 - Volume de rencontres

- `1` : Très peu de matchs, analysés en profondeur
- `2` : Plutôt une sélection réduite
- `3` : Un équilibre entre sélection et variété
- `4` : Plutôt beaucoup de possibilités
- `5` : Le maximum de rencontres pertinentes

### Q12 - Approches de pari

- `secure_bets` : Sécuriser et éliminer les paris risqués
- `solid_edges` : Rechercher des favoris solides ou des écarts nets
- `balanced_opportunities` : Repérer des matchs équilibrés avec une opportunité
- `match_dynamics` : Lire la dynamique du match : offensif ou défensif
- `form_and_context` : Exploiter la forme récente et le contexte
- `ticket_construction` : Construire des tickets prudents ou ambitieux

### Q13 - Importance de la cote

- `1` : Très faible
- `2` : Faible
- `3` : Moyenne
- `4` : Forte
- `5` : Très forte

## Persistance et données

Le profil d'onboarding peut être sauvegardé localement pour le développement.
Le repository de matchs supporte trois modes :

- `demo` : données de démonstration locales ;
- `snapshot` : snapshot API-Football normalisé par `ApiFootballMatchAdapter` ;
- `api` : explicitement indisponible tant qu'un backend sécurisé n'existe pas.

Le moteur travaille sur des objets normalisés (`MatchBoardItem`,
`NormalizedFixture`, `MatchMarket`, `MatchAnalysisData`) et pas directement sur
la réponse API brute.

## Tests existants

Les tests couvrent notamment :

- compilation du profil et valeurs par défaut ;
- conservation des options non sélectionnées ;
- mapping des marchés onboarding vers IDs internes ;
- sauvegarde/restauration locale du profil ;
- filtrage des compétitions ;
- passage en `watchlist` quand le marché est désactivé ;
- passage en `watchlist` quand le seuil de cote utilisateur bloque la sélection ;
- recommandation uniquement après détection d'une thèse ;
- analyse détaillée d'une rencontre hors profil.

Fichiers de tests principaux :

- `test/features/onboarding/domain/profile_compiler_test.dart`
- `test/features/matches/domain/match_insight_engine_test.dart`
- `test/features/matches/data/match_feed_repository_test.dart`
- `test/features/matches/data/api_football_match_adapter_test.dart`

## Écarts et risques

### Documentation corrigée pendant l'audit

`README.md` et `docs/architecture.md` contenaient des formulations héritées qui
présentaient le moteur comme futur ou absent de Flutter. Elles ont été mises à
jour pendant cet audit.

Risque restant : les autres documents historiques peuvent encore mélanger
architecture cible et état réel. Ce document doit servir de point d'entrée pour
l'état actuel.

### Couverture partielle des marchés

Le profil supporte plus de marchés que le moteur n'en recommande aujourd'hui.

Marchés compilés mais non exploités par des thèses V0 :

- `bothTeamsScore`
- `teamTotalHome`
- `teamTotalAway`
- `cornersTotal`
- `cardsTotal`

Risque : un utilisateur qui sélectionne surtout ces marchés peut recevoir peu ou
pas de recommandations, même si son onboarding semble complet.

### Questions compilées mais peu utilisées

Certaines réponses sont bien conservées dans le profil, mais influencent peu ou
pas le moteur actuel :

- Q3 `analysis_elements`
- Q4 `final_decision_influences`
- Q6 `ticket_selection_counts`
- Q7 `ticket_odds_ranges`
- Q10 `betting_frequency`
- Q13 `odds_importance`

Risque : perception de personnalisation plus forte que la réalité moteur.

### `analysisTimeId` limite peu de choses aujourd'hui

Le moteur applique une limite de signaux selon Q9, mais `_signalsFromThesis`
produit actuellement un signal principal par thèse. L'effet réel de Q9 est donc
faible tant que plusieurs signaux indépendants ne sont pas générés.

### Règles métier codées en dur

Les seuils de thèses et plafonds de cote sont directement dans
`MatchInsightEngine`.

Exemples :

- favori solide ignoré si la cote favorite dépasse `2.05` ;
- double chance prudente ignorée si la cote favorite dépasse `2.35`;
- outsider crédible ignoré au-delà de `4.50`;
- match ouvert si climat buts supérieur ou égal à `2.75`;
- match fermé si climat buts inférieur ou égal à `2.05`.

Risque : les ajustements produit nécessitent des modifications de code et des
tests, pas seulement de la configuration.

### Le score reste une confiance interne, pas une probabilité

La compatibilité est la confiance de la thèse retenue. Ce n'est pas une
probabilité de réussite, ni une espérance de valeur, ni une calibration
statistique.

Risque : l'interface doit rester très claire sur le sens du score.

## Recommandations

1. Garder ce document référencé dans l'index de documentation du `README.md`.
2. Décider explicitement quels marchés V1 doivent être supportés par le moteur
   avant usage produit.
3. Ajouter des thèses ou états explicites pour les marchés compilés mais non
   recommandables aujourd'hui.
4. Rendre l'effet réel de chaque question visible dans une matrice
   onboarding -> profil -> moteur -> UI.
5. Externaliser progressivement les seuils métier du moteur si le produit doit
   les ajuster fréquemment.
6. Ajouter un test dédié montrant que Q13 `odds_importance` est soit volontairement
   sans effet V0, soit réellement utilisé.
7. Ajouter un test ou une note produit sur Q9 tant que le moteur ne produit qu'un
   signal principal.

## Verdict

Le moteur actuel existe et il est cohérent avec le principe fondateur :
l'onboarding est compilé en profil métier, puis le moteur travaille sur ce
contrat stable.

La base est saine pour une V0 déterministe et explicable. Le principal sujet
d'audit n'est pas la structure, mais l'écart entre la richesse déclarée de
l'onboarding et l'utilisation partielle de certaines réponses dans les règles
actuelles.
