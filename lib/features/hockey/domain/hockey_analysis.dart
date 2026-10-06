import '../../../core/sports/domain/sport.dart';
import 'hockey_rules.dart';

class HockeyRecentGame {
  const HockeyRecentGame({
    required this.match,
    required this.competition,
    required this.season,
    required this.completedAt,
    required this.result,
    this.startedAt,
    this.home,
  });

  final SportEntityId match;
  final SportEntityId competition;
  final String season;
  final DateTime completedAt;
  // Optional ordering when completion is known only by a capture timestamp.
  final DateTime? startedAt;
  final HockeyResult result;
  final bool? home;
}

class HockeyStanding {
  const HockeyStanding({
    required this.competition,
    required this.season,
    required this.comparisonGroup,
    required this.gamesPlayed,
    required this.points,
    required this.asOf,
    this.tier,
    this.rank,
    this.tierVersion,
    this.structuralRanks,
  });

  final SportEntityId competition;
  final String season;
  // Explicit common comparison scope; a division rank cannot be compared
  // blindly with the same rank from a different conference.
  final String comparisonGroup;
  final int gamesPlayed;
  final int points;
  final DateTime asOf;
  final int? tier, rank;
  final String? tierVersion;

  /// Ranks across confirmed strong or multiple structural boundaries.
  final Set<int>? structuralRanks;
}

class HockeyTeamContext {
  const HockeyTeamContext({
    required this.team,
    required this.recentGames,
    this.standing,
    this.historyComplete = false,
  });

  final SportEntityId team;
  final List<HockeyRecentGame> recentGames;
  final HockeyStanding? standing;
  final bool historyComplete;
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
