# Migration moteur football V2

Date : 2026-08-03

## Architecture mise en place

Le moteur est maintenant structure en couches :

```text
MatchBoardItem + MatchAnalysisData
        ↓
FootballAnalyzer
        ↓
FootballReading[]
        ↓
OpportunityEngineV2
        ↓
Opportunity
        ↓
PickEngine / TicketGenerator
```

Le moteur historique reste present comme filet de securite dans `MatchInsightEngine`.
Si V2 produit une Opportunity, elle est utilisee. Sinon V1 continue de proteger les comportements existants.

## Contrats crees ou modifies

- `FootballReading` : lecture elementaire, horodatee, avec preuves et warnings.
- `FootballAnalysis` : ensemble de lectures pour une fixture.
- `ReadingRule` / `FootballReadingRules` : seuils documentes et centralises.
- `OpportunityEngineV2` : combinaison explicite des lectures.
- `PickEngine` : frontiere Opportunity vers pick eligible.
- `MatchAnalysisData` : ajoute `asOf`, xG, split home/away et flag predictions.
- `TeamExpectedGoalsSnapshot` : rolling xG et divergences buts/xG.
- `Opportunity` : ajoute `supportingReadings`, `contradictoryReadings`, `asOf`.

## Metriques disponibles

- classement : rang, points, matchs joues ;
- forme : serie compacte `W/D/L` ;
- splits domicile/exterieur : joues, victoires, nuls, defaites ;
- buts : moyennes pour/contre, clean sheets, failed to score ;
- xG : rolling xG for/against 5 matchs, saison, buts-xG, buts encaisses-xG ;
- marches : selections normalisees deja disponibles dans `MatchMarket`.

## Lectures implementees

- `ranking_superiority`
- `balanced_hierarchy`
- `structural_level_gap`
- `positive_streak`
- `negative_streak`
- `improving_form`
- `declining_form`
- `strong_home_team`
- `weak_away_team`
- `home_away_mismatch`
- `prolific_attack`
- `scoring_difficulty`
- `solid_defense`
- `fragile_defense`
- `frequent_clean_sheet`
- `open_match_profile`
- `frequent_over_25`
- `closed_match_profile`
- `frequent_under_25`
- `high_xg_creation`
- `low_xg_creation`
- `high_xg_conceded`
- `offensive_underperformance`
- `offensive_overperformance`
- `defensive_underperformance`
- `defensive_overperformance`
- `misleading_result`
- `conflicting_signals`
- `insufficient_data`

## Opportunities implementees

- `expected_domination`
- `favorite_with_protection`
- `convergent_open_match`
- `convergent_closed_match`
- `credible_outsider`
- `team_in_serious_difficulty`
- `controlled_favorite`
- `both_sides_can_score`
- `one_sided_scoring`
- `team_better_than_results`
- `team_worse_than_results`
- `avoid_match`

## Mapping lecture vers Opportunity

| Opportunity | Lectures principales |
|---|---|
| `expected_domination` | `structural_level_gap`, `ranking_superiority`, `positive_streak`, `strong_home_team`, `weak_away_team`, `home_away_mismatch` |
| `favorite_with_protection` | `ranking_superiority`, `solid_defense`, contradiction |
| `convergent_open_match` | `open_match_profile`, `frequent_over_25`, `high_xg_creation`, `fragile_defense`, `high_xg_conceded` |
| `convergent_closed_match` | `closed_match_profile`, `frequent_under_25`, `solid_defense`, `frequent_clean_sheet`, `scoring_difficulty` |
| `credible_outsider` | `balanced_hierarchy`, dynamique outsider, fragilite adverse |
| `team_in_serious_difficulty` | `negative_streak`, `scoring_difficulty`, `fragile_defense`, `weak_away_team` |
| `controlled_favorite` | `ranking_superiority`, `solid_defense`, `scoring_difficulty` adverse, `closed_match_profile` |
| `both_sides_can_score` | creations offensives des deux equipes, defense fragile ou xG conceded |
| `one_sided_scoring` | attaque forte, defense adverse fragile, attaque adverse faible, defense solide |
| `team_better_than_results` | `negative_streak`, `offensive_underperformance`, `high_xg_creation` |
| `team_worse_than_results` | `positive_streak`, `offensive_overperformance`, `defensive_overperformance` |
| `avoid_match` | `balanced_hierarchy`, `conflicting_signals`, `insufficient_data` |

## Mapping Opportunity vers marches compatibles

| Opportunity | Marches cibles |
|---|---|
| `expected_domination` | `matchResult`, `doubleChance` |
| `favorite_with_protection` | `doubleChance` |
| `convergent_open_match` | `goalsTotal Over 2.5`, `bothTeamsScore Yes` |
| `convergent_closed_match` | `goalsTotal Under 2.5` |
| `credible_outsider` | `doubleChance`, `matchResult` |
| `team_in_serious_difficulty` | `doubleChance` adverse, `matchResult` adverse |
| `controlled_favorite` | `matchResult`, `doubleChance` |
| `both_sides_can_score` | `bothTeamsScore Yes` |
| `one_sided_scoring` | `teamTotalHome/Away Over 0.5`, `matchResult` |
| `team_better_than_results` | `doubleChance` |
| `team_worse_than_results` | aucun marche automatique par defaut |
| `avoid_match` | aucun marche |

## Onboarding

Les dix familles d'opportunities sont maintenant supportees par le catalogue.
Les descriptions ont ete reformulees pour rester comprehensibles et ne pas exposer les lectures techniques.

## Seuils documentes

Les seuils sont centralises dans `FootballReadingRules` :

- hierarchy : `rankGap >= 3`, `pointsGap >= 5`, structurel `rankGap >= 5` ou `pointsGap >= 8` ;
- forme : 5 matchs, positif `>= 10` points, negatif `<= 4` points ;
- domicile/exterieur : fort `>= 60%`, faible exterieur `>= 45%` de defaites ;
- attaque : prolifique `>= 1.70` but/match, difficulte `<= 0.90` ;
- defense : solide `<= 1.00`, fragile `>= 1.60`, clean sheet `>= 35%` ;
- rythme : ouvert `>= 2.80`, ferme `<= 2.10` ;
- xG : creation haute `>= 1.50`, creation basse `<= 0.90`, xG concedé haut `>= 1.50`, divergence `>= 1.50`.

## Regles temporelles

- `MatchAnalysisData.asOf` porte l'horodatage du snapshot.
- Les xG sont utilises uniquement si leur `asOf` n'est pas posterieur au kickoff du match analyse.
- Si des xG post-match sont fournis pour une lecture pre-match, ils deviennent `insufficient_data` avec warning `post_match_xg_rejected`.
- Les predictions API restent signalees par `containsPredictions`, mais ne sont pas transformees en preuves factuelles.

## Elements non encore supportes

- calcul automatique des agrégats xG depuis une serie brute de fixtures ;
- qualite des adversaires recents ;
- blessures avec impact objectif par minutes/titularisations ;
- compositions et `lineup_strength_change` ;
- BTTS derive depuis historique reel match par match ;
- stockage backend immutable des snapshots API.

## Checklist

### Donnees

- [x] snapshots horodates avec `asOf` dans le domaine ;
- [x] aucune donnee xG posterieure utilisee en pre-match ;
- [x] xG stockables apres match via `TeamExpectedGoalsSnapshot` ;
- [ ] cotes stockees avant coup d'envoi dans un backend persistant ;
- [x] distinction donnees factuelles / predictions API ;
- [x] taille d'echantillon disponible.

### Football Analyzer

- [x] lectures elementaires independantes ;
- [x] aucune selection de marche ;
- [x] preuves attachees ;
- [x] contradictions attachees ;
- [x] donnees insuffisantes gerees ;
- [x] tests unitaires par famille prioritaire.

### Opportunity Engine

- [x] combinaisons explicites ;
- [x] une seule Opportunity par rencontre ;
- [x] plusieurs profils possibles ;
- [x] aucune duplication ;
- [x] Opportunity possible sans marche ;
- [x] `avoid_match` possible.

### xG

- [x] `expected_goals` transportable ;
- [x] xG pour et contre attribues correctement ;
- [x] agregats sur cinq matchs ;
- [x] agregats saison ;
- [x] divergences buts/xG ;
- [x] aucun usage futuriste des xG ;
- [x] absence de xG geree sans erreur.

### Onboarding

- [x] question conservee et descriptions reformulees ;
- [x] descriptions courtes ;
- [x] familles comprehensibles ;
- [x] aucune lecture technique exposee ;
- [x] profils non supportes retires du parcours principal ;
- [x] modification apres onboarding conservee.

### UI

- [x] arguments avant statistiques deja en place dans les cartes/detail ;
- [x] contradictions visibles par compteurs ;
- [x] aucune confiance en pourcentage dans les tests UI principaux ;
- [x] preuves consultables via arguments existants ;
- [x] Opportunity sans marche affichee ;
- [x] une seule carte par match.

### Regression

- [x] `dart format` ;
- [x] `flutter analyze` ;
- [x] `flutter test` ;
- [x] aucun changement silencieux des regles existantes : fallback V1 conserve ;
- [x] documentation des seuils ;
- [x] rapport de migration.
