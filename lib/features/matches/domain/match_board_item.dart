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

  bool get isContinentalTournament =>
      apiFootballLeagueId == 2 ||
      apiFootballLeagueId == 3 ||
      apiFootballLeagueId == 848;
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
    this.scenarioMatches = 0,
    this.marketMatches = 0,
  });

  static const none = MatchProfileRelevance();

  final int readingMatches;
  final int scenarioMatches;
  final int marketMatches;

  int get total => readingMatches + scenarioMatches + marketMatches;

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
    this.metricValue,
    this.metricLabel,
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

  /// Optional decimal metric used by non-points ranking views (for example xG).
  final double? metricValue;
  final String? metricLabel;

  TeamStandingSnapshot copyWith({
    int? rank,
    int? points,
    int? played,
    int? wins,
    int? draws,
    int? losses,
    int? goalsFor,
    int? goalsAgainst,
    int? goalDiff,
    String? form,
    double? metricValue,
    String? metricLabel,
  }) {
    return TeamStandingSnapshot(
      teamId: teamId,
      teamName: teamName,
      group: group,
      description: description,
      rank: rank ?? this.rank,
      points: points ?? this.points,
      played: played ?? this.played,
      wins: wins ?? this.wins,
      draws: draws ?? this.draws,
      losses: losses ?? this.losses,
      goalsFor: goalsFor ?? this.goalsFor,
      goalsAgainst: goalsAgainst ?? this.goalsAgainst,
      goalDiff: goalDiff ?? this.goalDiff,
      form: form ?? this.form,
      metricValue: metricValue ?? this.metricValue,
      metricLabel: metricLabel ?? this.metricLabel,
    );
  }
}

enum ChampionshipStandingView {
  general,
  home,
  away,
  form,
  firstLeg,
  secondLeg,
  firstHalf,
  secondHalf,
  attack,
  defense,
  expectedGoals,
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
    this.penaltyMissed,
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
  final int? penaltyMissed;

  double? get goalsPer90 {
    final value = minutes;
    final totalGoals = goals;
    if (value == null || value <= 0 || totalGoals == null) return null;
    return totalGoals / value * 90;
  }

  double? get shotsPer90 => _per90(shots);
  double? get shotsOnTargetPer90 => _per90(shotsOnTarget);
  double? get assistsPer90 => _per90(assists);
  double? get penaltyGoalsPer90 => _per90(penaltyGoals);
  int? get penaltyAttempts => penaltyGoals == null && penaltyMissed == null
      ? null
      : (penaltyGoals ?? 0) + (penaltyMissed ?? 0);
  double? get penaltyAttemptsPer90 => _per90(penaltyAttempts);
  double? get contributionsPer90 {
    final goalsValue = goals;
    final assistsValue = assists;
    if (goalsValue == null && assistsValue == null) return null;
    return _per90((goalsValue ?? 0) + (assistsValue ?? 0));
  }

  double? _per90(int? total) {
    final playedMinutes = minutes;
    if (playedMinutes == null || playedMinutes <= 0 || total == null) {
      return null;
    }
    return total / playedMinutes * 90;
  }
}

class TeamPerformanceStatisticsSnapshot {
  const TeamPerformanceStatisticsSnapshot({
    required this.teamId,
    required this.teamName,
    required this.asOf,
    required this.sampleSize,
    this.shotsFor,
    this.shotsAgainst,
    this.shotsOnTargetFor,
    this.shotsOnTargetAgainst,
    this.cornersFor,
    this.cornersAgainst,
    this.cardsFor,
    this.cardsAgainst,
    this.totalCorners,
    this.totalCards,
    this.secondHalfCardsShare,
    this.observedCards,
  });

  final int teamId;
  final String teamName;
  final DateTime asOf;
  final int sampleSize;
  final double? shotsFor;
  final double? shotsAgainst;
  final double? shotsOnTargetFor;
  final double? shotsOnTargetAgainst;
  final double? cornersFor;
  final double? cornersAgainst;
  final double? cardsFor;
  final double? cardsAgainst;
  final double? totalCorners;
  final double? totalCards;
  final double? secondHalfCardsShare;
  final int? observedCards;

  double? get shotAccuracy {
    final shots = shotsFor;
    final onTarget = shotsOnTargetFor;
    if (shots == null || shots <= 0 || onTarget == null) return null;
    return onTarget / shots;
  }
}

class TeamGoalProfileSnapshot {
  const TeamGoalProfileSnapshot({
    required this.teamId,
    required this.teamName,
    required this.played,
    required this.over25,
    required this.btts,
    required this.totalGoals,
    this.halftimeLeads = 0,
    this.retainedLeads = 0,
    this.halftimeDeficits = 0,
    this.recoveredDeficits = 0,
  });

  final int teamId;
  final String teamName;
  final int played;
  final int over25;
  final int btts;
  final int totalGoals;
  final int halftimeLeads;
  final int retainedLeads;
  final int halftimeDeficits;
  final int recoveredDeficits;

  double? get over25Rate => played > 0 ? over25 / played : null;
  double? get under25Rate => played > 0 ? (played - over25) / played : null;
  double? get bttsRate => played > 0 ? btts / played : null;
  double? get totalGoalsPerMatch => played > 0 ? totalGoals / played : null;
  double? get leadRetentionRate =>
      halftimeLeads > 0 ? retainedLeads / halftimeLeads : null;
  double? get lostLeadRate => halftimeLeads > 0
      ? (halftimeLeads - retainedLeads) / halftimeLeads
      : null;
  double? get recoveryRate =>
      halftimeDeficits > 0 ? recoveredDeficits / halftimeDeficits : null;
}

class PlayerUnavailableSnapshot {
  const PlayerUnavailableSnapshot({
    required this.playerId,
    required this.playerName,
    required this.teamId,
    required this.asOf,
    required this.reason,
  });

  final int playerId;
  final String playerName;
  final int teamId;
  final DateTime asOf;
  final String reason;
}

class MatchAnalysisData {
  const MatchAnalysisData({
    this.asOf,
    this.homeStanding,
    this.awayStanding,
    this.leagueStandings = const [],
    this.standingTables = const {},
    this.championshipTierSnapshot,
    this.structuralRelation,
    this.contextKeys = const [],
    this.contextKeyAvailability = MatchContextKeyAvailability.unavailable,
    this.homeRecentLeagueMatches = const [],
    this.awayRecentLeagueMatches = const [],
    this.leagueRecentLeagueMatches = const {},
    this.homeStatistics,
    this.awayStatistics,
    this.leagueTeamStatistics = const [],
    this.homeExpectedGoals,
    this.awayExpectedGoals,
    this.leagueExpectedGoals = const [],
    this.homePlayerStatistics = const [],
    this.awayPlayerStatistics = const [],
    this.leaguePlayerStatistics = const [],
    this.unavailablePlayers = const [],
    this.homePerformanceStatistics,
    this.awayPerformanceStatistics,
    this.leaguePerformanceStatistics = const [],
    this.homeGoalProfile,
    this.awayGoalProfile,
    this.leagueGoalProfiles = const [],
    this.homeDomesticContext,
    this.awayDomesticContext,
    this.tournamentPaths = const [],
    this.containsPredictions = false,
  });

  final DateTime? asOf;
  final TeamStandingSnapshot? homeStanding;
  final TeamStandingSnapshot? awayStanding;
  final List<TeamStandingSnapshot> leagueStandings;
  final Map<ChampionshipStandingView, List<TeamStandingSnapshot>>
  standingTables;
  final ChampionshipTierSnapshot? championshipTierSnapshot;
  final MatchStructuralRelation? structuralRelation;
  final List<MatchContextKey> contextKeys;
  final MatchContextKeyAvailability contextKeyAvailability;
  final List<TeamRecentMatchSnapshot> homeRecentLeagueMatches;
  final List<TeamRecentMatchSnapshot> awayRecentLeagueMatches;
  final Map<int, List<TeamRecentMatchSnapshot>> leagueRecentLeagueMatches;
  final TeamStatisticsSnapshot? homeStatistics;
  final TeamStatisticsSnapshot? awayStatistics;
  final List<TeamStatisticsSnapshot> leagueTeamStatistics;
  final TeamExpectedGoalsSnapshot? homeExpectedGoals;
  final TeamExpectedGoalsSnapshot? awayExpectedGoals;
  final List<TeamExpectedGoalsSnapshot> leagueExpectedGoals;
  final List<PlayerSeasonStatisticsSnapshot> homePlayerStatistics;
  final List<PlayerSeasonStatisticsSnapshot> awayPlayerStatistics;
  final List<PlayerSeasonStatisticsSnapshot> leaguePlayerStatistics;
  final List<PlayerUnavailableSnapshot> unavailablePlayers;
  final TeamPerformanceStatisticsSnapshot? homePerformanceStatistics;
  final TeamPerformanceStatisticsSnapshot? awayPerformanceStatistics;
  final List<TeamPerformanceStatisticsSnapshot> leaguePerformanceStatistics;
  final TeamGoalProfileSnapshot? homeGoalProfile;
  final TeamGoalProfileSnapshot? awayGoalProfile;
  final List<TeamGoalProfileSnapshot> leagueGoalProfiles;

  /// Domestic-league evidence for a team taking part in a continental match.
  ///
  /// It stays separate from the tournament table: two clubs from different
  /// countries must never be compared as if they shared one championship.
  final TeamCompetitionContext? homeDomesticContext;
  final TeamCompetitionContext? awayDomesticContext;
  final List<TournamentPathSnapshot> tournamentPaths;
  final bool containsPredictions;

  bool get hasStandings =>
      homeStanding != null ||
      awayStanding != null ||
      leagueStandings.isNotEmpty;

  List<TeamStandingSnapshot> standingsFor(ChampionshipStandingView view) {
    if (view == ChampionshipStandingView.general) {
      return leagueStandings;
    }
    return standingTables[view] ?? const [];
  }

  bool get hasStatistics => homeStatistics != null || awayStatistics != null;
  bool get hasRecentLeagueMatches =>
      homeRecentLeagueMatches.isNotEmpty || awayRecentLeagueMatches.isNotEmpty;
  bool get hasExpectedGoals =>
      homeExpectedGoals != null || awayExpectedGoals != null;
  bool get hasPlayerStatistics =>
      homePlayerStatistics.isNotEmpty || awayPlayerStatistics.isNotEmpty;
  bool get hasPerformanceStatistics =>
      homePerformanceStatistics != null || awayPerformanceStatistics != null;
  bool get hasAnalysisData =>
      hasStandings ||
      hasStatistics ||
      hasRecentLeagueMatches ||
      hasExpectedGoals ||
      hasPlayerStatistics ||
      hasPerformanceStatistics;

  MatchAnalysisData copyWith({
    DateTime? asOf,
    TeamStandingSnapshot? homeStanding,
    TeamStandingSnapshot? awayStanding,
    List<TeamStandingSnapshot>? leagueStandings,
    Map<ChampionshipStandingView, List<TeamStandingSnapshot>>? standingTables,
    ChampionshipTierSnapshot? championshipTierSnapshot,
    MatchStructuralRelation? structuralRelation,
    List<MatchContextKey>? contextKeys,
    MatchContextKeyAvailability? contextKeyAvailability,
    List<TeamRecentMatchSnapshot>? homeRecentLeagueMatches,
    List<TeamRecentMatchSnapshot>? awayRecentLeagueMatches,
    Map<int, List<TeamRecentMatchSnapshot>>? leagueRecentLeagueMatches,
    TeamStatisticsSnapshot? homeStatistics,
    TeamStatisticsSnapshot? awayStatistics,
    List<TeamStatisticsSnapshot>? leagueTeamStatistics,
    TeamExpectedGoalsSnapshot? homeExpectedGoals,
    TeamExpectedGoalsSnapshot? awayExpectedGoals,
    List<TeamExpectedGoalsSnapshot>? leagueExpectedGoals,
    List<PlayerSeasonStatisticsSnapshot>? homePlayerStatistics,
    List<PlayerSeasonStatisticsSnapshot>? awayPlayerStatistics,
    List<PlayerSeasonStatisticsSnapshot>? leaguePlayerStatistics,
    List<PlayerUnavailableSnapshot>? unavailablePlayers,
    TeamPerformanceStatisticsSnapshot? homePerformanceStatistics,
    TeamPerformanceStatisticsSnapshot? awayPerformanceStatistics,
    List<TeamPerformanceStatisticsSnapshot>? leaguePerformanceStatistics,
    TeamGoalProfileSnapshot? homeGoalProfile,
    TeamGoalProfileSnapshot? awayGoalProfile,
    List<TeamGoalProfileSnapshot>? leagueGoalProfiles,
    TeamCompetitionContext? homeDomesticContext,
    TeamCompetitionContext? awayDomesticContext,
    List<TournamentPathSnapshot>? tournamentPaths,
    bool? containsPredictions,
  }) {
    return MatchAnalysisData(
      asOf: asOf ?? this.asOf,
      homeStanding: homeStanding ?? this.homeStanding,
      awayStanding: awayStanding ?? this.awayStanding,
      leagueStandings: leagueStandings ?? this.leagueStandings,
      standingTables: standingTables ?? this.standingTables,
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
      leagueRecentLeagueMatches:
          leagueRecentLeagueMatches ?? this.leagueRecentLeagueMatches,
      homeStatistics: homeStatistics ?? this.homeStatistics,
      awayStatistics: awayStatistics ?? this.awayStatistics,
      leagueTeamStatistics: leagueTeamStatistics ?? this.leagueTeamStatistics,
      homeExpectedGoals: homeExpectedGoals ?? this.homeExpectedGoals,
      awayExpectedGoals: awayExpectedGoals ?? this.awayExpectedGoals,
      leagueExpectedGoals: leagueExpectedGoals ?? this.leagueExpectedGoals,
      homePlayerStatistics: homePlayerStatistics ?? this.homePlayerStatistics,
      awayPlayerStatistics: awayPlayerStatistics ?? this.awayPlayerStatistics,
      leaguePlayerStatistics:
          leaguePlayerStatistics ?? this.leaguePlayerStatistics,
      unavailablePlayers: unavailablePlayers ?? this.unavailablePlayers,
      homePerformanceStatistics:
          homePerformanceStatistics ?? this.homePerformanceStatistics,
      awayPerformanceStatistics:
          awayPerformanceStatistics ?? this.awayPerformanceStatistics,
      leaguePerformanceStatistics:
          leaguePerformanceStatistics ?? this.leaguePerformanceStatistics,
      homeGoalProfile: homeGoalProfile ?? this.homeGoalProfile,
      awayGoalProfile: awayGoalProfile ?? this.awayGoalProfile,
      leagueGoalProfiles: leagueGoalProfiles ?? this.leagueGoalProfiles,
      homeDomesticContext: homeDomesticContext ?? this.homeDomesticContext,
      awayDomesticContext: awayDomesticContext ?? this.awayDomesticContext,
      tournamentPaths: tournamentPaths ?? this.tournamentPaths,
      containsPredictions: containsPredictions ?? this.containsPredictions,
    );
  }
}

class TournamentPathSnapshot {
  const TournamentPathSnapshot({
    required this.teamId,
    required this.teamName,
    required this.played,
    required this.averageOpponentPointsPerGame,
  });

  final int teamId;
  final String teamName;
  final int played;
  final double averageOpponentPointsPerGame;
}

class TeamCompetitionContext {
  const TeamCompetitionContext({
    required this.competition,
    required this.teamId,
    this.standing,
    this.leagueStandings = const [],
    this.standingTables = const {},
    this.statistics,
    this.recentMatches = const [],
    this.expectedGoals,
    this.playerStatistics = const [],
  });

  final CompetitionInfo competition;
  final int teamId;
  final TeamStandingSnapshot? standing;
  final List<TeamStandingSnapshot> leagueStandings;
  final Map<ChampionshipStandingView, List<TeamStandingSnapshot>>
  standingTables;
  final TeamStatisticsSnapshot? statistics;
  final List<TeamRecentMatchSnapshot> recentMatches;
  final TeamExpectedGoalsSnapshot? expectedGoals;
  final List<PlayerSeasonStatisticsSnapshot> playerStatistics;

  int? get played => standing?.played ?? statistics?.playedTotal;
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
    this.goalsForByMinute = const {},
    this.goalsAgainstByMinute = const {},
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
  final Map<String, int> goalsForByMinute;
  final Map<String, int> goalsAgainstByMinute;
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

    return goals - xg * sampleSize;
  }

  double? get goalsConcededMinusXgAgainst5 {
    final goals = goalsAgainst5;
    final xg = rollingXgAgainst5;
    if (goals == null || xg == null) {
      return null;
    }

    return goals - xg * sampleSize;
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
    this.betRecommendations = const [],
    this.analysis = const MatchAnalysisData(),
    this.profileStatus = MatchProfileStatus.inProfile,
    this.profileRelevance = MatchProfileRelevance.none,
    this.thesis,
  });

  final NormalizedFixture fixture;
  final MarketOdds primaryMarket;
  final List<MatchMarket> availableMarkets;
  final List<BetCandidate> betCandidates;
  final List<BetRecommendation> betRecommendations;
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
    List<BetRecommendation>? betRecommendations,
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
      betRecommendations: betRecommendations ?? this.betRecommendations,
      analysis: analysis ?? this.analysis,
      profileStatus: profileStatus ?? this.profileStatus,
      profileRelevance: profileRelevance ?? this.profileRelevance,
      compatibility: compatibility ?? this.compatibility,
      signals: signals ?? this.signals,
      thesis: thesis ?? this.thesis,
    );
  }
}
