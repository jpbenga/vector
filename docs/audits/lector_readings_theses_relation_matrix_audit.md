# Audit Lector - readings, theses et matrice de relations

Date d'audit : 2026-09-02  
Périmètre : audit documentaire historique. Le runtime actuel utilise seulement
le pipeline V2 dynamique ; le fallback historique a été supprimé.

## 1. Executive Summary

Lector possède aujourd'hui un vrai socle déterministe de lectures football via `FootballAnalyzer`, puis un moteur V2 qui transforme ces lectures en une `Opportunity` unique par match. Le moteur sait produire 29 lectures effectives, auxquelles s'ajoutent 6 IDs référencés mais non produits ou seulement présents en métadonnées/UI. Il sait évaluer 12 scénarios V2 et 6 scénarios supplémentaires encore présents dans le moteur historique de fallback, soit 18 IDs de thèses/scénarios uniques réellement recensés.

Constats principaux :

- `FootballAnalyzer` est global par match dans sa signature, mais il n'est appelé par le pipeline V2 qu'après vérification du profil, de la compétition et des thèses autorisées.
- `OpportunityEngineV2` calcule plusieurs candidats possibles, mais ne retient qu'une seule thèse par match. La coexistence des thèses n'est donc pas conservée dans le résultat V2.
- Plusieurs readings consommées par V2 ne sont pas produites : `strong_away_team`, `weak_home_team`. Plusieurs readings existent dans les mappings de présentation mais pas dans le producteur : `attack_in_form`, `declining_defense`, `frequent_btts`.
- Les contradictions actuelles sont pauvres et attachées au sujet de la thèse, jamais aux forces pertinentes de l'adversaire.
- Le profil utilisateur intervient trop tôt : il peut empêcher l'analyse d'une compétition, filtrer les thèses candidates avant sélection, et empêcher qu'une thèse non préférée serve de contradiction à une thèse préférée.
- La feuille "Voir les lectures" de `match_detail_page.dart` est partiellement hardcodée : elle affiche trois cartes fixes, quel que soit le vrai set de `FootballReading` retenues.

## 2. Current Analysis Pipeline

Pipeline actuel côté application :

1. `MatchFeedRepositoryLoader.load` choisit la source : demo, snapshot local, snapshot Supabase ou fallback local (`lib/features/matches/data/match_feed_repository_loader.dart:30`).
2. `ApiFootballMatchAdapter.fromSnapshot` normalise fixtures, cotes, standings, team statistics, recent matches, expected goals et predictions dans `MatchBoardItem.analysis` (`lib/features/matches/data/api_football_match_adapter.dart:20`).
3. `SnapshotMatchFeedRepository` et `DemoMatchFeedRepository` construisent la
   `MatchIntelligence` avec `OpportunityEngineV2`.
4. `OpportunityEngineV2` analyse les matchs via `FootballAnalyzer`, évalue les
   thèses puis sélectionne une opportunité compatible avec le profil et la
   maturité établie.
5. `PickEngine` ne crée un pick que si une `Opportunity` possède déjà un marché
   recommandé et si ce marché est activé dans le profil.

## 3. Match Intelligence vs User Matching

Frontière actuelle :

| Stage | Current dependency on profile | Should be global? | Reason | Severity |
|---|---:|---:|---|---|
| Repository `opportunitiesFor` | Oui, compile le profil avant toute opportunity | Non pour l'appel UI, oui pour l'analyse sportive sous-jacente | Le repository mélange récupération du feed et personnalisation | MEDIUM |
| `OpportunityEngineV2.opportunities` | Oui : profil complet obligatoire | Partiellement | Le moteur ne calcule pas de candidates si le profil est incomplet | HIGH |
| Filtre compétition | Oui avant `analyzeOpportunity` | Non pour `MATCH INTELLIGENCE` | Une compétition désactivée peut empêcher l'analyse football globale | HIGH |
| `FootballAnalyzer.analyze` | Non dans sa signature | Oui | C'est la bonne frontière théorique, mais il est appelé trop tard | LOW |
| Candidate thesis filtering | Oui via `profile.isThesisAllowed` avant sélection | Non pour l'intelligence, oui pour la présentation | Une thèse non préférée ne peut plus renforcer/contredire une thèse préférée | CRITICAL |
| Marchés compatibles | Oui via `profile.enabledMarket` | Non pour l'existence de la thèse ; oui pour recommandation | Correct pour `USER MATCHING` | LOW |
| Pick Engine | Oui | Non, user-specific | Correct : transformer une opportunity en pick est dépendant du profil | LOW |

Frontière cible recommandée :

- `MATCH INTELLIGENCE` calculable une fois par match : normalized data, all `FootballReading`, all candidate theses, supports, contradictions, thesis-to-thesis relations, market intents théoriques, temporal warnings.
- `USER MATCHING` spécifique utilisateur : compétitions visibles, thèses préférées, marchés activés, odds/risk preferences, ranking, filtrage "Pour moi", ticket selection.

## 4. Complete Reading Inventory

Statuts : `CURRENT` = produit par `FootballAnalyzer`; `CONSUMED_BUT_NOT_PRODUCED` = attendu par moteur/mapping mais pas produit; `HARDCODED_UI` = libellé ou concept de présentation; `PRODUCED_BUT_NOT_CONSUMED` = produit mais pas utilisé comme support V2.

| ID / Type | Producer | Inputs | Condition exacte | Subject | Strength | Consumers | Temporal safety | Status | Remarques |
|---|---|---|---|---|---|---|---|---|---|
| `balanced_hierarchy` | `FootballAnalyzer._hierarchyReadings` | `homeStanding.rank`, `awayStanding.rank`, `points`, `played` | `rankGap <= 2 && pointsGap <= 4` | match | `moderate` | `credible_outsider`, `avoid_match` | `asOf = match.analysis.asOf ?? kickoff ?? now`; pas de freshness check | CURRENT | Signal non discriminant par définition. |
| `ranking_superiority` | `_hierarchyReadings` | ranks, points | `rankGap >= 3 || pointsGap >= 5`; sujet = meilleure rank | équipe mieux classée | `fromGap(rankGap + pointsGap / 2, 5, 10)` | `expected_domination`, `favorite_with_protection`, `controlled_favorite` | Même sécurité générale | CURRENT | Peut être faible si seul l'écart points déclenche. |
| `structural_level_gap` | `_hierarchyReadings` | ranks, points | `rankGap >= 5 || pointsGap >= 8` | équipe mieux classée | `fromGap(rankGap + pointsGap / 2, 8, 14)` | `expected_domination` obligatoire | Même sécurité générale | CURRENT | Le nom est fort alors que la règle est OR, pas une double confirmation. |
| `positive_streak` | `_formFor` | `standing.form ?? statistics.form` | forme normalisée WDL; `sampleSize >= 5 && score >= 10` | home ou away | `strong` si `score >= 13`, sinon `moderate` | `expected_domination`, `credible_outsider`, `team_worse_than_results`; contradictions | Pas de contrôle fraîcheur de la chaîne | CURRENT | Mesure une bonne forme absolue, pas une supériorité vs adversaire. |
| `negative_streak` | `_formFor` | form | `sampleSize >= 5 && score <= 4` | home ou away | `strong` si `score <= 2`, sinon `moderate` | `credible_outsider` adverse, `team_in_serious_difficulty`, `team_better_than_results` | Idem | CURRENT | Absolu, pas comparatif. |
| `improving_form` | `_formFor` | form | `sampleSize >= 5 && lastThree >= firstTwo + 4`, avec `lastThree = score(recent[0..2])`, `firstTwo = score(recent[3..4])` | home ou away | `moderate` | Aucun consommateur V2 | Idem | PRODUCED_BUT_NOT_CONSUMED | La direction temporelle de `form` doit être confirmée. |
| `declining_form` | `_formFor` | form | `sampleSize >= 5 && lastThree + 4 <= firstTwo` | home ou away | `moderate` | `credible_outsider` si adversaire | Idem | CURRENT | Produit mais très peu consommé. |
| `strong_home_team` | `_homeAwayReadings` | `homeStatistics.playedHome ?? playedTotal`, `winsHome ?? winsTotal` | `homePlayed >= 5 && wins/homePlayed >= 0.60` | home | `strong` si rate `>= .72`, sinon `moderate` | `expected_domination` home, `credible_outsider` | Stats snapshot only | CURRENT | Pas d'équivalent produit pour l'away. |
| `weak_away_team` | `_homeAwayReadings` | `awayStatistics.playedAway ?? playedTotal`, `lossesAway ?? lossesTotal` | `awayPlayed >= 5 && losses/awayPlayed >= 0.45` | away | `strong` si rate `>= .58`, sinon `moderate` | `team_in_serious_difficulty` away; indirectement `expected_domination` home via `home_away_mismatch` seulement | Stats snapshot only | CURRENT | Pas d'équivalent produit pour le home; la consommation directe par domination est neutralisée par le filtre sujet. |
| `home_away_mismatch` | `_homeAwayReadings` | readings produites | présence de `strong_home_team` ET `weak_away_team` | match | `strong` | `expected_domination` | Dérivé des readings | CURRENT | Uniquement favorable au home, asymétrique. |
| `strong_away_team` | Aucun producteur actif | `winsAway` possible dans modèle | Consommé si sujet de `expected_domination` est away | away | n/a | `expected_domination` away | n/a | CONSUMED_BUT_NOT_PRODUCED | Trou critique pour les favoris visiteurs. |
| `weak_home_team` | Aucun producteur actif | `lossesHome` possible dans modèle | Listé par `expected_domination` away et `team_in_serious_difficulty` home | home | n/a | V2 | n/a | CONSUMED_BUT_NOT_PRODUCED | Rend certaines thèses home-difficulty impossibles; dans `expected_domination`, resterait aussi mal dirigé si produit avec subject home. |
| `prolific_attack` | `_attackFor` | `goalsForAverageTotal`, `playedTotal` | `played >= 8 && average >= 1.70` | home ou away | `strong` si `>= 2.05` | open, BTTS, one-sided | Stats snapshot only | CURRENT | Total season average, pas split home/away. |
| `scoring_difficulty` | `_attackFor` | `goalsForAverageTotal`, `playedTotal` | `played >= 8 && average <= 0.90` | home ou away | `strong` si `<= .65` | closed, difficulty, controlled favorite, one-sided opponent | Stats snapshot only | CURRENT | Mappé en `weakRecentForm` côté argument, vocabulaire discutable. |
| `attack_in_form` | Aucun producteur actif | n/a | n/a | équipe | n/a | mappings UI/type seulement | n/a | HARDCODED_UI | Présent dans `FootballReading.toCopilotArgument` et copies, pas produit. |
| `solid_defense` | `_defenseFor` | `goalsAgainstAverageTotal`, `playedTotal` | `played >= 8 && average <= 1.00` | home ou away | `strong` si `<= .75` | closed, favorite protection, controlled favorite, one-sided subject | Stats snapshot only | CURRENT | Total season average. |
| `fragile_defense` | `_defenseFor` | `goalsAgainstAverageTotal`, `playedTotal` | `played >= 8 && average >= 1.60` | home ou away | `strong` si `>= 1.95` | open, outsider adverse, difficulty, BTTS, one-sided | Stats snapshot only | CURRENT | Sert aussi à produire `conflicting_signals`. |
| `declining_defense` | Aucun producteur actif | n/a | n/a | équipe | n/a | mappings UI/type seulement | n/a | HARDCODED_UI | Présent dans mappings, pas produit. |
| `frequent_clean_sheet` | `_defenseFor` | `cleanSheetsTotal`, `playedTotal` | `played > 0 && cleanSheets/played >= 0.35` après `played >= 8` | home ou away | `strong` si `>= .50` | `convergent_closed_match` | Stats snapshot only | CURRENT | Compatible avec `solid_defense`. |
| `open_match_profile` | `_rhythmReadings` | 4 moyennes buts total | `sampleSize >= 8 && climate >= 2.80`, `climate=(homeFor+awayFor+homeAgainst+awayAgainst)/2` | match | `strong` si `>= 3.20` | `convergent_open_match` | Stats snapshot only | CURRENT | Produit en même temps que `frequent_over_25`. |
| `frequent_over_25` | `_rhythmReadings` | même `climate` | même condition que `open_match_profile` | match | `moderate` | `convergent_open_match` | Stats snapshot only | CURRENT | Nom suggère une fréquence over, mais aucun historique over direct n'est lu. |
| `closed_match_profile` | `_rhythmReadings` | 4 moyennes buts total | `sampleSize >= 8 && climate <= 2.10` | match | `strong` si `<= 1.80` | `convergent_closed_match`, `controlled_favorite` | Stats snapshot only | CURRENT | Produit en même temps que `frequent_under_25`. |
| `frequent_under_25` | `_rhythmReadings` | même `climate` | même condition que `closed_match_profile` | match | `moderate` | `convergent_closed_match` | Stats snapshot only | CURRENT | Nom suggère une fréquence under, mais aucun historique under direct n'est lu. |
| `frequent_btts` | Aucun producteur actif | n/a | n/a | match | n/a | mappings UI/type seulement | n/a | HARDCODED_UI | Considéré par docs/UI, pas par V2. |
| `high_xg_creation` | `_expectedGoalsFor` | `rollingXgFor5`, `sampleSize`, `xg.asOf`, kickoff | `sampleSize >= 3`, `xg.asOf <= kickoff`, `created >= 1.50` | home ou away | `strong` si `abs(value) >= 2`, sinon `moderate` | open, outsider, BTTS, one-sided, better-than-results | Rejette xG post-kickoff | CURRENT | Bonne sécurité spécifique xG. |
| `low_xg_creation` | `_expectedGoalsFor` | `rollingXgFor5` | `sampleSize >= 3`, pre-kickoff, `created <= 0.90` | home ou away | même resolver xG | Aucun consommateur V2 | Rejette xG post-kickoff | PRODUCED_BUT_NOT_CONSUMED | Contradiction logique manquante contre scénarios offensifs. |
| `high_xg_conceded` | `_expectedGoalsFor` | `rollingXgAgainst5` | `sampleSize >= 3`, pre-kickoff, `conceded >= 1.50` | home ou away | même resolver xG | open, BTTS, one-sided | Rejette xG post-kickoff | CURRENT | Peut contredire des thèses défensives, mais pas modélisé. |
| `offensive_underperformance` | `_expectedGoalsFor` | `goalsFor5 - rollingXgFor5` | `<= -1.50` | home ou away | même resolver xG | `team_better_than_results` | Rejette xG post-kickoff | CURRENT | Peut être positif pour potentiel futur, pas seulement négatif. |
| `offensive_overperformance` | `_expectedGoalsFor` | `goalsFor5 - rollingXgFor5` | `>= 1.50` | home ou away | même resolver xG | `team_worse_than_results`; contradiction generator | Rejette xG post-kickoff | CURRENT | Renforce "résultats à nuancer". |
| `defensive_overperformance` | `_expectedGoalsFor` | `goalsAgainst5 - rollingXgAgainst5` | `<= -1.50` | home ou away | même resolver xG | `team_worse_than_results`; contradiction generator | Rejette xG post-kickoff | CURRENT | Le nom "overperformance" est correct mais fragile pour l'utilisateur. |
| `defensive_underperformance` | `_expectedGoalsFor` | `goalsAgainst5 - rollingXgAgainst5` | `>= 1.50` | home ou away | même resolver xG | Aucun consommateur V2 direct | Rejette xG post-kickoff | PRODUCED_BUT_NOT_CONSUMED | Devrait probablement renforcer fragilité défensive. |
| `misleading_result` | `_contradictions` | readings same team | `positive_streak && (offensive_overperformance || defensive_overperformance)` | home ou away | `moderate`; contradiction | Attaché comme contradiction aux thèses du même sujet | Dérivé des readings | CURRENT | Jamais utilisé comme support de `team_worse_than_results`, seulement limite. |
| `conflicting_signals` | `_contradictions` | readings same team | `positive_streak && fragile_defense` | home ou away | `moderate`; contradiction | `avoid_match`; limite des thèses du même sujet | Dérivé des readings | CURRENT | Contradiction intra-équipe uniquement. |
| `insufficient_data` | `analyze` ou `_expectedGoalsFor` | absence readings ou xG post-match | aucun reading détecté, ou `xg.asOf.isAfter(kickoff)` | match ou équipe | `strong` si absence totale; `moderate` si xG rejeté | `avoid_match`; limite | xG post-match explicitement rejeté | CURRENT | Même ID pour absence globale et rejet xG local. |
| `false_favorite` | Aucun producteur actif | n/a | anciennement référencé par une métadonnée supprimée | équipe | n/a | Aucun consumer opérationnel | n/a | REMOVED_LEGACY_METADATA | Catalogue legacy supprimé. |

## 5. Reading Families

| Family | Readings | Symétrie | Seuils | Consommation | Constats |
|---|---|---|---|---|---|
| Hiérarchie | `balanced_hierarchy`, `ranking_superiority`, `structural_level_gap` | Oui équipe A/B pour supériorité; `balanced` match | rank/points OR | Forte | Vocabulaire parfois plus fort que la règle. |
| Forme récente | `positive_streak`, `negative_streak`, `improving_form`, `declining_form` | Oui home/away | score W=3 D=1 L=0 sur 5 | Partielle | `improving_form` inutilisé; la direction temporelle de la string varie entre modules. |
| Domicile/extérieur | `strong_home_team`, `weak_away_team`, `home_away_mismatch`; attendus `strong_away_team`, `weak_home_team` | Non | `.60`, `.45` | Asymétrique | Grosse dette : les favoris visiteurs sont sous-modélisés. |
| Attaque | `prolific_attack`, `scoring_difficulty`, `high_xg_creation`, `low_xg_creation`, xG over/under performance | Oui | buts total et xG rolling | Partielle | Pas de split home/away; `low_xg_creation` inutilisé. |
| Défense | `solid_defense`, `fragile_defense`, `frequent_clean_sheet`, `high_xg_conceded`, defensive xG divergence | Oui | buts contre, clean sheets, xG | Partielle | `defensive_underperformance` produit mais non consommé. |
| Profil buts | `open_match_profile`, `closed_match_profile`, `frequent_over_25`, `frequent_under_25`, `frequent_btts` | Match | climate | Forte mais redondante | `frequent_*` ne mesure pas une fréquence réelle. |
| Contradictions | `misleading_result`, `conflicting_signals`, `insufficient_data`, `false_favorite` | Partielle | règles ad hoc | Faible | Contradictions adverses et contextuelles absentes. |

## 6. Complete Thesis / Scenario Inventory

### Vue synthétique

| ID exact | Engine | Label | Subject | Detection actuelle | Priority / score | Markets | Profile relation | Status |
|---|---|---|---|---|---|---|---|---|
| `expected_domination` | V2 | Domination attendue | home/away | support >= 3 ET `structural_level_gap` | priority 90; score priority + support - contradictions | `matchResult`, `doubleChance` | `solid_favorite`, `ranking_gap`, `positive_series` | CURRENT |
| `favorite_with_protection` | V2 | Favori avec protection | market favorite | market favorite + `ranking_superiority` + `solid_defense` + contradiction | 82 | `doubleChance` | `solid_favorite` | CURRENT |
| `convergent_open_match` | V2 | Match ouvert | match | open/buts/xG/fragility support >= 3 | 78 | `goalsTotal` over 2.5, `bothTeamsScore` yes | `offensive_match`, `fragile_defense` | CURRENT |
| `convergent_closed_match` | V2 | Match fermé | match | closed/defense/scoring support >= 3 | 76 | `goalsTotal` under 2.5 | `defensive_match` | CURRENT |
| `credible_outsider` | V2 + legacy | Outsider crédible | market outsider | outsider <= 4.50 + support >= 3 | 74 V2; legacy score >=68 | `doubleChance`, `matchResult` | `credible_outsider` | CURRENT |
| `team_in_serious_difficulty` | V2 | Équipe en difficulté | home/away | weak readings team >=3 | 72 | opponent `doubleChance`, opponent `matchResult` | `struggling_team`, `fragile_defense`, `negative_series` | CURRENT |
| `controlled_favorite` | V2 | Favori en contrôle | market favorite | favorite with ranking/defense/opponent low scoring/closed support >=3 | 70 | `matchResult`, `doubleChance` | `solid_favorite` | CURRENT |
| `both_sides_can_score` | V2 | Les deux équipes peuvent marquer | match | both teams creation + at least one fragile/xGA | 68 | `bothTeamsScore` yes | `offensive_match`, `prolific_attack` | CURRENT |
| `one_sided_scoring` | V2 | Pression offensive à sens unique | home/away | target attack + opponent fragility/scoring difficulty + target defense >=3 | 66 | team total over 0.5, `matchResult` | `ranking_gap`, `fragile_defense`, `prolific_attack` | CURRENT |
| `team_better_than_results` | V2 | Meilleur que les résultats | home/away | `negative_streak` + `offensive_underperformance` + `high_xg_creation` | 64 | `doubleChance` | `negative_series` | CURRENT |
| `team_worse_than_results` | V2 | Résultats à nuancer | home/away | `positive_streak` + offensive/defensive overperformance | 60 | none | `positive_series` | CURRENT |
| `avoid_match` | V2 | Match à éviter | match | `balanced_hierarchy`, `conflicting_signals`, `insufficient_data`, support >=2 | 10 | none | aucune entrée catalogue, donc allowed par défaut | CURRENT |
| `solid_favorite` | legacy fallback | Favori solide | market favorite | odds <=2.05 + market support + >=1 edge | base 52 + edges | `matchResult` max 2.40 | `solid_favorite` | PARTIAL |
| `cautious_double_chance` | legacy fallback | Double chance prudente | market favorite | odds <=2.35 + market support + standing/form edge | base 50 + edges | `doubleChance` max 2.10 | `solid_favorite` | PARTIAL |
| `level_gap` | legacy fallback | Écart de niveau | best-ranked side | `rankGap >=5 || pointsGap >=8` | 74 if market confirms else 62 | `doubleChance`, `matchResult` | `ranking_gap`, `solid_favorite` | PARTIAL |
| `open_match` | legacy fallback | Match ouvert | match | `goalClimate >= 2.75` | 76 if >=3.2 else 66 | `goalsTotal` over 2.5 | `offensive_match` | PARTIAL |
| `closed_match` | legacy fallback | Match fermé | match | `goalClimate <= 2.05` | 74 if <=1.75 else 64 | `goalsTotal` under 2.5 | `defensive_match` | PARTIAL |
| `no_sufficient_thesis` | legacy fallback | Aucune thèse suffisante | match | fallback when no legacy candidate | 0 | none | profile reasons legacy only | CURRENT fallback |

### Fiches standardisées

#### `expected_domination`

**User-facing label:** Domination attendue.  
**Current status:** CURRENT V2.  
**Subject:** équipe home ou away; boucle home puis away.  
**Purpose:** détecter une supériorité structurelle avec contexte convergent.  
**Current detection rule:** `_readingsFor(team.id, [structural_level_gap, ranking_superiority, positive_streak, strong_home_team/strong_away_team, weak_away_team/weak_home_team, home_away_mismatch])`; `supporting.length >= 3 && contains(structural_level_gap)`.  
**Current core readings:** `structural_level_gap` obligatoire; deux autres readings de la liste.  
**Current optional readings:** aucune distinction technique.  
**Proposed CORE_SUPPORT:** `structural_level_gap`, `ranking_superiority`, `positive_streak` si discriminant.  
**Proposed ADDITIONAL_SUPPORT:** context strength du sujet, weakness contextuelle adverse, `prolific_attack`, opponent `fragile_defense`.  
**Proposed CONTRADICTIONS:** opponent `strong_home_team` si sujet away; opponent `strong_away_team` si sujet home; opponent `positive_streak`; subject `fragile_defense`; `balanced_hierarchy`.  
**Potential STRONG_CONTRADICTIONS:** subject away face à opponent `strong_home_team` strong; formes comparables fortes.  
**Potential opposing theses:** `credible_outsider`, `both_sides_can_score`, `convergent_open_match`.  
**Potential reinforcing theses:** `controlled_favorite`, `one_sided_scoring`, legacy `level_gap`.  
**Non-discriminating situations:** les deux équipes ont `positive_streak`; les deux équipes ont une force contextuelle home/away forte.  
**Missing engine capabilities:** away strength, weak home, relation adversaire, discriminance de forme.  
**Semantic concerns:** "domination" est fort pour une règle à 3 supports dont un seul obligatoire.  
**Product decisions required:** faut-il exiger un avantage dynamique comparatif ou seulement une bonne forme absolue ?

#### `favorite_with_protection`

**Current status:** CURRENT V2.  
**Subject:** favori marché 1N2.  
**Current detection rule:** `_marketFavorite` requis; support `ranking_superiority`, `solid_defense`; contradictions team non vides; `supporting.length >= 2`.  
**Current core readings:** `ranking_superiority`, `solid_defense`, au moins une contradiction du même sujet.  
**Proposed ADDITIONAL_SUPPORT:** `positive_streak`, opponent `scoring_difficulty`, `frequent_clean_sheet`.  
**Proposed CONTRADICTIONS:** opponent context strength; opponent high creation; `misleading_result` du favori.  
**Semantic concerns:** "protection" dépend d'une contradiction interne, pas d'une lecture de risque marché explicite.  
**Product decisions required:** décider si la contradiction doit être condition de détection ou simple downgrade de marché.

#### `convergent_open_match`

**Current status:** CURRENT V2.  
**Subject:** match global.  
**Current detection rule:** count >=3 parmi `open_match_profile`, `frequent_over_25`, `high_xg_creation`, `fragile_defense`, `high_xg_conceded`.  
**Current core readings:** techniquement aucune obligatoire.  
**Proposed CORE_SUPPORT:** `open_match_profile` OU double création offensive; au moins une fragilité défensive.  
**Proposed ADDITIONAL_SUPPORT:** `frequent_over_25`, `prolific_attack`, `high_xg_creation`.  
**Proposed CONTRADICTIONS:** `closed_match_profile`, deux `solid_defense`, deux `scoring_difficulty`, `low_xg_creation` sur une ou deux équipes.  
**Semantic concerns:** `frequent_over_25` ne vient pas d'une fréquence over réelle.  
**Product decisions required:** valider si xG d'une seule équipe peut suffire à "match ouvert".

#### `convergent_closed_match`

**Current status:** CURRENT V2.  
**Subject:** match global.  
**Current detection rule:** count >=3 parmi `closed_match_profile`, `frequent_under_25`, `solid_defense`, `frequent_clean_sheet`, `scoring_difficulty`.  
**Proposed CORE_SUPPORT:** `closed_match_profile` ou combinaison défenses solides + difficultés offensives.  
**Proposed ADDITIONAL_SUPPORT:** clean sheets, low creation.  
**Proposed CONTRADICTIONS:** `open_match_profile`, `prolific_attack` des deux équipes, `high_xg_creation`, `fragile_defense`.  
**Semantic concerns:** peut être détecté avec deux readings générées par le même climate plus une seule défense solide.  
**Product decisions required:** éviter double counting `closed_match_profile` + `frequent_under_25`.

#### `credible_outsider`

**Current status:** CURRENT V2 et legacy.  
**Subject:** outsider du marché 1N2.  
**Current detection rule V2:** favorite et outsider requis; `outsider.odds <= 4.50`; support >=3 parmi `balanced_hierarchy`, outsider `positive_streak`, outsider `strong_home_team`, outsider `high_xg_creation`, opponent `negative_streak`, `declining_form`, `fragile_defense`.  
**Proposed CORE_SUPPORT:** statut outsider marché + au moins deux signaux sportifs qui réduisent l'écart.  
**Proposed ADDITIONAL_SUPPORT:** contexte home/away correct selon le side, high xG, fragilité adverse.  
**Proposed CONTRADICTIONS:** `structural_level_gap` fort pour le favori; outsider `scoring_difficulty`; outsider `fragile_defense`.  
**Semantic concerns:** V2 utilise `strong_home_team` pour l'outsider même si l'outsider est away.  
**Product decisions required:** valider seuil outsider et relation aux forces du favori.

#### `team_in_serious_difficulty`

**Current status:** CURRENT V2.  
**Subject:** équipe home ou away.  
**Current detection rule:** support >=3 parmi `negative_streak`, `scoring_difficulty`, `fragile_defense`, `weak_away_team` si away ou `weak_home_team` si home.  
**Proposed CORE_SUPPORT:** au moins deux familles distinctes parmi forme, attaque, défense, contexte.  
**Proposed ADDITIONAL_SUPPORT:** opponent `ranking_superiority`, opponent `prolific_attack`.  
**Proposed CONTRADICTIONS:** target `high_xg_creation`, target `offensive_underperformance`, target `solid_defense`, target `positive_streak`.  
**Semantic concerns:** home side a une condition impossible via `weak_home_team`.  
**Product decisions required:** décider si "serious" exige 3 familles différentes.

#### `controlled_favorite`

**Current status:** CURRENT V2.  
**Subject:** favori marché.  
**Current detection rule:** market favorite; support >=3 parmi favorite `ranking_superiority`, favorite `solid_defense`, opponent `scoring_difficulty`, match `closed_match_profile`.  
**Proposed CORE_SUPPORT:** favori + `solid_defense` + opponent low scoring/closed climate.  
**Proposed ADDITIONAL_SUPPORT:** `frequent_clean_sheet`, `ranking_superiority`, `structural_level_gap`.  
**Proposed CONTRADICTIONS:** opponent `high_xg_creation`, opponent `prolific_attack`, match `open_match_profile`.  
**Semantic concerns:** le marché favori est obligatoire mais pas stocké comme reading V2.  
**Product decisions required:** décider si market favorite doit être une reading explicite.

#### `both_sides_can_score`

**Current status:** CURRENT V2.  
**Subject:** match global.  
**Current detection rule:** home has `high_xg_creation` or `prolific_attack`; away has same; at least one `fragile_defense` or `high_xg_conceded`.  
**Proposed CORE_SUPPORT:** création offensive des deux équipes.  
**Proposed ADDITIONAL_SUPPORT:** fragilité défensive d'une ou deux équipes, open profile.  
**Proposed CONTRADICTIONS:** une équipe `scoring_difficulty` ou `low_xg_creation`; deux `solid_defense`; `closed_match_profile`.  
**Semantic concerns:** une seule défense fragile suffit actuellement.  
**Product decisions required:** préciser si BTTS exige fragilité des deux défenses ou seulement capacité des deux attaques.

#### `one_sided_scoring`

**Current status:** CURRENT V2.  
**Subject:** équipe cible.  
**Current detection rule:** support >=3 parmi target `prolific_attack`/`high_xg_creation`, opponent `fragile_defense`/`high_xg_conceded`/`scoring_difficulty`, target `solid_defense`.  
**Proposed CORE_SUPPORT:** target attack + opponent defensive weakness.  
**Proposed ADDITIONAL_SUPPORT:** opponent scoring difficulty, target solid defense.  
**Proposed CONTRADICTIONS:** opponent strong attack/high creation; target scoring difficulty/low xG.  
**Semantic concerns:** `scoring_difficulty` de l'adversaire soutient "sens unique" mais pas directement le scoring de la cible.  
**Product decisions required:** séparer "team to score" et "match control" ?

#### `team_better_than_results`

**Current status:** CURRENT V2.  
**Subject:** équipe home ou away.  
**Current detection rule:** `negative_streak` + `offensive_underperformance` + `high_xg_creation`; les 3 requis.  
**Proposed CORE_SUPPORT:** mauvais résultats + xG creation + underperformance finishing.  
**Proposed ADDITIONAL_SUPPORT:** opponent fragile defense.  
**Proposed CONTRADICTIONS:** `low_xg_creation`, `scoring_difficulty`, `fragile_defense` forte.  
**Semantic concerns:** uniquement offensif; ignore défense qui peut expliquer les mauvais résultats.  
**Product decisions required:** décider si défense fragile doit empêcher ou seulement nuancer.

#### `team_worse_than_results`

**Current status:** CURRENT V2.  
**Subject:** équipe home ou away.  
**Current detection rule:** `positive_streak` + `offensive_overperformance` + `defensive_overperformance`; les 3 requis.  
**Proposed CORE_SUPPORT:** bonne série + surperformance xG.  
**Proposed ADDITIONAL_SUPPORT:** `misleading_result` devrait renforcer cette thèse comme conclusion dérivée.  
**Proposed CONTRADICTIONS:** `high_xg_creation`, `solid_defense`, `ranking_superiority` selon contexte.  
**Semantic concerns:** aucun marché automatique, mais reste une thèse de vigilance.  
**Product decisions required:** clarifier si cette thèse est un scénario autonome ou une contradiction générique.

#### `avoid_match`

**Current status:** CURRENT V2.  
**Subject:** match global.  
**Current detection rule:** count >=2 parmi `balanced_hierarchy`, `conflicting_signals`, `insufficient_data`.  
**Proposed CORE_SUPPORT:** ambiguïté forte, données insuffisantes, contradictions importantes.  
**Proposed ADDITIONAL_SUPPORT:** signaux non discriminants et forces opposées.  
**Proposed CONTRADICTIONS:** aucune ; c'est une thèse de prudence.  
**Semantic concerns:** allowed par défaut car absent du catalogue profil.  
**Product decisions required:** doit-elle apparaître dans "Tous" même si non préférée ?

#### `solid_favorite`

**Current status:** PARTIAL legacy fallback.  
**Subject:** favori marché.  
**Current detection rule:** favorite 1N2 odds <=2.05; score base 52; ajoute standing edge, form edge, reliability edge; support length >=2.  
**Proposed CORE_SUPPORT:** ranking/form/reliability discriminants sans dépendre du profil.  
**Semantic concerns:** n'existe pas en V2 malgré présence forte dans onboarding.  
**Product decisions required:** décider si concept devient thèse V2 ou famille profil.

#### `cautious_double_chance`

**Current status:** PARTIAL legacy fallback.  
**Subject:** favori marché.  
**Current detection rule:** favorite odds <=2.35; standing/form edge; support length >=2.  
**Semantic concerns:** orienté marché plus que football.  
**Product decisions required:** rester user-matching ou devenir scénario ?

#### `level_gap`

**Current status:** PARTIAL legacy fallback.  
**Subject:** équipe mieux classée.  
**Current detection rule:** `rankGap >=5 || pointsGap >=8`; score 74 si marché confirme, sinon 62.  
**Semantic concerns:** doublonne partiellement `structural_level_gap` et `expected_domination`.  
**Product decisions required:** thèse autonome ou support de domination ?

#### `open_match`

**Current status:** PARTIAL legacy fallback.  
**Subject:** match.  
**Current detection rule:** `goalClimate >= 2.75`; score 76 si `>=3.2`, sinon 66.  
**Semantic concerns:** doublon legacy de `convergent_open_match` avec moins de supports.  
**Product decisions required:** conserver simple thesis ou fusionner avec V2 ?

#### `closed_match`

**Current status:** PARTIAL legacy fallback.  
**Subject:** match.  
**Current detection rule:** `goalClimate <= 2.05`; score 74 si `<=1.75`, sinon 64.  
**Semantic concerns:** doublon legacy de `convergent_closed_match`.  
**Product decisions required:** même décision que `open_match`.

#### `no_sufficient_thesis`

**Current status:** CURRENT fallback only.  
**Subject:** match.  
**Current detection rule:** aucune candidate legacy; ajoute limites selon données absentes, outsider très coté ou favori marché non soutenu.  
**Semantic concerns:** utile pour "Tous", pas une opportunity V2.  
**Product decisions required:** doit devenir une thèse V2 explicite ou rester fallback UI ?

## 7. Current Reading -> Thesis Relationships

| Source Reading | Target Thesis | Relation actuelle | Direction | Statut |
|---|---|---|---|---|
| `structural_level_gap` | `expected_domination` | CORE obligatoire | subject team ou match-level via `_readingsFor` | CURRENT |
| `ranking_superiority` | `expected_domination` | support compté | subject team | CURRENT |
| `positive_streak` | `expected_domination` | support compté | subject team | CURRENT |
| `strong_home_team` / `strong_away_team` | `expected_domination` | support compté | subject side; away non produit | PARTIAL |
| `weak_away_team` / `weak_home_team` | `expected_domination` | IDs listés mais pas réellement trouvés comme faiblesse adverse | opponent contextual attendu, mais `_readingsFor` filtre sur le sujet de la thèse ou le match | PARTIAL |
| `home_away_mismatch` | `expected_domination` | support compté | match-level | CURRENT |
| `ranking_superiority`, `solid_defense` | `favorite_with_protection` | CORE avec contradiction obligatoire | favorite side | CURRENT |
| all same-team contradictions | `favorite_with_protection` | condition d'existence et limits | favorite side | CURRENT |
| `open_match_profile`, `frequent_over_25`, `high_xg_creation`, `fragile_defense`, `high_xg_conceded` | `convergent_open_match` | support compté, min 3 | any side / match | CURRENT |
| `closed_match_profile`, `frequent_under_25`, `solid_defense`, `frequent_clean_sheet`, `scoring_difficulty` | `convergent_closed_match` | support compté, min 3 | any side / match | CURRENT |
| `balanced_hierarchy`, outsider `positive_streak`, outsider `strong_home_team`, outsider `high_xg_creation`, opponent `negative_streak`, `declining_form`, `fragile_defense` | `credible_outsider` | support compté, min 3 | mixed | PARTIAL |
| `negative_streak`, `scoring_difficulty`, `fragile_defense`, context weak | `team_in_serious_difficulty` | support compté, min 3 | subject team | PARTIAL |
| favorite `ranking_superiority`, favorite `solid_defense`, opponent `scoring_difficulty`, `closed_match_profile` | `controlled_favorite` | support compté, min 3 | mixed | CURRENT |
| both teams attack creation + fragile/xGA | `both_sides_can_score` | CORE booleans | both teams + any fragile | CURRENT |
| target attack, opponent fragile/low scoring, target defense | `one_sided_scoring` | support compté, min 3 | directional | CURRENT |
| `negative_streak`, `offensive_underperformance`, `high_xg_creation` | `team_better_than_results` | all 3 required | subject team | CURRENT |
| `positive_streak`, `offensive_overperformance`, `defensive_overperformance` | `team_worse_than_results` | all 3 required | subject team | CURRENT |
| `balanced_hierarchy`, `conflicting_signals`, `insufficient_data` | `avoid_match` | support compté, min 2 | match / any | CURRENT |

## 8. Proposed Reading -> Thesis Matrix

Cette matrice ne liste que les relations significatives, ambiguës ou manquantes. Règle générale proposée : toute relation absente de cette table est `NOT_RELEVANT unless explicitly mapped`.

| Source | Target | Relation actuelle | Relation proposée | Team direction / context | Why | Statut | Confidence |
|---|---|---|---|---|---|---|---|
| `structural_level_gap` | `expected_domination` | CORE | CORE_SUPPORT | sujet = équipe mieux classée | Base structurelle de la domination. | CURRENT | HIGH |
| `ranking_superiority` | `expected_domination` | Support | CORE_SUPPORT | sujet | Confirme hiérarchie, mais moins fort que structural. | CURRENT | HIGH |
| `positive_streak` | `expected_domination` | Support | CORE_SUPPORT if discriminant | sujet | Bonne dynamique soutient domination seulement si adversaire pas équivalent. | PARTIAL | MEDIUM |
| `strong_home_team` | `expected_domination` | Support home | ADDITIONAL_SUPPORT | sujet home | Force contextuelle pertinente. | CURRENT | HIGH |
| `strong_away_team` | `expected_domination` | Support away attendu | ADDITIONAL_SUPPORT | sujet away | Symétrie nécessaire pour favoris visiteurs. | CONSUMED_BUT_NOT_PRODUCED | HIGH |
| opponent `strong_home_team` | `expected_domination` away | Aucune | CONTRADICTION | sujet away, adversaire home | La force domicile adverse résiste à une domination extérieure. | MISSING_RELATION | HIGH |
| opponent `positive_streak` | `expected_domination` | Aucune | CONTRADICTION if comparable | adversaire | Forme adverse forte réduit la discriminance du sujet. | MISSING_RELATION | MEDIUM |
| `balanced_hierarchy` | `expected_domination` | Aucune | STRONG_CONTRADICTION | match | Hiérarchie proche contredit domination structurelle. | MISSING_RELATION | HIGH |
| `fragile_defense` subject | `expected_domination` | Aucune sauf contradiction interne si positive streak | CONTRADICTION | sujet | Dominer tout en concédant beaucoup doit être nuancé. | MISSING_RELATION | MEDIUM |
| `prolific_attack` subject | `expected_domination` | Aucune | ADDITIONAL_SUPPORT | sujet | Renforce capacité à concrétiser domination. | MISSING_RELATION | MEDIUM |
| `ranking_superiority` | `favorite_with_protection` | CORE | CORE_SUPPORT | favori marché | Support sportif du favori. | CURRENT | HIGH |
| `solid_defense` | `favorite_with_protection` | CORE | CORE_SUPPORT | favori | Justifie protection plutôt que volatilité. | CURRENT | HIGH |
| `misleading_result` | `favorite_with_protection` | contradiction requise | CONTRADICTION | favori | Explique pourquoi couvrir le favori. | CURRENT | HIGH |
| opponent `high_xg_creation` | `favorite_with_protection` | Aucune | CONTRADICTION | adversaire | Menace offensive adverse justifie protection. | MISSING_RELATION | MEDIUM |
| `open_match_profile` | `convergent_open_match` | Support | CORE_SUPPORT | match | Décrit le climat buts global. | CURRENT | HIGH |
| `frequent_over_25` | `convergent_open_match` | Support | ADDITIONAL_SUPPORT | match | Redondant avec climate actuel; support secondaire. | PARTIAL | HIGH |
| `high_xg_creation` | `convergent_open_match` | Support | ADDITIONAL_SUPPORT | une ou deux équipes | Création récente augmente probabilité de rythme ouvert. | CURRENT | HIGH |
| `prolific_attack` | `convergent_open_match` | Aucune | ADDITIONAL_SUPPORT | une ou deux équipes | Production buts soutient match ouvert. | MISSING_RELATION | MEDIUM |
| `fragile_defense` / `high_xg_conceded` | `convergent_open_match` | Support | ADDITIONAL_SUPPORT | une ou deux équipes | Défense exposée ouvre le match. | CURRENT | HIGH |
| `closed_match_profile` | `convergent_open_match` | Aucune | STRONG_CONTRADICTION | match | Climat bas oppose directement thèse ouverte. | MISSING_RELATION | HIGH |
| `solid_defense` both teams | `convergent_open_match` | Aucune | CONTRADICTION | both teams | Deux défenses solides résistent au scénario buts. | MISSING_RELATION | MEDIUM |
| `closed_match_profile` | `convergent_closed_match` | Support | CORE_SUPPORT | match | Décrit le climat bas. | CURRENT | HIGH |
| `frequent_under_25` | `convergent_closed_match` | Support | ADDITIONAL_SUPPORT | match | Redondant avec climate actuel. | PARTIAL | HIGH |
| `solid_defense` / `frequent_clean_sheet` | `convergent_closed_match` | Support | ADDITIONAL_SUPPORT | une ou deux équipes | Défense solide soutient under. | CURRENT | HIGH |
| `scoring_difficulty` | `convergent_closed_match` | Support | ADDITIONAL_SUPPORT | une ou deux équipes | Faible attaque soutient match fermé. | CURRENT | HIGH |
| `open_match_profile` | `convergent_closed_match` | Aucune | STRONG_CONTRADICTION | match | Contradiction directe de rythme. | MISSING_RELATION | HIGH |
| `balanced_hierarchy` | `credible_outsider` | Support | CORE_SUPPORT | match | Réduit l'écart entre favori et outsider. | CURRENT | HIGH |
| outsider `positive_streak` | `credible_outsider` | Support | CORE_SUPPORT if opponent not same | outsider | Rend la surprise crédible si discriminant. | PARTIAL | MEDIUM |
| outsider `strong_home_team` / `strong_away_team` | `credible_outsider` | Home only | CORE_SUPPORT contextuel | selon side réel | Le contexte doit correspondre au terrain de l'outsider. | PARTIAL | HIGH |
| favorite `structural_level_gap` | `credible_outsider` | Aucune | CONTRADICTION | favori | Écart structurel fort réduit crédibilité outsider. | MISSING_RELATION | HIGH |
| outsider `scoring_difficulty` | `credible_outsider` | Aucune | CONTRADICTION | outsider | Surprise moins crédible sans capacité de marquer. | MISSING_RELATION | MEDIUM |
| `negative_streak` | `team_in_serious_difficulty` | Support | CORE_SUPPORT | sujet | Mauvaise dynamique. | CURRENT | HIGH |
| `scoring_difficulty` | `team_in_serious_difficulty` | Support | CORE_SUPPORT | sujet | Faible production offensive. | CURRENT | HIGH |
| `fragile_defense` | `team_in_serious_difficulty` | Support | CORE_SUPPORT | sujet | Faiblesse défensive. | CURRENT | HIGH |
| `weak_home_team` / `weak_away_team` | `team_in_serious_difficulty` | Away only produit | ADDITIONAL_SUPPORT | contexte du sujet | Le contexte local aggrave la difficulté. | PARTIAL | HIGH |
| `high_xg_creation` subject | `team_in_serious_difficulty` | Aucune | CONTRADICTION | sujet | Une équipe crée encore des occasions malgré les résultats. | MISSING_RELATION | MEDIUM |
| `offensive_underperformance` subject | `team_in_serious_difficulty` | Aucune | CONTRADICTION / REQUIRES_PRODUCT_DECISION | sujet | Peut signaler un potentiel caché plutôt qu'une difficulté structurelle. | MISSING_RELATION | MEDIUM |
| `ranking_superiority` favorite | `controlled_favorite` | Support | ADDITIONAL_SUPPORT | favori | Renforce contrôle mais pas nécessairement style fermé. | CURRENT | MEDIUM |
| `solid_defense` favorite | `controlled_favorite` | Support | CORE_SUPPORT | favori | Condition naturelle d'un favori en contrôle. | CURRENT | HIGH |
| opponent `scoring_difficulty` | `controlled_favorite` | Support | CORE_SUPPORT | adversaire | Réduit menace adverse. | CURRENT | HIGH |
| `closed_match_profile` | `controlled_favorite` | Support | ADDITIONAL_SUPPORT | match | Cohérent avec contrôle. | CURRENT | HIGH |
| opponent `high_xg_creation` | `controlled_favorite` | Aucune | CONTRADICTION | adversaire | Création adverse fragilise l'idée de contrôle. | MISSING_RELATION | HIGH |
| both teams `high_xg_creation`/`prolific_attack` | `both_sides_can_score` | CORE booleans | CORE_SUPPORT | home et away | Chaque équipe doit pouvoir marquer. | CURRENT | HIGH |
| any `fragile_defense`/`high_xg_conceded` | `both_sides_can_score` | CORE boolean | ADDITIONAL_SUPPORT | au moins une défense | Ouvre la porte au BTTS. | CURRENT | HIGH |
| `closed_match_profile` | `both_sides_can_score` | Aucune | CONTRADICTION | match | Climat fermé résiste au BTTS. | MISSING_RELATION | MEDIUM |
| one team `low_xg_creation`/`scoring_difficulty` | `both_sides_can_score` | Aucune | STRONG_CONTRADICTION | l'une des équipes | Une équipe incapable de créer contredit BTTS. | MISSING_RELATION | HIGH |
| target attack readings | `one_sided_scoring` | Support | CORE_SUPPORT | sujet | Capacité offensive cible. | CURRENT | HIGH |
| opponent defensive weakness | `one_sided_scoring` | Support | CORE_SUPPORT | adversaire | Défense adverse exposée. | CURRENT | HIGH |
| target `solid_defense` | `one_sided_scoring` | Support | ADDITIONAL_SUPPORT | sujet | Soutient sens unique, pas nécessaire à marquer. | CURRENT | MEDIUM |
| opponent `prolific_attack` / `high_xg_creation` | `one_sided_scoring` | Aucune | CONTRADICTION | adversaire | L'adversaire peut aussi peser offensivement. | MISSING_RELATION | HIGH |
| `negative_streak` + `offensive_underperformance` + `high_xg_creation` | `team_better_than_results` | CORE all | CORE_SUPPORT | sujet | Mauvais résultats mais production sous-jacente active. | CURRENT | HIGH |
| `low_xg_creation` | `team_better_than_results` | Aucune | STRONG_CONTRADICTION | sujet | Contredit l'idée de production cachée. | MISSING_RELATION | HIGH |
| `positive_streak` + overperformances | `team_worse_than_results` | CORE all | CORE_SUPPORT | sujet | Bons résultats portés par écarts xG. | CURRENT | HIGH |
| `misleading_result` | `team_worse_than_results` | limite attachée | ADDITIONAL_SUPPORT | sujet | C'est exactement la conclusion dérivée. | MISSING_RELATION | HIGH |
| `high_xg_creation` | `team_worse_than_results` | Aucune | CONTRADICTION | sujet | Création réelle forte nuance la thèse "worse". | MISSING_RELATION | MEDIUM |
| `balanced_hierarchy` | `avoid_match` | Support | CORE_SUPPORT | match | Peu discriminant. | CURRENT | HIGH |
| `conflicting_signals` | `avoid_match` | Support | CORE_SUPPORT | any | Ambiguïté explicite. | CURRENT | HIGH |
| `insufficient_data` | `avoid_match` | Support | CORE_SUPPORT | match/team | Données insuffisantes. | CURRENT | HIGH |
| opposed context strengths | `avoid_match` | Aucune | ADDITIONAL_SUPPORT | home strong vs away strong | Deux forces opposées réduisent la clarté. | MISSING_RELATION | HIGH |

Relations significatives proposées recensées dans cette matrice : 58.

## 9. Thesis -> Thesis Relationships

| Source Thesis | Target Thesis | Relation | Direction | Justification | Dérivable des readings ? | Statut |
|---|---|---|---|---|---|---|
| `expected_domination(A)` | `controlled_favorite(A)` | REINFORCES | même sujet | Domination structurelle + contrôle défensif convergent. | Oui, via hierarchy/defense/closed | PROPOSED |
| `controlled_favorite(A)` | `expected_domination(A)` | REINFORCES | même sujet | Le contrôle rend la domination plus crédible. | Oui | PROPOSED |
| `credible_outsider(B)` | `expected_domination(A)` | CONTRADICTS | adversaire | L'outsider crédible réduit la clarté de domination. | Oui, via balanced/opponent supports | PROPOSED |
| `both_sides_can_score` | `one_sided_scoring(A)` | CONTRADICTS | match vs team | BTTS contredit "sens unique" si l'adversaire a aussi création. | Partiellement | PROPOSED |
| `convergent_open_match` | `convergent_closed_match` | STRONGLY_CONTRADICTS | match | Rythmes opposés. | Oui, via open/closed readings | PROPOSED |
| `convergent_open_match` | `both_sides_can_score` | REINFORCES | match | Rythme ouvert soutient BTTS. | Oui | PROPOSED |
| `convergent_closed_match` | `controlled_favorite(A)` | COEXISTS / REINFORCES | match + favorite | Match fermé peut soutenir contrôle. | Oui | PROPOSED |
| `team_in_serious_difficulty(B)` | `one_sided_scoring(A)` | REINFORCES | adversaire de A | Difficulté B soutient pression A. | Oui | PROPOSED |
| `team_better_than_results(A)` | `team_in_serious_difficulty(A)` | CONTRADICTS | même sujet | Potentiel xG caché fragilise "serious difficulty". | Oui | PROPOSED |
| `team_worse_than_results(A)` | `expected_domination(A)` | CONTRADICTS | même sujet | Résultats positifs trompeurs fragilisent domination. | Oui | PROPOSED |
| `avoid_match` | toute thèse recommended | CONTRADICTS | match | Prudence globale devrait empêcher surconfiance. | Partiellement | PROPOSED |
| Legacy `solid_favorite` | V2 `expected_domination` | COEXISTS | même sujet | Concepts proches mais pas identiques. | Partiellement | PARTIAL |

Recommandation : ne pas coder directement la plupart de ces relations thesis->thesis. Elles doivent d'abord être dérivées des relations Reading->Thesis. Les relations directes utiles sont surtout les familles globales (`avoid_match`, conflit open/closed) quand elles représentent une décision produit de présentation.

## 10. Core Support vs Additional Support

| Thesis | Current CORE | Current additional | Proposed CORE | Proposed additional |
|---|---|---|---|---|
| `expected_domination` | `structural_level_gap` + 2 autres supports indifférenciés | aucun | structural + ranking + forme discriminante | attack, context, opponent weakness |
| `favorite_with_protection` | ranking + solid defense + contradiction | aucun | ranking/solid defense + risk signal | opponent creation, clean sheet |
| `convergent_open_match` | aucun obligatoire, min 3 | aucun | open climate ou bilateral creation + fragility | over label, xG, attacks |
| `convergent_closed_match` | aucun obligatoire, min 3 | aucun | closed climate ou defensive/low attack combo | clean sheets, low xG |
| `credible_outsider` | market outsider + supports min 3 | aucun | outsider status + gap-reducing sports supports | opponent fragility |
| `team_in_serious_difficulty` | min 3 weak readings | aucun | two/three weak families | opponent superiority |
| `controlled_favorite` | market favorite + min 3 | aucun | solid defense + opponent low threat | ranking, closed climate |
| `both_sides_can_score` | both creation + one fragility | aucun | both creation | open climate, fragility |
| `one_sided_scoring` | min 3 mixed directional | aucun | target attack + opponent defensive weakness | target defense, opponent scoring difficulty |
| `team_better_than_results` | all 3 readings | aucun | negative results + xG creation + underperformance | opponent fragility |
| `team_worse_than_results` | all 3 readings | aucun | positive results + xG overperformance | `misleading_result` |
| `avoid_match` | min 2 ambiguity readings | aucun | ambiguity/insufficient data | opposing strengths |

## 11. Contradiction Map

| Thesis | Current contradictions | Missing / proposed contradictions |
|---|---|---|
| `expected_domination` | same-team `misleading_result`, `conflicting_signals`, match `insufficient_data` | opponent context strength, opponent positive form, subject fragile defense, balanced hierarchy |
| `favorite_with_protection` | same-team contradictions required | opponent high creation / strong attack |
| `convergent_open_match` | all analysis contradictions, not rhythm-specific | closed profile, two solid defenses, low creation/scoring difficulty |
| `convergent_closed_match` | all analysis contradictions | open profile, two prolific attacks, high creation/high conceded |
| `credible_outsider` | same-team contradictions only | strong structural gap for favorite, outsider low creation/scoring difficulty |
| `team_in_serious_difficulty` | same-team contradictions only | hidden xG creation, offensive underperformance, positive form |
| `controlled_favorite` | same-team contradictions only | opponent high creation/prolific attack, open profile |
| `both_sides_can_score` | all analysis contradictions | one team's low creation/scoring difficulty, closed profile |
| `one_sided_scoring` | same-team contradictions only | opponent strong attack, opponent high creation |
| `team_better_than_results` | same-team contradictions only | low xG, scoring difficulty, fragile defense as nuance |
| `team_worse_than_results` | same-team contradictions only | high xG creation, solid defense |
| `avoid_match` | n/a | n/a |

## 12. Opposing Strength Cases

| Situation | Current handling | Proposed representation | Status |
|---|---|---|---|
| Home `strong_home_team` AND away `strong_away_team` | impossible, `strong_away_team` not produced | opposing contextual strengths, likely `avoid_match` support or contradiction to domination | MISSING_RELATION |
| Both teams `positive_streak` | both readings can exist; no discriminance check | non-discriminating form, not support for one-sided domination | MISSING_RELATION |
| Both teams `high_xg_creation` | supports `both_sides_can_score`; may also support open match | can contradict `one_sided_scoring` | PARTIAL |
| Target strong attack vs opponent solid defense | both can exist; no relation | opposing attack/defense strength | MISSING_RELATION |
| Hierarchy advantage vs outsider form/context | only candidate competition by priority | explicit contradiction between domination and outsider credibility | MISSING_RELATION |
| Closed climate vs individual attacking strength | candidates can coexist internally but V2 keeps one | relation open/closed/BTTS should be evaluated before selection | MISSING_RELATION |

## 13. Non-Discriminating Signal Cases

| Signal | Current risk | Why non-discriminating | Recommendation |
|---|---|---|---|
| `positive_streak(A)` and `positive_streak(B)` | Can support A if A also has structural gap | Both teams arrive well | Mark as support only if gap exists or opponent lacks same signal |
| Similar form scores, e.g. 11/15 vs 11/15 | Current V2 sees only absolute positive streak | No advantage in form | Add comparative relation, not new score yet |
| Both teams prolific | Can support open/BTTS | Does not decide winner | Avoid using for domination without subject relation |
| Both teams fragile defense | Supports open | Does not favor one side | Match-level only |
| Ranking gap by points but close ranks | `structural_level_gap` can trigger by OR | Structural message may overstate | Split rank and points relation in future |
| `frequent_over_25` with same climate as `open_match_profile` | Double counts one calculation | Same evidence appears as two readings | Treat one as derived display, or decide explicit double count |

## 14. Producer / Consumer Mismatches

| Concept | Producer | Consumer | Problème | Statut |
|---|---|---|---|---|
| `strong_away_team` | none | `expected_domination` away, mappings UI | Favorite away loses contextual support | CONSUMED_BUT_NOT_PRODUCED |
| `weak_home_team` | none | listed by `expected_domination` away, `team_in_serious_difficulty` home, mappings UI | Home difficulty and away domination asymmetrical; relation domination mal dirigée | CONSUMED_BUT_NOT_PRODUCED |
| `attack_in_form` | none | `FootballReading.toCopilotArgument`, copy catalog | UI/mapping suggests capability absent | HARDCODED_UI |
| `declining_defense` | none | copy/theme mappings | UI/mapping suggests capability absent | HARDCODED_UI |
| `frequent_btts` | none | copy/theme mappings, docs | BTTS reading absent though BTTS thesis exists | HARDCODED_UI |
| `false_favorite` | none | metadata legacy supprimée | Dead contradiction ID removed | REMOVED_LEGACY_METADATA |
| `improving_form` | `_formFor` | none V2 | Produced but no thesis uses it | PRODUCED_BUT_NOT_CONSUMED |
| `low_xg_creation` | `_expectedGoalsFor` | none V2 | Important contradiction unused | PRODUCED_BUT_NOT_CONSUMED |
| `defensive_underperformance` | `_expectedGoalsFor` | no direct V2 consumer | Defensive fragility xG not used | PRODUCED_BUT_NOT_CONSUMED |
| `open_match_confirmed` | ticket UI docs | no engine thesis | Presentation-only combined reading | HARDCODED_UI |

## 15. Missing Relations

| Source | Target | Relation attendue | Existe actuellement ? | Impact potentiel | Recommandation |
|---|---|---|---|---|---|
| opponent `strong_home_team` | `expected_domination(away)` | CONTRADICTION | Non | Domination extérieure suraffirmée | Ajouter relation contextuelle après validation |
| `strong_away_team` | `expected_domination(away)` | ADDITIONAL_SUPPORT | Consommé mais non produit | Favori visiteur sous-supporté | Produire lecture symétrique |
| `weak_home_team` | `team_in_serious_difficulty(home)` et `expected_domination(away)` | CORE/ADDITIONAL | Consommé mais non produit; domination mal dirigée | Difficultés home invisibles et domination away incomplète | Produire lecture symétrique puis mapper comme opponent relation |
| both positive forms | any superiority thesis | NON_DISCRIMINATING | Non | Support surestimé | Ajouter discriminance comparative |
| `low_xg_creation` | open/BTTS/team-better | CONTRADICTION | Non | Scénarios offensifs trop permissifs | Mapper comme contradiction |
| `closed_match_profile` | open/BTTS | STRONG_CONTRADICTION | Non | Coexistence non arbitrée | Relation rhythm opposée |
| `open_match_profile` | closed/controlled | CONTRADICTION | Non | Favori en contrôle trop permissif | Relation rhythm opposée |
| `misleading_result` | `team_worse_than_results` | ADDITIONAL_SUPPORT | Non, seulement contradiction | Conclusion xG sous-utilisée | Reclassifier comme support de cette thèse |
| favorite `structural_level_gap` | `credible_outsider` | CONTRADICTION | Non | Outsider peut être trop crédible | Mapper si gap fort |
| opponent high creation | `controlled_favorite` | CONTRADICTION | Non | Contrôle surestimé | Ajouter contradiction adverse |

## 16. Profile Leakage Audit

| Stage | Current dependency on profile | Should be global? | Reason | Severity |
|---|---|---:|---|---|
| `OpportunityEngineV2.opportunities` early return if `!profile.isCompleted` | Analyse absente | Oui | Un match devrait pouvoir être analysé sans profil | CRITICAL |
| competition filter before `analyzeOpportunity` | Analyse absente pour compétition désactivée | Oui | `Tous` pourrait vouloir l'intelligence complète | HIGH |
| `profile.isThesisAllowed(candidate.id)` before candidate selection | Candidate supprimée | Oui | Supprime renforcements/contradictions utiles | CRITICAL |
| compatible markets use enabled profile markets | Marché filtré | Non | Correct user-specific | LOW |
| `PickEngine` market check | Pick filtré | Non | Correct user-specific | LOW |
| UI profile copy | Textes personnalisés | Non | Correct présentation | LOW |

## 17. Backend / Shared Computation Audit

Calculable une fois par match :

- Normalisation snapshot dans `ApiFootballMatchAdapter`.
- Toutes les readings de `FootballAnalyzer`.
- Tous les candidats V2 sans filtre profil.
- Matrices support/contradiction.
- Liste complète des marchés disponibles et market intents théoriques.
- Warnings temporels, notamment xG post-kickoff.

Reste utilisateur-spécifique :

- Compétitions à afficher dans "Pour moi".
- Thèses préférées et ordre de présentation.
- Marchés activés, sélections compatibles, cotes maximales/minimales futures.
- Passage opportunity -> pick -> ticket.
- Ranking final et volume de propositions.

Écart actuel : `OpportunityEngineV2` ne matérialise pas un `FootballAnalysis` réutilisable. Le résultat est recalculé par appel profil et filtré avant conservation.

## 18. User-Facing Semantic Mismatches

| Internal concept | Actual calculation | User-facing wording | Mismatch | Severity |
|---|---|---|---|---|
| `structural_level_gap` | `rankGap >=5 || pointsGap >=8` | "Écart structurel confirmé" | OR rule peut être moins structurelle que le libellé | HIGH |
| `ranking_superiority` | rank ou points gap | "supériorité" | Supériorité au classement, pas globale | MEDIUM |
| `positive_streak` | score >=10 sur 5 | "dynamique positive" | Correct mais pas comparative | MEDIUM |
| `improving_form` | comparaison positions de la string | "amélioration récente" | Direction temporelle de `form` incertaine | HIGH |
| `frequent_over_25` | climate agrégé | "tendance/frequent over" | Pas de fréquence over calculée | HIGH |
| `frequent_under_25` | climate agrégé | "tendance/frequent under" | Pas de fréquence under calculée | HIGH |
| `expected_domination` | structural + 2 supports | "Domination attendue" | Peut ignorer résistances adverses majeures | HIGH |
| `scoring_difficulty` argument type | faible buts/match | `weakRecentForm` | Confond forme récente et production offensive | MEDIUM |
| `home_away_mismatch` | strong home + weak away uniquement | "Avantage domicile / extérieur" | Un seul sens couvert | HIGH |
| `insufficient_data` | absence globale ou xG rejeté | "Donnée non exploitable" | Un ID couvre deux situations | MEDIUM |

## 19. UI Integrity Findings

La feuille `_showScenarioReadingsSheet` dans `match_detail_page.dart` affiche toujours trois cartes :

- "Écart de niveau structurel";
- "Dynamique récente supérieure";
- "Avantage domicile / faiblesse extérieure".

Ces cartes sont reconstruites depuis `MatchBoardItem.analysis` via `_scenarioStructuralDescription`, `_scenarioFormDescription`, `_scenarioHomeAwayDescription`, et non depuis la liste réelle `opportunity.supportingReadings`. Le compteur `_scenarioReadingCount` plafonne les `supportingEvidence` à 3, ou tombe sur `signals.length`, ce qui peut diverger du nombre réel de readings V2.

Ce qui vient réellement du moteur :

- `match.thesis.title`, `summary`, `supportingEvidence`, `limits`, `arguments`;
- `opportunity.positiveArguments`, `contradictions`, `supportingReadings` quand l'opportunity est passée;
- `FootballReadingCopyCatalog` utilise `readingId` dans les paramètres des `CopilotArgument`.

Ce qui est hardcodé ou reconstruit :

- les trois cartes fixes de la bottom sheet;
- les descriptions de forme/classement/home-away;
- certains IDs d'explication tickets : `home_strength`, `positive_form`, `xg_creation`, `open_match_confirmed`, `team_in_difficulty`, `probable_goal`;
- le mapping `_readingIdForLabel` du ticket generator qui devine un thème depuis du texte.

Statut : `HARDCODED_UI` pour les cartes fixes et les IDs d'explication non produits par le moteur.

## 20. KR Reykjavik vs Vikingur Case Study

Données pré-match fournies :

- Vikingur : 1er, 51 points.
- KR : 3e, 43 points.
- Écart : 2 places, 8 points.
- KR à domicile : 8V, 2N, 0D.
- Vikingur à l'extérieur : 8V, 1N, 1D.
- Forme comparable autour de 11/15.
- Opportunity actuelle : `expected_domination(Vikingur)`.

Pourquoi `expected_domination(Vikingur)` peut être détectée aujourd'hui :

- `structural_level_gap(Vikingur)` peut être déclenché par `pointsGap >= 8` même si `rankGap = 2`.
- `ranking_superiority(Vikingur)` peut être déclenché par `pointsGap >= 5`.
- `positive_streak(Vikingur)` peut exister si la forme atteint `score >= 10`.
- Si d'autres supports match-level existent, `supporting.length >= 3` est atteint.

Core supports actuels probables :

- `structural_level_gap(Vikingur)`;
- `ranking_superiority(Vikingur)`;
- `positive_streak(Vikingur)` si forme >=10.

Additional supports qui devraient exister :

- `strong_away_team(Vikingur)` car 8V/1N/1D away indique une force extérieure, mais cette reading n'est pas produite.

Contradictions/résistances KR qui devraient être représentées :

- `strong_home_team(KR)` avec 8V/2N/0D est une contradiction contextuelle importante contre une domination extérieure.
- Forme KR comparable autour de 11/15 rend `positive_streak(Vikingur)` peu discriminant.
- `balanced_hierarchy` ne se déclenche pas car pointsGap=8, mais le rankGap=2 montre un cas mixte : points gap fort, classement proche.

Thèses pouvant coexister :

- `expected_domination(Vikingur)`;
- `credible_outsider(KR)` si marché outsider et supports KR suffisants;
- `avoid_match` conceptuel si deux forces contextuelles fortes s'opposent;
- un scénario ouvert/fermé indépendant si les stats buts le soutiennent.

Relations manquantes aujourd'hui :

- `strong_home_team(KR)` -> contradiction de `expected_domination(Vikingur away)`;
- `strong_away_team(Vikingur)` -> support additionnel produit;
- signal "forme comparable" -> non-discriminating support;
- relation rankGap faible mais pointsGap fort -> ambiguïté structurelle à valider.

Le résultat final du match n'est pas utilisé dans cette analyse.

## 21. "Solid Favorite" Conceptual Case Study

Le concept existe déjà comme :

- profil utilisateur `solid_favorite` dans `OpportunityProfileCatalog`;
- thèse legacy `solid_favorite`;
- famille qui inclut en V2 `expected_domination`, `favorite_with_protection`, `controlled_favorite`.

Il n'existe pas comme thèse V2 explicite.

Noyau existant possible :

- `ranking_superiority` / `structural_level_gap`;
- forme positive ou avantage de forme comparatif;
- reliability edge legacy (`lossRate` plus faible), mais pas produit comme `FootballReading`;
- contexte home/away symétrique.

Capacités manquantes :

- vraie trajectoire temporelle : `D D W W W` vs `W W W D D`;
- relation discriminante de forme;
- `strong_away_team`, `weak_home_team`;
- market favorite comme reading ou comme relation explicite séparée du profil;
- conservation des contradictions adverses même si l'utilisateur ne sélectionne que classement/forme.

## 22. Relation Gaps Ranked by Severity

| Severity | Source | Target | Relation attendue | Existe actuellement ? | Impact potentiel | Recommandation |
|---|---|---|---|---|---|---|
| CRITICAL | `profile.isThesisAllowed` | all candidate theses | Ne devrait pas supprimer l'intelligence globale | Oui, filtre trop tôt | Cécité profil | Séparer analyse exhaustive et matching |
| CRITICAL | opponent `strong_home_team` | `expected_domination(away)` | CONTRADICTION | Non | Domination away trompeuse | Mapper après validation |
| HIGH | `strong_away_team` | away theses | SUPPORT | Consommé, non produit | Asymétrie visiteurs | Produire lecture |
| HIGH | `weak_home_team` | home difficulty / away domination | SUPPORT | Consommé, non produit | Asymétrie domicile | Produire lecture |
| HIGH | `closed_match_profile` | open/BTTS | CONTRADICTION | Non | Scénarios buts incohérents | Relation rhythm opposée |
| HIGH | `low_xg_creation` | offensive theses | CONTRADICTION | Non | Supports offensifs trop faibles | Mapper contradiction |
| HIGH | UI fixed readings sheet | actual readings | Doit refléter moteur | Non | UI raconte une lecture inexistante | Refondre après validation |
| MEDIUM | `improving_form` | favorite/outsider | SUPPORT | Non | Trajectoire ignorée | Valider direction temporelle |
| MEDIUM | `misleading_result` | `team_worse_than_results` | SUPPORT | Non | Thèse xG moins claire | Mapper comme support |
| LOW | `false_favorite` | contradictions | Concept à clarifier | Non | Metadata morte | Supprimer ou produire plus tard |

## 23. Ambiguous Relations Requiring Product Decision

| # | Ambiguïté | Décision requise |
|---:|---|---|
| 1 | `positive_streak` est-il core de domination si l'adversaire est aussi en forme ? | Définir discriminance requise. |
| 2 | `structural_level_gap` par points seuls suffit-il à "structurel" ? | Valider vocabulaire ou relation. |
| 3 | `frequent_over_25` doit-il rester une reading séparée si même calcul que `open_match_profile` ? | Éviter double counting. |
| 4 | Même question pour `frequent_under_25`. | Éviter double counting. |
| 5 | `favorite_with_protection` doit-il nécessiter une contradiction ? | Core ou downgrade marché. |
| 6 | `credible_outsider` doit-il être autorisé face à un `structural_level_gap` fort ? | Définir contradiction forte. |
| 7 | `both_sides_can_score` exige-t-il fragilité d'une ou des deux défenses ? | Valider logique BTTS. |
| 8 | `one_sided_scoring` inclut-il contrôle défensif ou seulement scoring cible ? | Séparer thèses si besoin. |
| 9 | `team_better_than_results` doit-il être contredit par défense fragile ? | Valider rôle de la défense. |
| 10 | `team_worse_than_results` est-il une thèse autonome ou une contradiction réutilisable ? | Définir statut produit. |
| 11 | `avoid_match` doit-il être affiché même hors profil ? | Décision "Tous" / prudence. |
| 12 | Market favorite doit-il devenir une `FootballReading` ? | Clarifier frontière marché/football. |
| 13 | Reliability edge legacy doit-il devenir une reading V2 ? | Valider valeur produit. |
| 14 | La direction temporelle de `form` est-elle fiable et uniforme ? | Fixer convention avant trajectoire. |
| 15 | Les readings de contexte doivent-elles utiliser splits home/away pour attaque/défense ? | Valider granularité. |
| 16 | `insufficient_data` doit-il être scindé entre absence globale et donnée rejetée ? | Clarifier sémantique. |
| 17 | Les relations thesis->thesis doivent-elles être codées ou dérivées ? | Choisir modèle cible. |
| 18 | `solid_favorite` revient-il comme thèse V2 ou reste-t-il profil composite ? | Décision architecture. |

Nombre de décisions/ambiguïtés : 18.

## 24. Recommended Target Relationship Model

Modèle conceptuel déterministe recommandé, sans implémentation :

```text
MatchAnalysisBundle
  fixtureId
  asOf
  readings[]
  candidateTheses[]
  readingThesisRelations[]
  derivedThesisRelations[]
  temporalWarnings[]
```

Relation reading -> thesis :

```text
sourceReadingId
targetThesisId
relation: CORE_SUPPORT | ADDITIONAL_SUPPORT | CONTRADICTION | STRONG_CONTRADICTION | NON_DISCRIMINATING | NOT_RELEVANT
teamDirection: SUBJECT | OPPONENT | HOME | AWAY | MATCH
context
status: CURRENT | PARTIAL | MISSING_RELATION | PROPOSED
confidence: HIGH | MEDIUM | LOW
```

Règle d'architecture :

- Les thèses ne doivent pas être filtrées avant la construction du bundle match.
- Le profil ne doit intervenir qu'après, pour sélectionner, prioriser, ordonner ou masquer.
- Une thèse non préférée doit rester disponible si elle renforce ou contredit une thèse préférée.
- Les relations thesis->thesis doivent être dérivées des readings chaque fois que possible pour éviter la duplication.

## 25. Questions to Resolve Before Implementation

1. `solid_favorite` doit-il être une thèse V2 autonome ou seulement une famille profil ?
2. Quels signaux sont obligatoirement discriminants pour soutenir une thèse de supériorité ?
3. Les contradictions adverses doivent-elles bloquer une thèse ou seulement l'annoter ?
4. Les readings `frequent_over_25` et `frequent_under_25` doivent-elles être recalculées depuis de vraies fréquences ?
5. Faut-il scinder les readings "total season" et "home/away split" pour attaque/défense ?
6. `avoid_match` doit-il exister dans le résultat global indépendamment du profil ?
7. Quel format stable adopter pour sérialiser une analyse match réutilisable par plusieurs utilisateurs ?
8. Quelle convention temporelle officielle pour `form` : premier caractère = plus récent ou plus ancien ?
9. Quels IDs présentation-only doivent disparaître ou être alignés sur le moteur ?
10. Faut-il conserver le fallback legacy une fois la matrice V2 validée ?

## Vérification Finale

- IDs `FootballReading` produits reparcourus dans `football_analyzer.dart`.
- IDs de readings consommés reparcourus dans `opportunity_engine_v2.dart`, `football_reading.dart`, `opportunity_decision_presenter.dart`, `app_components.dart`, `ticket_generator_page.dart`.
- IDs thèses V2 reparcourus dans `opportunity_engine_v2.dart`.
- Mappings profil reparcourus dans `decision_profile_catalogs.dart` et `compiled_decision_profile.dart`.
- Tests inspectés : `football_analyzer_test.dart`, `opportunity_engine_v2_test.dart` et `opportunity_decision_presenter_test.dart`.
- Aucune relation proposée n'est marquée `CURRENT` si elle n'est pas visible dans le code.
- Le cas KR Reykjavik vs Vikingur utilise uniquement les données pré-match fournies.

Compteurs :

- Lectures recensées : 35 au total, dont 29 produites par `FootballAnalyzer`.
- Thèses/scénarios recensés : 18 uniques, dont 12 V2.
- Relations significatives proposées : 58.
- Décisions/ambiguïtés à valider : 18.
