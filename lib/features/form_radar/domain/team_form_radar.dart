import '../../../core/domain/lector_victory_series.dart';
import '../../../core/domain/lector_team_form_policy.dart';

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
    this.competitionNames = const {},
  });

  final int teamId;
  final String teamName;
  final String? logoUrl;
  final int leagueId;
  final String leagueName;
  final Map<int, String> competitionNames;
  final List<TeamRecentMatchSnapshot> activity;

  bool belongsToCompetition(int competitionId) => competitionNames.isEmpty
      ? leagueId == competitionId
      : competitionNames.containsKey(competitionId);
}

class TeamFormRadarEntry {
  const TeamFormRadarEntry({
    required this.profile,
    required this.points,
    required this.recentPoints,
    required this.unbeatenStreak,
    this.weakest = false,
  });

  final TeamFormRadarProfile profile;
  final int points;
  final int recentPoints;
  final int unbeatenStreak;
  final bool weakest;
  LectorVictorySeriesAssessment get victorySeries => LectorVictorySeries.assess(
    profile.activity.reversed,
    won: (g) => switch (g.result.toUpperCase()) {
      'W' || 'V' => true,
      'D' || 'N' || 'L' => false,
      _ => null,
    },
    home: (g) => g.venue == RecentMatchVenue.home,
  );
  String get streakLabel => weakest
      ? unbeatenStreak == 0
            ? 'Aucune série de défaites'
            : '$unbeatenStreak dernières rencontres perdues'
      : victorySeries.detected
      ? victorySeries.radarLabel
      : 'Invaincu · $unbeatenStreak';
}

class TeamFormRadarRanker {
  const TeamFormRadarRanker._();

  static const window = LectorTeamFormPolicy.window;
  static const recentWindow = LectorTeamFormPolicy.recentWindow;

  static List<TeamFormRadarEntry> rank(
    Iterable<TeamFormRadarProfile> profiles, {
    bool weakest = false,
  }) => List.unmodifiable(
    LectorTeamFormPolicy.rank(
      profiles.where(
        (p) =>
            !weakest ||
            p.activity.every(
              (m) => const {
                'W',
                'V',
                'D',
                'N',
                'L',
              }.contains(m.result.toUpperCase()),
            ),
      ),
      resultValues: (profile) => [
        for (final match in profile.activity)
          switch (match.result.toUpperCase()) {
            'W' || 'V' => 3,
            'D' || 'N' => 1,
            _ => 0,
          },
      ],
      continuesSeries: (value) => weakest ? value == 0 : value > 0,
      name: (profile) => profile.teamName,
      weakest: weakest,
    ).map(
      (entry) => TeamFormRadarEntry(
        profile: entry.profile,
        points: entry.score,
        recentPoints: entry.recentScore,
        unbeatenStreak: entry.series,
        weakest: weakest,
      ),
    ),
  );
}
