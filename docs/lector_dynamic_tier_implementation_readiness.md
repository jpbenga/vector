# Lector - Dynamic Tier Implementation Readiness Audit

Date d'audit : 2026-09-02  
Statut : `IMPLEMENTATION_READINESS_AUDIT`, sans implementation.  
Algorithme cible : `DynamicTierAlgorithmV1` / `tier-v1`  
Perimetre : audit repository avant changement de code de production.

## 1. Executive Summary

Lector est pret a commencer une implementation phasee du Dynamic Tier Algorithm V1, a condition de traiter les gaps de donnees et d'architecture dans l'ordre. Le repository possede deja une base solide : ingestion API-Football server-side, cache brut, snapshots pre-match immuables, payload `raw.standings`, normalisation de `rank`, `points`, `played`, table complete de classement par ligue dans `MatchAnalysisData.leagueStandings`, et tests backend/client autour du contrat de snapshot.

Les principaux ecarts avec le contrat verrouille sont clairement identifiables et solvables par implementation :

- `standings[].description` existe dans les payloads bruts/API snapshots, mais n'est pas retenu dans `TeamStandingSnapshot`.
- Il n'existe pas encore de metadata fiable pour `competitionFormat`, `podiumAnchor`, `relegationAnchor`, ni de version de metadata.
- Il n'existe pas encore de `standingsSnapshotIdentity`, de `canonicalStandingsStateHash`, ni de stockage de `previousBoundaryState`.
- `FootballAnalyzer._hierarchyReadings` produit encore `balanced_hierarchy`, `ranking_superiority` et `structural_level_gap` depuis des heuristiques raw rank/points.
- `OpportunityEngineV2` applique le profil avant l'analyse exhaustive et filtre les theses avant selection.
- `expected_domination` n'a pas encore de Tier Gate `EG_EXPECTED_DOMINATION_TIER_GAP`.
- La UI de detail contient encore des cartes de lectures hardcodees.

Aucun item ne bloque le demarrage de l'implementation. Les blockers sont des travaux a faire pendant les premieres phases, pas des decisions produit ouvertes. Le verdict est donc :

```text
DYNAMIC TIER IMPLEMENTATION READY - PROCEED TO PHASED IMPLEMENTATION
```

## 2. Scope

Cet audit couvre :

- le pipeline API-Football vers feed Lector ;
- la disponibilite des standings et champs structurels ;
- les metadata d'anchors et de formats ;
- `analysisAsOf`, timestamps, snapshots et persistence ;
- `FootballAnalyzer`, readings de hierarchie et `OpportunityEngineV2` ;
- l'intervention du profil utilisateur ;
- UI et tests existants ;
- architecture cible, phases, migrations futures et risques.

Hors perimetre :

- aucun changement Dart ;
- aucune migration SQL ;
- aucun changement Edge Function ;
- aucun changement UI ;
- aucun test modifie ;
- aucune modification des documents normatifs verrouilles.

## 3. Normative References

Ordre d'autorite :

1. `docs/lector_business_matrix_v2_1.md`
2. `docs/lector_dynamic_tier_system_spec.md`
3. `docs/lector_dynamic_tier_algorithm_v1.md`
4. code actuel

Regle d'audit : adapter le repository au contrat verrouille, pas adapter le contrat aux raccourcis legacy.

## 4. Current Repository Pipeline

Pipeline observe :

| Stage | File / symbol | Input | Output | Responsibility | Future Tier integration |
|---|---|---|---|---|---|
| API-Football sync | `supabase/functions/api-football-sync/index.ts` | API-Football endpoints | `api_football_cached_responses` | Fetch server-side and store raw response body, `fetched_at`, `as_of`. | Keep as raw source; no Tier logic here except ensuring standings coverage. |
| Raw cache table | `supabase/migrations/20260811103000_backend_lot_2_api_football_server.sql` | API response | immutable-ish cache row keyed by endpoint/query | Server-only cache with timestamps. | Source provenance for standings timestamp. |
| Snapshot builder | `supabase/functions/build-match-feed-snapshot/index.ts` | cached raw rows | `match_feed_snapshots.payload` | Builds pre-match feed payload with `raw.fixtures`, `raw.odds`, `raw.standings`, `raw.team_statistics`, `raw.recent_league_matches`, `raw.expected_goals`. | Best backend insertion point for precomputed/cached Tier snapshots later. |
| Snapshot DB | `supabase/migrations/20260811113000_backend_lot_3a_match_feed_snapshots.sql` | payload | immutable `match_feed_snapshots`, fixture index, source links | Read model consumed by client. | Can reference/persist future `championship_tier_snapshots`. |
| Remote repository | `lib/features/matches/data/supabase_match_feed_snapshot_repository.dart` | Supabase rows | merged snapshot payload | Loads latest snapshots by date and merges league-scoped payloads. | Can pass `as_of`/source metadata into structural snapshot builder. |
| Loader | `lib/features/matches/data/match_feed_repository_loader.dart` | config source | `MatchFeedRepository` | Chooses demo/local/supabase with local fallback. | Future can attach Tier cache/provider to snapshot repository. |
| Adapter | `lib/features/matches/data/api_football_match_adapter.dart` | snapshot payload | `List<MatchBoardItem>` | Normalizes fixture, competition, teams, odds, standings, stats, recent form, xG. | Must retain structural standings metadata and expose full league table. |
| Match model | `lib/features/matches/domain/match_board_item.dart` | normalized values | `MatchBoardItem.analysis` | Holds `MatchAnalysisData` with home/away standings and `leagueStandings`. | Add/reference `MatchStructuralRelation` or future bundle. |
| Analyzer | `lib/features/matches/domain/football_analyzer.dart` | `MatchBoardItem` | `FootballAnalysis.readings` | Produces deterministic readings. | Consume `MatchStructuralRelation` for hierarchy readings. |
| V2 opportunities | `lib/features/matches/domain/opportunity_engine_v2.dart` | `MatchBoardItem`, profile | `Opportunity` | Produces one selected V2 opportunity per match. | Add gates and evaluate all canonical theses before user matching. |
| Legacy fallback | `lib/features/matches/domain/match_insight_engine.dart` | match/profile | legacy `Opportunity`/`MatchThesis` | Used when V2 empty or analyze fallback. | Must be isolated or removed after V2 matrix migration. |
| Picks | `lib/features/matches/domain/pick_engine.dart` | opportunities/profile | `GeneratedTicketPick` | Requires recommended market enabled in profile. | Remains user-specific after Match Intelligence. |
| Presentation | `lib/features/matches/presentation/match_detail_page.dart`, `opportunity_decision_presenter.dart` | `MatchBoardItem`, thesis args | UI cards/copy | Mixes engine output and hardcoded explanation cards. | Consume engine readings/relations only. |

## 5. API-Football Standings Data Audit

API-Football standings are fetched through `/standings` in `api-football-sync/index.ts` and then collected by `build-match-feed-snapshot/index.ts` through `cachedResponsesFor(endpoint: "/standings")`. The snapshot builder flattens `response_body.response` with `flatResponseItems` and stores those objects inside `payload.raw.standings`.

Observed raw structure in fixtures/tests and snapshots :

```text
raw.standings[].league.id
raw.standings[].league.season
raw.standings[].league.standings[][]
standing.rank
standing.team.id
standing.team.name
standing.points
standing.goalsDiff
standing.group
standing.form
standing.description
standing.all.played
```

Observed local `description` values include :

```text
Promotion - Champions League (Qualification)
Promotion - Conference League (Qualification)
Promotion - Europa League (Qualification)
Eliteserien (Relegation)
Relegation - OBOS-ligaen
Relegation Playoffs
Relegation
Promotion - Veikkausliiga (Championship Group)
Veikkausliiga (Relegation Group)
null
```

Conclusion :

- raw source contains enough shape to preserve `description`;
- descriptions are heterogeneous and cannot be treated as universal rules without metadata/override;
- current adapter ignores `description`;
- V1 should retain it as raw structural metadata and let a future anchor resolver qualify it.

## 6. Normalized Standings Model Audit

Current type : `TeamStandingSnapshot` in `lib/features/matches/domain/match_board_item.dart`.

| Field required by audit | Current status | Repository evidence | Notes |
|---|---|---|---|
| `teamId` | `AVAILABLE` | `TeamStandingSnapshot.teamId` | API-Football numeric team id. |
| `officialRank` / `rank` | `AVAILABLE` | `rank` parsed from `standing['rank']` | Nullable in model, required by tier-v1 maturity/availability. |
| `points` | `AVAILABLE` | `points` parsed from `standing['points']` | Nullable in model. |
| `played` | `AVAILABLE` | `played` parsed from `standing['all']['played']` | Nullable in model. |
| `group` | `AVAILABLE` | `group` parsed from `standing['group']` | Useful for atypical/split detection but not sufficient alone. |
| `description` | `NOT_RETAINED` | raw has field; constructor has no field | Must be added before reliable anchors from API descriptions. |
| `source timestamp` | `AVAILABLE_ELSEWHERE` | snapshot/cached source rows | Not present per team standing. |
| `competitionId` | `AVAILABLE_ELSEWHERE` | `CompetitionInfo.id`, league map key | Not in `TeamStandingSnapshot`; available at match/league context. |
| `season` | `AVAILABLE_ELSEWHERE` | `CompetitionInfo.season`, `season_by_league` payload | Not in standing row. |

Future minimal change :

- add `description` or `standingDescription` to `TeamStandingSnapshot`;
- add structural metadata at league snapshot level rather than duplicating competition/season into every row unless serialization demands it;
- keep raw `rank`, `points`, `played` nullable in the generic model, but make Tier input validation reject missing values.

## 7. Anchor Metadata Audit

Existing sources :

| Source | Coverage | Reliability | Temporal safety | Current normalization | Usable for `tier-v1`? |
|---|---|---|---|---|---|
| `DecisionCompetitionDefinition` / `CompetitionCatalog` | league id, name, country, legacy ids | Good for identity, weak for rules | Static | yes for ids only | `PARTIAL` |
| `RuntimeCompetitionCatalog.apiFootballLeagueIds` | active leagues | Good for scope | Static | yes | `PARTIAL` |
| `CompetitionInfo` | id, name, country, season, API league id, logo | Good for match context | From snapshot | yes | `PARTIAL` |
| API-Football `standing.description` | promotion/relegation strings, sometimes null | Mixed, provider-specific | Snapshot-safe if retained | raw only, lost in adapter | `PARTIAL_AFTER_RETENTION` |
| DB schema | no league rule table found | Missing | n/a | n/a | `MISSING` |
| Seed/config metadata for podium/relegation | none found | Missing | n/a | n/a | `MISSING` |

Conclusion : hybrid anchor strategy is implementable, but Phase 1 must add explicit Lector metadata/override and retain API descriptions. No universal `top 3` / `last 3` fallback should be introduced.

## 8. Competition Format Audit

Current repository can identify:

- API-Football league id;
- country/name;
- season;
- group string in standings;
- fixture league round string in raw fixtures;
- active runtime league allowlist.

Current repository cannot reliably identify:

- standard round-robin vs split league;
- playoffs-only competitions;
- apertura/clausura;
- conference semantics;
- leagues without relegation;
- relegation playoff vs direct relegation rules.

Classification : `IMPLEMENTATION_GAP`.

Future required source :

- a `CompetitionStructuralMetadata` catalog/table with `competitionFormat`, `formatVersion`, supported status, anchor policy, podium/relegation sizes or explicit description mappings;
- API `description` as secondary evidence only when marked reliable for that competition.

## 9. Played / PPG Audit

`played` is available from API-Football standings:

```text
standing.all.played -> ApiFootballMatchAdapter._standingSnapshot -> TeamStandingSnapshot.played
```

It is also available in team statistics:

```text
team_statistics.fixtures.played.total/home/away -> TeamStatisticsSnapshot
```

Downstream consumers today :

- `FootballAnalyzer._hierarchyReadings` uses min home/away standing `played` as sample size.
- `FootballAnalyzer` attack/defense/rhythm uses `TeamStatisticsSnapshot.playedTotal`.
- legacy `MatchInsightEngine` uses `played` for reliability/performance arguments.
- UI detail tables display `played`.

PPG audit :

- no domain `pointsPerGame` or `ppg` model found;
- `_pointsPerMatch` exists in `match_detail_page.dart`, but it computes `(wins * 3 + draws) / played` for presentation/stats, not official standing PPG for Tier;
- Tier V1 must introduce a pure structural PPG calculation from `points / played`, not reuse UI helper logic.

Nullability risk :

- `played` is nullable in `TeamStandingSnapshot`;
- Tier V1 validation must return `UNAVAILABLE` when required standing rows miss `played`.

## 10. Temporal / analysisAsOf Audit

Current temporal sources :

- `api_football_cached_responses.fetched_at` and `as_of`;
- `match_feed_snapshots.captured_at`, `as_of`, `snapshot_created_at`;
- snapshot payload `captured_at`;
- `MatchAnalysisData.asOf`;
- `FootballReading.asOf`;
- `Opportunity.asOf`;
- `TeamExpectedGoalsSnapshot.asOf`.

Current flow :

```text
match_feed_snapshots.payload.captured_at
  -> ApiFootballMatchAdapter.fromSnapshot capturedAt
  -> MatchAnalysisData.asOf
  -> FootballAnalyzer.analyze snapshotTime
  -> FootballAnalysis.asOf / FootballReading.asOf
  -> Opportunity.asOf
```

Risks :

- `FootballAnalyzer.analyze` falls back to `match.fixture.kickoff` then `DateTime.now()` when `asOf` and `match.analysis.asOf` are absent.
- `ApiFootballMatchAdapter._expectedGoalsByTeamId` falls back to `DateTime.now().toUtc()` if `capturedAt` is missing.
- current standings represent the snapshot payload state, but no separate check guarantees a fixture's standings were captured before kickoff.
- historical reconstruction is only as good as retained immutable snapshots and raw cache retention.

Classification : `TEMPORAL_INTEGRITY_RISK`, not a blocker before code because the required fields exist and the implementation path is clear.

Future requirement :

- Tier V1 inputs must require explicit `analysisAsOf`;
- no `DateTime.now()` fallback inside Dynamic Tier computation;
- Match Intelligence should reject/not evaluate structural relation if standing source `as_of` is after the relevant pre-match boundary.

## 11. Standings Snapshot Identity Audit

Current identity exists for feed snapshots :

```text
match_feed_snapshots_identity_idx:
source + schema_version + season + timezone + window_start + window_end + as_of
```

This is not enough for Tier temporal confirmation because a rerun with identical normalized standings could have a new ingestion timestamp or feed snapshot identity.

Current missing concepts :

- `standingsSnapshotIdentity`;
- `canonicalStandingsStateHash`;
- `anchorMetadataVersion`;
- `competitionFormatVersion`;
- `previousBoundaryState`;
- protection against same-snapshot rerun advancing a MODERATE boundary.

Recommended future `canonicalStandingsStateHash` fields :

```text
competitionId
season
ordered standings rows:
  teamId
  officialRank
  points
  played
  group
retained standing description, if consumed by anchor resolver
anchorMetadataVersion
competitionFormatVersion
tierSystemVersion
```

Best layer : pure domain/data boundary after standings normalization and metadata resolution, before `DynamicTierAlgorithmV1`.

## 12. Existing Persistence / Cache Audit

Existing persistence :

- `api_football_cached_responses`: raw server-only cache, endpoint/query keyed, includes `fetched_at`, `as_of`, `response_body`.
- `match_feed_snapshots`: immutable pre-match payload read model, includes `schema_version`, `captured_at`, `as_of`, `provenance`, `coverage_summary`.
- `match_feed_snapshot_sources`: provenance links to cached responses.
- `match_feed_snapshot_fixtures`: fixture index and coverage flags.
- user-facing persistence exists for profiles, tickets and favorites, but not analysis bundles.

No existing table/model found for :

- `ChampionshipTierSnapshot`;
- `MatchAnalysisBundle`;
- `MatchStructuralRelation`;
- versioned engine output;
- previous boundary temporal state.

Recommendation : start with pure deterministic domain + in-memory per-feed computation, then add persisted/cached `championship_tier_snapshots` once the algorithm output is stable.

## 13. Current Football Analyzer Audit

Current class : `FootballAnalyzer` in `lib/features/matches/domain/football_analyzer.dart`.

Signature :

```text
FootballAnalysis analyze(MatchBoardItem match, {DateTime? asOf})
```

Inputs :

- `MatchBoardItem`;
- `MatchAnalysisData` standings, league standings, statistics, recent matches, expected goals;
- optional `asOf`.

Outputs :

- `FootballAnalysis.fixtureId`;
- `FootballAnalysis.asOf`;
- `FootballAnalysis.readings`.

Profile dependency : none inside `FootballAnalyzer`.  
Market dependency : none inside `FootballAnalyzer`.  
Opportunity dependency : none inside `FootballAnalyzer`.

Produced readings observed :

```text
balanced_hierarchy
ranking_superiority
structural_level_gap
positive_streak
negative_streak
improving_form
declining_form
strong_home_team
weak_away_team
home_away_mismatch
prolific_attack
scoring_difficulty
solid_defense
fragile_defense
frequent_clean_sheet
open_match_profile
frequent_over_25
closed_match_profile
frequent_under_25
insufficient_data
post_match_xg_rejected
high_xg_creation
low_xg_creation
high_xg_conceded
offensive_underperformance
offensive_overperformance
defensive_overperformance
defensive_underperformance
misleading_result
conflicting_signals
```

Boundary recommendation :

- do not hide `DynamicTierAlgorithmV1` inside `FootballAnalyzer`;
- create a standalone structural championship module;
- feed `FootballAnalyzer` a `MatchStructuralRelation` or a richer match intelligence context for hierarchy readings only.

## 14. Current Hierarchy Readings Audit

Current producer : `FootballAnalyzer._hierarchyReadings`.

| Reading | Current rule | Current evidence | Future `tier-v1` producer | Migration action |
|---|---|---|---|---|
| `balanced_hierarchy` | `rankGap <= 2 && pointsGap <= 4` | raw ranks/points | `structuralBoundaryGap = 0` and rank/points closeness from locked algorithm | Replace fixed thresholds with `MatchStructuralRelation` + `typicalGap`. |
| `ranking_superiority` | `rankGap >= 3 || pointsGap >= 5`, subject is better official rank | raw ranks/points | factual hierarchy reading can remain independent of Tier | Preserve, but wording should avoid structural superiority. |
| `structural_level_gap` | `rankGap >= 5 || pointsGap >= 8`, subject is better official rank | raw ranks/points | better rank plus one STRONG counted boundary or at least two counted boundaries | Replace raw threshold producer with Tier-derived producer. |

Critical finding : current `structural_level_gap` can be triggered by raw rank or raw points alone. This conflicts with the locked algorithm.

## 15. Expected Domination Audit

Current V2 producer : `OpportunityEngineV2._expectedDomination`.

Current logic :

```text
for home/away:
  supporting = structural_level_gap
             + ranking_superiority
             + positive_streak
             + venue strength/weakness ids
             + home_away_mismatch
  if supporting.length >= 3
  and any structural_level_gap:
    produce expected_domination
```

Current Tier gate : `MISSING`.

Bypass risk :

- raw `structural_level_gap` can satisfy the current core condition;
- `sameTier` is unknown to the engine;
- `ranking_superiority` and points gap currently help support domination even without structural boundary context.

Required future gate location :

- before support count and before `structural_level_gap` can count for `expected_domination`;
- in the future `ThesisAssessment` / candidate gate layer, or as the first branch inside `_expectedDomination` during transitional implementation;
- failed result must be `NOT_ELIGIBLE` with `failedGate = EG_EXPECTED_DOMINATION_TIER_GAP`, not contradiction.

## 16. User Profile Intervention Audit

Current profile intervention points :

- `MatchFeedRepository.opportunitiesFor(profile)` compiles profile before opportunities.
- `MatchInsightEngine.opportunities` calls V2 first; fallback batch only runs if V2 returns no opportunities.
- `OpportunityEngineV2.opportunities` returns empty for incomplete profile and filters competitions before `analyzeOpportunity`.
- `OpportunityEngineV2.analyzeOpportunity` returns null if profile incomplete or competition disabled.
- V2 filters candidates with `profile.isThesisAllowed(candidate.id)` before selection.
- `_compatibleMarkets` and `PickEngine` filter markets by profile.

Classification : `ARCHITECTURE_MISMATCH`.

Target :

```text
match feed
-> exhaustive Match Intelligence
-> all readings and thesis assessments
-> user matching / profile filters
-> opportunity presentation
-> pick eligibility
```

The profile should not prevent full Tier, reading or thesis evaluation.

## 17. Match Intelligence / Bundle Audit

Existing closest types :

- `MatchAnalysisData`: raw/normalized sports facts attached to `MatchBoardItem`;
- `FootballAnalysis`: readings for one fixture;
- `Opportunity`: selected opportunity with retained theses/readings;
- `MatchThesis`: presentation-level thesis payload.

No true `MatchAnalysisBundle` exists. Current V2 returns only one retained thesis per match. It does not preserve all canonical thesis assessments, failed gates, non-discriminating evidence or thesis-to-thesis relations.

Future recommendation :

- introduce `MatchAnalysisBundle` or equivalent after the Tier module is working;
- reference `ChampionshipTierSnapshot` by identity/version;
- embed the per-match `MatchStructuralRelation`;
- preserve all `FootballReading` and all `ThesisAssessment` before user matching.

## 18. Evidence Family Audit

Current code representation :

- `CopilotArgumentFamily.hierarchy` exists in `match_board_item.dart`;
- mappings in `FootballReading.toCopilotArgument`, `opportunity_decision_presenter.dart`, `match_detail_page.dart`, `app_components.dart`;
- `EF_HIERARCHY` is normative in `docs/lector_business_matrix_v2_1.md`, not an explicit domain enum.

Risk :

```text
ranking_superiority
+ raw points/rank facts
+ tierGap
+ structural_level_gap
```

could be counted as independent evidence if future work simply adds Tier artifacts as readings.

Required future dedupe/correlation point :

- thesis assessment layer, before support count;
- hierarchy artifacts must remain gate inputs/explanatory context;
- `structural_level_gap`, `ranking_superiority`, `balanced_hierarchy`, rank/points/tier facts must be grouped under one hierarchy lineage.

## 19. UI Integrity Audit

Confirmed hardcoded UI :

- `_showScenarioReadingsSheet` builds `_ScenarioReadingsSheet`.
- `_ScenarioReadingsSheet` always renders three cards:
  - `Ecart de niveau structurel`;
  - `Dynamique recente superieure`;
  - `Avantage domicile / faiblesse exterieure`.
- `_scenarioReadingCount` clamps evidence/signal count to 1..3 and does not drive the actual rendered cards.
- `ticket_generator_page.dart` has hardcoded generated ticket explanation IDs such as `home_strength`, `positive_form`, `xg_creation`, `open_match_confirmed`, `team_in_difficulty`, `probable_goal`.
- `ticket_generator_page.dart` also maps readings by label/id for display.

Classification :

- `UI_INTEGRITY_FOLLOW_UP`;
- `BLOCKS_CORRECT_ENGINE_EXPLAINABILITY` once Tier readings are exposed.

It does not block pure algorithm implementation, but must be fixed before claiming user-facing explanations are engine-faithful.

## 20. Existing Test Audit

| Test file | Scope protected | Reuse for Tier V1 | Expected impact |
|---|---|---|---|
| `test/backend/supabase_lot_2_api_football_server_test.dart` | raw API-Football cache contract | Reuse for timestamp/source provenance | Add checks for structural metadata only if migrations added. |
| `test/backend/supabase_lot_3a_snapshot_contract_test.dart` | immutable snapshot tables and payload keys | Reuse for pre-match snapshot guarantees | Future migration tests for Tier snapshots. |
| `test/backend/supabase_lot_3b_snapshot_builder_test.dart` | snapshot builder and raw payload composition | Reuse for retaining standings description | Add assertion that description is preserved in normalized/structural payload. |
| `test/features/matches/data/api_football_match_adapter_test.dart` | adapter standings/stats/xG mapping | Reuse for `TeamStandingSnapshot.description` and `leagueStandings` completeness | Must update when model adds structural fields. |
| `test/features/matches/domain/football_analyzer_test.dart` | current readings and xG temporal safety | Reuse for hierarchy migration regression | Existing `structural_level_gap` expectations will change. |
| `test/features/matches/domain/opportunity_engine_v2_test.dart` | one V2 opportunity, profile gating, market mapping | Reuse for expected_domination gate tests | Existing domination fixture may need Tier relation. |
| `test/features/matches/domain/match_insight_engine_test.dart` | legacy fallback scenarios | Reuse as compatibility guard | May remain unchanged if V2 path becomes authoritative. |
| `test/features/matches/presentation/opportunity_decision_presenter_test.dart` | reading copy mapping | Reuse for hierarchy copy nuance | Update copy after Tier-derived structural gap. |
| `test/features/matches/presentation/matches_home_page_test.dart` | presentation behavior | Reuse for no hardcoded structural text regressions | UI follow-up. |
| `test/features/tickets/domain/ticket_generator_test.dart` | ticket generation evidence snapshots | Reuse for display ID stability | Generated explanation IDs may need alignment. |

## 21. Dynamic Tier Target Integration

Target integration sequence :

```text
ApiFootballMatchAdapter / snapshot payload
-> normalized league standings + structural metadata
-> Structural Championship module
-> ChampionshipTierSnapshot
-> MatchStructuralRelation
-> FootballAnalyzer hierarchy readings
-> ThesisAssessment gates/supports
-> Opportunity/user matching
```

The Tier System should be computed per `competitionId + season + analysisAsOf + tierSystemVersion + canonicalStandingsStateHash`, then reused for all matches from that competition snapshot.

## 22. MatchStructuralRelation Design Recommendation

Recommended object :

```text
MatchStructuralRelation
  competitionId
  season
  analysisAsOf
  tierSystemVersion
  standingsSnapshotIdentity
  homeTeamId
  awayTeamId
  homeTeamTier
  awayTeamTier
  sameTier
  ordinalTierGap
  structuralBoundaryGap
  boundariesBetweenTeams[]
  maturity
  warnings[]
```

Recommendation : pass `MatchStructuralRelation` to match analysis rather than exposing the full `ChampionshipTierSnapshot` to every thesis producer. The full snapshot remains reusable/debuggable at championship level; the relation is the match-level contract.

## 23. Backend vs Client Placement

| Option | Correction | Simplicity | Cost | Temporal integrity | Traceability | Verdict |
|---|---|---|---|---|---|---|
| A. Compute per match in client | Medium | High | Repeats work | Depends on payload | Weak | Not recommended beyond temporary tests. |
| B. Compute once per league in client memory | Good | Medium | Low | Good if snapshot-safe | Medium | Good first integration step. |
| C. Compute and cache/persist backend | Very good | Medium | Low per user | Strong | Strong | Recommended target. |
| D. Precompute in ingestion job | Very good | Medium/High | Efficient | Strong | Strong | Best long-term once stable. |

Recommendation :

- Phase implementation with pure Dart domain logic first.
- Run once per league snapshot in the repository/application layer for initial integration.
- Add backend persistence/cache once output contract stabilizes.
- Long-term, precompute during snapshot build or immediately after it, using the same deterministic contract.

## 24. Persistence / Cache Recommendation

Recommended strategy :

```text
Phase 1-4: EPHEMERAL per feed load / in-memory map
Phase 9: CACHED/PERSISTED championship_tier_snapshots
Long-term: PRECOMPUTED from snapshot builder or scheduled job
```

Cache key/invalidation :

```text
competitionId
season
analysisAsOf
tierSystemVersion
canonicalStandingsStateHash
anchorMetadataVersion
competitionFormatVersion
```

Invalidate when :

- standings rows change;
- points/rank/played change;
- anchor metadata changes;
- competition format metadata changes;
- `tierSystemVersion` changes.

Do not use a duration-only cache.

## 25. Versioning Recommendation

Existing versioning :

- `match_feed_snapshots.schema_version`;
- snapshot payload `schema_version`;
- `CompiledDecisionProfile.currentSchemaVersion`;
- `OnboardingQuestionnaire.version`;
- ticket schema versions.

Required future additions :

- `tierSystemVersion = tier-v1` in `ChampionshipTierSnapshot`;
- structural metadata versions for anchor and competition format;
- optional `engineVersion` when Match Intelligence bundle is formalized;
- persisted Tier rows must be traceable to algorithm version and input hash.

## 26. Error / Warning Taxonomy

V1 required statuses/warnings :

```text
TIER_UNAVAILABLE_NO_STANDINGS
TIER_UNAVAILABLE_INCOMPLETE_STANDINGS
TIER_UNAVAILABLE_UNSUPPORTED_FORMAT
TIER_UNAVAILABLE_TEAM_COUNT_OUT_OF_RANGE
TIER_UNAVAILABLE_MISSING_ANCHOR_METADATA
TIER_IMMATURE_EARLY_SEASON
TIER_IMMATURE_MIN_PLAYED
TIER_IMMATURE_PLAYED_IMBALANCE
TIER_WARNING_PLAYED_IMBALANCE
TIER_WARNING_PPG_QUALIFICATION_USED
TIER_WARNING_PPG_BOUNDARY_REJECTED
TIER_WARNING_PPG_BOUNDARY_DOWNGRADED
TIER_WARNING_ANCHOR_INTERNAL_OUTLIER
TIER_WARNING_MISSING_DESCRIPTION
TIER_WARNING_PARTIAL_ANCHOR_METADATA
TIER_WARNING_PENDING_MODERATE_BOUNDARY
TIER_WARNING_BOUNDARY_PERSISTED
```

Future/non-V1 :

```text
TIER_WARNING_MATURE_WITH_WARNING
TIER_UNAVAILABLE_SPLIT_PHASE_UNMODELED
TIER_UNAVAILABLE_CONFERENCE_LOGIC_UNMODELED
```

## 27. Implementation Gaps Table

| Gap | Current code | Locked target | Severity | Required change | Blocks V1 |
|---|---|---|---|---|---|
| No Tier domain types | No `ChampionshipTierSnapshot` or related types | Explicit tier-v1 contract | CRITICAL | Add pure domain contracts | Yes, during implementation |
| `description` not normalized | `TeamStandingSnapshot` lacks field | Hybrid anchors can use retained API descriptions | HIGH | Retain field in adapter/model | Yes, for API-description fallback |
| Anchor metadata missing | Competition catalog has ids only | reliable metadata/override first | CRITICAL | Add structural competition metadata | Yes, during Phase 1 |
| Competition format missing | No reliable standard/split/playoff flag | abstain unsupported V1 formats | CRITICAL | Add format metadata/version | Yes, during Phase 1 |
| No standings identity | Feed snapshot identity only | canonical structural hash | CRITICAL | Add identity builder | Yes, before temporal stability |
| No previous boundary state | No Tier persistence/cache | temporal confirmation/persistence | HIGH | Add state contract/cache/persistence | Required for temporal behavior |
| `structural_level_gap` raw producer | rankGap >= 5 or pointsGap >= 8 | Tier-derived confirmed separation | CRITICAL | Migrate hierarchy producer | Yes, before engine exposure |
| `balanced_hierarchy` fixed producer | rank <=2 and points <=4 | structuralBoundaryGap 0 plus relative closeness | HIGH | Migrate hierarchy producer | Yes, before engine exposure |
| `expected_domination` lacks Tier Gate | support count + raw structural reading | sameTier blocks with gate failure | CRITICAL | Add gate assessment before supports | Yes, before behavior exposure |
| Profile filters before full analysis | V2 returns null before analyzer on disabled/incomplete profile | exhaustive Match Intelligence first | HIGH | Separate intelligence from matching | Required for target architecture |
| One retained V2 thesis | V2 returns one selected thesis | all canonical thesis assessments preserved | HIGH | Add assessment bundle | Required for full Business Matrix target |
| EF correlation not explicit | `CopilotArgumentFamily.hierarchy` only | no hierarchy double counting | HIGH | Add evidence family/dedupe in thesis layer | Required before support counts rely on Tier |
| UI hardcoded reading cards | fixed three-card sheet | engine-faithful readings | MEDIUM | UI reads actual readings/relations | Before final UX |
| Missing `strong_away_team` / `weak_home_team` producers | consumed/mapped but not produced | symmetric context readings | MEDIUM | Follow-up engine work | No, not Tier-specific |
| DateTime fallbacks | analyzer/adapter fall back to now | explicit pre-match asOf for Tier | HIGH | Require asOf in Tier path | Yes for temporal correctness |

## 28. Migration Risks

| Risk | Cause | Expected effect | Mitigation | Test required |
|---|---|---|---|---|
| Fewer `expected_domination` opportunities | same Tier gate and stricter `structural_level_gap` | feed count/ranking changes | shadow mode and targeted regression | V2 integration tests |
| Existing tests fail on structural gap | current fixtures expect raw `structural_level_gap` | unit failures | update tests with explicit MatchStructuralRelation | analyzer tests |
| Anchor metadata incomplete | many runtime leagues lack rules | `UNAVAILABLE` rate high | start with explicit supported league subset | metadata tests |
| UI says structural gap when none exists | hardcoded reading sheet | misleading explanations | UI follow-up after engine migration | widget tests |
| Snapshot reruns advance temporal confirmation | no structural hash | false confirmation | canonical identity + state tests | temporal unit tests |
| API description parser overfits | provider strings vary | wrong anchors | metadata-first resolver, warnings | adapter/data tests |
| Backend/client divergence | duplicate logic in TS/Dart | inconsistent tiers | pure domain source of truth or generated fixtures | golden tests |
| Persistence schema churn | algorithm output evolves | migration complexity | start ephemeral, persist after stable contract | migration tests |

## 29. Future File Change Map

| Path | Current responsibility | Future change | Why | Risk | Phase |
|---|---|---|---|---|---|
| `lib/features/matches/domain/match_board_item.dart` | normalized match/standing models | add standing description or structural metadata references | retain API anchor hints and relation | serialization ripple | Phase 1/5 |
| `lib/features/matches/data/api_football_match_adapter.dart` | snapshot adapter | map `description`, expose league structural context | preserve source data | adapter tests need updates | Phase 1 |
| `lib/features/onboarding/domain/decision_profile_catalogs.dart` or new config | competition ids | do not overload onboarding catalog; maybe reference structural metadata separately | avoid profile coupling | coupling risk | Phase 1 |
| `lib/features/matches/data/match_feed_repository.dart` | repository and profile entry | compute/reuse tier snapshots before per-match analysis | shared computation | behavior changes | Phase 4/8 |
| `lib/features/matches/data/supabase_match_feed_snapshot_repository.dart` | load/merge snapshots | preserve source/as_of metadata for structural identity | temporal identity | merge semantics | Phase 3/9 |
| `lib/features/matches/domain/football_analyzer.dart` | readings | consume `MatchStructuralRelation` for hierarchy readings | locked producers | breaking tests | Phase 6 |
| `lib/features/matches/domain/opportunity_engine_v2.dart` | V2 thesis selection | add Tier Gate, later assessments | Business Matrix compliance | opportunity count changes | Phase 7/8 |
| `lib/features/matches/domain/match_insight_engine.dart` | V2/legacy orchestration | move toward exhaustive intelligence then matching | profile boundary | fallback interactions | Phase 8 |
| `lib/features/opportunities/domain/opportunity.dart` | selected opportunity payload | reference readings/assessments/relation as needed | explanation traceability | API shape | Phase 8 |
| `lib/features/matches/presentation/match_detail_page.dart` | detail UI | replace hardcoded reading cards with engine data | UI integrity | widget churn | Phase 10 |
| `lib/features/matches/presentation/opportunity_decision_presenter.dart` | reading copy | update hierarchy copy semantics | avoid overclaiming | copy snapshots | Phase 10 |
| `lib/features/tickets/presentation/ticket_generator_page.dart` | ticket UI/generator display | align generated explanation ids with engine readings | consistency | saved ticket display | Phase 10 |
| `supabase/functions/build-match-feed-snapshot/index.ts` | snapshot build | optional precompute/persist Tier | backend cache target | TS/Dart parity | Phase 9 |
| `supabase/migrations/*` | schema | add structural metadata/tier snapshot tables | persistence | migration risk | Phase 1/9 |

## 30. Future New Files

| Suggested path | Purpose | Layer | Persisted? | Serialized? | Public contract? |
|---|---|---|---|---|---|
| `lib/features/matches/domain/structural_tiers/tier_models.dart` | `TierLabel`, `TierMaturity`, `BoundaryStrength`, snapshot/relation contracts | domain | no | yes | yes |
| `lib/features/matches/domain/structural_tiers/dynamic_tier_algorithm_v1.dart` | pure algorithm | domain | no | no | internal/public domain |
| `lib/features/matches/domain/structural_tiers/tier_parameters.dart` | locked constants | domain | no | no | internal |
| `lib/features/matches/domain/structural_tiers/standings_snapshot_identity.dart` | canonical hash/identity | domain | no | yes | yes |
| `lib/features/matches/domain/structural_tiers/competition_structural_metadata.dart` | anchor/format contract | domain/config | possible | yes | yes |
| `lib/features/matches/data/competition_structural_metadata_repository.dart` | metadata source | data | possible | yes | no |
| `lib/features/matches/data/championship_tier_snapshot_cache.dart` | in-memory/cache bridge | data | optional | yes | no |
| `test/features/matches/domain/structural_tiers/dynamic_tier_algorithm_v1_test.dart` | pure algorithm tests | test | n/a | n/a | n/a |
| `test/features/matches/domain/structural_tiers/standings_snapshot_identity_test.dart` | same-snapshot rerun protection | test | n/a | n/a | n/a |
| `test/features/matches/integration/dynamic_tier_match_intelligence_test.dart` | standings -> relation -> readings/gates | test | n/a | n/a | n/a |
| `supabase/migrations/*_championship_tier_snapshots.sql` | future persisted snapshots | DB | yes | yes | yes |

## 31. Future Test Plan

Unit tests - pure math :

- median;
- MAD;
- IQR fallback;
- MAD zero fallback;
- `typicalGap`;
- `robustZ`;
- `gapRatio`;
- candidate detection;
- segmentation gain;
- boundary score;
- BoundaryStrength;
- PPG qualification reject/downgrade/survival;
- maturity;
- partition quality and epsilon.

Unit tests - temporal :

- same snapshot rerun does not confirm MODERATE;
- two distinct compatible MODERATE snapshots confirm;
- STRONG confirms immediately;
- one-snapshot persistence;
- expiry;
- compatible boundary drift;
- equal-points and PPG rejection guard persistence.

Unit tests - Tier assignment :

- no middle boundary;
- one middle boundary;
- two middle boundaries;
- missing labels;
- more confirmed structural boundaries than Tier partitions;
- anchor without strong adjacent boundary;
- equal-points blocks.

Integration tests :

- API standings -> normalized structural input;
- snapshot metadata -> `standingsSnapshotIdentity`;
- snapshot -> `ChampionshipTierSnapshot`;
- snapshot -> `MatchStructuralRelation`;
- relation -> hierarchy readings;
- relation -> `expected_domination` gate failure.

Regression tests :

- KR Reykjavik vs Vikingur;
- compact league;
- stretched league;
- equal points;
- games-in-hand;
- unsupported format abstention.

## 32. Shadow Validation Recommendation

Recommendation : use shadow mode before user-visible cutover.

Shadow mode behavior :

```text
run legacy hierarchy readings
run tier-v1 structural module
compare outputs
do not expose tier-v1 decisions until validated
do not calibrate tier-v1 against betting outcome or match result
```

Useful metrics :

- number of matches with legacy `structural_level_gap`;
- number of matches with tier-v1 `structural_level_gap`;
- number of sameTier `expected_domination` blocks;
- boundary count by league;
- immature/unavailable rate;
- PPG qualification frequency;
- Tier distribution by league;
- confirmed vs tier partition boundary count;
- hardcoded UI divergence count.

Forbidden metrics :

- winning bets;
- match outcomes;
- prediction accuracy;
- profitability.

## 33. Implementation Phases

| Phase | Goal | Files likely modified | Tests | Rollback boundary |
|---|---|---|---|---|
| 1. Data contract | retain `description`, add structural competition metadata | adapter/model/config/migration if persisted | adapter + backend contract | Revert metadata fields only |
| 2. Pure Tier domain algorithm | implement `DynamicTierAlgorithmV1` | new domain files | pure math/unit battery | Isolated module |
| 3. Snapshot identity / temporal state | add canonical hash and previous boundary contract | new identity/cache files | temporal unit tests | Disable temporal state |
| 4. ChampionshipTierSnapshot integration | compute once per league snapshot | repository/application layer | integration tests | Feature flag off |
| 5. MatchStructuralRelation | derive per-match relation | domain + match analysis data | relation tests | Remove relation injection |
| 6. Hierarchy readings migration | replace hierarchy producers | `football_analyzer.dart` | analyzer tests | Restore legacy producer behind flag |
| 7. expected_domination gate | add Tier Gate | opportunity/thesis layer | V2 tests | Gate flag off |
| 8. Match Intelligence pipeline placement | separate exhaustive analysis from user matching | engine/repository/opportunity | integration tests | Keep old opportunities path |
| 9. persistence/cache | optional persisted snapshots and boundary state | Supabase + data repositories | migration/backend tests | fall back to in-memory |
| 10. UI integrity | remove hardcoded reading explanations | presentation files | widget/copy tests | display old sheet behind flag |
| 11. regression validation | shadow compare and KR/Vikingur battery | tests/docs/diagnostics | full suite | hold rollout |

## 34. Proposed Commit Sequence

1. Retain standings structural metadata.
2. Add competition structural metadata contracts.
3. Add Tier domain contracts and `tier-v1` parameters.
4. Implement pure `DynamicTierAlgorithmV1`.
5. Add standings snapshot identity and temporal state contract.
6. Integrate `ChampionshipTierSnapshot` computation per league snapshot.
7. Add `MatchStructuralRelation`.
8. Migrate hierarchy readings to structural relation.
9. Add `expected_domination` Tier Gate.
10. Split exhaustive Match Intelligence from user matching.
11. Add persistence/cache for Tier snapshots.
12. Replace hardcoded reading UI with engine-backed display.
13. Add shadow validation diagnostics.
14. Add KR/Vikingur and synthetic regression suite.

## 35. Implementation Blockers

`BLOCKING_BEFORE_CODE` :

- NONE.

`BLOCKING_DURING_IMPLEMENTATION` :

- add/retain anchor metadata;
- add competition format metadata;
- add `standingsSnapshotIdentity`;
- implement temporal boundary state;
- migrate hierarchy readings before exposing Tier-derived decisions;
- add `expected_domination` Tier Gate before production exposure.

`NON_BLOCKING` :

- UI hardcoded readings for pure algorithm phases;
- backend persistence if initial integration is in-memory;
- ticket explanation cleanup before final UX.

`FUTURE` :

- atypical competition V2 support;
- possible `MATURE_WITH_WARNING`;
- richer presentation of every confirmed structural boundary.

## 36. Non-Blocking Follow-Ups

- Symmetric home/away context readings: `strong_away_team` and `weak_home_team` are consumed/mapped but not produced.
- `attack_in_form`, `declining_defense`, `frequent_btts` remain presentation/mapping IDs without active producers.
- Legacy fallback theses should be retired or isolated after all canonical V2 assessments exist.
- UI should expose actual `FootballReading` and `MatchStructuralRelation` rather than reconstructing narrative cards.
- Admin/debug surface should expose Tier diagnostics after implementation.

## 37. Repository-Specific Target Architecture

Recommended architecture :

```text
supabase/functions/api-football-sync/index.ts
        ->
api_football_cached_responses
        ->
supabase/functions/build-match-feed-snapshot/index.ts
        ->
match_feed_snapshots.payload.raw.standings
        ->
ApiFootballMatchAdapter
        ->
MatchAnalysisData.leagueStandings + retained standing descriptions
        ->
lib/features/matches/domain/structural_tiers/
        ->
ChampionshipTierSnapshot
        ->
MatchStructuralRelation
        ->
FootballAnalyzer
        ->
FootballReadings
        ->
ThesisAssessment / OpportunityEngineV2 gates
        ->
Opportunity
        ->
PickEngine / presentation
```

Placement rules :

- Structural Tier module belongs in domain and must be pure.
- Data repositories provide raw/normalized standings, metadata and optional persisted snapshots.
- User profile remains outside Tier construction.
- UI consumes results after engine computation only.

## 38. Readiness Checklist

| Criterion | Status | Notes |
|---|---|---|
| Full standings obtainable | READY | `raw.standings` and `leagueStandings` exist. |
| rank available | READY | `TeamStandingSnapshot.rank`. |
| points available | READY | `TeamStandingSnapshot.points`. |
| played available | READY | `TeamStandingSnapshot.played`. |
| descriptions obtainable | READY_WITH_IMPLEMENTATION | raw payload has them; normalized model drops them. |
| anchor path clear | READY_WITH_IMPLEMENTATION | add metadata/override, API description fallback. |
| competition format path clear | READY_WITH_IMPLEMENTATION | add metadata/version. |
| analysisAsOf available | PARTIAL_READY | snapshot `captured_at/as_of`; remove `now` fallback from Tier path. |
| standings identity feasible | READY_WITH_IMPLEMENTATION | canonical hash from normalized fields. |
| same-snapshot rerun protection feasible | READY_WITH_IMPLEMENTATION | requires identity + temporal state. |
| pure algorithm implementable | READY | locked constants and rules exist. |
| MatchStructuralRelation path clear | READY | can derive from snapshot + home/away ranks. |
| hierarchy migration path clear | READY | producers localized in `FootballAnalyzer`. |
| expected_domination gate path clear | READY | localized in V2 candidate path, later assessment layer. |
| tests can be added | READY | existing suite patterns are good. |
| no product blocker found | READY | remaining work is implementation. |

## 39. Final Recommendation

Lector is ready to start phased implementation of `DynamicTierAlgorithmV1`.

Recommended first implementation target :

```text
Phase 1 - Data contract
```

Specifically :

- retain `standings[].description`;
- introduce structural competition metadata with format/anchor versions;
- define the future input object for the pure Tier module;
- add tests proving no runtime behavior changes beyond data retention.

Final verdict :

```text
DYNAMIC TIER IMPLEMENTATION READY - PROCEED TO PHASED IMPLEMENTATION
```
