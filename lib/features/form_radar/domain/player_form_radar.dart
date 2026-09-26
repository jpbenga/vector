import '../../matches/domain/match_board_item.dart';

/// The explainable Form Radar ranking.
///
/// The last three completed team matches define who is hot today. Continuity
/// before that window then rewards a player who has remained decisive without
/// a gap for four, five, six matches or more.
class PlayerFormRadarEntry {
  const PlayerFormRadarEntry({
    required this.profile,
    required this.recentActivity,
    required this.recentDecisiveMatches,
    required this.recentContributions,
    required this.recentMinutes,
    required this.decisiveStreak,
  });

  final PlayerFormRadarProfile profile;
  final List<PlayerFormRadarMatchSnapshot> recentActivity;
  final int recentDecisiveMatches;
  final int recentContributions;
  final int recentMinutes;
  final int decisiveStreak;

  int get goals =>
      recentActivity.fold(0, (total, match) => total + match.goals);
  int get assists =>
      recentActivity.fold(0, (total, match) => total + match.assists);
  double? get minutesPerContribution =>
      recentContributions == 0 ? null : recentMinutes / recentContributions;
}

class PlayerFormRadarRanker {
  const PlayerFormRadarRanker._();

  static const recentWindow = 3;

  /// A player must have produced at least two actions in the current window.
  /// This retains super-subs while excluding a single isolated contribution.
  static List<PlayerFormRadarEntry> rank(
    Iterable<PlayerFormRadarProfile> profiles,
  ) {
    final entries = <PlayerFormRadarEntry>[];
    for (final profile in profiles) {
      if (profile.activity.length < recentWindow) continue;
      final recent = profile.activity
          .skip(profile.activity.length - recentWindow)
          .toList(growable: false);
      final contributions = recent.fold<int>(
        0,
        (total, match) => total + match.contributions,
      );
      if (contributions < 2) continue;
      entries.add(
        PlayerFormRadarEntry(
          profile: profile,
          recentActivity: recent,
          recentDecisiveMatches: recent
              .where((match) => match.isDecisive)
              .length,
          recentContributions: contributions,
          recentMinutes: recent.fold(
            0,
            (total, match) => total + match.minutes,
          ),
          decisiveStreak: _currentDecisiveStreak(profile.activity),
        ),
      );
    }
    entries.sort((left, right) {
      // The current three-match consistency is the first promise of Radar.
      final regularity = right.recentDecisiveMatches.compareTo(
        left.recentDecisiveMatches,
      );
      if (regularity != 0) return regularity;
      // A run with no gap beyond the three-match window takes precedence over
      // a one-off explosion. It is the requested four, five, six+ advantage.
      final continuity = right.decisiveStreak.compareTo(left.decisiveStreak);
      if (continuity != 0) return continuity;
      final volume = right.recentContributions.compareTo(
        left.recentContributions,
      );
      if (volume != 0) return volume;
      return left.profile.playerName.compareTo(right.profile.playerName);
    });
    return List.unmodifiable(entries);
  }

  static int _currentDecisiveStreak(
    List<PlayerFormRadarMatchSnapshot> activity,
  ) {
    var length = 0;
    for (final match in activity.reversed) {
      if (!match.isDecisive) break;
      length += 1;
    }
    return length;
  }
}
