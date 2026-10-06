import '../../domain/lector_temporal_state.dart';
import 'sport_match_history.dart';
import 'sport_competition_context.dart';
import 'sport.dart';
import 'sport_policy.dart';

enum SportFixtureStatus {
  scheduled,
  live,
  finished,
  postponed,
  cancelled,
  unknown,
}

/// Modules can declare additional scopes (periods, quarters, innings...).
/// A final score must never be used as a missing regulation score.
class SportScoreScope {
  const SportScoreScope(this.key);
  static const regulation = SportScoreScope('regulation');
  static const finalResult = SportScoreScope('final');
  final String key;

  @override
  bool operator ==(Object other) =>
      other is SportScoreScope && key == other.key;
  @override
  int get hashCode => key.hashCode;
}

class SportScore {
  SportScore({required this.home, required this.away}) {
    if (home < 0 || away < 0) throw ArgumentError('Scores cannot be negative.');
  }
  final int home;
  final int away;
}

class SportParticipant {
  const SportParticipant({required this.id, required this.name, this.logoUrl});
  final SportEntityId id;
  final String name;
  final String? logoUrl;
}

/// Shared factual presentation envelope. Detailed statistics, readings and
/// settlement algorithms remain typed inside their discipline's module.
class SportFixture {
  SportFixture({
    required this.id,
    required this.competition,
    required this.competitionName,
    required this.season,
    required this.home,
    required this.away,
    required this.startsAt,
    required this.status,
    this.calendarDate,
    this.providerStatus,
    this.period,
    this.clock,
    this.capturedAt,
    this.headToHead,
    this.matchEvents = const [],
    this.matchEventsCapturedAt,
    Map<SportScoreScope, SportScore> scores = const {},
    Iterable<SportFormResult> homeForm = const [],
    Iterable<SportFormResult> awayForm = const [],
  }) : scores = Map.unmodifiable(scores),
       homeForm = List.unmodifiable(homeForm),
       awayForm = List.unmodifiable(awayForm) {
    if (id.kind != SportEntityKind.match ||
        competition.kind != SportEntityKind.competition ||
        home.id.kind != SportEntityKind.team ||
        away.id.kind != SportEntityKind.team ||
        home.id == away.id ||
        season.trim().isEmpty ||
        [competition, home.id, away.id].any(
          (other) => other.sport != id.sport || other.provider != id.provider,
        )) {
      throw ArgumentError(
        'Fixture identities must belong to the same sport and provider.',
      );
    }
    if (scores.keys.any((scope) => scope.key.trim().isEmpty)) {
      throw ArgumentError('A score needs an explicit scope.');
    }
  }

  final SportEntityId id;
  final SportEntityId competition;
  final String competitionName;
  final String season;
  final SportParticipant home;
  final SportParticipant away;
  final DateTime? startsAt;
  final SportFixtureStatus status;
  // Publication calendar day; avoids shifting dates with browser time zones.
  final DateTime? calendarDate;
  final String? providerStatus;
  final String? period, clock;
  final DateTime? capturedAt;
  LectorTemporalState get temporal => LectorTemporalState(
    phase: switch (status) {
      SportFixtureStatus.live => LectorMatchPhase.live,
      SportFixtureStatus.scheduled => LectorMatchPhase.upcoming,
      SportFixtureStatus.finished => LectorMatchPhase.finished,
      _ => LectorMatchPhase.other,
    },
    period:
        period ??
        switch (providerStatus) {
          'P1' => 'P1',
          'P2' => 'P2',
          'P3' => 'P3',
          'OT' => 'Prol.',
          'BT' || 'IN1' || 'IN2' => 'Pause',
          'PT' || 'PEN' => 'TAB',
          _ => null,
        },
    clock: clock,
    capturedAt: capturedAt,
  );
  final SportMatchHistory? headToHead;
  final List<SportMatchEvent> matchEvents;
  final DateTime? matchEventsCapturedAt;
  final Map<SportScoreScope, SportScore> scores;
  final List<SportFormResult> homeForm, awayForm;
  SportId get sport => id.sport;

  (SportParticipant, SportParticipant) displayedParticipants(
    SportParticipantOrder order,
  ) => order == SportParticipantOrder.homeAway ? (home, away) : (away, home);

  SportScore? scoreFor(SportScoreScope scope) => scores[scope];
}
