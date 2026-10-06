import '../../domain/lector_head_to_head_policy.dart';
import 'sport_fixture.dart';

class SportMatchHistory {
  SportMatchHistory({
    required this.collectedAt,
    required Iterable<SportHistoricalMatch> meetings,
  }) : meetings = List.unmodifiable(meetings);
  final DateTime collectedAt;
  final List<SportHistoricalMatch> meetings;
}

class SportHistoricalMatch {
  SportHistoricalMatch({
    required this.fixture,
    required this.eventsCollected,
    this.eventDataIssue,
    this.competitionPhase,
    this.competitionKind = LectorMeetingKind.unknown,
    required Iterable<SportMatchEvent> events,
  }) : events = List.unmodifiable(events);
  final SportFixture fixture;
  final bool eventsCollected;
  final String? eventDataIssue, competitionPhase;
  final LectorMeetingKind competitionKind;
  final List<SportMatchEvent> events;
}

class SportMatchEvent {
  SportMatchEvent({
    required this.period,
    required this.minute,
    required this.elapsed,
    required this.teamId,
    required this.type,
    required this.detail,
    required Iterable<String> players,
    required Iterable<String> assists,
  }) : players = List.unmodifiable(players),
       assists = List.unmodifiable(assists);
  final String period, teamId, type, detail;
  final int? minute, elapsed;
  final List<String> players, assists;
}
