import '../../../core/domain/lector_temporal_state.dart';
import '../data/match_reading_bilan_repository.dart';
import 'match_board_item.dart';

/// Score overlay only. Prematch evidence and personalized readings stay frozen.
class LiveMatchState {
  const LiveMatchState({
    required this.fixtureId,
    required this.status,
    required this.capturedAt,
    this.elapsed,
    this.extra,
    this.homeGoals,
    this.awayGoals,
    this.statistics = const [],
    this.statisticsCapturedAt,
    this.readings = const [],
  });

  factory LiveMatchState.fromJson(Map<String, dynamic> json) => LiveMatchState(
    fixtureId: (json['fixture_id'] as num).toInt(),
    status: json['status'] as String? ?? 'NS',
    capturedAt: DateTime.tryParse('${json['captured_at']}'),
    elapsed: (json['elapsed'] as num?)?.toInt(),
    extra: (json['extra'] as num?)?.toInt(),
    homeGoals: (json['home_goals'] as num?)?.toInt(),
    awayGoals: (json['away_goals'] as num?)?.toInt(),
    statistics: (json['statistics'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false),
    statisticsCapturedAt: DateTime.tryParse(
      '${json['statistics_captured_at']}',
    ),
    readings: (json['readings'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(MatchReadingBilanEntry.fromJson)
        .toList(growable: false),
  );

  final int fixtureId;
  final String status;
  final DateTime? capturedAt;
  final int? elapsed;
  final int? extra;
  final int? homeGoals;
  final int? awayGoals;
  final List<MatchReadingBilanEntry> readings;
  final List<Map<String, dynamic>> statistics;
  final DateTime? statisticsCapturedAt;
  bool get isFinal => const {'FT', 'AET', 'PEN'}.contains(status);
  bool get isLive =>
      const {'1H', 'HT', '2H', 'ET', 'BT', 'P', 'LIVE'}.contains(status);
  bool isStale(DateTime now) =>
      (isLive || const {'SUSP', 'INT'}.contains(status)) &&
      capturedAt != null &&
      now.difference(capturedAt!) > const Duration(minutes: 3);
  String get statusLabel => switch (status) {
    'HT' => 'Mi-temps',
    'FT' => 'Terminé',
    'AET' => 'Terminé après prolongation',
    'PEN' => 'Terminé aux tirs au but',
    'PST' => 'Reporté',
    'CANC' => 'Annulé',
    'SUSP' || 'INT' => 'Interrompu',
    'ABD' => 'Abandonné',
    'AWD' || 'WO' => 'Décision administrative',
    _ when isLive =>
      elapsed == null
          ? 'En direct'
          : '${elapsed!}${extra != null && extra! > 0 ? '+$extra' : ''}′ · En direct',
    _ => 'Avant-match',
  };

  LectorTemporalState get temporal => LectorTemporalState(
    phase: isLive
        ? LectorMatchPhase.live
        : isFinal
        ? LectorMatchPhase.finished
        : const {'NS', 'TBD'}.contains(status)
        ? LectorMatchPhase.upcoming
        : LectorMatchPhase.other,
    period: status == 'HT'
        ? 'MT'
        : status == 'BT'
        ? 'Pause'
        : status == 'P'
        ? 'TAB'
        : null,
    clock: status == 'HT' || status == 'BT' || status == 'P' || elapsed == null
        ? null
        : '${elapsed!}${extra != null && extra! > 0 ? '+$extra' : ''}′',
    capturedAt: capturedAt,
    label: statusLabel,
  );

  List<MatchReadingBilanEntry> visibleReadings(
    Set<String> ids, {
    Set<String> scenarioIds = const {},
  }) => readings
      .where((entry) {
        if (entry.announcementKind == 'scenario') {
          return scenarioIds.contains(entry.readingId);
        }
        if (entry.announcementKind == 'nuance') return false;
        return ids.contains(entry.readingId);
      })
      .toList(growable: false);

  MatchBoardItem overlay(MatchBoardItem match) {
    if (fixtureId != match.fixture.apiFootballFixtureId || capturedAt == null) {
      return match;
    }
    final fixture = match.fixture;
    // Never regress a known final while reconnecting to an older live row.
    if (fixture.status == FixtureStatus.finished && !isFinal) return match;
    final normalizedStatus = isFinal
        ? FixtureStatus.finished
        : isLive
        ? FixtureStatus.live
        : switch (status) {
            'PST' => FixtureStatus.postponed,
            'CANC' || 'ABD' || 'AWD' || 'WO' => FixtureStatus.cancelled,
            _ => fixture.status,
          };
    return match.copyWith(
      fixture: NormalizedFixture(
        id: fixture.id,
        apiFootballFixtureId: fixture.apiFootballFixtureId,
        competition: fixture.competition,
        homeTeam: fixture.homeTeam,
        awayTeam: fixture.awayTeam,
        kickoffLabel: fixture.kickoffLabel,
        kickoff: fixture.kickoff,
        round: fixture.round,
        status: normalizedStatus,
        venue: fixture.venue,
        score: homeGoals != null && awayGoals != null
            ? FixtureScore(home: homeGoals!, away: awayGoals!)
            : fixture.score,
      ),
    );
  }
}
