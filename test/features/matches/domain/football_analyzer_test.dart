import 'package:copilot/features/matches/domain/football_analyzer.dart';
import 'package:copilot/features/matches/domain/match_board_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FootballAnalyzer', () {
    test('produces independent readings without selecting a market', () {
      final analysis = const FootballAnalyzer().analyze(_match());

      expect(analysis.has('structural_level_gap', subjectTeamId: 'home'), true);
      expect(analysis.has('positive_streak', subjectTeamId: 'home'), true);
      expect(analysis.has('strong_home_team', subjectTeamId: 'home'), true);
      expect(analysis.has('weak_away_team', subjectTeamId: 'away'), true);
      expect(analysis.has('prolific_attack', subjectTeamId: 'home'), true);
      expect(analysis.has('fragile_defense', subjectTeamId: 'away'), true);
      expect(
        analysis.supportingReadings.every(
          (reading) => reading.evidence.isNotEmpty,
        ),
        true,
      );
    });

    test('derives expected-goals readings from pre-match rolling xG only', () {
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

      expect(analysis.has('high_xg_creation', subjectTeamId: 'home'), true);
      expect(
        analysis.has('offensive_overperformance', subjectTeamId: 'home'),
        true,
      );
      expect(
        analysis.has('defensive_underperformance', subjectTeamId: 'home'),
        true,
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
  });
}

MatchBoardItem _match({TeamExpectedGoalsSnapshot? homeExpectedGoals}) {
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
      homeStanding: TeamStandingSnapshot(
        teamId: 10,
        teamName: 'Home',
        rank: 2,
        points: 24,
        played: 10,
        wins: 7,
        draws: 3,
        losses: 0,
        goalsFor: 20,
        goalsAgainst: 8,
        form: 'WWDWW',
      ),
      awayStanding: TeamStandingSnapshot(
        teamId: 11,
        teamName: 'Away',
        rank: 10,
        points: 11,
        played: 10,
        wins: 3,
        draws: 2,
        losses: 5,
        goalsFor: 11,
        goalsAgainst: 18,
        form: 'LLDLW',
      ),
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
