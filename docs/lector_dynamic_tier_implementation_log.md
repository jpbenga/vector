# Lector - Dynamic Tier Implementation Log

Date : 2026-09-02  
Scope : Dynamic Tier implementation tracking.

## Phase 1 - Data Contract

Status : `IMPLEMENTED`

Implemented :

- retained API-Football standing `description` in `TeamStandingSnapshot`;
- mapped raw `standings[].description` in `ApiFootballMatchAdapter`;
- added pure structural metadata contracts for competition format, support status, anchors, anchor source, description mappings and metadata versions;
- added a minimal explicit static structural metadata catalog;
- added `DynamicTierInput` and `DynamicTierInputBuilder`;
- added validation for explicit `analysisAsOf`, required standings fields and required structural metadata;
- added tests for description retention, metadata contracts, input builder validation and analyzer non-regression.

Deliberately not implemented in Phase 1 :

- no Dynamic Tier algorithm math;
- no `ChampionshipTierSnapshot`;
- no `MatchStructuralRelation`;
- no hierarchy reading migration;
- no `expected_domination` Tier Gate;
- no temporal boundary persistence;
- no UI changes;
- no changes to locked normative documents.

Next recommended phase :

```text
Phase 2 - Pure Tier domain algorithm
```

## Phase 2 - Pure Tier Domain Algorithm

Status : `IMPLEMENTED`

Files changed :

- `lib/features/matches/domain/structural_tiers/tier_parameters.dart`
- `lib/features/matches/domain/structural_tiers/tier_models.dart`
- `lib/features/matches/domain/structural_tiers/tier_input.dart`
- `lib/features/matches/domain/structural_tiers/dynamic_tier_algorithm_v1.dart`
- `test/features/matches/domain/structural_tiers/dynamic_tier_algorithm_v1_test.dart`

Algorithm components implemented :

- locked `tier-v1` parameter registry;
- pure `DynamicTierAlgorithmV1`;
- maturity / unavailable / mature status handling;
- official-rank ordered point distribution;
- adjacent point gaps;
- deterministic median, MAD, IQR and MAD-zero fallback robust scale;
- candidate boundary detection;
- segmentation validation;
- boundary evidence score;
- PPG qualification, rejection and downgrade;
- `BoundaryStrength`;
- spatial confirmation;
- MODERATE temporal confirmation using distinct standings snapshot identities;
- STRONG immediate confirmation;
- one-snapshot boundary persistence with guardrails;
- complete `confirmedStructuralBoundaries[]`;
- global `tierPartitionBoundaries[]` selection capped at two;
- Tier assignment with missing intermediate labels allowed;
- `ordinalTierGap`;
- `structuralBoundaryGap`;
- pure structural helpers for future `structural_level_gap` and `balanced_hierarchy`.

Tests added :

- pure math and robust statistics tests;
- numeric threshold edge tests;
- PPG threshold and survival tests;
- maturity and unavailable tests;
- temporal confirmation and persistence tests;
- partition adversarial tests;
- 26-case synthetic championship battery;
- KR/Vikingur same-Tier structural regression;
- invariant tests for confirmed boundaries, partition subset and unique assignments.

Deliberately not implemented in Phase 2 :

- no repository/feed integration;
- no `FootballAnalyzer` hierarchy migration;
- no `OpportunityEngineV2` gate;
- no user profile flow changes;
- no UI changes;
- no Supabase persistence or migrations;
- no backend snapshot builder changes.

Remaining Phase 3 work :

- wire explicit `standingsSnapshotIdentity` / canonical hash at repository or application boundary;
- provide real previous boundary state storage/cache;
- compute `DynamicTierAlgorithmV1` once per league snapshot in memory;
- keep integration behind the next phase boundary.

Next recommended phase :

```text
Phase 3 - Snapshot identity / temporal state wiring
```

## Phase 3 - Snapshot Identity / Temporal State

Status : `IMPLEMENTED`

Identity strategy :

- added deterministic canonical structural serialization for standings;
- added `canonicalStandingsStateHash` using SHA-256 over canonical UTF-8 data;
- added `StandingsSnapshotIdentity` value object;
- included competition id, season, ordered standings rows, `tierSystemVersion`, `anchorMetadataVersion` and `competitionFormatVersion`;
- excluded volatile timestamps, UI state, profile, match id, odds, xG, form, team names and provider insertion order;
- excluded retained standing `description` from the hash by default because Phase 1 anchors are explicit metadata-only;
- allowed `description` to enter the hash only when structural description mappings are actually consumed.

Temporal provenance :

- added `StructuralSnapshotProvenance`;
- traced `analysisAsOf`, `sourceAsOf`, `sourceFetchedAt` and provider snapshot version;
- added source metadata extraction from the current snapshot payload shape;
- rejected source snapshots where `sourceAsOf > analysisAsOf`.

State store :

- added injectable `ChampionshipTierTemporalStateStore`;
- added in-memory implementation for Phase 3;
- keyed temporal lineage by competition, season, `tierSystemVersion`, anchor metadata version and competition format version;
- deliberately excluded current structural hash from the temporal lineage key;
- preserved previous `PreviousBoundaryState` contracts from Phase 2.

Service :

- added `ChampionshipTierSnapshotEngine` as a thin orchestration layer;
- builds structural identity;
- reads previous temporal state;
- runs `DynamicTierAlgorithmV1`;
- stores next boundary state;
- keeps a separate current-result cache keyed by structural identity.

Tests :

- canonical hash determinism;
- unordered row stability;
- rank / points / played hash invalidation;
- metadata and tier version invalidation;
- volatile timestamp exclusion;
- optional description hash inclusion;
- same-snapshot MODERATE rerun remains pending;
- distinct compatible MODERATE snapshot confirms;
- multiple same-league reads do not advance temporal age;
- STRONG boundary still confirms immediately;
- pre-match source safety rejection;
- real snapshot payload shape through adapter to structural identity.

Deliberately not implemented in Phase 3 :

- no `FootballAnalyzer` integration;
- no `MatchStructuralRelation`;
- no hierarchy readings migration;
- no `expected_domination` Tier Gate;
- no profile flow refactor;
- no UI changes;
- no Supabase Tier persistence.

Remaining Phase 4 work :

- compute `ChampionshipTierSnapshot` once per real league snapshot in the feed/application layer;
- attach the Phase 3 engine to the repository boundary without exposing readings yet;
- preserve feature-flag or shadow-mode isolation before Phase 5 relation work.

## Final Engine Integration

Status : `IMPLEMENTED_FOR_PRODUCT_VALIDATION`

Implemented :

- connected `ChampionshipTierSnapshotEngine` to `SnapshotMatchFeedRepository`;
- computed Tier snapshots once per `competitionId + season` feed snapshot and reused them across matches;
- added `MatchStructuralRelation` as the match-level structural contract;
- attached `MatchStructuralRelation` to `MatchAnalysisData`;
- migrated `balanced_hierarchy` to Tier-derived rank and points closeness with `structuralBoundaryGap = 0`;
- migrated `structural_level_gap` to confirmed-boundary semantics only;
- kept `ranking_superiority` factual and independent from structural superiority;
- added contextual symmetry readings `strong_away_team` and `weak_home_team`;
- added comparative `form_advantage`;
- made trajectory ordering distinguish same-aggregate forms such as `WWWLL` and `LLWWW`;
- added `ThesisAssessment` and `ThesisEvidenceRelation`;
- added full canonical thesis assessment before user/profile filtering;
- added `EG_EXPECTED_DOMINATION_TIER_GAP` as a hard same-Tier gate;
- classified opponent/context evidence as resistance rather than contradiction;
- preserved non-discriminating shared form evidence;
- deduplicated evidence families for thesis clarity scoring;
- kept multiple thesis assessments on selected `Opportunity`;
- removed hardcoded scenario reading cards from match detail sheet and rendered engine-backed arguments instead.

Deliberately not implemented :

- no database migration;
- no backend Tier persistence;
- no plugin/external service;
- no new UI explanation DSL;
- no changes to locked normative documents.

Validation :

- `flutter analyze` passes;
- `flutter test` passes.

## Feed Reliability Fix - Daily Proposals

Status : `IMPLEMENTED`

Problem :

- the generated Supabase Cron previously scheduled `api-football-sync` and
  `build-match-feed-snapshot` as two separate jobs per league;
- the snapshot job ran only 3 minutes after collection start;
- with team statistics, recent form and xG, collection duration is data
  dependent, so the snapshot could be built from incomplete cache rows;
- this could leave the app with no usable proposals for the current day even
  though matches existed.

Implemented :

- `tool/generate_supabase_cron_sql.dart` now creates one cron job per league
  calling `daily-football-sync`;
- `daily-football-sync` remains the single orchestrator that calls
  `api-football-sync` first and `build-match-feed-snapshot` only after the
  collection response returns;
- generated run-now SQL follows the same orchestrated contract;
- backend guard tests reject the old fixed-delay snapshot scheduling pattern;
- operational docs now document the invariant explicitly.

Validation :

- `flutter analyze` passes;
- `flutter test test/backend/daily_football_sync_test.dart test/backend/backend_data_pipeline_guard_test.dart test/features/matches/data/match_feed_repository_test.dart test/features/matches/domain/opportunity_engine_v2_test.dart` passes.
