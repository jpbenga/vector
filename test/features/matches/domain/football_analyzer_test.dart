import 'package:copilot/features/matches/domain/football_analyzer.dart';
import 'package:copilot/features/matches/domain/analysis_maturity.dart';
import 'package:copilot/features/matches/domain/football_reading.dart';
import 'package:copilot/features/matches/domain/match_board_item.dart';
import 'package:copilot/features/matches/domain/structural_tiers/tier_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FootballAnalyzer', () {
    test('produces independent readings without selecting a market', () {
      final analysis = const FootballAnalyzer().analyze(_match());

      expect(analysis.has('structural_level_gap', subjectTeamId: 'home'), true);
      expect(analysis.has('positive_streak', subjectTeamId: 'home'), true);
      expect(analysis.has('strong_home_team', subjectTeamId: 'home'), true);
      expect(analysis.has('prolific_attack', subjectTeamId: 'home'), true);
      expect(analysis.has('fragile_defense', subjectTeamId: 'away'), true);
      expect(
        analysis.supportingReadings.every(
          (reading) => reading.evidence.isNotEmpty,
        ),
        true,
      );
    });

    test('does not classify xG with a legacy absolute cutoff', () {
      final analysis = const FootballAnalyzer().analyze(
        _match(
          homeExpectedGoals: TeamExpectedGoalsSnapshot(
            teamId: 10,
            teamName: 'Home',
            asOf: DateTime.utc(2026, 7, 29, 10),
            sampleSize: 5,
            rollingXgFor5: 1.82,
            rollingXgAgainst5: 0.88,
            goalsFor5: 6,
            goalsAgainst5: 5,
          ),
        ),
      );

      expect(analysis.has('high_xg_creation', subjectTeamId: 'home'), false);
      expect(
        analysis.has('offensive_overperformance', subjectTeamId: 'home'),
        false,
      );
    });

    test('rejects xG captured after kickoff for a pre-match reading', () {
      final analysis = const FootballAnalyzer().analyze(
        _match(
          homeExpectedGoals: TeamExpectedGoalsSnapshot(
            teamId: 10,
            teamName: 'Home',
            asOf: DateTime.utc(2026, 7, 30, 21),
            sampleSize: 5,
            rollingXgFor5: 2.10,
            rollingXgAgainst5: 1.80,
            goalsFor5: 9,
            goalsAgainst5: 8,
          ),
        ),
      );

      expect(analysis.has('high_xg_creation', subjectTeamId: 'home'), false);
      final warning = analysis.contradictoryReadings.singleWhere(
        (reading) => reading.subjectTeamId == 'home',
      );
      expect(warning.id, 'insufficient_data');
      expect(warning.warnings.single.id, 'post_match_xg_rejected');
    });

    test('emits insufficient data when no reading can be supported', () {
      final analysis = const FootballAnalyzer().analyze(_emptyMatch());

      expect(analysis.has('insufficient_data'), true);
      expect(analysis.contradictoryReadings.single.id, 'insufficient_data');
    });

    test('ignores retained standing descriptions in current readings', () {
      final analyzer = const FootballAnalyzer();
      final baseline = analyzer.analyze(_match());
      final described = analyzer.analyze(
        _match(
          homeDescription: 'Promotion - Champions League (Qualification)',
          awayDescription: 'Relegation',
        ),
      );

      expect(_readingSignature(described), _readingSignature(baseline));
    });

    test(
      'does not produce structural_level_gap from raw rank or points alone',
      () {
        final analysis = const FootballAnalyzer().analyze(
          _match(withStructuralRelation: false),
        );

        expect(
          analysis.has('ranking_superiority', subjectTeamId: 'home'),
          true,
        );
        expect(
          analysis.has('structural_level_gap', subjectTeamId: 'home'),
          false,
        );
      },
    );

    test('uses the championship distribution for hierarchy', () {
      final narrow = const FootballAnalyzer().analyze(
        _match(
          withStructuralRelation: false,
          homeRank: 3,
          awayRank: 6,
          homePoints: 21,
          awayPoints: 17,
        ),
      );
      expect(narrow.has('ranking_superiority'), isFalse);
    });

    test('analyzes J1, J2 and J5 as EARLY without suppressing the match', () {
      for (final played in [0, 1, 4]) {
        final analysis = const FootballAnalyzer().analyze(
          _match(homePlayed: played, awayPlayed: played),
        );

        expect(analysis.maturity, AnalysisMaturity.early);
        expect(analysis.fixtureId, 'fixture');
        expect(
          analysis.readings.every(
            (reading) => reading.strength == ReadingStrength.weak,
          ),
          isTrue,
        );
      }
    });

    test(
      'marks the sixth scheduled match as ESTABLISHED after five played',
      () {
        final analysis = const FootballAnalyzer().analyze(
          _match(homePlayed: 5, awayPlayed: 5),
        );

        expect(analysis.maturity, AnalysisMaturity.established);
      },
    );

    test('keeps a postponed team EARLY even on a later calendar round', () {
      final analysis = const FootballAnalyzer().analyze(
        _match(homePlayed: 4, awayPlayed: 6),
      );

      expect(analysis.maturity, AnalysisMaturity.early);
    });

    test('does not drop attack or defense below eight played matches', () {
      final analysis = const FootballAnalyzer().analyze(
        _match(homePlayed: 4, awayPlayed: 4),
      );

      expect(analysis.has('prolific_attack', subjectTeamId: 'home'), isTrue);
      expect(analysis.has('fragile_defense', subjectTeamId: 'away'), isTrue);
      expect(analysis.maturity, AnalysisMaturity.early);
    });

    test('does not infer a trajectory from a legacy fixed gap', () {
      final analysis = const FootballAnalyzer().analyze(
        _match(homeForm: 'WWWLL', awayForm: 'LLWWW'),
      );

      expect(analysis.has('improving_form'), false);
      expect(analysis.has('declining_form'), false);
    });
  });
}

MatchBoardItem _match({
  TeamExpectedGoalsSnapshot? homeExpectedGoals,
  String? homeDescription,
  String? awayDescription,
  String homeForm = 'WWWWW',
  String awayForm = 'LLLLL',
  int homeRank = 2,
  int awayRank = 10,
  int homePoints = 24,
  int awayPoints = 11,
  int homePlayed = 10,
  int awayPlayed = 10,
  bool withStructuralRelation = true,
  MatchStructuralRelation? structuralRelation,
}) {
  final homeStanding = TeamStandingSnapshot(
    teamId: 10,
    teamName: 'Home',
    description: homeDescription,
    rank: homeRank,
    points: homePoints,
    played: homePlayed,
    wins: 7,
    draws: 3,
    losses: 0,
    goalsFor: 20,
    goalsAgainst: 8,
    form: homeForm,
  );
  final awayStanding = TeamStandingSnapshot(
    teamId: 11,
    teamName: 'Away',
    description: awayDescription,
    rank: awayRank,
    points: awayPoints,
    played: awayPlayed,
    wins: 3,
    draws: 2,
    losses: 5,
    goalsFor: 11,
    goalsAgainst: 32,
    form: awayForm,
  );
  return MatchBoardItem(
    fixture: NormalizedFixture(
      id: 'fixture',
      competition: const CompetitionInfo(
        id: '39',
        name: 'Premier League',
        country: CountryInfo(code: 'GB', name: 'Angleterre'),
        season: 2026,
      ),
      homeTeam: const TeamInfo(id: 'home', name: 'Home', apiFootballTeamId: 10),
      awayTeam: const TeamInfo(id: 'away', name: 'Away', apiFootballTeamId: 11),
      kickoffLabel: '20:00',
      kickoff: DateTime.utc(2026, 7, 30, 18),
      status: FixtureStatus.scheduled,
    ),
    primaryMarket: const MarketOdds(
      id: 'market_unavailable',
      label: 'Marché indisponible',
      odds: 0,
    ),
    availableMarkets: const [],
    analysis: MatchAnalysisData(
      asOf: DateTime.utc(2026, 7, 30, 8),
      homeStanding: homeStanding,
      awayStanding: awayStanding,
      leagueStandings: _leagueStandings(homeStanding, awayStanding),
      structuralRelation:
          structuralRelation ??
          (withStructuralRelation ? _defaultStructuralRelation() : null),
      homeStatistics: TeamStatisticsSnapshot(
        teamId: 10,
        teamName: 'Home',
        playedTotal: 10,
        playedHome: 5,
        winsTotal: 7,
        winsHome: 4,
        lossesTotal: 0,
        lossesHome: 0,
        goalsForAverageTotal: 1.95,
        goalsAgainstAverageTotal: 0.80,
        cleanSheetsTotal: 5,
      ),
      awayStatistics: TeamStatisticsSnapshot(
        teamId: 11,
        teamName: 'Away',
        playedTotal: 10,
        playedAway: 5,
        winsTotal: 3,
        lossesTotal: 5,
        lossesAway: 3,
        goalsForAverageTotal: 0.85,
        goalsAgainstAverageTotal: 1.90,
      ),
      homeExpectedGoals: homeExpectedGoals,
    ),
    compatibility: 0,
    signals: const [],
  );
}

List<TeamStandingSnapshot> _leagueStandings(
  TeamStandingSnapshot home,
  TeamStandingSnapshot away,
) {
  return [
    home,
    TeamStandingSnapshot(
      teamId: 12,
      teamName: 'Two',
      rank: 1,
      points: 20,
      played: home.played,
      goalsFor: 16,
      goalsAgainst: 10,
      form: 'WWWDD',
    ),
    TeamStandingSnapshot(
      teamId: 13,
      teamName: 'Three',
      rank: 3,
      points: 18,
      played: home.played,
      goalsFor: 15,
      goalsAgainst: 11,
      form: 'WWDDL',
    ),
    TeamStandingSnapshot(
      teamId: 14,
      teamName: 'Four',
      rank: 4,
      points: 16,
      played: home.played,
      goalsFor: 14,
      goalsAgainst: 12,
      form: 'WDDLL',
    ),
    TeamStandingSnapshot(
      teamId: 15,
      teamName: 'Five',
      rank: 5,
      points: 14,
      played: home.played,
      goalsFor: 13,
      goalsAgainst: 13,
      form: 'DDLLL',
    ),
    TeamStandingSnapshot(
      teamId: 16,
      teamName: 'Six',
      rank: 6,
      points: 12,
      played: home.played,
      goalsFor: 12,
      goalsAgainst: 14,
      form: 'DLLLW',
    ),
    TeamStandingSnapshot(
      teamId: 17,
      teamName: 'Seven',
      rank: 7,
      points: 10,
      played: home.played,
      goalsFor: 11,
      goalsAgainst: 15,
      form: 'LLLWW',
    ),
    TeamStandingSnapshot(
      teamId: 18,
      teamName: 'Eight',
      rank: 8,
      points: 8,
      played: home.played,
      goalsFor: 10,
      goalsAgainst: 16,
      form: 'LLWWW',
    ),
    TeamStandingSnapshot(
      teamId: 19,
      teamName: 'Nine',
      rank: 9,
      points: 6,
      played: home.played,
      goalsFor: 9,
      goalsAgainst: 17,
      form: 'LWWLL',
    ),
    away,
  ];
}

MatchStructuralRelation _defaultStructuralRelation() {
  return MatchStructuralRelation(
    competitionId: '39',
    season: 2026,
    analysisAsOf: DateTime.utc(2026, 7, 30, 8),
    tierSystemVersion: 'tier-v1',
    standingsSnapshotIdentity: 'snapshot-1',
    homeTeamId: 10,
    awayTeamId: 11,
    homeTeamTier: TierLabel.tier1Podium,
    awayTeamTier: TierLabel.tier4LowerChampionship,
    sameTier: false,
    ordinalTierGap: 3,
    structuralBoundaryGap: 1,
    confirmedBoundariesBetweenTeams: const [
      ConfirmedStructuralBoundary(
        boundaryIndex: 3,
        upperRank: 3,
        lowerRank: 4,
        rawGap: 12,
        score: 80,
        strength: BoundaryStrength.strong,
        standingsSnapshotIdentity: 'snapshot-1',
      ),
    ],
    tierMaturity: TierMaturity.mature,
    tierStatus: TierSystemStatus.mature,
    championshipTeamCount: 10,
    typicalGap: 1,
    homeOfficialRank: 2,
    awayOfficialRank: 10,
    homePoints: 24,
    awayPoints: 11,
    homeStructuralLevelGap: const StructuralLevelGapAssessment(
      exists: true,
      strength: StructuralLevelGapStrength.moderate,
    ),
    awayStructuralLevelGap: const StructuralLevelGapAssessment(exists: false),
    balancedHierarchy: const BalancedHierarchyAssessment(exists: false),
    warnings: const [],
  );
}

List<String> _readingSignature(FootballAnalysis analysis) {
  return analysis.readings
      .map(
        (reading) =>
            '${reading.id}:'
            '${reading.subjectTeamId}:'
            '${reading.subjectSide.name}:'
            '${reading.status.name}:'
            '${reading.strength.name}:'
            '${reading.isContradiction}',
      )
      .toList(growable: false);
}

MatchBoardItem _emptyMatch() {
  return MatchBoardItem(
    fixture: const NormalizedFixture(
      id: 'empty',
      competition: CompetitionInfo(
        id: '39',
        name: 'Premier League',
        country: CountryInfo(code: 'GB', name: 'Angleterre'),
        season: 2026,
      ),
      homeTeam: TeamInfo(id: 'home', name: 'Home'),
      awayTeam: TeamInfo(id: 'away', name: 'Away'),
      kickoffLabel: '20:00',
      status: FixtureStatus.scheduled,
    ),
    primaryMarket: const MarketOdds(
      id: 'market_unavailable',
      label: 'Marché indisponible',
      odds: 0,
    ),
    compatibility: 0,
    signals: const [],
  );
}
