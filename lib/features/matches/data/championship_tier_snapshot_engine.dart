import '../domain/match_board_item.dart';
import '../domain/structural_tiers/competition_structural_metadata.dart';
import '../domain/structural_tiers/dynamic_tier_algorithm_v1.dart';
import '../domain/structural_tiers/standings_snapshot_identity.dart';
import '../domain/structural_tiers/tier_input.dart';
import '../domain/structural_tiers/tier_models.dart';
import 'championship_tier_temporal_state_store.dart';

enum ChampionshipTierSnapshotEngineError {
  invalidInput,
  sourceSnapshotAfterAnalysis,
}

class ChampionshipTierSnapshotEngineResult {
  const ChampionshipTierSnapshotEngineResult._({
    this.snapshot,
    this.identity,
    this.provenance,
    this.errors = const [],
    this.inputErrors = const [],
  });

  factory ChampionshipTierSnapshotEngineResult.success({
    required ChampionshipTierSnapshot snapshot,
    required StandingsSnapshotIdentity identity,
  }) {
    return ChampionshipTierSnapshotEngineResult._(
      snapshot: snapshot,
      identity: identity,
      provenance: identity.provenance,
    );
  }

  factory ChampionshipTierSnapshotEngineResult.failure({
    required Iterable<ChampionshipTierSnapshotEngineError> errors,
    Iterable<DynamicTierInputBuildError> inputErrors = const [],
    StandingsSnapshotIdentity? identity,
    StructuralSnapshotProvenance? provenance,
  }) {
    return ChampionshipTierSnapshotEngineResult._(
      identity: identity,
      provenance: provenance ?? identity?.provenance,
      errors: List.unmodifiable(errors),
      inputErrors: List.unmodifiable(inputErrors),
    );
  }

  final ChampionshipTierSnapshot? snapshot;
  final StandingsSnapshotIdentity? identity;
  final StructuralSnapshotProvenance? provenance;
  final List<ChampionshipTierSnapshotEngineError> errors;
  final List<DynamicTierInputBuildError> inputErrors;

  bool get isSuccess => snapshot != null && errors.isEmpty;
}

class ChampionshipTierSnapshotEngine {
  ChampionshipTierSnapshotEngine({
    required ChampionshipTierTemporalStateStore temporalStateStore,
    DynamicTierAlgorithmV1 algorithm = const DynamicTierAlgorithmV1(),
    DynamicTierInputBuilder inputBuilder = const DynamicTierInputBuilder(),
    StandingsSnapshotIdentityBuilder identityBuilder =
        const StandingsSnapshotIdentityBuilder(),
  }) : this._(temporalStateStore, algorithm, inputBuilder, identityBuilder);

  ChampionshipTierSnapshotEngine._(
    this._temporalStateStore,
    this._algorithm,
    this._inputBuilder,
    this._identityBuilder,
  );

  final ChampionshipTierTemporalStateStore _temporalStateStore;
  final DynamicTierAlgorithmV1 _algorithm;
  final DynamicTierInputBuilder _inputBuilder;
  final StandingsSnapshotIdentityBuilder _identityBuilder;
  final Map<String, ChampionshipTierSnapshot> _resultCache = {};

  ChampionshipTierSnapshotEngineResult buildSnapshot({
    required String competitionId,
    required int season,
    required DateTime? analysisAsOf,
    required List<TeamStandingSnapshot> leagueStandings,
    required CompetitionStructuralMetadata? metadata,
    double? seasonProgress,
    DynamicTierSourceMetadata sourceMetadata =
        const DynamicTierSourceMetadata(),
  }) {
    final draft = _inputBuilder.build(
      competitionId: competitionId,
      season: season,
      analysisAsOf: analysisAsOf,
      leagueStandings: leagueStandings,
      metadata: metadata,
      standingsSnapshotIdentity: 'pending-standings-snapshot-identity',
      seasonProgress: seasonProgress,
      sourceMetadata: sourceMetadata,
    );
    if (!draft.isValid) {
      return ChampionshipTierSnapshotEngineResult.failure(
        errors: _engineErrorsFor(draft.errors),
        inputErrors: draft.errors,
      );
    }

    final draftInput = draft.input!;
    final identity = _identityBuilder.build(
      competitionId: competitionId,
      season: season,
      analysisAsOf: draftInput.analysisAsOf,
      standingsRows: draftInput.standingsRows,
      tierSystemVersion: DynamicTierAlgorithmV1.tierSystemVersion,
      anchorMetadataVersion: draftInput.anchorMetadataVersion,
      competitionFormatVersion: draftInput.competitionFormatVersion,
      sourceMetadata: sourceMetadata,
      includeDescriptionInHash: _descriptionIsStructurallyConsumed(metadata!),
    );
    if (!identity.provenance.isTemporalSafe) {
      return ChampionshipTierSnapshotEngineResult.failure(
        errors: const [
          ChampionshipTierSnapshotEngineError.sourceSnapshotAfterAnalysis,
        ],
        identity: identity,
      );
    }

    final cacheKey = ChampionshipTierSnapshotCacheKey(
      competitionId: competitionId,
      season: season,
      canonicalStandingsStateHash: identity.canonicalStandingsStateHash.value,
      tierSystemVersion: DynamicTierAlgorithmV1.tierSystemVersion,
      anchorMetadataVersion: draftInput.anchorMetadataVersion,
      competitionFormatVersion: draftInput.competitionFormatVersion,
    );
    final cached = _resultCache[cacheKey.value];
    if (cached != null) {
      return ChampionshipTierSnapshotEngineResult.success(
        snapshot: cached,
        identity: identity,
      );
    }

    final input = DynamicTierInput(
      competitionId: draftInput.competitionId,
      season: draftInput.season,
      analysisAsOf: draftInput.analysisAsOf,
      competitionFormat: draftInput.competitionFormat,
      standingsRows: draftInput.standingsRows,
      podiumAnchor: draftInput.podiumAnchor,
      relegationAnchor: draftInput.relegationAnchor,
      anchorMetadataVersion: draftInput.anchorMetadataVersion,
      competitionFormatVersion: draftInput.competitionFormatVersion,
      structuralMetadataVersion: draftInput.structuralMetadataVersion,
      standingsSnapshotIdentity: identity.value,
      seasonProgress: draftInput.seasonProgress,
      sourceMetadata: sourceMetadata,
    );
    final previousState =
        _temporalStateStore.read(identity.lineageKey) ??
        PreviousBoundaryState.empty;
    final snapshot = _algorithm.buildSnapshot(
      input,
      previousState: previousState,
    );
    _temporalStateStore.write(
      identity.lineageKey,
      snapshot.toPreviousBoundaryState(),
    );
    _resultCache[cacheKey.value] = snapshot;

    return ChampionshipTierSnapshotEngineResult.success(
      snapshot: snapshot,
      identity: identity,
    );
  }

  void clearResultCache() {
    _resultCache.clear();
  }

  static bool _descriptionIsStructurallyConsumed(
    CompetitionStructuralMetadata metadata,
  ) {
    return metadata.descriptionPolicy.mappings.isNotEmpty;
  }

  static List<ChampionshipTierSnapshotEngineError> _engineErrorsFor(
    List<DynamicTierInputBuildError> errors,
  ) {
    if (errors.contains(
      DynamicTierInputBuildError.sourceSnapshotAfterAnalysis,
    )) {
      return const [
        ChampionshipTierSnapshotEngineError.sourceSnapshotAfterAnalysis,
      ];
    }
    return const [ChampionshipTierSnapshotEngineError.invalidInput];
  }
}
