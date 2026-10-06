import 'sport_player_activity.dart';
import 'sport_competition_context.dart';
import 'sport.dart';

/// Metadata contract for future sport publications. An empty day is valid.
/// Decode provider payloads inside the appropriate sport adapter first.
class SportSnapshot<T> {
  SportSnapshot({
    required this.sport,
    required this.schemaVersion,
    required this.capturedAt,
    required this.windowStart,
    required this.windowEnd,
    required Iterable<T> items,
    required SportId Function(T) sportOf,
    Iterable<SportCompetitionContext> competitions = const [],
    Iterable<SportPlayerProfile> players = const [],
    Iterable<SportPlayerRadarCoverage> playerRadarCoverage = const [],
  }) : items = List.unmodifiable(items),
       players = List.unmodifiable(players),
       playerRadarCoverage = List.unmodifiable(playerRadarCoverage),
       competitions = List.unmodifiable(competitions) {
    if (schemaVersion != 1 || windowEnd.isBefore(windowStart)) {
      throw ArgumentError('Unsupported schema or invalid snapshot window.');
    }
    if (this.items.any((item) => sportOf(item) != sport)) {
      throw ArgumentError('A snapshot cannot contain another sport.');
    }
  }

  final SportId sport;
  final int schemaVersion;
  final DateTime capturedAt;
  // Inclusive UTC date bounds, deliberately independent of match count.
  final DateTime windowStart;
  final DateTime windowEnd;
  final List<T> items;
  final List<SportPlayerProfile> players;
  final List<SportPlayerRadarCoverage> playerRadarCoverage;
  final List<SportCompetitionContext> competitions;

  bool covers(DateTime date) {
    DateTime day(DateTime value) =>
        DateTime.utc(value.year, value.month, value.day);
    return !day(date).isBefore(day(windowStart)) &&
        !day(date).isAfter(day(windowEnd));
  }
}
