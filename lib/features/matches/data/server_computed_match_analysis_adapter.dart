import '../domain/analysis_maturity.dart';
import '../domain/football_reading.dart';
import '../domain/football_scenario.dart';

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
  });

  final FootballAnalysis analysis;
  final List<FootballScenarioMatch> scenarios;
}

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
