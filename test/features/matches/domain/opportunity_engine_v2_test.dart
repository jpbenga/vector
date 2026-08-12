import 'package:copilot/features/matches/domain/match_board_item.dart';
import 'package:copilot/features/matches/domain/opportunity_engine_v2.dart';
import 'package:copilot/features/onboarding/domain/compiled_decision_profile.dart';
import 'package:copilot/features/onboarding/domain/decision_profile.dart';
import 'package:copilot/features/onboarding/domain/onboarding_answer.dart';
import 'package:copilot/features/onboarding/domain/profile_compiler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OpportunityEngineV2', () {
    test('creates one combined opportunity with readings and a market', () {
      final opportunities = const OpportunityEngineV2().opportunities([
        _match(),
      ], _profile(markets: ['double_chance'], profiles: ['ranking_gap']));

      expect(opportunities, hasLength(1));
      final opportunity = opportunities.single;
      expect(opportunity.retainedTheses.single.id, 'expected_domination');
      expect(opportunity.supportingReadings.length, greaterThanOrEqualTo(3));
      expect(opportunity.recommendedMarket?.market.id, 'doubleChance');
      expect(opportunity.recommendedMarket?.selection.label, '1X');
      expect(opportunity.argumentCount, greaterThanOrEqualTo(3));
      expect(
        opportunity.copilotArguments.map((argument) => argument.subjectName),
        everyElement(isNot(startsWith('api-team-'))),
      );
      expect(
        opportunity.copilotArguments.map((argument) => argument.subjectName),
        contains('Home'),
      );
      expect(
        opportunity.positiveArguments.map((argument) => argument.subjectName),
        everyElement(isNot(startsWith('api-team-'))),
      );
      expect(
        opportunity.positiveArguments.map((argument) => argument.subjectName),
        contains('Home'),
      );
      expect(opportunity.asOf, DateTime.utc(2026, 7, 30, 8));
    });

    test(
      'keeps an opportunity visible when no enabled market translates it',
      () {
        final opportunities = const OpportunityEngineV2().opportunities([
          _match(),
        ], _profile(markets: ['match_result'], profiles: ['ranking_gap']));

        expect(opportunities, hasLength(1));
        expect(
          opportunities.single.retainedTheses.single.id,
          'expected_domination',
        );
        expect(opportunities.single.recommendedMarket, isNull);
        expect(opportunities.single.compatibleMarkets, isEmpty);
        expect(
          opportunities.single.retainedTheses.single.status,
          MatchThesisStatus.watchlist,
        );
      },
    );

    test('can produce avoid_match without proposing a market', () {
      final opportunities = const OpportunityEngineV2().opportunities([
        _balancedConflictingMatch(),
      ], _profile(markets: ['double_chance'], profiles: ['solid_favorite']));

      expect(opportunities, hasLength(1));
      expect(opportunities.single.retainedTheses.single.id, 'avoid_match');
      expect(opportunities.single.recommendedMarket, isNull);
      expect(opportunities.single.compatibleMarkets, isEmpty);
    });

    test('does not create opportunities for incomplete profiles', () {
      final profile = const ProfileCompiler().compile(
        const DecisionProfile(onboardingVersion: 'test', answers: []),
      );

      final opportunities = const OpportunityEngineV2().opportunities([
        _match(),
      ], profile);

      expect(opportunities, isEmpty);
    });
  });
}

CompiledDecisionProfile _profile({
  required List<String> markets,
  required List<String> profiles,
}) {
  return const ProfileCompiler().compile(
    DecisionProfile(
      onboardingVersion: 'test',
      answers: [
        OnboardingAnswer(
          questionId: 'competitions',
          orderedOptionIds: ['eng_premier_league'],
        ),
        OnboardingAnswer(questionId: 'markets', orderedOptionIds: markets),
        OnboardingAnswer(
          questionId: 'opportunity_profiles',
          orderedOptionIds: profiles,
        ),
      ],
    ),
  );
}

MatchBoardItem _match() {
  return MatchBoardItem(
    fixture: NormalizedFixture(
      id: 'fixture',
      competition: const CompetitionInfo(
        id: '39',
        name: 'Premier League',
        country: CountryInfo(code: 'GB', name: 'Angleterre'),
        season: 2026,
      ),
      homeTeam: const TeamInfo(
        id: 'api-team-10',
        name: 'Home',
        apiFootballTeamId: 10,
      ),
      awayTeam: const TeamInfo(
        id: 'api-team-11',
        name: 'Away',
        apiFootballTeamId: 11,
      ),
      kickoffLabel: '20:00',
      kickoff: DateTime.utc(2026, 7, 30, 18),
      status: FixtureStatus.scheduled,
    ),
    primaryMarket: const MarketOdds(
      id: 'market_unavailable',
      label: 'Marché indisponible',
      odds: 0,
    ),
    availableMarkets: const [
      MatchMarket(
        id: 'doubleChance',
        label: 'Double chance',
        selections: [
          MarketOdds(
            id: 'double_chance_1x',
            label: '1X',
            odds: 1.42,
            apiFootballValue: 'Home/Draw',
          ),
        ],
      ),
    ],
    analysis: MatchAnalysisData(
      asOf: DateTime.utc(2026, 7, 30, 8),
      homeStanding: const TeamStandingSnapshot(
        teamId: 10,
        teamName: 'Home',
        rank: 2,
        points: 26,
        played: 10,
        wins: 8,
        draws: 2,
        losses: 0,
        goalsFor: 22,
        goalsAgainst: 8,
        form: 'WWDWW',
      ),
      awayStanding: const TeamStandingSnapshot(
        teamId: 11,
        teamName: 'Away',
        rank: 11,
        points: 11,
        played: 10,
        wins: 3,
        draws: 2,
        losses: 5,
        goalsFor: 10,
        goalsAgainst: 18,
        form: 'LLDLW',
      ),
      homeStatistics: const TeamStatisticsSnapshot(
        teamId: 10,
        teamName: 'Home',
        playedTotal: 10,
        playedHome: 5,
        winsTotal: 8,
        winsHome: 4,
        goalsForAverageTotal: 1.90,
        goalsAgainstAverageTotal: 0.80,
        cleanSheetsTotal: 4,
      ),
      awayStatistics: const TeamStatisticsSnapshot(
        teamId: 11,
        teamName: 'Away',
        playedTotal: 10,
        playedAway: 5,
        lossesTotal: 5,
        lossesAway: 3,
        goalsForAverageTotal: 0.90,
        goalsAgainstAverageTotal: 1.85,
      ),
    ),
    compatibility: 0,
    signals: const [],
  );
}

MatchBoardItem _balancedConflictingMatch() {
  return MatchBoardItem(
    fixture: NormalizedFixture(
      id: 'balanced',
      competition: const CompetitionInfo(
        id: '39',
        name: 'Premier League',
        country: CountryInfo(code: 'GB', name: 'Angleterre'),
        season: 2026,
      ),
      homeTeam: const TeamInfo(id: 'home', name: 'Home'),
      awayTeam: const TeamInfo(id: 'away', name: 'Away'),
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
      homeStanding: const TeamStandingSnapshot(
        teamId: 10,
        teamName: 'Home',
        rank: 5,
        points: 18,
        played: 10,
        form: 'WWWWW',
      ),
      awayStanding: const TeamStandingSnapshot(
        teamId: 11,
        teamName: 'Away',
        rank: 6,
        points: 16,
        played: 10,
        form: 'WDWDW',
      ),
      homeStatistics: const TeamStatisticsSnapshot(
        teamId: 10,
        teamName: 'Home',
        playedTotal: 10,
        goalsForAverageTotal: 1.40,
        goalsAgainstAverageTotal: 1.75,
      ),
      awayStatistics: const TeamStatisticsSnapshot(
        teamId: 11,
        teamName: 'Away',
        playedTotal: 10,
        goalsForAverageTotal: 1.30,
        goalsAgainstAverageTotal: 1.20,
      ),
    ),
    compatibility: 0,
    signals: const [],
  );
}
