import 'package:copilot/features/matches/domain/analysis_maturity.dart';
import 'package:copilot/features/matches/domain/market_assessment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('selectSuggestedBetCandidate', () {
    test('is independent from the candidate list order', () {
      final deeper = _candidate(
        selectionId: 'home',
        readings: const ['strong_home_team', 'weak_away_team'],
        theses: const ['expected_domination'],
      );
      final weaker = _candidate(
        selectionId: 'over',
        readings: const ['prolific_attack'],
        theses: const [],
      );

      expect(
        selectSuggestedBetCandidate([deeper, weaker])?.selectionId,
        'home',
      );
      expect(
        selectSuggestedBetCandidate([weaker, deeper])?.selectionId,
        'home',
      );
    });

    test('rejects a contradicted candidate before comparing support', () {
      final clean = _candidate(selectionId: 'clean', readings: const ['form']);
      final contradicted = _candidate(
        selectionId: 'contradicted',
        readings: const ['attack', 'defense'],
        theses: const ['expected_domination'],
        contradictions: const ['conflicting_signals'],
      );

      expect(selectSuggestedBetCandidate([contradicted, clean]), clean);
    });

    test('abstains when automatic candidates are analytically equivalent', () {
      final home = _candidate(
        selectionId: 'home',
        readings: const ['strong_home_team', 'weak_away_team'],
      );
      final doubleChance = _candidate(
        selectionId: '1x',
        readings: const ['strong_home_team', 'weak_away_team'],
      );

      expect(selectSuggestedBetCandidate([home, doubleChance]), isNull);
      expect(selectSuggestedBetCandidate([doubleChance, home]), isNull);
    });

    test('abstains for EARLY candidates and accepts odds below 1.20', () {
      final early = _candidate(
        selectionId: 'early',
        maturity: AnalysisMaturity.early,
      );
      final lowOdds = _candidate(selectionId: '1x', odds: 1.11);

      expect(selectSuggestedBetCandidate([early]), isNull);
      expect(selectSuggestedBetCandidate([lowOdds]), lowOdds);
    });
  });
}

BetCandidate _candidate({
  required String selectionId,
  double odds = 1.52,
  List<String> readings = const ['reading'],
  List<String> theses = const ['thesis'],
  List<String> contradictions = const [],
  AnalysisMaturity maturity = AnalysisMaturity.established,
}) {
  return BetCandidate(
    matchId: 'fixture',
    marketId: 'market-$selectionId',
    marketLabel: 'Market',
    selectionId: selectionId,
    selectionLabel: selectionId,
    selectionValue: selectionId,
    odds: odds,
    supportingReadingIds: readings,
    supportingThesisIds: theses,
    contradictionIds: contradictions,
    maturity: maturity,
  );
}
