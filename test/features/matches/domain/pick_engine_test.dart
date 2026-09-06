import 'package:copilot/features/matches/domain/analysis_maturity.dart';
import 'package:copilot/features/matches/domain/market_assessment.dart';
import 'package:copilot/features/matches/domain/match_board_item.dart';
import 'package:copilot/features/matches/domain/pick_engine.dart';
import 'package:copilot/features/onboarding/domain/decision_profile.dart';
import 'package:copilot/features/onboarding/domain/onboarding_answer.dart';
import 'package:copilot/features/onboarding/domain/profile_compiler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'filters configured markets before selecting an automatic candidate',
    () {
      final match = _matchWithEquivalentCandidates();
      final profile = const ProfileCompiler().compile(
        const DecisionProfile(
          onboardingVersion: '3.0',
          answers: [
            OnboardingAnswer(
              questionId: 'competitions',
              orderedOptionIds: ['61'],
            ),
            OnboardingAnswer(
              questionId: 'markets',
              orderedOptionIds: ['match_result'],
            ),
          ],
        ),
      );

      final picks = const PickEngine().eligiblePicks(
        matches: [match],
        profile: profile,
      );

      expect(picks, hasLength(1));
      expect(picks.single.marketId, 'matchResult');
      expect(picks.single.selectionLabel, 'Home');
    },
  );
}

MatchBoardItem _matchWithEquivalentCandidates() {
  const homeSelection = MarketOdds(id: 'home', label: 'Home', odds: 1.52);
  const doubleChanceSelection = MarketOdds(id: '1x', label: '1X', odds: 1.13);
  const readings = ['strong_home_team', 'weak_away_team'];
  return MatchBoardItem(
    fixture: NormalizedFixture(
      id: 'fixture',
      competition: const CompetitionInfo(
        id: '61',
        name: 'Ligue 1',
        country: CountryInfo(code: 'FR', name: 'France'),
        season: 2026,
      ),
      homeTeam: const TeamInfo(id: 'home', name: 'Home'),
      awayTeam: const TeamInfo(id: 'away', name: 'Away'),
      kickoffLabel: '20:00',
      kickoff: DateTime.utc(2026, 8, 9, 18),
      status: FixtureStatus.scheduled,
    ),
    primaryMarket: homeSelection,
    availableMarkets: const [
      MatchMarket(
        id: 'matchResult',
        label: 'Résultat du match',
        selections: [homeSelection],
      ),
      MatchMarket(
        id: 'doubleChance',
        label: 'Double chance',
        selections: [doubleChanceSelection],
      ),
    ],
    betCandidates: const [
      BetCandidate(
        matchId: 'fixture',
        marketId: 'matchResult',
        marketLabel: 'Résultat du match',
        selectionId: 'home',
        selectionLabel: 'Home',
        selectionValue: 'Home',
        odds: 1.52,
        supportingReadingIds: readings,
        supportingThesisIds: ['expected_domination'],
        contradictionIds: [],
        maturity: AnalysisMaturity.established,
      ),
      BetCandidate(
        matchId: 'fixture',
        marketId: 'doubleChance',
        marketLabel: 'Double chance',
        selectionId: '1x',
        selectionLabel: '1X',
        selectionValue: 'Home/Draw',
        odds: 1.13,
        supportingReadingIds: readings,
        supportingThesisIds: ['expected_domination'],
        contradictionIds: [],
        maturity: AnalysisMaturity.established,
      ),
    ],
    compatibility: 0,
    signals: const [],
  );
}
