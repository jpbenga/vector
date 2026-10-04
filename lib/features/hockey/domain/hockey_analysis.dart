import '../../../core/sports/domain/sport.dart';
import 'hockey_rules.dart';

class HockeyRecentGame {
  const HockeyRecentGame({
    required this.match,
    required this.competition,
    required this.season,
    required this.completedAt,
    required this.result,
  });

  final SportEntityId match;
  final SportEntityId competition;
  final String season;
  final DateTime completedAt;
  final HockeyResult result;
}

class HockeyStanding {
  const HockeyStanding({
    required this.competition,
    required this.season,
    required this.comparisonGroup,
    required this.gamesPlayed,
    required this.points,
    required this.asOf,
  });

  final SportEntityId competition;
  final String season;
  // Explicit common comparison scope; a division rank cannot be compared
  // blindly with the same rank from a different conference.
  final String comparisonGroup;
  final int gamesPlayed;
  final int points;
  final DateTime asOf;
}

class HockeyTeamContext {
  const HockeyTeamContext({
    required this.team,
    required this.recentGames,
    this.standing,
  });

  final SportEntityId team;
  final List<HockeyRecentGame> recentGames;
  final HockeyStanding? standing;
}

class HockeyMatchContext {
  const HockeyMatchContext({
    required this.match,
    required this.competition,
    required this.season,
    required this.startsAt,
    required this.asOf,
    required this.pointsRules,
    required this.home,
    required this.away,
  });

  final SportEntityId match;
  final SportEntityId competition;
  final String season;
  final DateTime startsAt;
  final DateTime asOf;
  final HockeyPointsRules pointsRules;
  final HockeyTeamContext home;
  final HockeyTeamContext away;
}
