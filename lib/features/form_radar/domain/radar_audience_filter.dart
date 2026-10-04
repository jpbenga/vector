import '../../matches/domain/match_board_item.dart';
import '../../onboarding/domain/decision_profile_catalogs.dart';

/// Explicit categories, independent of form scores and account readings.
class RadarParticipantCategory {
  const RadarParticipantCategory({this.isWomen = false, this.isYouth = false});

  final bool isWomen;
  final bool isYouth;

  static final _women = RegExp(
    r"\b(?:women(?:'s)?|womens|feminine?|feminin(?:e)?s?|femenin[ao]s?|feminin[ao]s?|frauen|dames)\b",
    caseSensitive: false,
  );
  // API team suffixes, including 'France W U20'. Do not match W Connection,
  // Wolves, Utrecht or letters inside a senior team's name.
  static final _womenTeamSuffix = RegExp(
    r'\bw(?:\s+u[ -]?(?:1\d|2[0-3]))?\s*$',
    caseSensitive: false,
  );
  static final _youth = RegExp(
    r'\b(?:u[ -]?(?:1\d|2[0-3])|under[ -]?(?:1\d|2[0-3]))\b',
    caseSensitive: false,
  );

  factory RadarParticipantCategory.classify({
    required int? leagueId,
    required String teamName,
    String competitionName = '',
  }) {
    final definition = leagueId == null
        ? null
        : CompetitionCatalog.byApiFootballLeagueId(leagueId);
    String normalized(String value) => value
        .replaceAll(RegExp('[éèêë]'), 'e')
        .replaceAll(RegExp('[ÉÈÊË]'), 'E')
        .replaceAll('_', ' ');
    final team = normalized(teamName);
    final competition = normalized(competitionName);
    return RadarParticipantCategory(
      isWomen:
          definition?.isWomen == true ||
          _women.hasMatch(competition) ||
          _women.hasMatch(team) ||
          _womenTeamSuffix.hasMatch(team),
      isYouth:
          definition?.isYouth == true ||
          _youth.hasMatch(competition) ||
          _youth.hasMatch(team),
    );
  }
}

class RadarAudienceFilter {
  const RadarAudienceFilter({
    this.includeWomen = false,
    this.includeYouth = false,
  });

  final bool includeWomen;
  final bool includeYouth;

  int get exclusionCount => (includeWomen ? 0 : 1) + (includeYouth ? 0 : 1);

  String get label => switch ((includeWomen, includeYouth)) {
    (false, false) => 'Hommes · Seniors',
    (true, false) => 'Hommes et femmes · Seniors',
    (false, true) => 'Hommes · Tous les âges',
    (true, true) => 'Toutes les catégories',
  };

  bool includes({
    required int? leagueId,
    required String teamName,
    String competitionName = '',
  }) {
    final category = RadarParticipantCategory.classify(
      leagueId: leagueId,
      teamName: teamName,
      competitionName: competitionName,
    );
    return (includeWomen || !category.isWomen) &&
        (includeYouth || !category.isYouth);
  }

  bool includesMatch(MatchBoardItem match) =>
      includes(
        leagueId: match.competition.apiFootballLeagueId,
        teamName: match.homeTeam.name,
        competitionName: match.competition.name,
      ) &&
      includes(
        leagueId: match.competition.apiFootballLeagueId,
        teamName: match.awayTeam.name,
        competitionName: match.competition.name,
      );

  Map<String, bool> toJson() => {
    'includeWomen': includeWomen,
    'includeYouth': includeYouth,
  };

  factory RadarAudienceFilter.fromJson(Map<String, Object?> json) =>
      RadarAudienceFilter(
        includeWomen: json['includeWomen'] == true,
        includeYouth: json['includeYouth'] == true,
      );
}
