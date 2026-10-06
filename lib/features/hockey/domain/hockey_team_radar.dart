import '../../../core/domain/lector_victory_series.dart';
import '../../../core/domain/lector_team_form_policy.dart';
import '../../../core/sports/domain/sport_competition_context.dart';

class HockeyTeamRadarEntry {
  const HockeyTeamRadarEntry({
    required this.competition,
    required this.row,
    this.wins = 0,
    this.streak = 0,
  });
  final SportCompetitionContext competition;
  final SportStandingRow row;
  final int wins, streak;
  LectorVictorySeriesAssessment get victorySeries => LectorVictorySeries.assess(
    row.formHistory.reversed,
    won: (g) => g.outcome == SportFormOutcome.draw
        ? null
        : g.outcome == SportFormOutcome.win,
    home: (g) => g.home,
    historyComplete: row.formHistory.length == row.played,
  );
  String get streakLabel => victorySeries.detected
      ? victorySeries.radarLabel
      : victorySeries.count == 0
      ? 'Aucune série de victoires'
      : victorySeries.label;
}

/// Hockey supplies the win/loss rule; chronology and tie breaking are shared.
abstract final class HockeyTeamRadarRanker {
  static List<HockeyTeamRadarEntry> rank(
    Iterable<SportCompetitionContext> competitions,
  ) {
    final teams = <String, HockeyTeamRadarEntry>{};
    for (final competition in competitions) {
      if (!competition.formPhaseVerified) continue;
      for (final table in competition.tables) {
        for (final row in table.rows) {
          teams.putIfAbsent(
            '${competition.id.key}:${row.team.id.key}',
            () => HockeyTeamRadarEntry(competition: competition, row: row),
          );
        }
      }
    }
    return List.unmodifiable(
      LectorTeamFormPolicy.rank(
        teams.values,
        resultValues: (entry) => [
          for (final match in entry.row.formHistory)
            match.outcome == SportFormOutcome.win ? 1 : 0,
        ],
        continuesSeries: (value) => value == 1,
        name: (entry) => entry.row.team.name,
      ).map(
        (entry) => HockeyTeamRadarEntry(
          competition: entry.profile.competition,
          row: entry.profile.row,
          wins: entry.score,
          streak: entry.series,
        ),
      ),
    );
  }
}
