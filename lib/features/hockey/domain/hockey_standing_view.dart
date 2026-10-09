import '../../../core/sports/domain/sport.dart';
import '../../../core/sports/domain/sport_competition_context.dart';

/// Same official membership in every scope. Venue positions are recomputed
/// inside that group, never copied from the league-wide calculated position.
abstract final class HockeyStandingView {
  // Display caution only; not a calibrated confidence or reading trigger.
  static const minimumInterGroupGames = 10;
  static int? localGroup(
    SportCompetitionContext competition,
    SportEntityId? team,
  ) {
    final candidates =
        competition.standingContext?.groups
            .where(
              (g) => competition.tables[g.tableIndex].rows.any(
                (r) => r.team.id == team,
              ),
            )
            .toList() ??
        [];
    candidates.sort(
      (a, b) => competition.tables[a.tableIndex].rows.length.compareTo(
        competition.tables[b.tableIndex].rows.length,
      ),
    );
    return candidates.firstOrNull?.tableIndex;
  }

  static List<SportStandingRow> rows(
    SportCompetitionContext competition,
    int tableIndex,
    int scope,
  ) {
    final official = competition.tables[tableIndex];
    if (scope == 0) {
      return [...official.rows]..sort((a, b) => a.rank.compareTo(b.rank));
    }
    final venue = competition.venueStandings;
    if (venue == null || !venue.hasCalculatedPoints) return [];
    final members = official.rows.map((r) => r.team.id).toSet();
    final rows = (scope == 1 ? venue.home : venue.away)
        .where((r) => members.contains(r.team.id))
        .toList();
    // A subset must not masquerade as a complete division/conference ranking.
    if (rows.length != members.length ||
        rows.map((r) => r.team.id).toSet().length != members.length ||
        rows.any((r) => r.points == null)) {
      return [];
    }
    int compare(SportVenueStandingRow a, SportVenueStandingRow b) =>
        b.points!.compareTo(a.points!) != 0
        ? b.points!.compareTo(a.points!)
        : (b.goalsFor - b.goalsAgainst).compareTo(
                a.goalsFor - a.goalsAgainst,
              ) !=
              0
        ? (b.goalsFor - b.goalsAgainst).compareTo(a.goalsFor - a.goalsAgainst)
        : b.goalsFor.compareTo(a.goalsFor);
    rows.sort(
      (a, b) => compare(a, b) != 0
          ? compare(a, b)
          : a.team.name.compareTo(b.team.name),
    );
    var rank = 0;
    return [
      for (final (index, r) in rows.indexed)
        SportStandingRow(
          team: r.team,
          rank: rank = index > 0 && compare(rows[index - 1], r) == 0
              ? rank
              : index + 1,
          played: r.played,
          points: r.points!,
          wins: r.wins - (r.overtimeWins ?? 0),
          losses: r.losses - (r.overtimeLosses ?? 0),
          overtimeWins: r.overtimeWins,
          overtimeLosses: r.overtimeLosses,
          goalsFor: r.goalsFor,
          goalsAgainst: r.goalsAgainst,
        ),
    ];
  }

  static double? leagueMean(SportCompetitionContext c, int scope) {
    final unique = <SportEntityId, SportStandingRow>{};
    final members = c.tables
        .expand((t) => t.rows)
        .map((r) => r.team.id)
        .toSet();
    for (final g in c.standingContext!.groups) {
      for (final r in rows(c, g.tableIndex, scope)) {
        unique[r.team.id] = r;
      }
    }
    if (unique.length != members.length) return null;
    final played = unique.values.fold<int>(0, (n, r) => n + r.played);
    return played == 0
        ? null
        : unique.values.fold<int>(0, (n, r) => n + r.points) / played;
  }
}
