import '../../../core/domain/lector_player_form_policy.dart';
import '../../../core/sports/domain/sport_player_activity.dart';

class HockeyPlayerRadarEntry {
  const HockeyPlayerRadarEntry(this.profile);
  final SportPlayerProfile profile;
  List<SportPlayerMatchActivity> get recentActivity =>
      LectorPlayerFormPolicy.recent(profile.activity);
  int get goals => recentActivity.fold(0, (v, m) => v + m.goals!);
  int get assists => recentActivity.fold(0, (v, m) => v + m.assists!);
  int get decisiveMatches =>
      recentActivity.where((m) => m.contributions! > 0).length;
  int get streak => LectorPlayerFormPolicy.streak(
    profile.activity,
    (match) => match.contributions == null ? null : match.contributions! > 0,
  );
  bool get streakLimitedByUnknown {
    final boundary = profile.activity.length - streak - 1;
    return boundary >= 0 && !profile.activity[boundary].contributionsKnown;
  }
}

/// Same temporal contract as football: qualify on the three latest team games,
/// then reward the current uninterrupted series across the available history.
/// Missing older evidence is never a zero or a bridge across two known games.
abstract final class HockeyPlayerRadarRanker {
  static const recentWindow = LectorPlayerFormPolicy.recentWindow;
  static List<HockeyPlayerRadarEntry> rank(
    Iterable<SportPlayerProfile> profiles, {
    required DateTime before,
  }) {
    final entries = profiles
        .where(
          (p) =>
              p.activity.length >= recentWindow &&
              p.activity.every((m) => m.result.startsAt.isBefore(before)) &&
              LectorPlayerFormPolicy.recent(
                p.activity,
              ).every((m) => m.contributionsKnown),
        )
        .map(HockeyPlayerRadarEntry.new)
        .where(
          (e) =>
              e.goals + e.assists >=
              LectorPlayerFormPolicy.minimumContributions,
        )
        .toList();
    entries.sort((a, b) {
      var diff = b.decisiveMatches.compareTo(a.decisiveMatches);
      if (diff == 0) diff = b.streak.compareTo(a.streak);
      if (diff == 0) {
        diff = (b.goals + b.assists).compareTo(a.goals + a.assists);
      }
      return diff == 0 ? a.profile.name.compareTo(b.profile.name) : diff;
    });
    return entries;
  }
}
