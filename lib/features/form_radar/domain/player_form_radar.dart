import '../../../core/domain/lector_player_form_policy.dart';
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

  static const recentWindow = LectorPlayerFormPolicy.recentWindow;

  /// A player must have produced at least two actions in the current window.
  /// This retains super-subs while excluding a single isolated contribution.
  static List<PlayerFormRadarEntry> rank(
    Iterable<PlayerFormRadarProfile> profiles,
  ) {
    final entries = <PlayerFormRadarEntry>[];
    for (final profile in latestProfiles(profiles)) {
      if (profile.activity.length < recentWindow) continue;
      final recent = LectorPlayerFormPolicy.recent(profile.activity);
      final contributions = recent.fold<int>(
        0,
        (total, match) => total + match.contributions,
      );
      if (contributions < LectorPlayerFormPolicy.minimumContributions) continue;
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

  /// Competition snapshots may repeat a player for the same team. Select
  /// current evidence before detecting form, so an old hot window cannot
  /// replace a newer window in which the player has cooled down. Club and
  /// national-team profiles remain independent because their team IDs differ.
  static List<PlayerFormRadarProfile> latestProfiles(
    Iterable<PlayerFormRadarProfile> profiles, {
    Map<int, DateTime> latestTeamMatchDates = const {},
  }) {
    final candidates = profiles.toList(growable: false);
    final teamDates = Map<int, DateTime>.of(latestTeamMatchDates);
    for (final profile in candidates) {
      final date = _lastMatchDate(profile);
      final current = teamDates[profile.teamId];
      if (date != null && (current == null || date.isAfter(current))) {
        teamDates[profile.teamId] = date;
      }
    }
    final latest = <(int, int), PlayerFormRadarProfile>{};
    for (final profile in candidates) {
      final date = _lastMatchDate(profile);
      final teamDate = teamDates[profile.teamId];
      // A player absent from the current sample must not reappear solely
      // because an older competition still carries a hot profile for them.
      if (teamDate != null && (date == null || date.isBefore(teamDate))) {
        continue;
      }
      final key = (profile.teamId, profile.playerId);
      final previous = latest[key];
      if (previous == null || _compareEvidence(profile, previous) > 0) {
        latest[key] = profile;
      }
    }
    return List.unmodifiable(latest.values);
  }

  static int _compareEvidence(
    PlayerFormRadarProfile left,
    PlayerFormRadarProfile right,
  ) {
    final leftDate = _lastMatchDate(left);
    final rightDate = _lastMatchDate(right);
    if (leftDate == null && rightDate != null) return -1;
    if (leftDate != null && rightDate == null) return 1;
    if (leftDate != null && rightDate != null) {
      final recency = leftDate.compareTo(rightDate);
      if (recency != 0) return recency;
    }
    final history = left.activity.length.compareTo(right.activity.length);
    if (history != 0) return history;
    return right.leagueId.compareTo(left.leagueId);
  }

  static DateTime? _lastMatchDate(PlayerFormRadarProfile profile) => profile
      .activity
      .map((match) => match.playedAt)
      .fold<DateTime?>(
        null,
        (last, date) => last == null || date.isAfter(last) ? date : last,
      );

  static int _currentDecisiveStreak(
    List<PlayerFormRadarMatchSnapshot> activity,
  ) {
    return LectorPlayerFormPolicy.streak(activity, (match) => match.isDecisive);
  }
}
