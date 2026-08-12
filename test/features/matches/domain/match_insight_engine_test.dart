import 'package:copilot/features/matches/domain/match_board_item.dart';
import 'package:copilot/features/matches/domain/match_insight_engine.dart';
import 'package:copilot/features/onboarding/domain/compiled_decision_profile.dart';
import 'package:copilot/features/onboarding/domain/decision_profile.dart';
import 'package:copilot/features/onboarding/domain/onboarding_answer.dart';
import 'package:copilot/features/onboarding/domain/profile_compiler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MatchInsightEngine', () {
    test('recommends only matches from enabled competitions', () {
      final profile = _compiledProfile(
        competitionIds: ['fr_ligue_1'],
        marketIds: ['double_chance'],
      );

      final recommendations = const MatchInsightEngine().recommendations([
        _match(),
        _match(competitionId: '135', fixtureId: 'italy'),
      ], profile);

      expect(recommendations, hasLength(1));
      expect(recommendations.single.competition.id, '61');
      expect(recommendations.single.compatibility, greaterThan(0));
    });

    test('keeps a detected thesis as watchlist when markets are disabled', () {
      final profile = _compiledProfile(
        competitionIds: ['fr_ligue_1'],
        marketIds: ['match_result'],
      );

      final analyzed = const MatchInsightEngine().analyze(_match(), profile);

      expect(analyzed.compatibility, 0);
      expect(analyzed.thesis?.status, MatchThesisStatus.watchlist);
      expect(analyzed.thesis?.id, 'expected_domination');
      expect(analyzed.thesis?.recommendedMarket, isNull);
    });

    test('keeps an opportunity even when no market can translate it', () {
      final profile = _compiledProfile(
        competitionIds: ['fr_ligue_1'],
        marketIds: ['match_result'],
      );

      final opportunities = const MatchInsightEngine().opportunities([
        _match(),
      ], profile);

      expect(opportunities, hasLength(1));
      expect(opportunities.single.matchId, 'fixture');
      expect(
        opportunities.single.retainedTheses.single.id,
        'expected_domination',
      );
      expect(opportunities.single.compatibleMarkets, isEmpty);
      expect(opportunities.single.recommendedMarket, isNull);
      expect(opportunities.single.engineScore, greaterThan(0));
      expect(
        opportunities.single.opportunityProfileIds,
        contains('ranking_gap'),
      );
    });

    test('recommends a market only after a supported thesis is detected', () {
      final profile = _compiledProfile(
        competitionIds: ['fr_ligue_1'],
        marketIds: ['double_chance'],
        matchTypes: ['ranking_gap'],
      );

      final analyzed = const MatchInsightEngine().analyze(_match(), profile);

      expect(analyzed.compatibility, greaterThan(0));
      expect(analyzed.primaryMarket.label, '1X');
      expect(analyzed.primaryMarket.odds, 1.55);
      expect(analyzed.thesis?.status, MatchThesisStatus.recommended);
      expect(analyzed.thesis?.id, 'expected_domination');
      expect(analyzed.thesis?.recommendedMarket?.market.id, 'doubleChance');
      expect(analyzed.thesis?.supportingEvidence, isNotEmpty);
      expect(analyzed.thesis?.arguments, isNotEmpty);
      expect(
        analyzed.thesis?.arguments.first.type,
        CopilotArgumentType.rankingGap,
      );
      expect(analyzed.signals.single.id, 'expected_domination');
    });

    test('keeps one opportunity with several compatible markets', () {
      final profile = _compiledProfile(
        competitionIds: ['fr_ligue_1'],
        marketIds: ['double_chance', 'match_result'],
        matchTypes: ['ranking_gap'],
      );

      final opportunities = const MatchInsightEngine().opportunities([
        _match(includeMatchResult: true),
      ], profile);

      expect(opportunities, hasLength(1));
      expect(
        opportunities.single.retainedTheses.first.id,
        'expected_domination',
      );
      expect(opportunities.single.compatibleMarkets, hasLength(2));
      expect(
        opportunities.single.compatibleMarkets.map((fit) => fit.market.id),
        ['matchResult', 'doubleChance'],
      );
      expect(opportunities.single.recommendedMarket?.market.id, 'matchResult');
    });

    test('does not propose a thesis disabled by matchTypes', () {
      final profile = _compiledProfile(
        competitionIds: ['fr_ligue_1'],
        marketIds: ['double_chance'],
        matchTypes: ['credible_outsider'],
      );

      final analyzed = const MatchInsightEngine().analyze(_match(), profile);

      expect(analyzed.compatibility, 0);
      expect(analyzed.thesis?.status, MatchThesisStatus.notRecommended);
      expect(analyzed.thesis?.id, 'no_sufficient_thesis');
      expect(analyzed.thesis?.recommendedMarket, isNull);
    });

    test('keeps analytical reading separate from profile availability', () {
      final profile = _compiledProfile(
        competitionIds: ['ita_serie_a'],
        marketIds: ['double_chance'],
      );

      final analyzed = const MatchInsightEngine().analyze(_match(), profile);

      expect(analyzed.profileStatus, MatchProfileStatus.outOfProfile);
      expect(analyzed.compatibility, 0);
      expect(analyzed.thesis?.id, 'level_gap');
      expect(analyzed.thesis?.status, MatchThesisStatus.watchlist);
      expect(analyzed.thesis?.recommendedMarket, isNull);
      expect(analyzed.thesis?.arguments, isNotEmpty);
    });
  });
}

CompiledDecisionProfile _compiledProfile({
  required List<String> competitionIds,
  required List<String> marketIds,
  List<String> matchTypes = const ['ranking_gap'],
}) {
  return const ProfileCompiler().compile(
    DecisionProfile(
      onboardingVersion: 'test',
      answers: [
        OnboardingAnswer(
          questionId: 'competitions',
          orderedOptionIds: competitionIds,
        ),
        OnboardingAnswer(questionId: 'markets', orderedOptionIds: marketIds),
        OnboardingAnswer(
          questionId: 'opportunity_profiles',
          orderedOptionIds: matchTypes,
        ),
      ],
    ),
  );
}

MatchBoardItem _match({
  String fixtureId = 'fixture',
  String competitionId = '61',
  bool includeMatchResult = false,
}) {
  return MatchBoardItem(
    fixture: NormalizedFixture(
      id: fixtureId,
      competition: CompetitionInfo(
        id: competitionId,
        name: competitionId,
        country: const CountryInfo(code: 'FR', name: 'France'),
        season: 2026,
      ),
      homeTeam: const TeamInfo(id: 'home', name: 'Home', apiFootballTeamId: 10),
      awayTeam: const TeamInfo(id: 'away', name: 'Away', apiFootballTeamId: 11),
      kickoffLabel: '20:00',
      status: FixtureStatus.scheduled,
    ),
    primaryMarket: const MarketOdds(
      id: 'market_unavailable',
      label: 'Marché indisponible',
      odds: 0,
    ),
    availableMarkets: [
      MatchMarket(
        id: 'doubleChance',
        label: 'Double chance',
        selections: [
          MarketOdds(id: 'double_chance_1x', label: '1X', odds: 1.55),
        ],
        bookmakerName: 'Unibet',
      ),
      if (includeMatchResult)
        const MatchMarket(
          id: 'matchResult',
          label: 'Résultat du match',
          selections: [
            MarketOdds(id: 'match_result_home', label: '1', odds: 1.85),
            MarketOdds(id: 'match_result_draw', label: 'N', odds: 3.35),
            MarketOdds(id: 'match_result_away', label: '2', odds: 4.40),
          ],
          bookmakerName: 'Unibet',
        ),
    ],
    analysis: const MatchAnalysisData(
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
        rank: 9,
        points: 12,
        played: 10,
        wins: 3,
        draws: 3,
        losses: 4,
        goalsFor: 11,
        goalsAgainst: 16,
        form: 'LDLDW',
      ),
    ),
    compatibility: 0,
    signals: const [],
  );
}
