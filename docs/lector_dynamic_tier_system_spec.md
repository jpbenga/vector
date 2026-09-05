# Lector - Dynamic Championship Tier System Spec

Date de specification : 2026-09-02  
Statut : product model verrouille avant formalisation algorithmique.  
Reference : `docs/lector_business_matrix_v2_1.md`  
Perimetre : Structural Championship Intelligence, Dynamic Championship Tier System, ChampionshipTierSnapshot, TeamTierAssignment, Tier Gap, boundaries, maturity, temporal safety.

## Executive Summary

Le Dynamic Championship Tier System est une fonctionnalite autonome de Lector. Il sert a comprendre la structure reelle d'un championnat a un instant donne, en analysant la distribution interne des points, les ancres footballistiques et les ruptures entre zones du classement.

Il ne remplace pas le classement officiel. Il ne predit pas la force intrinseque des equipes. Il ne consomme pas la forme, les xG, les records home/away, les cotes ou le profil utilisateur.

Le systeme produit de la `Structural Championship Intelligence` reusable :

```text
CHAMPIONSHIP RAW / NORMALIZED DATA
    -> CHAMPIONSHIP STRUCTURAL INTELLIGENCE
    -> DYNAMIC CHAMPIONSHIP TIER SYSTEM
    -> CHAMPIONSHIP TIER SNAPSHOT
    -> TEAM TIER ASSIGNMENTS
    -> MATCH STRUCTURAL RELATION
    -> MATCH INTELLIGENCE
    -> READINGS / ELIGIBILITY GATES / THESES
```

Decision centrale : les 5 labels de Tier sont le vocabulaire maximal, pas une obligation de produire 5 groupes remplis. Un Tier intermediaire peut etre absent si la distribution ne justifie pas de zone structurelle distincte.

Decision produit verrouillee : utiliser un modele `ANCHORED ROBUST HYBRID`, deterministic et explicable, base sur le classement officiel, la distribution officielle des points, une qualification PPG secondaire pour les games-in-hand, des anchors podium/relegation, et une detection robuste des boundaries relatives au championnat.

Ce modele verrouille l'architecture produit. Il ne verrouille pas encore la formule exacte, les coefficients, les seuils, la combinaison MAD / segmentation / natural breaks, ni la regle numerique finale de `POINT_GAP_BREAK`. Ces elements passent en `REQUIRES_ALGORITHMIC_DEFINITION`.

## Scope

Ce document definit :

- le vocabulaire metier des Tiers ;
- les inputs necessaires ;
- la difference entre rang officiel et interpretation structurelle ;
- la notion de `POINT_GAP_BREAK` ;
- les options Points vs PPG ;
- les Tiers absents ;
- les structural boundaries ;
- le Tier Gap ;
- la maturity ;
- la stability ;
- la temporal safety ;
- le snapshot contract conceptuel ;
- les cas de test ;
- les methodes algorithmiques candidates ;
- le modele recommande ;
- les decisions produit restantes.

## Non-Goals

Cette specification ne doit pas :

- modifier la Business Matrix V2.1.1 ;
- implementer un algorithme ;
- modifier du code Dart, SQL, Edge Function, UI ou test ;
- creer des seuils numeriques arbitraires ;
- creer un score de clarity ;
- transformer le Tier System en power ranking ;
- remplacer le classement officiel ;
- utiliser un profil utilisateur ;
- utiliser la forme, les xG, les cotes ou les performances home/away pour assigner des Tiers.

## Relationship with Business Matrix V2.1.1

La Business Matrix V2.1.1 est verrouillee.

Le Dynamic Tier System fournit les artifacts necessaires a certaines readings, relations et Eligibility Gates, notamment :

- `teamTier` ;
- `tierGap` ;
- `structuralBoundaryInformation` ;
- `tierMaturity` ;
- `ChampionshipTierSnapshot`.

Il respecte les principes verrouilles :

- football analysis is profile-independent ;
- every available reading is preserved ;
- every canonical thesis is evaluated ;
- raw facts are not automatically independent evidence ;
- structural artifacts are distinct from ordinary readings ;
- Gate Failure != Contradiction ;
- Evidence unavailable != Contradiction ;
- correlated readings cannot inflate evidence count ;
- market context cannot manufacture football evidence ;
- same Tier blocks `expected_domination` ;
- passing the Tier Gate does not automatically validate `expected_domination`.

## Domain Definition

Question metier :

> Comment la hierarchie actuelle de CE championnat est-elle structurellement organisee a `analysisAsOf` ?

Le systeme doit repondre a trois niveaux :

1. Structure championnat : quelles zones existent vraiment ?
2. Assignment equipe : a quel niveau appartient chaque equipe ?
3. Relation match : combien de separation structurelle existe entre deux equipes ?

Il doit pouvoir s'abstenir :

- si les standings sont absents ;
- si le championnat est trop jeune ;
- si les donnees sont incoherentes ;
- si la competition a une structure non supportee en V1.

## Five-Tier Vocabulary

| Tier | Label technique | Label FR | Signification |
|---|---|---|---|
| `TIER_1` | `PODIUM` | Podium | Zone superieure de reference du championnat. |
| `TIER_2` | `UPPER_CHAMPIONSHIP` | Groupe superieur | Equipes proches du haut sans appartenir au podium. |
| `TIER_3` | `MIDDLE_CHAMPIONSHIP` | Milieu de tableau | Groupe central structurel. |
| `TIER_4` | `LOWER_CHAMPIONSHIP` | Groupe inferieur | Equipes proches du bas sans appartenir a la relegation. |
| `TIER_5` | `RELEGATION` | Relegation | Zone inferieure structurelle, selon la competition. |

Ces 5 categories constituent le vocabulaire maximal. Elles ne signifient pas que chaque snapshot doit contenir 5 groupes.

## Anchors

Le systeme utilise deux ancres footballistiques :

- `PODIUM` ;
- `RELEGATION`.

Ces ancres doivent venir de la structure reelle de la competition. Elles ne doivent pas etre supposees universellement comme `top 3` et `last 3`.

Repository findings :

| Data | Status | Notes |
|---|---|---|
| `rank` | Available | Normalise dans `TeamStandingSnapshot`. |
| `points` | Available | Normalise dans `TeamStandingSnapshot`. |
| `played` | Available | Normalise depuis `standing.all.played`. |
| full standings by league | Available / partial | `ApiFootballMatchAdapter` construit une table triee par leagueId. |
| `group` | Available | Normalise dans `TeamStandingSnapshot`. |
| standings `description` | Source available, not retained | API-Football raw standings expose des descriptions comme promotion/relegation, mais `TeamStandingSnapshot` ne les conserve pas actuellement. |
| qualification zones | Requires data source retention | Souvent presentes via `description` dans le brut API-Football. |
| relegation zones | Requires data source retention | Souvent presentes via `description`, mais non normalisees aujourd'hui. |
| league metadata | Partial | `CompetitionInfo` contient id, name, country, season, apiFootballLeagueId, logoUrl. |
| competition-specific rules | Missing | Pas de metadata locale podium/relegation/playoff par competition. |

Decision verrouillee : utiliser une source hybride d'anchors.

Ordre conceptuel :

1. reliable competition metadata / explicit Lector override ;
2. reliable retained API-Football standings description ;
3. otherwise anchor unavailable.

`TIER_1 = PODIUM` is locked for supported standard championships. `TIER_5` represents the true relegation zone when the competition has one.

Data work remains `REQUIRES_IMPLEMENTATION` because the current normalized model does not retain `standings[].description`.

## Why Tiers Are Dynamic

Deux championnats avec les memes ranks peuvent avoir des structures differentes.

Example compact :

```text
1  60
2  58
3  57
4  55
5  53
6  52
```

Example avec rupture podium :

```text
1  60
2  59
3  58
4  45
5  44
6  42
```

Dans les deux cas, `rankGap(3,4) = 1`. Mais la relation structurelle entre 3e et 4e n'est pas la meme.

## Championship-Relative Structure

Chaque championnat est son propre referentiel.

Un `pointsGap = 8` peut etre :

- enorme dans un championnat compact ;
- banal dans un championnat tres etire ;
- decisif autour d'une boundary ;
- peu significatif au milieu d'une distribution continue.

Le systeme doit donc evaluer un gap par rapport a la distribution interne du championnat, pas par rapport a une constante universelle.

## Official Rank vs Structural Interpretation

Le classement officiel reste la verite factuelle :

- une equipe 7e reste officiellement 7e ;
- Lector ne doit pas pretendre qu'elle est 4e ;
- PPG ou toute normalisation ne reecrit pas le classement.

La Structural Interpretation repond a une autre question :

> Cette equipe appartient-elle structurellement au meme groupe que les equipes qui l'entourent ?

## Point Distribution

Le systeme traite le classement comme une distribution ordonnee.

Inputs minimum :

- teamId ;
- officialRank ;
- points ;
- played ;
- competitionId ;
- season ;
- analysisAsOf.

Derived facts possibles :

- adjacent gaps ;
- points per game ;
- played distribution ;
- compactness ;
- stretch ;
- candidate boundaries ;
- boundary strength ;
- distance to boundary.

## Point Gap Break

Definition :

> Un `POINT_GAP_BREAK` est une rupture inhabituellement importante entre deux zones voisines du classement, relativement a la distribution interne du championnat.

Il ne doit pas etre defini par une constante universelle.

Le break depend :

- de la taille des adjacent gaps ;
- de la distribution globale de ces gaps ;
- de la position du gap ;
- des anchors ;
- de la maturite du championnat ;
- d'une eventuelle normalisation PPG.

Status : concept produit verrouille. La formule exacte est `REQUIRES_ALGORITHMIC_DEFINITION`.

## Points vs PPG

Le systeme doit traiter les games-in-hand.

### Option A - Points only

Principe : utiliser uniquement les points officiels.

Avantages :

- tres explicable ;
- respecte strictement le classement officiel ;
- stable pour l'utilisateur.

Problemes :

- peut surestimer un ecart lorsque des equipes ont des matchs en retard ;
- fragile dans les ligues avec calendrier desequilibre ;
- peut creer une boundary structurelle artificielle.

### Option B - PPG only

Principe : remplacer les points par points per game.

Avantages :

- compare le rendement ;
- corrige mieux les matchs en retard ;
- utile dans les calendriers fortement desequilibres.

Problemes :

- peut sembler reecrire le classement officiel ;
- moins intuitif pour l'utilisateur ;
- plus volatil en debut de saison ;
- peut contredire la table officielle.

### Option C - Hybrid

Principe :

```text
official standings position
    + points distribution
    + PPG normalization when played mismatch exists
```

Avantages :

- conserve la verite factuelle du classement ;
- limite les erreurs dues aux games-in-hand ;
- reste explicable si PPG est presente comme ajustement de structure, pas comme classement alternatif.

Problemes :

- necessite une politique produit : quand le mismatch de matchs joues justifie-t-il l'ajustement ?
- complexite d'explication superieure a Points only.

Locked decision : Hybrid.

```text
official points = primary structural signal
PPG = secondary qualification when played imbalance may distort apparent structure
```

PPG must not rewrite official rank, become the primary Tier basis, create a Tier alone, create a `POINT_GAP_BREAK` alone, or create structural superiority alone.

The numeric activation condition remains `REQUIRES_ALGORITHMIC_DEFINITION`.

## Games-in-Hand

Cas :

```text
Team A: 40 pts, 20 played, PPG 2.00
Team B: 36 pts, 18 played, PPG 2.00
```

Le `pointsGap = 4` existe officiellement. Mais la structure peut etre plus proche que les points bruts ne le suggerent.

Regle verrouillee :

- official points remain primary ;
- PPG is secondary structural context ;
- PPG can weaken or qualify a candidate boundary ;
- PPG must not rewrite official rank ;
- PPG influence formula remains `REQUIRES_ALGORITHMIC_DEFINITION`.

## Intermediate Tier Discovery

Entre Podium et Relegation :

- `TIER_2` = Upper Championship ;
- `TIER_3` = Middle Championship ;
- `TIER_4` = Lower Championship.

Ces Tiers doivent venir de boundaries structurelles detectees. Ils ne doivent pas etre des thirds, quartiles, quintiles ou ranges fixes.

Le systeme doit permettre :

```text
TIER_1 = present
TIER_2 = absent
TIER_3 = present
TIER_4 = present
TIER_5 = present
```

## Missing Tier Semantics

Un Tier absent ne signifie pas que des equipes n'ont pas ete analysees.

Cela signifie :

> La distribution actuelle ne justifie pas une zone structurelle suffisamment distincte pour materialiser ce label.

Example :

```text
TIER_1 = podium anchor
TIER_2 = absent
TIER_3 = large central cluster
TIER_4 = absent
TIER_5 = relegation anchor
```

Le label absent reste connu dans le vocabulaire, mais n'est pas peuple dans le snapshot.

Status : `LOCKED_PRODUCT_DECISION`.

Missing labels are allowed. They are not data gaps, engine errors or unanalysed teams.

## Structural Boundaries

Une boundary est une rupture detectee entre deux zones.

Un Tier est la classification resultante.

Cette distinction permet de separer :

- combien de labels separent deux equipes ;
- combien de boundaries structurelles significatives les separent.

## Tier Gap Semantics

Deux notions sont necessaires :

| Concept | Meaning | Use |
|---|---|---|
| `ordinalTierGap` | Difference entre labels numeriques de Tier. | Simple a lire, utile pour explication. |
| `structuralBoundaryGap` | Nombre de boundaries structurelles significatives entre deux equipes. | Plus juste si des Tiers intermediaires sont absents. |

Example :

```text
TIER_1 exists
TIER_2 absent
TIER_3 exists
Team A = TIER_1
Team B = TIER_3
```

Options :

- ordinal gap = 2 ;
- effective structural boundary gap = 1.

Locked decision :

- `ordinalTierGap` is retained as explanatory metadata ;
- `structuralBoundaryGap` is retained as the default structural separation measure ;
- future Eligibility Gates that need structural separation should use `structuralBoundaryGap` unless a thesis-specific business rule explicitly says otherwise.

The exact thesis policy for `structuralBoundaryGap = 1` remains `REQUIRES_PRODUCT_DECISION_LATER`.

Normative consequence :

```text
differentTier != meaningfulStructuralBoundary
differentTier != strongStructuralBoundary
```

Different Tier labels do not automatically imply strong structural separation.

## Anchor vs Structural Boundary

An anchor can exist even if the adjacent boundary is weak.

Example :

```text
1  60
2  59
3  58
4  57
5  55
```

For a supported standard championship :

- `TIER_1 = PODIUM` remains valid ;
- the boundary after podium may be weak or non-meaningful ;
- the system must not infer `structural_level_gap(3rd, 4th)` solely because one team is in the podium Tier and the other is outside it.

The same principle may apply to a regulatory relegation zone. A regulatory anchor and a strong structural boundary are distinct concepts.

## Boundary Strength

`BoundaryStrength` represente la force relative d'une rupture dans la distribution.

Elle peut etre utile pour distinguer :

- huge structural break ;
- moderate but meaningful break ;
- weak candidate break.

Ce n'est pas une probabilite, pas un score de these et pas une confidence utilisateur.

Locked decision : keep as structural metadata in the snapshot.

Exact scale and thresholds remain `REQUIRES_ALGORITHMIC_DEFINITION`.

## Boundary Distance

Une equipe situee 1 point au-dessus d'une boundary n'est pas exactement equivalente a une equipe situee 12 points au-dessus.

Informations utiles :

- distanceToUpperBoundary ;
- distanceToLowerBoundary ;
- marginal member vs deeply installed member ;
- boundary proximity warnings.

Locked decision : include conceptual boundary distance metadata.

Deferred usage : it must not directly modify a thesis, create clarity or become a probability in this phase.

## Championship Maturity

States :

| State | Meaning |
|---|---|
| `MATURE` | La distribution contient assez d'information pour produire des Tiers exploitables. |
| `IMMATURE` | Les standings existent mais la saison est trop jeune ou trop instable. |
| `UNAVAILABLE` | Donnees absentes, incoherentes ou competition non supportee. |

Possible maturity criteria to evaluate :

- minimum matches played ;
- proportion of season played ;
- played distribution balance ;
- dispersion minimale ;
- boundary stability across snapshots ;
- combination of several criteria.

Locked semantics :

```text
core maturity = season progression + played coverage + played balance
```

Temporal stability can complement the diagnostic but is not mandatory for the first `MATURE` state.

No threshold is defined here. Exact threshold and played-balance tolerance are `REQUIRES_ALGORITHMIC_DEFINITION`.

## Temporal Stability

Le systeme doit eviter le Tier flickering :

```text
J20: Team A = Tier 2
J21: Team A = Tier 3
J22: Team A = Tier 2
J23: Team A = Tier 3
```

Locked stability model :

- boundary confirmation ;
- light boundary persistence ;
- responsiveness override for clearly strong new breaks.

Tradeoff :

- trop reactif = bruit ;
- trop stable = retard face a une vraie rupture.

Locked decision : introduce stability metadata, boundary confirmation, light boundary persistence and responsiveness override.

Important distinction :

- maturity asks whether enough football has been played to interpret the table structurally ;
- stability asks whether a detected boundary is robust enough over time to avoid noise.

Stability primarily applies to boundaries, not artificial team retention. If a boundary remains valid and a team truly crosses it, the team may change Tier.

Exact confirmation, persistence and override formulas remain `REQUIRES_ALGORITHMIC_DEFINITION`.

## analysisAsOf Safety

For `analysisAsOf = T`, the Tier System may only use data available at T.

Forbidden :

- future standings ;
- post-match results ;
- points acquired after the match ;
- boundaries calculated from later rounds.

Snapshot identity :

```text
ChampionshipTierSnapshot(competitionId, season, analysisAsOf, tierSystemVersion)
```

## Snapshot Semantics

Conceptual contract :

```text
ChampionshipTierSnapshot
  competitionId
  season
  analysisAsOf
  standingsSourceTimestamp
  tierSystemVersion
  maturity
  teamCount
  matchesPlayedDistribution
  pointDistribution
  ppgDistribution
  anchors
  detectedBoundaries
  tierPresence
  teamAssignments
  warnings
```

This is not a database schema. It is the business contract required by Match Intelligence.

## Team Tier Assignment

Conceptual contract :

```text
TeamTierAssignment
  teamId
  officialRank
  points
  played
  pointsPerGame
  assignedTier
  tierLabel
  upperBoundary
  lowerBoundary
  distanceToUpperBoundary
  distanceToLowerBoundary
  structuralPosition
  warnings
```

The assignment must be explainable without exposing opaque math.

## Equal Points

Teams tied on points must not be separated arbitrarily by rank alone.

Rule :

- equal-points teams should normally remain on the same side of a structural boundary ;
- a boundary should not cut through a points tie unless a competition-specific rule is explicitly validated ;
- goal difference, goals scored or head-to-head explain rank, not necessarily structural separation.

Quasi-equality policy remains `REQUIRES_ALGORITHMIC_DEFINITION`.

## Competition Size

The system must be independent of fixed league size.

Sizes to support conceptually :

- 10 teams ;
- 12 teams ;
- 16 teams ;
- 18 teams ;
- 20 teams ;
- 22 teams ;
- 24 teams.

Risk : very small leagues may not support all intermediate Tier labels. This is acceptable.

## Atypical Competitions

| Competition type | V1 status | Notes |
|---|---|---|
| Standard round-robin league | `SUPPORTED` | Primary target. |
| Unequal games played in a standard league | `SUPPORTED_WITH_SPECIAL_RULE` | Supported with PPG qualification. |
| Relegation playoffs | `UNAVAILABLE_UNTIL_RULE_EXISTS` | Requires explicit metadata for playoff zone vs direct relegation. |
| Leagues without relegation | `UNAVAILABLE_UNTIL_RULE_EXISTS` | Do not infer `TIER_5` silently. |
| Split leagues | `UNAVAILABLE_UNTIL_RULE_EXISTS` | Need current phase and group semantics. |
| Championship/relegation groups | `UNAVAILABLE_UNTIL_RULE_EXISTS` | Group context is critical. |
| Apertura/clausura | `UNAVAILABLE_UNTIL_RULE_EXISTS` | Season identity and anchors differ. |
| Playoffs-only competitions | `NOT_SUPPORTED_V1` | Tier System is league-standings oriented. |
| Conferences/groups | `UNAVAILABLE_UNTIL_RULE_EXISTS` | Need per-group vs whole-competition semantics. |
| Points deductions | `SUPPORTED_WITH_SPECIAL_RULE` | Official structure first, optional warning. |
| Abandoned/postponed matches | `SUPPORTED_WITH_SPECIAL_RULE` | Requires data quality warnings. |
| Mid-season format changes | `UNAVAILABLE_UNTIL_RULE_EXISTS` | Needs explicit competition metadata. |

V1 principle : better no Tier than a misleading Tier. Unsupported atypical formats must abstain rather than fallback to rank buckets.

## Points Deductions

The Tier System should represent the official structural position first.

Example :

```text
official points = 20
underlying performance equivalent = 35
```

The team belongs to the official table structure at 20 points. A future extension may expose deduction warnings or underlying performance context, but that belongs outside Tier assignment unless a future explicit business extension says otherwise.

Status : official-first is `LOCKED_PRODUCT_DECISION`. A performance-adjusted Tier is out of scope for V1 and would require a future product decision.

## Relationship with EF_HIERARCHY

The Tier System feeds `EF_HIERARCHY` without double counting.

Distinctions :

| Layer | Examples | Counting rule |
|---|---|---|
| Raw facts | rank, points, rankGap, pointsGap, played, PPG | Explanatory facts, not independent evidence by default. |
| Structural artifacts | teamTier, tierGap, boundary, boundaryStrength, pointGapBreak | Gate inputs and structure context, not ordinary readings. |
| Readings | `ranking_superiority`, `balanced_hierarchy`, `structural_level_gap` | Interpretations, but correlated with hierarchy lineage. |

No `tier_superiority` reading should be created merely to count one more support.

## structural_level_gap

Current issue : the name implies structural separation, while the legacy producer can be triggered by raw rank/points rules.

Locked decision : keep `structural_level_gap` as an explanatory reading, with stricter semantics derived from the Dynamic Tier System.

Final semantic direction :

```text
structural_level_gap = explanatory reading derived from confirmed structural separation,
not from raw rankGap or pointsGap alone.
```

Business rule :

```text
confirmed Tier separation + meaningful structural boundary -> structural_level_gap may exist
raw rankGap alone -> no structural_level_gap
raw pointsGap alone -> no structural_level_gap
```

This corresponds to the previous Option C, as a stricter variant of Option A. The A/B/C product decision is no longer open.

Exact producer details remain `REQUIRES_ALGORITHMIC_DEFINITION`.

## balanced_hierarchy

`balanced_hierarchy` should not be a synonym for same Tier.

Same Tier means no structural separation between teams.

Balanced hierarchy may mean :

- same Tier ;
- small rank gap ;
- small points gap ;
- no meaningful boundary ;
- similar structural position within a Tier.

Example :

```text
1st 60 pts
3rd 52 pts
same Tier
```

They may be in the same structural group without being perfectly balanced.

Locked decision : preserve `balanced_hierarchy` as a reading about closeness / lack of clear separation, but do not let it replace Tier artifacts or gates.

Exact producer details remain `REQUIRES_ALGORITHMIC_DEFINITION`.

## ranking_superiority

`ranking_superiority` is factual hierarchy evidence.

It can exist even when `tierGap = 0`.

Example KR/Vikingur :

```text
ranking_superiority(Vikingur) = true
Vikingur Tier = 1
KR Tier = 1
tierGap = 0
```

This is coherent. Ranking superiority does not imply structural superiority.

## expected_domination Integration

The Tier System does not redefine `expected_domination`.

It provides :

- subjectTier ;
- opponentTier ;
- sameTier ;
- ordinalTierGap ;
- structuralBoundaryGap ;
- boundaryInformation[] ;
- maturity.

Business Matrix rule remains locked :

```text
same Tier -> expected_domination NOT_ELIGIBLE
failedGate = EG_EXPECTED_DOMINATION_TIER_GAP
```

Passing the Tier Gate does not automatically validate `expected_domination`. Other independent evidence remains required.

## KR Reykjavik vs Vikingur

Pre-match facts :

- Vikingur: 1st, 51 pts ;
- KR: 3rd, 43 pts ;
- rankGap = 2 ;
- pointsGap = 8 ;
- Vikingur away = 8W 1D 1L ;
- KR home = 8W 2D 0L ;
- recent form comparable.

The Tier System must answer :

- What is Vikingur's Tier ?
- What is KR's Tier ?
- Is there a meaningful structural boundary between them ?
- What is their Tier Gap ?
- What is the maturity status ?

If :

```text
Vikingur = TIER_1
KR = TIER_1
```

Then :

```text
tierGap = 0
```

The Business Matrix will then produce :

```text
expected_domination(Vikingur) = NOT_ELIGIBLE
failedGate = EG_EXPECTED_DOMINATION_TIER_GAP
```

The Tier System must not use home strength, away strength, recent form, xG or market odds to modify their Tiers.

## Synthetic Test Cases

| Case | Scenario | Expected behavior |
|---|---|---|
| A | Championship with clear groups | Identify several natural zones if boundaries are meaningful. |
| B | Very compact championship | Do not invent five groups. |
| C | Highly stretched championship | High raw gaps are not automatically Point Gap Breaks. |
| D | Huge podium break | Recognize strong separation after podium. |
| E | Podium not detached | Podium remains anchor, but boundary to rest may be weak. |
| F | Huge relegation break | Recognize strong separation around relegation. |
| G | Relegation compact with lower-middle | Relegation exists regulatory, but structural boundary may be weak. |
| H | Games-in-hand | Compare points and PPG without rewriting official rank. |
| I | Equal points around candidate boundary | Do not cut equal-point teams arbitrarily. |
| J | Early season | Return `IMMATURE` or equivalent. |
| K | Missing Tier | Keep model valid when `TIER_2` or `TIER_4` absent. |
| L | Boundary instability | Avoid flickering while remaining responsive to real breaks. |
| M | Missing Tier gap | If `TIER_1` exists, `TIER_2` is absent and `TIER_3` exists with one meaningful boundary, expose `ordinalTierGap = 2` and `structuralBoundaryGap = 1`. Eligibility must not consume ordinal distance blindly. |
| N | Anchor without strong boundary | If podium exists but points are compact around ranks 3/4, keep `TIER_1 = PODIUM` but do not infer `structural_level_gap` from the anchor alone. |
| O | PPG qualifies false break | If a raw points gap is explained by games-in-hand, PPG may weaken the boundary without rewriting official rank or points. |
| P | Boundary stability | A marginal one-matchday change may keep a boundary through light persistence, but team membership follows actual position relative to the boundary. A new very strong break may trigger responsiveness override. |
| Q | Unsupported format | Unsafe competition formats return `UNAVAILABLE` / `NOT_SUPPORTED_V1`; never fabricate five Tiers or fallback rank buckets. |

## Algorithm Candidates

### Mean adjacent gap

Compare each adjacent gap to the average gap.

Pros : simple, deterministic.  
Cons : sensitive to outliers, weak for stretched leagues, may over-detect.

### Median adjacent gap

Compare each gap to the median gap.

Pros : more robust than mean, explainable.  
Cons : may be too coarse, does not handle multi-break segmentation alone.

### Standard deviation z-score

Detect gaps far from mean using standard deviation.

Pros : familiar, deterministic.  
Cons : sensitive to outliers, poor for small samples and non-normal distributions.

### Robust z-score / MAD

Detect unusual gaps relative to median absolute deviation.

Pros : robust to outliers, championship-relative, deterministic.  
Cons : harder to explain if surfaced mathematically, needs fallback when MAD is zero.

### Percentile of gaps

Treat top percentile gaps as candidate breaks.

Pros : simple relative logic.  
Cons : can force breaks in compact leagues unless guarded by absolute/semantic checks.

### IQR / outlier detection

Use interquartile range to identify unusually large gaps.

Pros : robust, common outlier method.  
Cons : less stable in small leagues, threshold policy still needed.

### Optimal segmentation

Find partitions that minimize within-group variance and maximize between-group separation.

Pros : good structural modeling.  
Cons : can overfit, may force too many groups unless missing tiers are allowed.

### Change-point detection

Detect distribution changes in ordered points.

Pros : natural fit for boundaries.  
Cons : more complex, product explanation harder.

### One-dimensional clustering

Cluster teams by points/PPG.

Pros : can find natural groups.  
Cons : risks becoming an alternative table and may force clusters.

### Natural breaks / Jenks

Find natural classes in one-dimensional data.

Pros : designed for natural group discovery, deterministic.  
Cons : often requires choosing number of classes, can force groups without guardrails.

### Anchored robust hybrid

Combine official anchors, adjacent gap analysis, robust relative gap detection, optional PPG context and missing-tier semantics.

Pros : best fit for Lector's business needs, avoids fixed partitions, explainable if surfaced as boundaries.  
Cons : requires algorithmic definitions for thresholds and fallback policy.

## Algorithm Comparison Matrix

| Method | Robust to compact leagues | Robust to stretched leagues | Small sample | Explainability | Stability | Supports missing Tiers | Complexity | Recommendation |
|---|---|---|---|---|---|---|---|---|
| Mean adjacent gap | Low | Low | Medium | High | Medium | Weak | Low | Not recommended alone |
| Median adjacent gap | Medium | Medium | Medium | High | Medium | Medium | Low | Useful component |
| Standard deviation | Low | Medium | Low | Medium | Low | Medium | Low | Not recommended alone |
| Robust z-score / MAD | High | Medium | Medium with fallback | Medium | Medium | High | Medium | Strong component |
| Percentile gaps | Low without guardrails | Medium | Low | High | Low | Weak | Low | Not recommended alone |
| IQR outliers | Medium | Medium | Low/Medium | Medium | Medium | High | Medium | Useful component |
| Optimal segmentation | Medium | High | Low/Medium | Medium | Medium | High if constrained | High | Candidate but heavy |
| Change-point detection | High | High | Low/Medium | Low/Medium | Medium | High | High | Research candidate |
| 1D clustering | Medium | Medium | Low | Medium | Low | Weak unless constrained | Medium | Risky as primary |
| Natural breaks / Jenks | Medium | High | Medium | Medium | Medium | Weak unless missing tiers allowed | Medium | Useful with guardrails |
| Anchored robust hybrid | High | High | Medium with maturity gate | High at product layer | High with stability policy | High | Medium | Locked product family |

## Locked Dynamic Tier Model

Decision status : `LOCKED_PRODUCT_DECISION`.

Locked sequence :

1. Validate competition metadata.
2. Build temporally safe official standings snapshot.
3. Validate standings completeness and team count.
4. Evaluate championship maturity.
5. Compute raw point distribution and adjacent gaps.
6. Compute PPG distribution as contextual adjustment when games-in-hand matter.
7. Establish podium/relegation anchors from reliable metadata.
8. Identify candidate `POINT_GAP_BREAK` boundaries relative to the championship distribution.
9. Compare candidate breaks using robust statistics and natural-break style grouping.
10. Reject artificial boundaries when evidence is weak.
11. Allow missing intermediate Tier labels.
12. Preserve equal-point groups across boundaries unless a future explicit business rule validates an exception.
13. Assign teams to Tier labels.
14. Compute boundary strength and distance metadata.
15. Compute `ordinalTierGap` and `structuralBoundaryGap` for match pairs.
16. Validate invariants.
17. Emit `ChampionshipTierSnapshot`.

| Component | Locked position | Status |
|---|---|---|
| Model family | Anchored robust hybrid. | `LOCKED_PRODUCT_DECISION` |
| Primary signal | Official points distribution. | `LOCKED_PRODUCT_DECISION` |
| Official rank | Factual ordering and explanation, not sole structure. | `LOCKED_FROM_BUSINESS_MATRIX` |
| PPG | Secondary qualification for games-in-hand; never primary. | `LOCKED_PRODUCT_DECISION` |
| Point Gap Break | Championship-relative boundary concept. | `LOCKED_PRODUCT_DECISION`; formula `REQUIRES_ALGORITHMIC_DEFINITION` |
| Anchors | Podium/relegation from hybrid anchor source. | `LOCKED_PRODUCT_DECISION`; data work `REQUIRES_IMPLEMENTATION` |
| Missing tiers | Supported; do not force five groups. | `LOCKED_PRODUCT_DECISION` |
| Tier Gap | Expose `ordinalTierGap` and `structuralBoundaryGap`; use boundary gap by default. | `LOCKED_PRODUCT_DECISION` |
| Maturity | Mature/Immature/Unavailable; based on season progression, played coverage and played balance. | `LOCKED_PRODUCT_DECISION`; thresholds `REQUIRES_ALGORITHMIC_DEFINITION` |
| Stability | Boundary confirmation + light persistence + strong-break responsiveness. | `LOCKED_PRODUCT_DECISION`; formulas `REQUIRES_ALGORITHMIC_DEFINITION` |
| Equal points | Do not split equal-point teams arbitrarily. | `LOCKED_PRODUCT_DECISION`; quasi-equality formula `REQUIRES_ALGORITHMIC_DEFINITION` |
| Atypical competitions | Support standard leagues first; unsupported formats abstain. | `LOCKED_PRODUCT_DECISION` |
| Output | Conceptual `ChampionshipTierSnapshot`. | `LOCKED_PRODUCT_DECISION` |

## Explainability

The system must explain in football language.

Acceptable :

> Marseille appartient au groupe superieur du championnat. Une rupture nette de points separe actuellement ce groupe du milieu de tableau.

Acceptable :

> Lille et Monaco appartiennent au meme niveau structurel malgre leur difference de classement.

Avoid :

> normalized z-score = 1.73 therefore Tier 2.

## Determinism

Same input must produce same output :

```text
same standings snapshot
+ same tierSystemVersion
= same Tier structure
```

Forbidden :

- generative AI ;
- subjective manual judgment at runtime ;
- opaque probabilistic classification ;
- user-specific output.

## Versioning

Conceptual field :

```text
tierSystemVersion
```

Why :

- the algorithm may evolve ;
- old MatchAnalysisBundles must remain traceable ;
- future comparisons require knowing which structural method produced the snapshot.

Relationship to other versions :

| Version | Meaning |
|---|---|
| `tierSystemVersion` | Structural championship algorithm and semantics. |
| `engineVersion` | Match Intelligence engine version. |
| `profileSchemaVersion` | User matching/profile schema version. |
| `dataSnapshotVersion` | Source data snapshot contract. |

No migration is specified here.

## Dynamic Tier System Invariants

1. Same snapshot + same version = same Tier result.
2. User profile cannot change Tier assignments.
3. Post-match data cannot affect pre-match snapshot.
4. Rank alone cannot define structural separation.
5. Raw points gap alone cannot universally define structural separation.
6. A Tier boundary must have structural justification.
7. Five possible Tier labels do not require five populated groups.
8. Missing structural evidence must not create artificial boundaries.
9. Equal-point teams must not be separated arbitrarily by rank alone.
10. Tier System does not consume form, xG, home/away strength or market odds.
11. Tier System is not a power ranking.
12. Tier System is competition-relative.
13. Tier System must expose maturity.
14. Immature != same Tier.
15. Unavailable != same Tier.
16. Structural artifacts cannot inflate evidence count.
17. Official standings remain factual truth.
18. PPG normalization, if used, interprets structure but does not rewrite official rank.
19. Tier assignments must be explainable.
20. Tier calculations must be reusable across users.
21. Missing intermediate Tiers are valid if boundaries are not justified.
22. Boundary and Tier are distinct concepts.
23. Tier Gap and raw pointsGap are distinct concepts.
24. Passing a Tier Gate does not validate any thesis by itself.
25. Different Tier labels do not automatically imply strong structural separation.
26. Structural separation is represented by confirmed boundaries, not label distance alone.
27. `structuralBoundaryGap` is the default structural separation measure.
28. `ordinalTierGap` is explanatory metadata unless explicitly required by a business rule.
29. PPG can qualify a boundary but cannot create structural superiority alone.
30. Maturity and stability are separate concepts.
31. Stability primarily applies to boundaries, not artificial team retention.
32. An anchor may exist without a strong adjacent structural boundary.
33. V1 must abstain on unsupported atypical competition formats.
34. `structural_level_gap` must originate from confirmed structural separation.

## Required Data

| Data | Required for | Current status |
|---|---|---|
| competitionId | Snapshot identity | Available. |
| season | Snapshot identity | Available. |
| analysisAsOf | Temporal safety | Available conceptually in match analysis. |
| full standings | Distribution | Available in snapshots when standings present. |
| team rank | Official order | Available. |
| team points | Point distribution | Available. |
| team played | PPG / maturity | Available. |
| team group | Groups / atypical competitions | Available. |
| standings description | anchors | Source available, not retained. |
| competition format metadata | anchors / atypical competitions | Missing. |
| standings source timestamp | reproducibility | Partially available via source snapshot/asOf; exact field requires validation. |

## Missing Data Behaviour

| Missing data | Output |
|---|---|
| No standings | `UNAVAILABLE` |
| Missing rank or points for key teams | `UNAVAILABLE` for affected relations |
| Missing played | PPG unavailable; Points-only interpretation may remain with warning |
| Missing anchors | Tiers may be partial or `REQUIRES_DATA_SOURCE` |
| Immature season | `IMMATURE`, not same Tier |
| Unsupported competition format | `UNAVAILABLE` or `NOT_SUPPORTED_V1` |

Missing data never means same Tier.

## Locked Dynamic Tier Product Model

| Element | Locked model | Status |
|---|---|---|
| Model | Anchored Robust Hybrid. | `LOCKED_PRODUCT_DECISION` |
| Primary signal | Official point distribution. | `LOCKED_PRODUCT_DECISION` |
| Secondary normalization | PPG qualification for games-in-hand. | `LOCKED_PRODUCT_DECISION` |
| Anchors | Podium + competition-specific relegation. | `LOCKED_PRODUCT_DECISION` |
| Anchor source | Reliable Lector metadata/override first, retained API-Football standings description second, otherwise unavailable. | `LOCKED_PRODUCT_DECISION` |
| Intermediate Tiers | Natural structural groups; optional/missing labels allowed. | `LOCKED_PRODUCT_DECISION` |
| Structural separation | Confirmed meaningful boundaries. | `LOCKED_PRODUCT_DECISION` |
| Default Tier Gap | `structuralBoundaryGap`. | `LOCKED_PRODUCT_DECISION` |
| Explanatory Tier Gap | `ordinalTierGap`. | `LOCKED_PRODUCT_DECISION` |
| Maturity | Season progression + played coverage/balance. | `LOCKED_PRODUCT_DECISION` |
| Stability | Boundary confirmation + light persistence + strong-break responsiveness. | `LOCKED_PRODUCT_DECISION` |
| Stability target | Stabilize boundaries, not team membership. | `LOCKED_PRODUCT_DECISION` |
| BoundaryStrength | Structural metadata only. | `LOCKED_PRODUCT_DECISION` |
| BoundaryDistance | Structural metadata only, future usage deferred. | `LOCKED_PRODUCT_DECISION` |
| `structural_level_gap` | Derived explanatory reading from confirmed structural separation. | `LOCKED_PRODUCT_DECISION` |
| `balanced_hierarchy` | Closeness / lack of clear separation, not synonym of same Tier. | `LOCKED_PRODUCT_DECISION` |
| `ranking_superiority` | Factual rank advantage preserved independently. | `LOCKED_FROM_BUSINESS_MATRIX` |
| V1 competitions | Standard leagues first; unsupported formats abstain. | `LOCKED_PRODUCT_DECISION` |
| Unequal games played | Supported in standard leagues via PPG qualification. | `LOCKED_PRODUCT_DECISION` |

## Product Decisions

Previously open decisions now locked :

| Decision | Locked outcome | Status |
|---|---|---|
| General algorithm family | Anchored Robust Hybrid. | `LOCKED_PRODUCT_DECISION` |
| PPG conceptual role | Secondary qualification for games-in-hand; never primary. | `LOCKED_PRODUCT_DECISION` |
| Maturity semantics | `MATURE`, `IMMATURE`, `UNAVAILABLE`; core maturity uses season progression, played coverage and played balance. | `LOCKED_PRODUCT_DECISION` |
| Missing Tier semantics | Five labels are maximum vocabulary; missing labels are valid and do not mean missing data. | `LOCKED_PRODUCT_DECISION` |
| Default Tier Gap meaning | `structuralBoundaryGap` is default for structural separation; `ordinalTierGap` remains explanatory. | `LOCKED_PRODUCT_DECISION` |
| Anchor source strategy | Lector metadata/override first, retained API-Football standings description second, otherwise unavailable. | `LOCKED_PRODUCT_DECISION` |
| Atypical competition V1 strategy | Standard leagues first; unsupported formats abstain. | `LOCKED_PRODUCT_DECISION` |
| `structural_level_gap` semantic option | Retained explanatory reading derived from confirmed structural separation. | `LOCKED_PRODUCT_DECISION` |
| Boundary-focused stability model | Boundary confirmation + light persistence + strong-break responsiveness; no artificial team retention. | `LOCKED_PRODUCT_DECISION` |

Product decisions still open are future usage decisions, not algorithm internals :

| Decision | Scope | Status |
|---|---|---|
| Minimum `structuralBoundaryGap` required by each thesis | Business Matrix extension after algorithm formalization. | `REQUIRES_PRODUCT_DECISION_LATER` |
| Specific `structuralBoundaryGap = 1` policy per thesis | Thesis eligibility nuance, especially `expected_domination`. | `REQUIRES_PRODUCT_DECISION_LATER` |
| Atypical competition formats V2 | Split seasons, playoffs, conferences, leagues without relegation. | `REQUIRES_PRODUCT_DECISION_LATER` |
| Future use of `BoundaryStrength` in Match Intelligence | Whether it may influence confidence, warnings or presentation after V1. | `REQUIRES_PRODUCT_DECISION_LATER` |

## Algorithmic Decisions Still Open

Only mathematical and deterministic parameters remain to formalize :

1. Exact robust `POINT_GAP_BREAK` formula.
2. Exact role and composition of MAD, natural-break or segmentation validation.
3. Exact candidate-boundary threshold.
4. Exact `BoundaryStrength` scale.
5. Exact PPG activation condition.
6. Exact maturity threshold.
7. Exact played-balance tolerance.
8. Exact boundary confirmation rule.
9. Exact light persistence rule.
10. Exact responsiveness override rule.
11. Exact handling when the robust dispersion metric is zero.
12. Exact minimum sample behavior for small leagues.
13. Exact assignment policy when intermediate labels are absent.
14. Exact producer condition for `balanced_hierarchy`.
15. Exact producer condition for `structural_level_gap` after structural separation is known.

## Implementation Details Deferred

Deferred :

- exact formulas ;
- numeric thresholds ;
- database schema ;
- cache design ;
- data migrations ;
- Dart models ;
- test files ;
- UI copy ;
- edge function changes ;
- MatchAnalysisBundle persistence implementation.

## Acceptance Criteria

| AC | Criterion | Status |
|---|---|---|
| AC1 | Same ranks with different point distributions can produce different structures. | Satisfied by design. |
| AC2 | Same raw points gap can have different meaning by championship. | Satisfied by design. |
| AC3 | System is never forced to produce five distinct groups. | Satisfied by design. |
| AC4 | Intermediate Tier can be absent. | Satisfied by design. |
| AC5 | Equal-point teams are not arbitrarily cut by rank. | Satisfied by design. |
| AC6 | Games-in-hand are explicitly treated. | Satisfied by design, exact activation algorithm open. |
| AC7 | Too-young season can produce `IMMATURE`. | Satisfied by design. |
| AC8 | `IMMATURE` does not mean same Tier. | Satisfied by design. |
| AC9 | Missing data can produce `UNAVAILABLE`. | Satisfied by design. |
| AC10 | `UNAVAILABLE` does not mean same Tier. | Satisfied by design. |
| AC11 | Form, xG, home/away records and odds never influence Tiers. | Satisfied by design. |
| AC12 | User profile never influences Tiers. | Satisfied by design. |
| AC13 | Official ranking is never rewritten. | Satisfied by design. |
| AC14 | System respects `analysisAsOf`. | Satisfied by design. |
| AC15 | Same snapshot + same algorithm version = same result. | Satisfied by design. |
| AC16 | Tier System can be explained in football terms. | Satisfied by design. |
| AC17 | `ranking_superiority` can exist between teams in same Tier. | Satisfied by design. |
| AC18 | High pointsGap is not enough universally for structural separation. | Satisfied by design. |
| AC19 | Tier System does not create double counting in `EF_HIERARCHY`. | Satisfied by design. |
| AC20 | KR/Vikingur can produce `ranking_superiority(Vikingur) = true` and `tierGap = 0`. | Satisfied by design. |
| AC21 | Missing Tier gap exposes both `ordinalTierGap` and `structuralBoundaryGap`. | Satisfied by design. |
| AC22 | Podium anchor can exist without a strong adjacent boundary. | Satisfied by design. |
| AC23 | PPG can qualify a false break without rewriting official table facts. | Satisfied by design. |
| AC24 | Stability applies to boundaries, not artificial team retention. | Satisfied by design. |
| AC25 | Unsupported formats abstain instead of approximating Tiers from rank buckets. | Satisfied by design. |

## Locked Acceptance Cases

### Missing Tier gap case

Given :

```text
TIER_1 = present
TIER_2 = absent
TIER_3 = present
meaningful boundaries between teams = 1
```

Expected :

```text
ordinalTierGap = 2
structuralBoundaryGap = 1
```

Eligibility must consume structural separation, not ordinal distance blindly.

### Weak podium boundary case

Given :

```text
1  60
2  59
3  58
4  57
5  55
```

Expected :

- `TIER_1 = PODIUM` remains valid for a supported standard championship ;
- podiumBoundaryStrength may be weak ;
- no `structural_level_gap(3rd, 4th)` is inferred from podium membership alone.

### PPG qualification case

Given :

```text
Team A: 40 pts, 20 played, PPG 2.00
Team B: 36 pts, 18 played, PPG 2.00
```

Expected :

- pointsGap remains an official fact ;
- PPG may weaken or qualify a candidate boundary ;
- officialRank and official points are not rewritten ;
- PPG does not create superior Tier or structural superiority alone.

### Boundary stability case

Given :

```text
J20: marginal boundary candidate
J21: one-matchday minor oscillation
```

Expected :

- light persistence may keep the boundary valid ;
- team memberships are determined by actual position relative to the boundary ;
- no artificial team-locking is allowed.

If a new very strong break appears, responsiveness override can validate it immediately according to the future deterministic rule.

### Unsupported competition case

Given :

```text
unsafe format: split season, playoffs-only, unsupported conference logic
```

Expected :

- TierSystemStatus = `UNAVAILABLE` / `NOT_SUPPORTED_V1` ;
- no five-Tier fabrication ;
- no fallback rank buckets.

## Final Recommendation

Adopt the locked Anchored Robust Hybrid Dynamic Tier Model for algorithm formalization.

Core stance :

- official standings remain factual truth ;
- points distribution is the main structural signal ;
- PPG is a contextual correction for games-in-hand ;
- podium and relegation are anchors only when supported by reliable metadata ;
- intermediate Tiers are discovered from meaningful boundaries ;
- missing Tiers are valid ;
- Tier Gap should expose both ordinal label gap and structural boundary gap ;
- maturity and unavailable states are first-class outputs ;
- stability is boundary-focused ;
- `structural_level_gap` is derived from confirmed structural separation ;
- the system is deterministic, versioned, profile-independent and explainable.

No implementation should begin until the algorithmic parameters listed above are formally defined.
