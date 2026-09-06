import 'match_context_key_models.dart';
import 'market_assessment.dart';
import 'structural_tiers/tier_models.dart';

/// Calendar day used by Lector for fixture presentation and filtering.
///
/// API-Football instants are normalized by [DateTime] before this point. The
/// UI deliberately groups them in the viewer's local timezone, rather than
/// comparing a UTC date string to a local selected date.
DateTime lectorLocalCalendarDate(DateTime value) {
  final local = value.toLocal();
  return DateTime(local.year, local.month, local.day);
}

DateTime? lectorLocalCalendarDateForFixture(NormalizedFixture fixture) {
  final kickoff = fixture.kickoff;
  return kickoff == null ? null : lectorLocalCalendarDate(kickoff);
}

enum MatchDataSourceMode { demo, snapshot, api }

enum FixtureStatus { scheduled, live, finished, postponed, cancelled }

class CountryInfo {
  const CountryInfo({required this.code, required this.name, this.flagUrl});

  final String code;
  final String name;
  final String? flagUrl;
}

class CompetitionInfo {
  const CompetitionInfo({
    required this.id,
    required this.name,
    required this.country,
    required this.season,
    this.apiFootballLeagueId,
    this.logoUrl,
  });

  final String id;
  final String name;
  final CountryInfo country;
  final int season;
  final int? apiFootballLeagueId;
  final String? logoUrl;
}

class TeamInfo {
  const TeamInfo({
    required this.id,
    required this.name,
    this.apiFootballTeamId,
    this.logoUrl,
  });

  final String id;
  final String name;
  final int? apiFootballTeamId;
  final String? logoUrl;
}

class FixtureScore {
  const FixtureScore({required this.home, required this.away});

  final int home;
  final int away;
}

class FixtureVenue {
  const FixtureVenue({this.name, this.city});

  final String? name;
  final String? city;
}

class NormalizedFixture {
  const NormalizedFixture({
    required this.id,
    required this.competition,
    required this.homeTeam,
    required this.awayTeam,
    required this.kickoffLabel,
    required this.status,
    this.apiFootballFixtureId,
    this.round,
    this.kickoff,
    this.score,
    this.venue,
  });

  final String id;
  final int? apiFootballFixtureId;

  /// Raw competition round supplied by the fixture provider, when available.
  final String? round;
  final CompetitionInfo competition;
  final TeamInfo homeTeam;
  final TeamInfo awayTeam;
  final String kickoffLabel;
  final DateTime? kickoff;
  final FixtureStatus status;
  final FixtureScore? score;
  final FixtureVenue? venue;
}

class MarketOdds {
  const MarketOdds({
    required this.id,
    required this.label,
    required this.odds,
    this.apiFootballBetId,
    this.apiFootballValue,
    this.playerName,
    this.bookmakerId,
    this.bookmakerName,
  });

  final String id;
  final String label;
  final double odds;
  final int? apiFootballBetId;
  final String? apiFootballValue;
  final String? playerName;
  final int? bookmakerId;
  final String? bookmakerName;
}

class MatchMarket {
  const MatchMarket({
    required this.id,
    required this.label,
    required this.selections,
    this.apiFootballBetId,
    this.bookmakerId,
    this.bookmakerName,
  });

  final String id;
  final String label;
  final List<MarketOdds> selections;
  final int? apiFootballBetId;
  final int? bookmakerId;
  final String? bookmakerName;
}

class MatchSignal {
  const MatchSignal({
    required this.id,
    required this.title,
    required this.summary,
    required this.proofs,
  });

  final String id;
  final String title;
  final String summary;
  final List<String> proofs;
}

enum MatchThesisStatus { recommended, watchlist, notRecommended }

enum MatchProfileStatus { inProfile, outOfProfile }

/// Explicit relevance of a match for the user's configured analysis scope.
///
/// This is a count of concrete profile matches, never a prediction, a
/// probability, or a betting-confidence score.
class MatchProfileRelevance {
  const MatchProfileRelevance({
    this.readingMatches = 0,
    this.thesisMatches = 0,
    this.marketMatches = 0,
  });

  static const none = MatchProfileRelevance();

  final int readingMatches;
  final int thesisMatches;
  final int marketMatches;

  int get total => readingMatches + thesisMatches + marketMatches;

  bool get isRelevant => total > 0;
}

enum CopilotArgumentType {
  marketFavorite,
  rankingGap,
  poorOverallPerformance,
  fragileDefense,
  strongAttack,
  strongRecentForm,
  weakRecentForm,
  openMatch,
  closedMatch,
  contradiction,
}

enum CopilotArgumentSeverity { moderate, strong }

enum CopilotArgumentFamily {
  market,
  hierarchy,
  performance,
  defense,
  attack,
  form,
  rhythm,
  contradiction,
}

enum CopilotEvidenceAction {
  market,
  standings,
  results,
  defensiveStats,
  offensiveStats,
  form,
  rhythm,
}

class ThesisEvidence {
  const ThesisEvidence({required this.label, required this.tone});

  final String label;
  final ThesisEvidenceTone tone;
}

enum ThesisEvidenceTone { positive, warning, negative, neutral }

class RecommendedMarket {
  const RecommendedMarket({required this.market, required this.selection});

  final MatchMarket market;
  final MarketOdds selection;
}

class CopilotArgument {
  const CopilotArgument({
    required this.id,
    required this.type,
    required this.family,
    required this.severity,
    required this.subjectName,
    required this.parameters,
    required this.evidence,
    required this.evidenceAction,
  });

  final String id;
  final CopilotArgumentType type;
  final CopilotArgumentFamily family;
  final CopilotArgumentSeverity severity;
  final String subjectName;
  final Map<String, Object> parameters;
  final List<ThesisEvidence> evidence;
  final CopilotEvidenceAction evidenceAction;
}

class MatchThesis {
  const MatchThesis({
    required this.id,
    required this.title,
    required this.summary,
    required this.status,
    required this.confidence,
    required this.supportingEvidence,
    required this.limits,
    required this.profileReasons,
    this.arguments = const [],
    this.recommendedMarket,
  });

  final String id;
  final String title;
  final String summary;
  final MatchThesisStatus status;
  final int confidence;
  final List<ThesisEvidence> supportingEvidence;
  final List<ThesisEvidence> limits;
  final List<String> profileReasons;
  final List<CopilotArgument> arguments;
  final RecommendedMarket? recommendedMarket;

  bool get hasRecommendedMarket =>
      status == MatchThesisStatus.recommended && recommendedMarket != null;
}

class TeamStandingSnapshot {
  const TeamStandingSnapshot({
    required this.teamId,
    required this.teamName,
    this.group,
    this.description,
    this.rank,
    this.points,
    this.played,
    this.wins,
    this.draws,
    this.losses,
    this.goalsFor,
    this.goalsAgainst,
    this.goalDiff,
    this.form,
  });

  final int teamId;
  final String teamName;
  final String? group;
  final String? description;
  final int? rank;
  final int? points;
  final int? played;
  final int? wins;
  final int? draws;
  final int? losses;
  final int? goalsFor;
  final int? goalsAgainst;
  final int? goalDiff;
  final String? form;
}

enum RecentMatchVenue { home, away }

class TeamRecentMatchSnapshot {
  const TeamRecentMatchSnapshot({
    required this.opponentName,
    required this.venue,
    required this.result,
    this.opponentTeamId,
    this.opponentLogoUrl,
    this.goalsFor,
    this.goalsAgainst,
  });

  final int? opponentTeamId;
  final String opponentName;
  final String? opponentLogoUrl;
  final RecentMatchVenue venue;
  final String result;
  final int? goalsFor;
  final int? goalsAgainst;
}

/// Factual season statistics for one player in the competition of this match.
/// They are deliberately separate from a team identifier: player identity is
/// always carried by [playerId].
class PlayerSeasonStatisticsSnapshot {
  const PlayerSeasonStatisticsSnapshot({
    required this.playerId,
    required this.playerName,
    required this.teamId,
    required this.teamName,
    this.appearances,
    this.lineups,
    this.minutes,
    this.goals,
    this.assists,
    this.shots,
    this.shotsOnTarget,
    this.penaltyGoals,
  });

  final int playerId;
  final String playerName;
  final int teamId;
  final String teamName;
  final int? appearances;
  final int? lineups;
  final int? minutes;
  final int? goals;
  final int? assists;
  final int? shots;
  final int? shotsOnTarget;
  final int? penaltyGoals;

  double? get goalsPer90 {
    final value = minutes;
    final totalGoals = goals;
    if (value == null || value <= 0 || totalGoals == null) return null;
    return totalGoals / value * 90;
  }
}

class MatchAnalysisData {
  const MatchAnalysisData({
    this.asOf,
    this.homeStanding,
    this.awayStanding,
    this.leagueStandings = const [],
    this.championshipTierSnapshot,
    this.structuralRelation,
    this.contextKeys = const [],
    this.contextKeyAvailability = MatchContextKeyAvailability.unavailable,
    this.homeRecentLeagueMatches = const [],
    this.awayRecentLeagueMatches = const [],
    this.homeStatistics,
    this.awayStatistics,
    this.homeExpectedGoals,
    this.awayExpectedGoals,
    this.homePlayerStatistics = const [],
    this.awayPlayerStatistics = const [],
    this.containsPredictions = false,
  });

  final DateTime? asOf;
  final TeamStandingSnapshot? homeStanding;
  final TeamStandingSnapshot? awayStanding;
  final List<TeamStandingSnapshot> leagueStandings;
  final ChampionshipTierSnapshot? championshipTierSnapshot;
  final MatchStructuralRelation? structuralRelation;
  final List<MatchContextKey> contextKeys;
  final MatchContextKeyAvailability contextKeyAvailability;
  final List<TeamRecentMatchSnapshot> homeRecentLeagueMatches;
  final List<TeamRecentMatchSnapshot> awayRecentLeagueMatches;
  final TeamStatisticsSnapshot? homeStatistics;
  final TeamStatisticsSnapshot? awayStatistics;
  final TeamExpectedGoalsSnapshot? homeExpectedGoals;
  final TeamExpectedGoalsSnapshot? awayExpectedGoals;
  final List<PlayerSeasonStatisticsSnapshot> homePlayerStatistics;
  final List<PlayerSeasonStatisticsSnapshot> awayPlayerStatistics;
  final bool containsPredictions;

  bool get hasStandings =>
      homeStanding != null ||
      awayStanding != null ||
      leagueStandings.isNotEmpty;
  bool get hasStatistics => homeStatistics != null || awayStatistics != null;
  bool get hasRecentLeagueMatches =>
      homeRecentLeagueMatches.isNotEmpty || awayRecentLeagueMatches.isNotEmpty;
  bool get hasExpectedGoals =>
      homeExpectedGoals != null || awayExpectedGoals != null;
  bool get hasPlayerStatistics =>
      homePlayerStatistics.isNotEmpty || awayPlayerStatistics.isNotEmpty;
  bool get hasAnalysisData =>
      hasStandings ||
      hasStatistics ||
      hasRecentLeagueMatches ||
      hasExpectedGoals ||
      hasPlayerStatistics;

  MatchAnalysisData copyWith({
    DateTime? asOf,
    TeamStandingSnapshot? homeStanding,
    TeamStandingSnapshot? awayStanding,
    List<TeamStandingSnapshot>? leagueStandings,
    ChampionshipTierSnapshot? championshipTierSnapshot,
    MatchStructuralRelation? structuralRelation,
    List<MatchContextKey>? contextKeys,
    MatchContextKeyAvailability? contextKeyAvailability,
    List<TeamRecentMatchSnapshot>? homeRecentLeagueMatches,
    List<TeamRecentMatchSnapshot>? awayRecentLeagueMatches,
    TeamStatisticsSnapshot? homeStatistics,
    TeamStatisticsSnapshot? awayStatistics,
    TeamExpectedGoalsSnapshot? homeExpectedGoals,
    TeamExpectedGoalsSnapshot? awayExpectedGoals,
    List<PlayerSeasonStatisticsSnapshot>? homePlayerStatistics,
    List<PlayerSeasonStatisticsSnapshot>? awayPlayerStatistics,
    bool? containsPredictions,
  }) {
    return MatchAnalysisData(
      asOf: asOf ?? this.asOf,
      homeStanding: homeStanding ?? this.homeStanding,
      awayStanding: awayStanding ?? this.awayStanding,
      leagueStandings: leagueStandings ?? this.leagueStandings,
      championshipTierSnapshot:
          championshipTierSnapshot ?? this.championshipTierSnapshot,
      structuralRelation: structuralRelation ?? this.structuralRelation,
      contextKeys: contextKeys ?? this.contextKeys,
      contextKeyAvailability:
          contextKeyAvailability ?? this.contextKeyAvailability,
      homeRecentLeagueMatches:
          homeRecentLeagueMatches ?? this.homeRecentLeagueMatches,
      awayRecentLeagueMatches:
          awayRecentLeagueMatches ?? this.awayRecentLeagueMatches,
      homeStatistics: homeStatistics ?? this.homeStatistics,
      awayStatistics: awayStatistics ?? this.awayStatistics,
      homeExpectedGoals: homeExpectedGoals ?? this.homeExpectedGoals,
      awayExpectedGoals: awayExpectedGoals ?? this.awayExpectedGoals,
      homePlayerStatistics: homePlayerStatistics ?? this.homePlayerStatistics,
      awayPlayerStatistics: awayPlayerStatistics ?? this.awayPlayerStatistics,
      containsPredictions: containsPredictions ?? this.containsPredictions,
    );
  }
}

class TeamStatisticsSnapshot {
  const TeamStatisticsSnapshot({
    required this.teamId,
    required this.teamName,
    this.form,
    this.playedTotal,
    this.playedHome,
    this.playedAway,
    this.winsTotal,
    this.winsHome,
    this.winsAway,
    this.drawsTotal,
    this.drawsHome,
    this.drawsAway,
    this.lossesTotal,
    this.lossesHome,
    this.lossesAway,
    this.goalsForTotal,
    this.goalsForHome,
    this.goalsForAway,
    this.goalsAgainstTotal,
    this.goalsAgainstHome,
    this.goalsAgainstAway,
    this.goalsForAverageTotal,
    this.goalsForAverageHome,
    this.goalsForAverageAway,
    this.goalsAgainstAverageTotal,
    this.goalsAgainstAverageHome,
    this.goalsAgainstAverageAway,
    this.cleanSheetsTotal,
    this.cleanSheetsHome,
    this.cleanSheetsAway,
    this.failedToScoreTotal,
    this.failedToScoreHome,
    this.failedToScoreAway,
  });

  final int teamId;
  final String teamName;
  final String? form;
  final int? playedTotal;
  final int? playedHome;
  final int? playedAway;
  final int? winsTotal;
  final int? winsHome;
  final int? winsAway;
  final int? drawsTotal;
  final int? drawsHome;
  final int? drawsAway;
  final int? lossesTotal;
  final int? lossesHome;
  final int? lossesAway;
  final int? goalsForTotal;
  final int? goalsForHome;
  final int? goalsForAway;
  final int? goalsAgainstTotal;
  final int? goalsAgainstHome;
  final int? goalsAgainstAway;
  final double? goalsForAverageTotal;
  final double? goalsForAverageHome;
  final double? goalsForAverageAway;
  final double? goalsAgainstAverageTotal;
  final double? goalsAgainstAverageHome;
  final double? goalsAgainstAverageAway;
  final int? cleanSheetsTotal;
  final int? cleanSheetsHome;
  final int? cleanSheetsAway;
  final int? failedToScoreTotal;
  final int? failedToScoreHome;
  final int? failedToScoreAway;
}

class TeamExpectedGoalsSnapshot {
  const TeamExpectedGoalsSnapshot({
    required this.teamId,
    required this.teamName,
    required this.asOf,
    required this.sampleSize,
    this.rollingXgFor5,
    this.rollingXgAgainst5,
    this.seasonXgForAverage,
    this.seasonXgAgainstAverage,
    this.goalsFor5,
    this.goalsAgainst5,
    this.latestMatchXgFor,
    this.latestMatchXgAgainst,
  });

  final int teamId;
  final String teamName;
  final DateTime asOf;
  final int sampleSize;
  final double? rollingXgFor5;
  final double? rollingXgAgainst5;
  final double? seasonXgForAverage;
  final double? seasonXgAgainstAverage;
  final int? goalsFor5;
  final int? goalsAgainst5;
  final double? latestMatchXgFor;
  final double? latestMatchXgAgainst;

  double? get rollingXgDifference5 {
    final created = rollingXgFor5;
    final conceded = rollingXgAgainst5;
    if (created == null || conceded == null) {
      return null;
    }

    return created - conceded;
  }

  double? get goalsMinusXgFor5 {
    final goals = goalsFor5;
    final xg = rollingXgFor5;
    if (goals == null || xg == null) {
      return null;
    }

    return goals - xg;
  }

  double? get goalsConcededMinusXgAgainst5 {
    final goals = goalsAgainst5;
    final xg = rollingXgAgainst5;
    if (goals == null || xg == null) {
      return null;
    }

    return goals - xg;
  }
}

class MatchBoardItem {
  const MatchBoardItem({
    required this.fixture,
    required this.primaryMarket,
    required this.compatibility,
    required this.signals,
    this.availableMarkets = const [],
    this.betCandidates = const [],
    this.analysis = const MatchAnalysisData(),
    this.profileStatus = MatchProfileStatus.inProfile,
    this.profileRelevance = MatchProfileRelevance.none,
    this.thesis,
  });

  final NormalizedFixture fixture;
  final MarketOdds primaryMarket;
  final List<MatchMarket> availableMarkets;
  final List<BetCandidate> betCandidates;
  final MatchAnalysisData analysis;
  final MatchProfileStatus profileStatus;
  final MatchProfileRelevance profileRelevance;
  final int compatibility;
  final List<MatchSignal> signals;
  final MatchThesis? thesis;

  String get id => fixture.id;
  CompetitionInfo get competition => fixture.competition;
  TeamInfo get homeTeam => fixture.homeTeam;
  TeamInfo get awayTeam => fixture.awayTeam;

  MatchMarket? get defaultMarket {
    for (final market in availableMarkets) {
      if (market.id == 'matchResult') {
        return market;
      }
    }

    return availableMarkets.isEmpty ? null : availableMarkets.first;
  }

  bool get hasMatchResultMarket {
    return availableMarkets.any((market) => market.id == 'matchResult');
  }

  BetCandidate? get suggestedBetCandidate {
    return selectSuggestedBetCandidate(betCandidates);
  }

  RecommendedMarket? recommendedMarketFor(BetCandidate? candidate) {
    if (candidate == null) {
      return null;
    }
    for (final market in availableMarkets) {
      if (market.id != candidate.marketId) {
        continue;
      }
      for (final selection in market.selections) {
        if (selection.id == candidate.selectionId) {
          return RecommendedMarket(market: market, selection: selection);
        }
      }
    }
    return null;
  }

  MatchBoardItem copyWith({
    MarketOdds? primaryMarket,
    List<MatchMarket>? availableMarkets,
    List<BetCandidate>? betCandidates,
    MatchAnalysisData? analysis,
    MatchProfileStatus? profileStatus,
    MatchProfileRelevance? profileRelevance,
    int? compatibility,
    List<MatchSignal>? signals,
    MatchThesis? thesis,
  }) {
    return MatchBoardItem(
      fixture: fixture,
      primaryMarket: primaryMarket ?? this.primaryMarket,
      availableMarkets: availableMarkets ?? this.availableMarkets,
      betCandidates: betCandidates ?? this.betCandidates,
      analysis: analysis ?? this.analysis,
      profileStatus: profileStatus ?? this.profileStatus,
      profileRelevance: profileRelevance ?? this.profileRelevance,
      compatibility: compatibility ?? this.compatibility,
      signals: signals ?? this.signals,
      thesis: thesis ?? this.thesis,
    );
  }
}
