import '../domain/analysis_maturity.dart';
import '../domain/football_reading.dart';
import '../domain/football_scenario.dart';
import '../domain/match_board_item.dart';
import '../domain/structural_tiers/tier_models.dart';

/// Decodes the compact read model built by `analyze-match-feed-snapshot`.
///
/// It intentionally has no fallback to [FootballAnalyzer]: football inputs are
/// transformed in Supabase before the app receives this payload.
class ServerComputedMatchAnalysisAdapter {
  const ServerComputedMatchAnalysisAdapter();

  Map<String, ServerComputedMatchAnalysis> fromSnapshot(
    Map<String, Object?> snapshot,
  ) {
    final computed = _map(snapshot['computed']);
    final asOf =
        DateTime.tryParse(snapshot['captured_at']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final results = <String, ServerComputedMatchAnalysis>{};
    for (final item in _list(computed['fixtures'])) {
      final fixtureId = _integer(item['fixture_id']);
      if (fixtureId == null) continue;
      final readings = _readings(
        _list(item['readings']),
        fixtureId: fixtureId,
        asOf: asOf,
      );
      results['api-fixture-$fixtureId'] = ServerComputedMatchAnalysis(
        analysis: FootballAnalysis(
          fixtureId: 'api-fixture-$fixtureId',
          asOf: asOf,
          readings: readings,
          maturity: AnalysisMaturity.established,
        ),
        scenarios: _scenarios(
          _list(item['scenarios']),
          fixtureId: fixtureId,
          readings: readings,
        ),
        displayReadings: _displayReadings(
          _list(item['readings']),
          fixtureId: fixtureId,
        ),
        championshipTierSnapshot: _tierSnapshot(_map(item['tier_snapshot'])),
      );
    }
    return Map.unmodifiable(results);
  }

  List<FootballReading> _readings(
    List<Map<String, Object?>> rows, {
    required int fixtureId,
    required DateTime asOf,
  }) {
    return List.unmodifiable([
      for (final row in rows)
        FootballReading(
          id: row['id']?.toString() ?? 'unknown',
          subjectTeamId:
              row['subject_team_id']?.toString() ?? 'api-fixture-$fixtureId',
          subjectSide: _side(row['side']),
          subjectKind: _integer(row['player_id']) == null
              ? ReadingSubjectKind.team
              : ReadingSubjectKind.player,
          playerId: _integer(row['player_id']),
          playerName: row['player_name']?.toString() ?? _playerName(row),
          playerPhotoUrl: _playerPhotoUrl(row),
          status: ReadingStatus.detected,
          strength: _strength(row['strength']),
          isContradiction: _isContradiction(row),
          evidence: _evidence(_list(row['evidence'])),
          warnings: const [],
          asOf: asOf,
          sampleSize: _integer(row['sample_size']) ?? 0,
        ),
    ]);
  }

  List<FootballScenarioMatch> _scenarios(
    List<Map<String, Object?>> rows, {
    required int fixtureId,
    required List<FootballReading> readings,
  }) {
    return List.unmodifiable([
      for (final row in rows)
        FootballScenarioMatch(
          scenarioId: row['id']?.toString() ?? 'unknown',
          subjectTeamId:
              row['subject_team_id']?.toString() ?? 'api-fixture-$fixtureId',
          subjectSide: _side(row['side']),
          supportingReadings: List.unmodifiable([
            for (final id in _strings(row['required_reading_ids']))
              ...readings.where((reading) => reading.id == id),
          ]),
        ),
    ]);
  }

  List<MatchComputedReading> _displayReadings(
    List<Map<String, Object?>> rows, {
    required int fixtureId,
  }) {
    return List.unmodifiable([
      for (final row in rows)
        MatchComputedReading(
          id: row['id']?.toString() ?? 'unknown',
          subjectTeamId:
              row['subject_team_id']?.toString() ?? 'api-fixture-$fixtureId',
          side: row['side']?.toString() ?? 'match',
          strength: row['strength']?.toString() ?? 'moderate',
          isContradiction: _isContradiction(row),
          evidenceLabel:
              _list(row['evidence']).firstOrNull?['label']?.toString() ??
              'Donnée calculée côté serveur.',
          evidenceValue: _list(row['evidence']).firstOrNull?['value'],
          playerName: row['player_name']?.toString() ?? _playerName(row),
          playerPhotoUrl: _playerPhotoUrl(row),
        ),
    ]);
  }

  ChampionshipTierSnapshot? _tierSnapshot(Map<String, Object?> row) {
    if (row.isEmpty) return null;
    final assignments = <TeamTierAssignment>[
      for (final value in _list(row['team_assignments']))
        if (_integer(value['team_id']) != null &&
            _integer(value['rank']) != null &&
            _integer(value['points']) != null &&
            _integer(value['played']) != null &&
            _tierLabel(value['assigned_tier']) != null)
          TeamTierAssignment(
            teamId: _integer(value['team_id'])!,
            teamName: value['team_name']?.toString() ?? 'Équipe',
            officialRank: _integer(value['rank'])!,
            points: _integer(value['points'])!,
            played: _integer(value['played'])!,
            pointsPerGame: _double(value['points_per_game']) ?? 0,
            assignedTier: _tierLabel(value['assigned_tier'])!,
            group: value['group']?.toString(),
            description: value['description']?.toString(),
          ),
    ];
    if (assignments.isEmpty) return null;
    final analysisAsOf = DateTime.tryParse(
      row['analysis_as_of']?.toString() ?? '',
    );
    if (analysisAsOf == null) return null;
    final boundaries = <ConfirmedStructuralBoundary>[
      for (final value in _list(row['confirmed_boundaries']))
        if (_integer(value['boundary_index']) != null &&
            _integer(value['upper_rank']) != null &&
            _integer(value['lower_rank']) != null &&
            _integer(value['raw_gap']) != null)
          ConfirmedStructuralBoundary(
            boundaryIndex: _integer(value['boundary_index'])!,
            upperRank: _integer(value['upper_rank'])!,
            lowerRank: _integer(value['lower_rank'])!,
            rawGap: _integer(value['raw_gap'])!,
            score: _double(value['score']) ?? 0,
            strength: _boundaryStrength(value['strength']),
            standingsSnapshotIdentity:
                row['standings_snapshot_identity']?.toString() ?? 'server',
          ),
    ];
    final partitions = <TierPartitionBoundary>[
      for (final value in _list(row['tier_partition_boundaries']))
        if (_integer(value['boundary_index']) != null)
          TierPartitionBoundary(
            boundaryIndex: _integer(value['boundary_index'])!,
            score: _double(value['score']) ?? 0,
            strength: _boundaryStrength(value['strength']),
          ),
    ];
    final presence = assignments
        .map((assignment) => assignment.assignedTier)
        .toSet();
    return ChampionshipTierSnapshot(
      competitionId: row['competition_id']?.toString() ?? '',
      season: _integer(row['season']) ?? 0,
      analysisAsOf: analysisAsOf,
      tierSystemVersion: row['tier_system_version']?.toString() ?? 'tier-v1',
      standingsSnapshotIdentity:
          row['standings_snapshot_identity']?.toString() ?? 'server',
      status: _tierStatus(row['status']),
      maturity: _tierMaturity(row['maturity']),
      teamCount: _integer(row['team_count']) ?? assignments.length,
      pointDistribution: null,
      ppgDistribution: null,
      boundaryCandidates: const [],
      confirmedStructuralBoundaries: boundaries,
      tierPartitionBoundaries: partitions,
      tierPresence: presence,
      teamAssignments: assignments,
      warnings: const [],
      unavailabilityReasons: const [],
    );
  }

  String? _playerName(Map<String, Object?> row) {
    for (final evidence in _list(row['evidence'])) {
      final value = _map(evidence['value']);
      final name = value['player_name']?.toString().trim();
      if (name != null && name.isNotEmpty) return name;
    }
    return null;
  }

  String? _playerPhotoUrl(Map<String, Object?> row) {
    for (final evidence in _list(row['evidence'])) {
      final value = _map(evidence['value']);
      final url = value['player_photo_url']?.toString().trim();
      if (url != null && url.isNotEmpty) return url;
    }
    return null;
  }

  List<ReadingEvidence> _evidence(List<Map<String, Object?>> rows) {
    return List.unmodifiable([
      for (final row in rows)
        ReadingEvidence(
          label: row['label']?.toString() ?? 'Donnée calculée côté serveur.',
          kind: _evidenceKind(row['kind']),
          sourcePath: row['source_path']?.toString() ?? 'server.computed',
          value: row['value'],
        ),
    ]);
  }
}

class ServerComputedMatchAnalysis {
  const ServerComputedMatchAnalysis({
    required this.analysis,
    required this.scenarios,
    required this.displayReadings,
    this.championshipTierSnapshot,
  });

  final FootballAnalysis analysis;
  final List<FootballScenarioMatch> scenarios;
  final List<MatchComputedReading> displayReadings;
  final ChampionshipTierSnapshot? championshipTierSnapshot;
}

TierLabel? _tierLabel(Object? value) => switch (value?.toString()) {
  'TIER_1' => TierLabel.tier1Podium,
  'TIER_2' => TierLabel.tier2UpperChampionship,
  'TIER_3' => TierLabel.tier3MiddleChampionship,
  'TIER_4' => TierLabel.tier4LowerChampionship,
  'TIER_5' => TierLabel.tier5Relegation,
  _ => null,
};

TierSystemStatus _tierStatus(Object? value) => switch (value?.toString()) {
  'mature' => TierSystemStatus.mature,
  'immature' => TierSystemStatus.immature,
  _ => TierSystemStatus.unavailable,
};

TierMaturity _tierMaturity(Object? value) => switch (value?.toString()) {
  'mature' => TierMaturity.mature,
  'immature' => TierMaturity.immature,
  _ => TierMaturity.unavailable,
};

BoundaryStrength _boundaryStrength(Object? value) =>
    switch (value?.toString()) {
      'strong' => BoundaryStrength.strong,
      'weak' => BoundaryStrength.weak,
      _ => BoundaryStrength.moderate,
    };

ReadingSubjectSide _side(Object? value) => switch (value?.toString()) {
  'home' => ReadingSubjectSide.home,
  'away' => ReadingSubjectSide.away,
  _ => ReadingSubjectSide.match,
};

ReadingStrength _strength(Object? value) => switch (value?.toString()) {
  'strong' => ReadingStrength.strong,
  'weak' => ReadingStrength.weak,
  _ => ReadingStrength.moderate,
};

ReadingEvidenceKind _evidenceKind(Object? value) => switch (value?.toString()) {
  'standing' => ReadingEvidenceKind.standing,
  'form' => ReadingEvidenceKind.form,
  'home_away' => ReadingEvidenceKind.homeAway,
  'goals' => ReadingEvidenceKind.goals,
  'expected_goals' => ReadingEvidenceKind.expectedGoals,
  'shots' => ReadingEvidenceKind.shots,
  'corners' => ReadingEvidenceKind.corners,
  'cards' => ReadingEvidenceKind.cards,
  'player' => ReadingEvidenceKind.player,
  'market' => ReadingEvidenceKind.market,
  'availability' => ReadingEvidenceKind.availability,
  _ => ReadingEvidenceKind.sample,
};

bool _isContradiction(Map<String, Object?> row) {
  return row['is_contradiction'] == true ||
      const {
        'misleading_result',
        'conflicting_signals',
        'key_player_unavailable',
      }.contains(row['id']?.toString());
}

Map<String, Object?> _map(Object? value) => value is Map
    ? {for (final entry in value.entries) entry.key.toString(): entry.value}
    : const {};

List<Map<String, Object?>> _list(Object? value) => value is List
    ? value.whereType<Map<Object?, Object?>>().map(_map).toList(growable: false)
    : const [];

List<String> _strings(Object? value) => value is List
    ? value.map((item) => item.toString()).toList(growable: false)
    : const [];

int? _integer(Object? value) => switch (value) {
  int value => value,
  num value => value.toInt(),
  String value => int.tryParse(value),
  _ => null,
};

double? _double(Object? value) => switch (value) {
  num value => value.toDouble(),
  String value => double.tryParse(value),
  _ => null,
};
