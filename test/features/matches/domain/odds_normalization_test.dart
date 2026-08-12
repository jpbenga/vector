import 'package:copilot/features/matches/domain/odds_normalization.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OddsNormalizationCatalog', () {
    test('contains the target MVP bookmakers', () {
      expect(
        OddsNormalizationCatalog.targetBookmakers.map(
          (bookmaker) => bookmaker.apiFootballId,
        ),
        [3, 4, 6, 8, 11, 16],
      );
      expect(
        OddsNormalizationCatalog.bookmakerForApiFootballId(8)?.displayName,
        'Bet365',
      );
      expect(OddsNormalizationCatalog.bookmakerForApiFootballId(27), isNull);
    });

    test('maps API-Football bet ids to MVP internal markets', () {
      expect(
        OddsNormalizationCatalog.marketForApiFootballBetId(45)?.internalId,
        InternalMarketId.cornersTotal,
      );
      expect(
        OddsNormalizationCatalog.marketForApiFootballBetId(80)?.internalId,
        InternalMarketId.cardsTotal,
      );
      expect(OddsNormalizationCatalog.marketForApiFootballBetId(4), isNull);
    });

    test('normalizes double chance values', () {
      final selection = OddsNormalizationCatalog.normalizeSelection(
        apiFootballBetId: 12,
        rawValue: 'Home/Draw',
      );

      expect(selection?.marketId, InternalMarketId.doubleChance);
      expect(selection?.side, InternalSelectionSide.home);
      expect(selection?.secondarySide, InternalSelectionSide.draw);
      expect(selection?.stableId, 'doubleChance:home:draw');
    });

    test('normalizes goal, corner and card totals', () {
      final goals = OddsNormalizationCatalog.normalizeSelection(
        apiFootballBetId: 5,
        rawValue: 'Over 2.5',
      );
      final corners = OddsNormalizationCatalog.normalizeSelection(
        apiFootballBetId: 45,
        rawValue: 'Under 9.5',
      );
      final cards = OddsNormalizationCatalog.normalizeSelection(
        apiFootballBetId: 80,
        rawValue: 'Over 4.5',
      );

      expect(goals?.stableId, 'goalsTotal:over:2.50');
      expect(corners?.stableId, 'cornersTotal:under:9.50');
      expect(cards?.stableId, 'cardsTotal:over:4.50');
    });

    test('normalizes both teams score and match winner markets', () {
      final btts = OddsNormalizationCatalog.normalizeSelection(
        apiFootballBetId: 8,
        rawValue: 'Yes',
      );
      final matchWinner = OddsNormalizationCatalog.normalizeSelection(
        apiFootballBetId: 1,
        rawValue: 'Away',
      );

      expect(btts?.stableId, 'bothTeamsScore:yes');
      expect(matchWinner?.stableId, 'matchResult:away');
      expect(OddsNormalizationCatalog.marketForApiFootballBetId(55), isNull);
    });
  });
}
