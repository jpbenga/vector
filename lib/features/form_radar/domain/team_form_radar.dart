import 'dart:math' as math;

import '../../matches/domain/match_board_item.dart';

/// Form Radar for teams. The five latest completed matches are the primary
/// score. A tie is then resolved match by match, starting with the sixth most
/// recent result, so a longer uninterrupted run is rewarded.
class TeamFormRadarProfile {
  const TeamFormRadarProfile({
    required this.teamId,
    required this.teamName,
    required this.leagueId,
    required this.leagueName,
    required this.activity,
    this.logoUrl,
  });

  final int teamId;
  final String teamName;
  final String? logoUrl;
  final int leagueId;
  final String leagueName;
  final List<TeamRecentMatchSnapshot> activity;
}

class TeamFormRadarEntry {
  const TeamFormRadarEntry({
    required this.profile,
    required this.points,
    required this.recentPoints,
    required this.unbeatenStreak,
  });

  final TeamFormRadarProfile profile;
  final int points;
  final int recentPoints;
  final int unbeatenStreak;
}

class TeamFormRadarRanker {
  const TeamFormRadarRanker._();

  static const window = 5;
  static const recentWindow = 3;

  static List<TeamFormRadarEntry> rank(
    Iterable<TeamFormRadarProfile> profiles,
  ) {
    final entries = <TeamFormRadarEntry>[];
    for (final profile in profiles) {
      final activity = profile.activity;
      if (activity.length < window) continue;
      final recent = _last(activity, recentWindow);
      entries.add(
        TeamFormRadarEntry(
          profile: profile,
          points: _points(_last(activity, window)),
          recentPoints: _points(recent),
          unbeatenStreak: _unbeatenStreak(activity),
        ),
      );
    }
    entries.sort((left, right) {
      final points = right.points.compareTo(left.points);
      if (points != 0) return points;
      final historicalTieBreak = _compareHistory(
        left.profile.activity,
        right.profile.activity,
      );
      if (historicalTieBreak != 0) return historicalTieBreak;
      final run = right.unbeatenStreak.compareTo(left.unbeatenStreak);
      if (run != 0) return run;
      return left.profile.teamName.compareTo(right.profile.teamName);
    });
    return List.unmodifiable(entries);
  }

  static int _points(Iterable<TeamRecentMatchSnapshot> matches) => matches.fold(
    0,
    (total, match) =>
        total +
        switch (match.result.toUpperCase()) {
          'W' || 'V' => 3,
          'D' || 'N' => 1,
          _ => 0,
        },
  );

  static int _unbeatenStreak(List<TeamRecentMatchSnapshot> matches) {
    var count = 0;
    for (final match in matches.reversed) {
      if (match.result.toUpperCase() == 'L') break;
      count += 1;
    }
    return count;
  }

  static List<TeamRecentMatchSnapshot> _last(
    List<TeamRecentMatchSnapshot> matches,
    int count,
  ) => matches.length <= count
      ? matches
      : matches.sublist(matches.length - count);

  /// Compare the sixth, seventh, eighth… most recent results in that order.
  /// A win is worth more than a draw, itself worth more than a loss. Keeping
  /// this comparison outside the five-match score guarantees that it acts only
  /// when the primary window is tied.
  static int _compareHistory(
    List<TeamRecentMatchSnapshot> left,
    List<TeamRecentMatchSnapshot> right,
  ) {
    final maxAvailableHistory = math.max(left.length, right.length);
    for (var offset = window + 1;
        offset <= maxAvailableHistory;
        offset += 1) {
      final leftValue = _resultValueFromEnd(left, offset);
      final rightValue = _resultValueFromEnd(right, offset);
      if (leftValue == null || rightValue == null || leftValue == rightValue) {
        continue;
      }
      return rightValue.compareTo(leftValue);
    }
    return 0;
  }

  static int? _resultValueFromEnd(
    List<TeamRecentMatchSnapshot> matches,
    int offset,
  ) {
    if (matches.length < offset) return null;
    return switch (matches[matches.length - offset].result.toUpperCase()) {
      'W' || 'V' => 3,
      'D' || 'N' => 1,
      _ => 0,
    };
  }
}
