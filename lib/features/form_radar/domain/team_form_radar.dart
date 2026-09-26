import '../../matches/domain/match_board_item.dart';

/// Form Radar for teams. The five latest completed league matches provide the
/// score, then the most recent three matches settle close positions.
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
      if (activity.length < recentWindow) continue;
      final recent = activity.length <= recentWindow
          ? activity
          : activity.sublist(activity.length - recentWindow);
      entries.add(
        TeamFormRadarEntry(
          profile: profile,
          points: _points(activity),
          recentPoints: _points(recent),
          unbeatenStreak: _unbeatenStreak(activity),
        ),
      );
    }
    entries.sort((left, right) {
      final points = right.points.compareTo(left.points);
      if (points != 0) return points;
      final recent = right.recentPoints.compareTo(left.recentPoints);
      if (recent != 0) return recent;
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
}
