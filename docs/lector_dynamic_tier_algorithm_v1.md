# Lector - Dynamic Tier Algorithm V1

Date de specification : 2026-09-02  
Statut : `LOCKED_ALGORITHM_V1`, pret pour implementation ulterieure.  
Reference produit : `docs/lector_dynamic_tier_system_spec.md`  
Contrainte normative : `docs/lector_business_matrix_v2_1.md`  
Perimetre : formalisation deterministe du Dynamic Championship Tier System V1.
tierSystemVersion : `tier-v1`

## Executive Summary

Ce document verrouille l'algorithme `DynamicTierAlgorithmV1`.

Il transforme le modele produit verrouille du Dynamic Tier System en une methode deterministe, testable et implementable sans interpretation metier supplementaire.

Le choix recommande est :

```text
ANCHORED ROBUST HYBRID
official point distribution primary
PPG secondary qualification only for games-in-hand
robust candidate detector
segmentation validation
anchor-aware tier construction
boundary-focused temporal stability
```

Le resultat de cette phase est un contrat algorithmique gele pour implementation ulterieure, sauf contradiction formelle detectee pendant l'implementation ou version future explicitement approuvee.

## Non-Goals

Ce document ne modifie pas :

- code Dart ;
- SQL ;
- migrations ;
- Edge Functions ;
- UI ;
- production tests ;
- Business Matrix V2.1.1 ;
- spec produit verrouillee.

Il ne fait pas de machine learning, pas de backtesting de paris et n'utilise jamais de resultat final.

## Product Model Compatibility

| Product constraint | Algorithm V1 behavior |
|---|---|
| Anchored Robust Hybrid | Utilise anchors, robust gaps, PPG qualification et validation de segmentation. |
| Official point distribution primary | Les points officiels produisent les gaps et restent le signal structurel principal. |
| PPG secondary only | PPG peut affaiblir une boundary candidate, jamais en creer une. |
| Podium + relegation anchors | Les anchors structurent les Tiers mais ne creent pas automatiquement une boundary forte. |
| Missing Tiers allowed | Aucun label intermediaire n'est force. |
| Structural separation | Comptee uniquement via confirmed meaningful boundaries. |
| Default structural gap | `structuralBoundaryGap`. |
| Explanatory gap | `ordinalTierGap`. |
| Maturity | Basee sur progression saison, couverture played et balance played. |
| Stability | Stabilise les boundaries, pas les equipes. |
| Unsupported formats | Abstention V1. |
| Five-label vocabulary | Simplifie la representation Tier, mais ne supprime jamais une boundary structurelle confirmee. |

`PRODUCT_MODEL_CONFLICT` : none identified.

## Algorithm Identity

```text
algorithmName = DynamicTierAlgorithmV1
tierSystemVersion = tier-v1
status = LOCKED_ALGORITHM_V1
```

Determinism rule :

```text
same standings snapshot
+ same competition metadata
+ same previous boundary state
+ tier-v1
= same ChampionshipTierSnapshot
```

## Inputs

Required input :

```text
competitionId
season
analysisAsOf
competitionFormat
teamCount
standingsRows[]
anchorMetadata
optional previousBoundaryState
```

Each `standingsRow` requires :

```text
teamId
officialRank
points
played
```

V1 supported format :

```text
standard round-robin league
standard league with unequal games played
```

Unsupported V1 formats return `UNAVAILABLE` / `NOT_SUPPORTED_V1` rather than approximate rank buckets.

## Conceptual Snapshot Contract

This is an algorithmic contract, not a database schema.

```text
ChampionshipTierSnapshot
  competitionId
  season
  analysisAsOf
  tierSystemVersion
  maturity
  pointDistribution
  ppgDistribution
  boundaryCandidates[]
  confirmedStructuralBoundaries[]
  tierPartitionBoundaries[]
  tierPresence
  teamAssignments[]
  structuralBoundaryGapMatrix
  warnings[]
```

Definitions :

- `boundaryCandidates[]` contains every statistically interesting boundary candidate before final confirmation.
- `confirmedStructuralBoundaries[]` contains every meaningful structural boundary confirmed by the algorithm.
- `tierPartitionBoundaries[]` is a subset of `confirmedStructuralBoundaries[]` used only to map the distribution into the five Tier labels.

Normative principle :

```text
The five-label Tier vocabulary may simplify the representation of championship structure,
but it must never erase confirmed structural information.
```

## Distinct Standings Snapshot Identity

Temporal confirmation depends on distinct standings snapshots, not on engine execution count.

Conceptual identity :

```text
standingsSnapshotIdentity =
  competitionId
  + season
  + analysisAsOf
  + providerSnapshotVersion if available
  + standingsSourceTimestamp if available
  + canonicalStandingsStateHash
```

`canonicalStandingsStateHash` is computed from the ordered, normalized structural fields only :

```text
teamId
officialRank
points
played
anchorMetadataVersion
competitionFormatVersion
```

Rules :

```text
same standingsSnapshotIdentity -> same standings snapshot
different standingsSnapshotIdentity -> distinct standings snapshot
```

If source timestamp changes but normalized structural fields do not, the hash remains the same and the snapshot does not advance temporal confirmation.

Idempotence invariant :

```text
same football data
+ same previous structural state
+ same metadata
+ same analysisAsOf
+ same tierSystemVersion
= identical Dynamic Tier result
```

Critical rule :

```text
rerunning the algorithm on identical standings data
must never advance temporal confirmation age.
```

## Parameter Registry

No numeric parameter should appear in the algorithm without being listed here.

| Parameter | Meaning | Candidate values studied | Recommended V1 | Rationale | Sensitivity |
|---|---|---:|---:|---|---|
| `SUPPORTED_MIN_TEAMS` | Minimum teams for V1 league structure. | 8, 10 | 10 | Matches supported target sizes and avoids tiny-table artifacts. | Lower value increases false structure in tiny leagues. |
| `SUPPORTED_MAX_TEAMS` | Maximum teams for V1. | 24, 26 | 24 | Covers requested V1 range. | Higher value needs extra anti-oversegmentation checks. |
| `MIN_MEDIAN_PLAYED_MATURE` | Minimum median played for maturity without schedule length. | 4, 6, 8 | 6 | Balanced between early noise and useful mid-season analysis. | Lower is noisy; higher delays availability. |
| `MIN_MIN_PLAYED_MATURE` | Minimum played for every team in mature snapshot. | 3, 4, 5 | 4 | Prevents a few under-observed teams from distorting PPG. | Higher penalizes postponed schedules. |
| `MIN_SEASON_PROGRESS_MATURE` | Minimum season progress if schedule length known. | 20%, 25%, 30% | 25% | Avoids first-quarter volatility. | Lower creates early false boundaries. |
| `MAX_PLAYED_SPREAD_BALANCED` | Normal played spread before imbalance warning. | 1, 2, 3 | 2 | Two games difference is common and manageable. | Lower over-warns; higher hides games-in-hand. |
| `MAX_PLAYED_SPREAD_USABLE_RATIO` | Severe played imbalance as share of median played. | 25%, 33%, 40% | 33% | Separates manageable backlog from unusable standings. | Lower creates too many `IMMATURE` snapshots. |
| `PPG_ADJACENT_PLAYED_DIFF_TRIGGER` | Adjacent pair played diff that activates PPG qualification. | 1, 2, 3 | 2 | One game is often ordinary; two can distort gaps. | Lower overuses PPG; higher misses false breaks. |
| `PPG_GLOBAL_SPREAD_TRIGGER` | Global played spread that activates PPG review. | 2, 3, 4 | 3 | Adds protection when schedule imbalance is broad. | Lower adds noise; higher under-corrects. |
| `MIN_RAW_GAP_CANDIDATE` | Minimum raw adjacent gap to inspect. | 2, 3, 4 | 3 | Avoids promoting tiny table noise. | Lower creates compact-league false positives. |
| `CANDIDATE_ROBUST_Z` | Robust abnormality threshold for candidate boundary. | 2.0, 2.5, 3.0 | 2.5 | Detects clear relative outliers without being too conservative. | Lower over-detects; higher misses moderate real breaks. |
| `CANDIDATE_GAP_RATIO` | Ratio threshold for candidate boundary. | 2.4, 3.0, 3.6 | 3.0 | Handles MAD=0 and repeated small gaps. | Lower flags small outliers; higher misses compact true breaks. |
| `MAD_NORMALIZATION_FACTOR` | Converts MAD to robust sigma-like scale. | 1.4826 | 1.4826 | Standard robust scale correction. | Fixed statistical convention. |
| `IQR_NORMALIZATION_FACTOR` | Converts IQR to sigma-like fallback scale. | 1.349 | 1.349 | Standard robust IQR scale convention. | Fixed statistical convention. |
| `MIN_ROBUST_SCALE` | Minimum denominator for robust z. | 0.5, 1.0 | 1.0 | Prevents division artifacts and tiny gap inflation. | Lower over-detects in low-scoring tables. |
| `MAD_ZERO_MEDIAN_POSITIVE_FACTOR` | Fallback scale component when MAD=0. | 0.5, 0.75, 1.0 | 0.5 | Keeps repeated-gap distributions defined while ratio does most work. | Higher makes z less sensitive; ratio still guards. |
| `SEGMENTATION_GAIN_MIN` | Minimum reduction in dispersion from split. | 0.15, 0.20, 0.28 | 0.20 | Requires real structural improvement. | Lower accepts weak splits; higher misses moderate zones. |
| `BOUNDARY_SCORE_SCALE` | Internal score scale. | 100 | 100 | Human-readable structural score, not probability. | Fixed presentation of internal metadata. |
| `BOUNDARY_SCORE_Z_WEIGHT` | Weight of robust z component. | 0.35, 0.45, 0.55 | 0.45 | Makes abnormality the primary score component. | Higher favors extreme gaps. |
| `BOUNDARY_SCORE_RATIO_WEIGHT` | Weight of robust ratio component. | 0.20, 0.30, 0.40 | 0.30 | Gives MAD=0 resilience without dominating. | Higher favors repeated low typical gaps. |
| `BOUNDARY_SCORE_SEGMENT_WEIGHT` | Weight of segmentation component. | 0.20, 0.25, 0.35 | 0.25 | Ensures candidate split improves group coherence. | Higher favors clean partitions. |
| `Z_COMPONENT_SATURATION` | Robust z value that caps z score component. | 3.5, 4.0, 5.0 | 4.0 | Prevents one extreme gap from dominating endlessly. | Lower makes strong category easier. |
| `GAP_RATIO_COMPONENT_OFFSET` | Ratio baseline before score contribution. | 1.0 | 1.0 | A normal gap ratio should contribute zero. | Fixed by ratio semantics. |
| `GAP_RATIO_COMPONENT_SPAN` | Ratio distance from ordinary to saturated. | 2.5, 3.0, 4.0 | 3.0 | Ratio 4 saturates the component. | Lower favors compact outliers. |
| `SEGMENTATION_GAIN_SATURATION` | Segmentation gain that caps segment component. | 0.30, 0.35, 0.45 | 0.35 | Rewards strong structural improvement without overfitting. | Lower makes clean splits score high faster. |
| `BOUNDARY_SCORE_CONFIRM` | Score needed for confirmed boundary. | 55, 60, 70 | 60 | Pairs robust signal with segmentation validation. | Lower creates more boundaries. |
| `BOUNDARY_SCORE_STRONG` | Score for strong boundary. | 75, 78, 85 | 78 | Captures obvious breaks while preserving moderate category. | Higher reduces immediate confirmation. |
| `BOUNDARY_SCORE_WEAK_MAX` | Max score still considered weak. | 45, 50, 55 | 50 | Separates metadata-only candidates from usable boundaries. | Affects warnings, not core structure. |
| `SEGMENT_MIN_SIZE_DEFAULT` | Minimum segment size around ordinary boundary. | 2, 3 | 2 | Allows small leagues and relegation-sized groups. | Higher rejects valid small groups. |
| `MAX_TIER_PARTITION_BOUNDARIES` | Max confirmed boundaries used for intermediate Tier labels. | 2, 3 | 2 | Three intermediate labels can express at most three middle segments. | Does not limit real confirmed structural boundaries. |
| `TIER_PARTITION_GAIN_EPSILON` | Negligible quality difference for partition tie-break. | 0.01, 0.02, 0.03 | 0.02 | Allows simpler partition when quality is effectively equal. | Higher favors fewer labels. |
| `PPG_REJECT_RATIO` | PPG equivalent gap ratio that rejects a candidate unless override. | 0.25, 0.35, 0.45 | 0.35 | Rejects false breaks mostly caused by games-in-hand. | Higher rejects more boundaries. |
| `PPG_DOWNGRADE_RATIO` | PPG equivalent ratio below which score is downgraded. | 0.50, 0.65, 0.75 | 0.65 | Handles partial games-in-hand distortion. | Lower under-corrects. |
| `PPG_DOWNGRADE_POINTS` | Score penalty for partial PPG distortion. | 10, 15, 20 | 15 | Meaningful but not fatal. | Higher loses moderate true breaks. |
| `PPG_EXTREME_RAW_BREAK_SURVIVAL_SCORE` | Raw structural score allowing survival despite PPG rejection. | 80, 85, 90 | 85 | Lets extreme raw structural breaks survive PPG qualification without becoming temporal responsiveness. | Lower ignores PPG too often. |
| `TEMPORAL_CONFIRM_MODERATE_SNAPSHOTS` | Consecutive compatible snapshots for new moderate boundary. | 2, 3 | 2 | Light confirmation without freezing analysis. | Higher delays legitimate structure. |
| `TEMPORAL_PERSISTENCE_SNAPSHOTS` | Survival of weakening existing boundary. | 1, 2 | 1 | Light persistence only. | Higher risks stale boundaries. |
| `TEMPORAL_COMPATIBLE_POSITION_DRIFT` | Rank-index movement allowed for same boundary. | 0, 1, 2 | 1 | Handles small rank movement without team locking. | Higher can merge different boundaries. |
| `BALANCED_RANK_GAP_RATIO` | Relative rank closeness for balanced hierarchy. | 10%, 15%, 20% | 15% | Scales across 10-24 teams. | Higher makes balanced too broad. |
| `BALANCED_POINTS_GAP_TYPICAL_MULTIPLIER` | Points closeness relative to typical gap. | 1.5, 2.0, 2.5 | 2.0 | Championship-relative closeness. | Higher may mark distant teams balanced. |
| `BALANCED_POINTS_GAP_ABSOLUTE_FLOOR` | Absolute floor for points closeness. | 3, 4, 5 | 4 | Avoids over-strictness in compact tables. | Higher broadens balanced labels. |

## Formal Definitions

Let standings be ordered by official rank :

```text
P1 >= P2 >= ... >= Pn
g_i = P_i - P_(i+1), i = 1..n-1
```

Only official points define `g_i`.

Definitions :

```text
positiveGaps = { g_i | g_i > 0 }
medianGap = median(gaps)
medianPositiveGap = median(positiveGaps), or 0 if none
typicalGap = max(MIN_ROBUST_SCALE, medianPositiveGap)
rawMAD = median(|g_i - medianGap|)
IQR = Q3(gaps) - Q1(gaps)
madScale = rawMAD * MAD_NORMALIZATION_FACTOR
iqrScale = IQR / IQR_NORMALIZATION_FACTOR
fallbackScale = max(MIN_ROBUST_SCALE, iqrScale, medianPositiveGap * MAD_ZERO_MEDIAN_POSITIVE_FACTOR)
robustScale = madScale if rawMAD > 0 else fallbackScale
robustZ_i = max(0, (g_i - medianGap) / robustScale)
gapRatio_i = g_i / typicalGap
```

MAD=0 is therefore defined and deterministic.

## Variant Study

### Variant A - Robust MAD

Formula :

```text
candidate if g_i >= MIN_RAW_GAP_CANDIDATE
and robustZ_i >= CANDIDATE_ROBUST_Z
```

Strengths :

- robust to ordinary outliers ;
- championship-relative ;
- easy to explain internally.

Failure modes :

- MAD=0 requires fallback ;
- many identical gaps can make z unstable if denominator is too small ;
- a single huge outlier can dominate narrative unless anchor guards exist.

Verdict : useful component, not sufficient alone.

### Variant B - Robust Gap Ratio

Formula :

```text
gapRatio_i = g_i / typicalGap
candidate if gapRatio_i >= CANDIDATE_GAP_RATIO
```

Candidate typical references studied :

| Reference | Pros | Cons | Verdict |
|---|---|---|---|
| median positive gap | Very robust, simple. | Can be too sensitive when typical gap = 1. | Recommended with raw gap floor. |
| trimmed mean | Smooths mild outliers. | Less stable in small leagues. | Useful for diagnostics only. |
| winsorized mean | Reduces extreme outlier effect. | More complex to explain. | Not needed V1. |
| mean gap | Easy. | Bad in outlier-heavy tables. | Rejected as primary. |

Verdict : strong MAD=0 companion, but not sufficient alone.

### Variant C - Hybrid Robust Score

Components :

```text
zComponent = clamp(robustZ_i / Z_COMPONENT_SATURATION, 0, 1)
ratioComponent = clamp((gapRatio_i - GAP_RATIO_COMPONENT_OFFSET) / GAP_RATIO_COMPONENT_SPAN, 0, 1)
segComponent = clamp(segmentationGain_i / SEGMENTATION_GAIN_SATURATION, 0, 1)
boundaryEvidenceScore_i =
  BOUNDARY_SCORE_SCALE * (
    BOUNDARY_SCORE_Z_WEIGHT * zComponent
    + BOUNDARY_SCORE_RATIO_WEIGHT * ratioComponent
    + BOUNDARY_SCORE_SEGMENT_WEIGHT * segComponent
  )
```

This score is deterministic structural evidence, not probability and not betting confidence.

Verdict : useful for category and temporal policy, but must remain internal/explanatory metadata.

### Variant D - Robust Candidate + Segmentation Validation

Pipeline :

```text
robust detector -> candidate boundary
candidate boundary -> segmentation validation
validated candidate -> PPG qualification
qualified candidate -> temporal confirmation
```

Verdict : recommended V1 backbone.

### Variant E - Natural Breaks / Jenks as Validator

Jenks is useful as a validation concept :

- "does this split reduce within-group variance?"
- "does it create coherent groups?"

Jenks is not used to force `k = 5`.

Verdict : use segmentation gain inspired by natural breaks, not full Jenks partitioning in V1.

## Tier Partition Quality Study

`confirmedStructuralBoundaries[]` and `tierPartitionBoundaries[]` solve different problems.

`confirmedStructuralBoundaries[]` answers :

> What structural breaks really exist in this championship?

`tierPartitionBoundaries[]` answers :

> Which confirmed breaks best express those structures through the five Tier labels?

The algorithm must evaluate all reasonable combinations of 0, 1 and 2 intermediate confirmed boundaries. It must not choose the two individually highest `boundaryEvidenceScore` values.

### Option A - global segmentation gain

Formula :

```text
partitionQuality =
  (MAD(allMiddlePoints) - weightedWithinSegmentMAD(allSelectedSegments))
  / max(MAD(allMiddlePoints), MIN_ROBUST_SCALE)
```

Pros :

- directly measures global partition coherence ;
- simple and deterministic ;
- avoids overvaluing adjacent high-score boundaries.

Cons :

- ignores individual boundary strength unless tie-breakers are added.

### Option B - segmentation gain + boundary strength

Formula :

```text
partitionQuality =
  globalSegmentationGain
  + smallBoundaryStrengthContribution
```

Pros :

- rewards strong boundaries ;
- can separate close partitions.

Cons :

- creates another composite score ;
- harder to explain ;
- risks recreating top-score bias.

### Option C - segmentation gain only with deterministic tie-breakers

Formula :

```text
primary quality = globalSegmentationGain
tie-breakers = fewer boundaries, segment balance, boundary score sum, boundary index order
```

Pros :

- most parsimonious ;
- prioritizes global partition coherence ;
- keeps boundary strength available without making it primary.

Cons :

- may choose a lower-score boundary if it improves the whole partition.

Recommended V1 : Option C.

Principle :

```text
global partition coherence is more important than selecting the individually highest boundary scores.
```

## Tier Partition Selection

Input :

```text
middleRegion
confirmedStructuralBoundaries inside middleRegion
MAX_TIER_PARTITION_BOUNDARIES = 2
```

Generate all combinations :

```text
0-boundary partition
all 1-boundary partitions
all 2-boundary partitions
```

For each partition :

```text
segments = split middleRegion by selected boundaries
globalSegmentationGain =
  (MAD(middleRegionPoints) - weightedWithinSegmentMAD(segments))
  / max(MAD(middleRegionPoints), MIN_ROBUST_SCALE)
minSegmentSize = min(size(segment))
selectedBoundaryScoreSum = sum(boundaryEvidenceScore)
```

A partition is eligible if every segment satisfies `SEGMENT_MIN_SIZE_DEFAULT`, unless the segment is a regulatory anchor-adjacent segment already protected by metadata.

Tie-breakers, in order :

1. Higher `globalSegmentationGain`.
2. If gain difference <= `TIER_PARTITION_GAIN_EPSILON`, fewer selected boundaries.
3. Higher `minSegmentSize`.
4. Higher `selectedBoundaryScoreSum`.
5. Stable deterministic boundary-index ordering.

The algorithm must support best partition = 0, 1 or 2 boundaries.

Example :

```text
confirmedStructuralBoundaries = [B6 score 91, B7 score 89, B16 score 82]
partitionQuality(B6+B16) > partitionQuality(B6+B7)
```

Expected :

```text
confirmedStructuralBoundaries = [B6, B7, B16]
tierPartitionBoundaries = [B6, B16]
```

`B7` remains a real structural boundary. It is stored, explained and counted by `structuralBoundaryGap`; it is only not used to assign the five public Tier labels.

## Recommended Boundary Pipeline

### Step 1 - Validate boundary position

A boundary position `i` is ineligible if :

```text
g_i = 0
or P_i = P_(i+1)
or it cuts an equal-points block
or it is inside a mandatory anchor block
```

Inside-anchor outliers may be emitted as warnings, but they do not split `TIER_1` or `TIER_5`.

### Step 2 - Candidate boundary

```text
candidateBoundary_i =
  eligiblePosition_i
  and g_i >= MIN_RAW_GAP_CANDIDATE
  and (
    robustZ_i >= CANDIDATE_ROBUST_Z
    or gapRatio_i >= CANDIDATE_GAP_RATIO
  )
```

### Step 3 - Segmentation validation

For a candidate at `i` :

```text
upper = P1..P_i
lower = P_(i+1)..Pn
totalDispersion = MAD(points)
upperDispersion = MAD(upper)
lowerDispersion = MAD(lower)
weightedSegmentDispersion =
  (size(upper) * upperDispersion + size(lower) * lowerDispersion) / n
segmentationGain =
  (totalDispersion - weightedSegmentDispersion) / max(totalDispersion, MIN_ROBUST_SCALE)
```

The split is segmentation-valid if :

```text
size(upper) >= SEGMENT_MIN_SIZE_DEFAULT
size(lower) >= SEGMENT_MIN_SIZE_DEFAULT
segmentationGain >= SEGMENTATION_GAIN_MIN
```

Anchor blocks can satisfy segment size through their regulatory size. The algorithm still cannot cut inside equal-points blocks.

### Step 4 - PPG qualification

PPG activates only as a qualifier :

```text
playedDiff_i = abs(played_i - played_(i+1))
playedSpread = max(played) - min(played)
ppgActive_i =
  playedDiff_i >= PPG_ADJACENT_PLAYED_DIFF_TRIGGER
  or playedSpread >= PPG_GLOBAL_SPREAD_TRIGGER
```

If active :

```text
ppg_i = P_i / played_i
ppg_j = P_(i+1) / played_(i+1)
ppgEquivalentGap_i = abs(ppg_i - ppg_j) * medianPlayed
ppgRatio_i = ppgEquivalentGap_i / max(g_i, MIN_ROBUST_SCALE)
```

Rules :

```text
if ppgRatio_i <= PPG_REJECT_RATIO
and boundaryEvidenceScore_i < PPG_EXTREME_RAW_BREAK_SURVIVAL_SCORE:
  candidate is rejected

else if ppgRatio_i <= PPG_DOWNGRADE_RATIO:
  boundaryEvidenceScore_i -= PPG_DOWNGRADE_POINTS

else:
  no PPG downgrade
```

PPG cannot create a candidate, cannot reorder standings and cannot create structural superiority alone.

### Step 5 - BoundaryStrength

```text
if boundaryEvidenceScore_i < BOUNDARY_SCORE_WEAK_MAX:
  BoundaryStrength = WEAK
else if boundaryEvidenceScore_i < BOUNDARY_SCORE_STRONG:
  BoundaryStrength = MODERATE
else:
  BoundaryStrength = STRONG
```

`WEAK` is metadata only. A confirmed meaningful boundary must be `MODERATE` or `STRONG`.

### Step 6 - Confirmed boundary

Current-snapshot confirmation before temporal history :

```text
spatialConfirmed_i =
  candidateBoundary_i
  and segmentationValid_i
  and boundaryEvidenceScore_i >= BOUNDARY_SCORE_CONFIRM
```

Temporal confirmation then decides final confirmation.

## Maturity Rule

Status is `UNAVAILABLE` if :

```text
unsupported competition format
or missing required standings
or n < SUPPORTED_MIN_TEAMS
or n > SUPPORTED_MAX_TEAMS
or missing officialRank / points / played for any team
or invalid duplicate ranks outside source-defined ties
or missing required anchor metadata for V1
```

Status is `IMMATURE` if :

```text
medianPlayed < MIN_MEDIAN_PLAYED_MATURE
or minPlayed < MIN_MIN_PLAYED_MATURE
or seasonProgress < MIN_SEASON_PROGRESS_MATURE when schedule length is known
or playedSpread > max(4, ceil(MAX_PLAYED_SPREAD_USABLE_RATIO * medianPlayed))
```

Otherwise status is `MATURE`.

Warnings :

```text
playedSpread > MAX_PLAYED_SPREAD_BALANCED -> PLAYED_IMBALANCE_WARNING
ppgActive_i for any candidate -> PPG_QUALIFICATION_USED
```

Maturity is not stability.

## Temporal Boundary Stability

Temporal stability uses previous confirmed boundary state when available.

### New boundary

```text
if spatialConfirmed_i and BoundaryStrength = STRONG:
  confirmed immediately

else if spatialConfirmed_i
and compatible MODERATE candidate existed in previous TEMPORAL_CONFIRM_MODERATE_SNAPSHOTS - 1 distinct standings snapshots:
  confirmed

else:
  pending candidate
```

Compatibility means boundary index differs by at most `TEMPORAL_COMPATIBLE_POSITION_DRIFT` and does not cut an equal-points block.

Distinct snapshot requirement :

```text
previous candidate counts only if previous.standingsSnapshotIdentity != current.standingsSnapshotIdentity
```

Repeated execution of the same snapshot remains pending for a new MODERATE boundary.

### Existing boundary

```text
if existingConfirmedBoundary has compatible current spatialConfirmed boundary:
  confirmed at current position

else if existingConfirmedBoundary has compatible current candidate
and currentBoundaryEvidenceScore >= BOUNDARY_SCORE_WEAK_MAX
and persistenceAge < TEMPORAL_PERSISTENCE_SNAPSHOTS:
  keep boundary confirmed for one snapshot

else:
  boundary expires
```

This stabilizes boundary existence only. Team Tier assignment always uses current standings and current boundary positions.

Strong-break responsiveness is already represented by `BoundaryStrength = STRONG`. There is no separate responsiveness override threshold in V1.

Persistence never :

- bypasses a PPG rejection ;
- crosses an equal-points block ;
- turns a WEAK boundary into confirmed structure ;
- creates a boundary absent from current candidates ;
- replaces initial MODERATE temporal confirmation.

## Tier Construction

Input :

```text
podiumAnchor = ranks 1..podiumEnd from reliable metadata
relegationAnchor = ranks relegationStart..n from reliable metadata
confirmedStructuralBoundaries[]
```

Rules :

1. Assign podium anchor teams to `TIER_1`.
2. Assign relegation anchor teams to `TIER_5`.
3. Build the middle region between anchors.
4. Evaluate all eligible combinations of 0, 1 and 2 middle-region confirmed boundaries.
5. Select the best global partition using `tierPartitionQuality`.
6. Store selected boundaries as `tierPartitionBoundaries[]`.
7. Preserve all confirmed boundaries in `confirmedStructuralBoundaries[]`.
8. Split the middle region by `tierPartitionBoundaries[]`.

Intermediate mapping :

| Middle segments | Tier labels |
|---:|---|
| 0 | none |
| 1 | `TIER_3` |
| 2 | upper segment = `TIER_2`, lower segment = `TIER_4` |
| 3 | upper = `TIER_2`, middle = `TIER_3`, lower = `TIER_4` |

If an intermediate label has no segment, it is absent. This is valid.

Anchor-adjacent boundaries can exist and count as structural boundaries, but anchor membership itself does not prove a strong boundary.

Important distinction :

```text
confirmedStructuralBoundaries[] = complete structural intelligence
tierPartitionBoundaries[] = subset used for five-label Tier assignment
```

Confirmed structural boundaries must never be discarded because the Tier vocabulary has only five labels.

## Gap Measures

```text
ordinalTierGap(A,B) =
  abs(tierOrdinal(A) - tierOrdinal(B))
```

Only computed when both assignments exist.

```text
structuralBoundaryGap(A,B) =
  count confirmedStructuralBoundaries whose boundary index lies strictly between rank(A) and rank(B)
```

It does not count :

- absent labels ;
- raw ordinal label distance ;
- weak candidates ;
- raw points gaps ;
- internal anchor warnings.
- `tierPartitionBoundaries[]` alone.

Example :

```text
confirmedStructuralBoundaries = [B5, B10, B15]
tierPartitionBoundaries = [B5, B15]
Team A above B5
Team B below B15
structuralBoundaryGap(A,B) = 3
```

The answer is 3, not 2.

## Derived Hierarchy Readings

### `ranking_superiority`

Unchanged from Business Matrix semantics :

```text
ranking_superiority(subject) may exist when subject has factual official ranking advantage.
```

It can exist when `structuralBoundaryGap = 0`.

### `structural_level_gap`

Variants studied :

| Variant | Rule | Pros | Cons |
|---|---|---|---|
| A | `structuralBoundaryGap >= 1`. | Captures all confirmed separation. | May overstate if one boundary is only moderate. |
| B | `structuralBoundaryGap >= 1` and at least one `STRONG` boundary. | Very safe wording. | Misses meaningful moderate separation. |
| C | `structuralBoundaryGap >= 1`; reading strength reflects strongest counted boundary. | Preserves signal without overstating strength. | Requires careful copy. |
| D | `structuralBoundaryGap >= 1` and (`STRONG` counted boundary or at least two counted boundaries). | Conservative existence rule aligned with strong wording. | Single moderate boundary becomes structural separation without `structural_level_gap`. |

Recommended V1 : Variant D.

Producer :

```text
if structuralBoundaryGap(subject, opponent) >= 1
and (
  at least one counted confirmedStructuralBoundary is STRONG
  or structuralBoundaryGap(subject, opponent) >= 2
)
and subject has better official rank:
  produce structural_level_gap(subject)
  reading.strength =
    STRONG if any counted boundary is STRONG and structuralBoundaryGap >= 2
    MODERATE otherwise
else:
  do not produce structural_level_gap
```

Acceptance :

```text
one MODERATE boundary -> no structural_level_gap
one STRONG boundary -> structural_level_gap exists, MODERATE strength
two MODERATE boundaries -> structural_level_gap exists, MODERATE strength
two boundaries including STRONG -> structural_level_gap exists, STRONG strength
```

This reading remains in `EF_HIERARCHY` and is correlated with rank, points, tier and boundary artifacts.

### `balanced_hierarchy`

Not equivalent to `sameTier`.

Producer :

```text
rankGap = abs(rank(A) - rank(B))
pointsGap = abs(points(A) - points(B))
relativeRankLimit = max(2, ceil(BALANCED_RANK_GAP_RATIO * n))
relativePointsLimit = max(
  BALANCED_POINTS_GAP_ABSOLUTE_FLOOR,
  BALANCED_POINTS_GAP_TYPICAL_MULTIPLIER * typicalGap
)

if structuralBoundaryGap(A,B) = 0
and (
  rankGap <= relativeRankLimit
  and pointsGap <= relativePointsLimit
):
  produce balanced_hierarchy(match)
else:
  do not produce balanced_hierarchy
```

Same Tier is an input to interpretation only through `structuralBoundaryGap = 0`; both rank closeness and points closeness are required.

Acceptance :

| Case | Inputs | Expected |
|---|---|---|
| BH1 | small rankGap, small pointsGap, `structuralBoundaryGap = 0` | `balanced_hierarchy = true` |
| BH2 | small rankGap, large pointsGap, `structuralBoundaryGap = 0` | `balanced_hierarchy = false` |
| BH3 | large rankGap, small pointsGap, `structuralBoundaryGap = 0` | `balanced_hierarchy = false` |
| BH4 | small rankGap, small pointsGap, `structuralBoundaryGap >= 1` | `balanced_hierarchy = false` |

## Synthetic Championship Battery

Assumptions for all synthetic cases unless noted :

```text
standard league
metadata supplied
podiumSize = 3
relegationSize = 2
all teams played 20
maturity = MATURE
no previous snapshots unless case says otherwise
```

Boundary notation :

```text
B3 = boundary between rank 3 and rank 4
S = STRONG
M = MODERATE
W = WEAK metadata only
```

| # | Case | Points | Adjacent gaps | Boundary candidates | confirmedStructuralBoundaries | tierPartitionBoundaries | Tier presence | Warnings / maturity |
|---:|---|---|---|---|---|---|---|---|
| 1 | Perfectly compact | 60,59,58,57,56,55,54,53,52,51 | 1,1,1,1,1,1,1,1,1 | none | none | none | T1,T3,T5 | MATURE |
| 2 | Compact with one small outlier | 60,59,58,56,55,54,53,52,51,50 | 1,1,2,1,1,1,1,1,1 | none | none | none | T1,T3,T5 | MATURE |
| 3 | Clear podium break | 60,59,58,45,44,43,42,41,40,39 | 1,1,13,1,1,1,1,1,1 | B3 | B3(S) | none | T1,T3,T5 | B3 counts in structuralBoundaryGap |
| 4 | Podium anchor without break | 60,59,58,57,55,54,53,52,51,50 | 1,1,1,2,1,1,1,1,1 | none | none | none | T1,T3,T5 | anchor without boundary |
| 5 | Clear relegation break | 60,58,57,56,55,54,53,52,38,37 | 2,1,1,1,1,1,1,14,1 | B8 | B8(S) | none | T1,T3,T5 | B8 counts in structuralBoundaryGap |
| 6 | Relegation anchor without break | 60,58,57,56,55,54,53,52,51,50 | 2,1,1,1,1,1,1,1,1 | none | none | none | T1,T3,T5 | anchor without boundary |
| 7 | One huge leader | 80,60,58,57,56,55,54,53,52,51 | 20,2,1,1,1,1,1,1,1 | B1 statistical only | none for Tier construction | none | T1,T3,T5 | `ANCHOR_INTERNAL_OUTLIER` |
| 8 | One isolated bottom | 80,79,78,77,76,75,74,73,72,50 | 1,1,1,1,1,1,1,1,22 | B9 statistical only | none for Tier construction | none | T1,T3,T5 | `ANCHOR_INTERNAL_OUTLIER` |
| 9 | Three natural groups | 70,68,67,55,54,53,42,41,40,39 | 2,1,12,1,1,11,1,1,1 | B3,B6 | B3(S),B6(S) | B6 | T1,T2,T4,T5 | B3+B6 both count in structuralBoundaryGap |
| 10 | Four natural groups | 70,68,67,58,57,56,45,44,43,30,29,28 | 2,1,9,1,1,11,1,1,13,1,1 | B3,B6,B9 | B3(S),B6(S),B9(S) | B6,B9 | T1,T2,T3,T4,T5 | B3 remains structural even if not middle partition |
| 11 | Five natural groups | 70,68,67,58,57,55,54,45,44,43,42,41,30,29,27,18,17 | 2,1,9,1,2,1,9,1,1,1,1,11,1,2,9,1 | B3,B7,B12,B15 | B3(S),B7(S),B12(S),B15(S) | B7,B12 | T1,T2,T3,T4,T5 | all four boundaries count structurally |
| 12 | Stretched continuous | 80,74,69,63,58,52,47,41,36,30,25,19 | 6,5,6,5,6,5,6,5,6,5,6 | none | none | none | T1,T3,T5 | MATURE |
| 13 | Multiple similar large gaps | 80,73,66,59,52,45,38,31,24,17 | 7,7,7,7,7,7,7,7,7 | none | none | none | T1,T3,T5 | MATURE |
| 14 | Equal-points block | 50,48,45,45,45,40,38,37,36,35 | 2,3,0,0,5,2,1,1,1 | B5 | B5(M) | B5 if globally useful | T1,T2/T3,T5 | no cut through 45 block |
| 15 | Quasi-equality | 50,48,45,44,44,40,38,37,36,35 | 2,3,1,0,4,2,1,1,1 | B5 candidate | B5 only if score >= 60 | B5 only if selected by quality | T1,T3,T5 | quasi-equality deferred |
| 16 | Games-in-hand mild | 40/20,36/19,35/20,34/20,33/20,32/20,31/20,30/20,29/20,28/20 | 4,1,1,1,1,1,1,1,1 | B1 inside anchor only | none for Tier construction | none | T1,T3,T5 | `PPG_QUALIFICATION_USED` |
| 17 | Games-in-hand severe false break | 40/20,36/18,35/20,34/20,33/20,32/20,31/20,30/20,29/20,28/20 | 4,1,1,1,1,1,1,1,1 | B1 inside anchor only | none for Tier construction | none | T1,T3,T5 | `PPG_QUALIFICATION_USED` |
| 18 | Early season | 9/3,7/3,6/3,5/3,4/3,4/3,3/3,2/3,1/3,0/3 | 2,1,1,1,0,1,1,1,1 | not evaluated | none | none | none | IMMATURE |
| 19 | Mature 24-team league | 75,73,72,68,67,66,62,61,60,59,58,57,53,52,51,50,49,48,44,43,42,38,37,36 | mixed 1-4 | B3,B12,B18,B21 weak/moderate | B12(M),B18(M) plus weak metadata | B12,B18 | T1,T2,T4,T5 | partition cap does not erase structural metadata |
| 20 | Noisy borderline | 60,58,57,53,52,51,48,47,46,42,41,40 | 2,1,4,1,1,3,1,1,4,1,1 | B3,B9 candidates | pending / not confirmed without history | none until confirmed | T1,T3,T5 | temporal confirmation required |
| 21 | Repeated execution is not temporal confirmation | S1 repeated with same B6(M) | unchanged | B6(M) | pending | none | T1,T3,T5 | same `standingsSnapshotIdentity`; still pending |
| 22 | Distinct snapshot confirms MODERATE | S1 B6(M), S2 compatible B6/B7(M) | compatible | B6/B7(M) | B6/B7(M) confirmed | selected if best partition | according to partition | distinct `standingsSnapshotIdentity` |
| 23 | STRONG immediate | S1 new B6(S) | clear | B6(S) | B6(S) confirmed immediately | selected if best partition | according to partition | no second snapshot required |
| 24 | More than two structural boundaries | 80,78,76,66,64,62,52,50,48,38,36,34,24,22,20 | 2,2,10,2,2,10,2,2,10,2,2,10,2,2 | B3,B6,B9,B12 | B3(S),B6(S),B9(S),B12(S) | best two by partition quality | T1,T2,T3/T4,T5 | all four count for structuralBoundaryGap |
| 25 | Negligible partition gain | two partitions differ by <= 0.02 quality | n/a | multiple | all confirmed preserved | simpler partition selected | fewer labels if equivalent | parsimony epsilon |
| 26 | Severe played imbalance | playedSpread > max(4, ceil(0.33 * medianPlayed)) | n/a | not evaluated | none | none | none | IMMATURE, no Tier structure |

## Adversarial Algorithm Cases

| Case | Failure searched | Cause | Guardrail | Remaining tradeoff |
|---|---|---|---|---|
| Compact league | Percentile method forces one largest gap. | Relative rank of gap, not true abnormality. | Require raw floor, robust z/ratio and segmentation gain. | May miss subtle tactical group separation, acceptable V1. |
| MAD = 0 | Division by zero or infinite z. | Identical gaps. | `fallbackScale` and ratio detector. | Ratio depends on typical gap floor. |
| Huge leader | Leader creates artificial Tier above podium. | Single outlier inside anchor. | Cannot cut inside mandatory anchor block for Tier construction. | Emits only warning, not extra Tier. |
| Huge bottom team | Last team creates artificial below-relegation Tier. | Single bottom outlier. | Cannot cut inside relegation anchor. | Bottom isolation not represented as new Tier. |
| Two outliers | Median/MAD distorted by extremes. | Top and bottom extremes. | Robust median, segmentation and max intermediate boundary cap. | Some moderate middle breaks may be suppressed. |
| Small league | Too few gaps for robust stats. | n=10 gives 9 gaps. | Maturity gate, min raw gap, MAD fallback. | Conservative local abstention. |
| Many identical gaps | Ratio/z ambiguous. | No true distribution break. | Candidate requires abnormality and segmentation gain. | Produces few boundaries by design. |
| Points tie around cut | Boundary cuts identical points. | Official rank tie-breakers. | Equal-points block guard. | Goal difference structure ignored V1. |
| Games-in-hand false break | Raw points gap due to fewer matches. | Unequal played counts. | PPG qualification can reject or downgrade. | PPG cannot add positive structure. |
| PPG erases true break | PPG similar but raw gap is huge and coherent. | Delayed games plus real separation. | `PPG_EXTREME_RAW_BREAK_SURVIVAL_SCORE`. | Requires careful review of PPG qualification sensitivity. |
| Boundary flicker | Moderate boundary appears/disappears daily. | Marginal score around threshold. | Two-snapshot confirmation and one-snapshot persistence. | First moderate break may be delayed. |
| Anchor confused with boundary | Podium/relegation treated as automatic rupture. | Regulatory category mistaken for distribution break. | Anchor != boundary rule. | Podium still labelled even without strong split. |
| Partition adversarial A | Two very strong adjacent boundaries beat one distant boundary by individual score. | Top-2-by-score creates tiny upper slices and ignores lower structure. | Exhaustive global partition quality. | May select a lower-score boundary for better global coherence. |
| Partition adversarial B | Three confirmed boundaries but only two useful Tier partitions. | Five labels cannot expose every structural break. | Preserve all in `confirmedStructuralBoundaries[]`; select subset for `tierPartitionBoundaries[]`. | UI Tier labels are simplified, but structural intelligence remains complete. |
| Partition adversarial C | Second selected boundary adds negligible coherence. | Mechanical maximization of labels. | Compare 0/1/2 boundary partitions and favor fewer when gain difference <= epsilon. | Some subtle segmentation may remain metadata only. |
| Partition adversarial D | Two partitions have quasi-identical quality. | Tie without deterministic policy. | Tie-break by fewer boundaries, min segment size, score sum, then boundary index order. | Tie-break is deterministic, not subjective. |

## Sensitivity Analysis

| Setting | More permissive | Recommended | More conservative | Expected impact |
|---|---|---|---|---|
| Candidate z | 2.0 | 2.5 | 3.0 | Permissive catches moderate gaps but over-flags noisy cases. |
| Candidate ratio | 2.4 | 3.0 | 3.6 | Permissive creates compact false positives when typical gap is 1. |
| Segmentation gain | 0.15 | 0.20 | 0.28 | Conservative loses some real middle boundaries. |
| Confirm score | 55 | 60 | 70 | Lower increases boundaries in noisy borderline distributions. |
| Strong score | 75 | 78 | 85 | Higher reduces immediate responsiveness. |
| PPG reject ratio | 0.25 | 0.35 | 0.45 | Conservative rejects more games-in-hand candidates. |
| Maturity median played | 4 | 6 | 8 | Early availability vs early-season noise. |
| Played spread usable ratio | 25% | 33% | 40% | Lower marks more schedules immature. |
| Temporal confirmation | immediate | 2 snapshots | 3 snapshots | Conservative reduces flicker but delays real moderate breaks. |
| Persistence | 0 | 1 snapshot | 2 snapshots | Higher risks stale boundary survival. |
| Max Tier partition boundaries | 1 | 2 | 3 | Higher can oversegment public Tier labels; confirmed structural boundaries are still preserved. |
| structural_level_gap existence | any one confirmed boundary | one STRONG or two confirmed boundaries | only STRONG boundaries | Recommended reduces overstatement from a single moderate boundary. |
| balanced_hierarchy closeness | rank OR points | rank AND points | stricter custom closeness | Recommended avoids calling teams balanced when only one dimension is close. |
| Tier partition selection | top-2 score | best global partition quality | single boundary only | Recommended avoids adjacent high-score boundaries distorting Tier labels. |

Recommended configuration prefers abstention when statistical evidence is ambiguous.

## Final Pseudocode

```text
function buildDynamicTierSnapshot(input):
  validation = validateCompetition(input)
  if validation.status = UNAVAILABLE:
    return unavailableSnapshot(validation.reasons)

  standings = buildStandingsSnapshot(input)
  standingsSnapshotIdentity = computeStandingsSnapshotIdentity(
    standings,
    input.metadata,
    input.analysisAsOf,
    input.providerSnapshotVersion,
    input.standingsSourceTimestamp
  )
  maturity = evaluateMaturity(standings, input.metadata)
  if maturity.status != MATURE:
    return snapshotWithMaturityOnly(maturity, standingsSnapshotIdentity)

  distribution = computePointDistribution(standings)
  gaps = computeAdjacentGaps(distribution.points)
  robustContext = computeRobustDispersion(gaps)
  ppgContext = computePPGContext(standings)

  candidates = []
  for each gap index i:
    if not isEligibleBoundaryPosition(i, standings, input.anchors):
      maybe record anchorInternalOutlier warning
      continue

    candidateMetrics = detectBoundaryCandidate(i, gaps, robustContext)
    if not candidateMetrics.isCandidate:
      continue

    segmentation = validateSegmentation(i, distribution.points)
    if not segmentation.valid:
      record weak candidate metadata
      continue

    score = computeBoundaryEvidenceScore(candidateMetrics, segmentation)
    ppgQualification = qualifyCandidateWithPPG(i, score, ppgContext)
    if ppgQualification.rejected:
      record rejected candidate warning
      continue

    score = ppgQualification.adjustedScore
    strength = computeBoundaryStrength(score)
    candidates.add(boundaryCandidate(i, score, strength, segmentation, ppgQualification))

  spatialConfirmed = []
  for candidate in candidates:
    if candidate.score >= BOUNDARY_SCORE_CONFIRM and candidate.strength != WEAK:
      spatialConfirmed.add(candidate)

  confirmedStructuralBoundaries = applyTemporalBoundaryStability(
    spatialConfirmed,
    input.previousBoundaryState,
    standingsSnapshotIdentity
  )

  tierPartitionBoundaries = selectBestTierPartition(
    standings,
    input.anchors,
    confirmedStructuralBoundaries,
    MAX_TIER_PARTITION_BOUNDARIES
  )

  tierStructure = applyAnchorSemantics(
    standings,
    input.anchors,
    confirmedStructuralBoundaries
  )

  assignments = assignTierLabels(
    standings,
    input.anchors,
    tierPartitionBoundaries
  )

  boundaryDistances = computeBoundaryDistances(assignments, confirmedStructuralBoundaries)

  for every match pair A,B requested:
    ordinalTierGap = computeOrdinalTierGap(assignments[A], assignments[B])
    structuralBoundaryGap = computeStructuralBoundaryGap(
      rank(A),
      rank(B),
      confirmedStructuralBoundaries
    )
    structuralLevelGap = deriveStructuralLevelGap(
      A,
      B,
      structuralBoundaryGap,
      confirmedStructuralBoundaries
    )
    balancedHierarchy = deriveBalancedHierarchy(
      A,
      B,
      structuralBoundaryGap,
      robustContext.typicalGap
    )

  validateInvariants(snapshot)
  return emitChampionshipTierSnapshot(
    version = tier-v1,
    standingsSnapshotIdentity,
    maturity,
    distribution,
    candidates,
    confirmedStructuralBoundaries,
    tierPartitionBoundaries,
    tierPresence,
    assignments,
    boundaryDistances,
    warnings
  )
```

## Recommended Dynamic Tier Algorithm V1

Status : `LOCKED_ALGORITHM_V1`.

### Maturity rule

```text
UNAVAILABLE if unsupported format, missing required data, n outside [10,24],
or missing required anchors.

IMMATURE if medianPlayed < 6
or minPlayed < 4
or known seasonProgress < 25%
or playedSpread > max(4, ceil(0.33 * medianPlayed)).

Otherwise MATURE.
```

### Played-balance rule

```text
playedSpread = max(played) - min(played)
balanced if playedSpread <= 2
warning if playedSpread > 2
severe imbalance if playedSpread > max(4, ceil(0.33 * medianPlayed))
```

### PPG activation rule

```text
ppgActive_i =
  abs(played_i - played_(i+1)) >= 2
  or playedSpread >= 3
```

### Candidate boundary rule

```text
candidateBoundary_i =
  eligiblePosition_i
  and g_i >= 3
  and (
    robustZ_i >= 2.5
    or gapRatio_i >= 3.0
  )
```

### Robust dispersion rule

```text
medianGap = median(gaps)
medianPositiveGap = median(gaps > 0)
typicalGap = max(1.0, medianPositiveGap)
rawMAD = median(|g_i - medianGap|)
madScale = rawMAD * 1.4826
iqrScale = IQR(gaps) / IQR_NORMALIZATION_FACTOR
fallbackScale = max(1.0, iqrScale, medianPositiveGap * 0.5)
robustScale = madScale if rawMAD > 0 else fallbackScale
robustZ_i = max(0, (g_i - medianGap) / robustScale)
gapRatio_i = g_i / typicalGap
```

### Segmentation validation

```text
segmentationGain =
  (MAD(allPoints) - weightedMAD(upper, lower))
  / max(MAD(allPoints), 1.0)

valid if upperSize >= 2
and lowerSize >= 2
and segmentationGain >= 0.20
```

### Boundary confirmation

```text
boundaryEvidenceScore =
  BOUNDARY_SCORE_SCALE * (
    BOUNDARY_SCORE_Z_WEIGHT * clamp(robustZ / Z_COMPONENT_SATURATION, 0, 1)
    + BOUNDARY_SCORE_RATIO_WEIGHT * clamp((gapRatio - GAP_RATIO_COMPONENT_OFFSET) / GAP_RATIO_COMPONENT_SPAN, 0, 1)
    + BOUNDARY_SCORE_SEGMENT_WEIGHT * clamp(segmentationGain / SEGMENTATION_GAIN_SATURATION, 0, 1)
  )

spatialConfirmed if score >= 60 and strength != WEAK
```

### BoundaryStrength

```text
WEAK if score < 50
MODERATE if 50 <= score < 78
STRONG if score >= 78
```

Only `MODERATE` and `STRONG` can become confirmed meaningful boundaries.

### Temporal confirmation

```text
new STRONG boundary -> immediate confirmed
new MODERATE boundary -> confirmed after 2 compatible snapshots
```

### Light persistence

```text
existing confirmed boundary survives 1 snapshot
if current compatible candidate remains score >= 50
and no equal-points or PPG rejection guard fails.
```

### Strong-break responsiveness

```text
BoundaryStrength = STRONG -> immediate confirmation
```

There is no separate responsiveness override threshold.

### Structural boundaries

```text
confirmedStructuralBoundaries[] = all temporally confirmed meaningful structural boundaries
tierPartitionBoundaries[] = subset selected for Tier label assignment only
```

No confirmed structural boundary is discarded because of the five-label Tier vocabulary.

### Intermediate Tier assignment

```text
podium anchor -> TIER_1
relegation anchor -> TIER_5

select best global partition using 0, 1 or 2 middle-region confirmedStructuralBoundaries.

middle segments after selected tierPartitionBoundaries:
1 segment -> TIER_3
2 segments -> TIER_2 + TIER_4
3 segments -> TIER_2 + TIER_3 + TIER_4

max selected Tier partition boundaries = 2
```

### structuralBoundaryGap

```text
count confirmedStructuralBoundaries strictly between the two official ranks.
```

### structural_level_gap

```text
produce for better-ranked subject if structuralBoundaryGap >= 1
and (
  at least one counted confirmedStructuralBoundary is STRONG
  or structuralBoundaryGap >= 2
).

strength = STRONG if at least one counted boundary is STRONG and structuralBoundaryGap >= 2.
strength = MODERATE otherwise.
```

### balanced_hierarchy

```text
produce if structuralBoundaryGap = 0
and (
  rankGap <= max(2, ceil(0.15 * n))
  and pointsGap <= max(4, 2.0 * typicalGap)
)
```

## KR Reykjavik vs Vikingur Acceptance

Pre-match only :

```text
Vikingur rank = 1
Vikingur points = 51
KR rank = 3
KR points = 43
```

If algorithm output is :

```text
Vikingur Tier = TIER_1
KR Tier = TIER_1
sameTier = true
structuralBoundaryGap = 0
```

Then Business Matrix behavior remains :

```text
ranking_superiority(Vikingur) may exist
structural_level_gap(Vikingur) does not exist
expected_domination(Vikingur) = NOT_ELIGIBLE
failedGate = EG_EXPECTED_DOMINATION_TIER_GAP
```

No threshold in this document was chosen to optimize this match. This match is an acceptance case, not a training case.

## Locked Dynamic Tier V1 Invariants

1. Tier analysis is profile-independent.
2. Tier analysis is pre-match temporal.
3. Five labels do not imply five populated groups.
4. Structural boundaries are not equivalent to Tier partition boundaries.
5. Confirmed structural boundaries are never discarded due to label capacity.
6. Tier partition uses at most two middle boundaries in V1.
7. `MAX_TIER_PARTITION_BOUNDARIES` is a Tier representation limit, not a structural analysis limit.
8. `structuralBoundaryGap` counts all confirmed boundaries between teams.
9. `structuralBoundaryGap` does not count only `tierPartitionBoundaries`.
10. `ordinalTierGap` does not replace `structuralBoundaryGap`.
11. Rank superiority does not imply structural superiority.
12. Same Tier does not imply perfectly balanced teams.
13. Same Tier blocks `expected_domination` according to the Business Matrix.
14. A same-Tier gate failure is not a contradiction, resistance, warning or confidence downgrade.
15. One MODERATE boundary does not produce `structural_level_gap`.
16. One STRONG boundary can produce `structural_level_gap`.
17. Two MODERATE boundaries can produce `structural_level_gap`.
18. `balanced_hierarchy` requires rank closeness and points closeness.
19. `balanced_hierarchy` also requires `structuralBoundaryGap = 0`.
20. STRONG new boundary is immediately confirmable.
21. MODERATE new boundary requires two distinct compatible standings snapshots.
22. Re-execution of the same snapshot cannot advance temporal confirmation.
23. WEAK boundary cannot become confirmed structural evidence.
24. Severe played imbalance returns `IMMATURE` in V1.
25. `MATURE_WITH_WARNING` is not a V1 maturity state.
26. PPG is secondary structural qualification, not primary ordering.
27. PPG cannot create a boundary alone.
28. PPG cannot rewrite official rank or points.
29. Tier partition selection is global, not top-N boundary score selection.
30. Negligible partition gain favors the simpler partition.
31. Tier construction cannot use user preferences.
32. Tier construction cannot use match outcomes.
33. Tier construction cannot use odds.
34. Tier construction cannot use form, xG or home-away signals.
35. Identical inputs and structural state produce identical output.
36. Anchor membership does not itself prove a structural boundary.
37. Podium can exist without a strong adjacent boundary.
38. Relegation can exist without a strong adjacent boundary.
39. Equal-points blocks cannot be split by structural boundaries.
40. Abstention is preferable to manufactured structure.
41. Unsupported V1 competition formats return unavailable/not supported instead of approximate Tiers.
42. All hierarchy artifacts remain correlated within `EF_HIERARCHY`.
43. No `tier_superiority` reading is created merely to increase support count.
44. `tier-v1` is the frozen algorithm version for this specification.

## Locked V1 Decisions

The previous open algorithmic ambiguities are resolved for `tier-v1`.

| Decision | Locked V1 outcome | Rationale |
|---|---|---|
| Moderate temporal confirmation | `TEMPORAL_CONFIRM_MODERATE_SNAPSHOTS = 2` distinct compatible standings snapshots. | Prevents one-run confirmation noise while remaining responsive. |
| Same-snapshot rerun | Does not advance confirmation age. | Confirmation must reflect new standings state, not execution count. |
| Strong temporal confirmation | `BoundaryStrength = STRONG` confirms immediately. | Strong-break responsiveness is carried by strength classification. |
| Tier partition capacity | `MAX_TIER_PARTITION_BOUNDARIES = 2`. | Limit applies only to five-label representation, not structural analysis. |
| Tier partition epsilon | `TIER_PARTITION_GAIN_EPSILON = 0.02`. | Negligible global gain favors simpler representation. |
| PPG extreme raw break survival | `PPG_EXTREME_RAW_BREAK_SURVIVAL_SCORE = 85`. | PPG can reject false gaps but should not erase exceptional raw structural evidence. |
| Severe played imbalance | `IMMATURE` in V1. | No `MATURE_WITH_WARNING` state is introduced in V1. |
| `structural_level_gap` existence | Requires better rank plus one STRONG counted boundary or at least two counted boundaries. | Avoids overclaiming from a single moderate boundary. |
| `balanced_hierarchy` existence | Requires `structuralBoundaryGap = 0` plus rank closeness and points closeness. | Same Tier alone is not enough. |

## Remaining Open Questions

| Classification | Question | V1 impact |
|---|---|---|
| `BLOCKING_V1_LOCK` | NONE | Algorithm can be locked. |
| `NON_BLOCKING_IMPLEMENTATION_DETAIL` | Exact persistence storage shape for `previousBoundaryState`. | Implementation detail as long as snapshot identity semantics are preserved. |
| `NON_BLOCKING_IMPLEMENTATION_DETAIL` | Exact serialization shape of `canonicalStandingsStateHash`. | Implementation detail as long as canonical fields and determinism are preserved. |
| `FUTURE_VERSION` | Whether a future `MATURE_WITH_WARNING` state is useful after observing real data. | Not part of V1. |
| `FUTURE_VERSION` | Whether future UI should expose every confirmed structural boundary or summarize them. | Presentation question, not V1 algorithm lock. |

## Final Verdict

```text
DYNAMIC TIER ALGORITHM V1 LOCKED — READY FOR IMPLEMENTATION
```
