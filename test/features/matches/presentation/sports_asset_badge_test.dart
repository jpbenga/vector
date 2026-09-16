import 'package:copilot/features/matches/presentation/widgets/sports_asset_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SportsAssetBadge contrast plate', () {
    testWidgets('uses a light bordered surface for an image in dark mode', (
      tester,
    ) async {
      final theme = ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Center(
            child: SportsAssetBadge(
              size: 32,
              imageUrl: 'https://example.com/competition.png',
              fallbackLabel: 'Competition',
              contrastPlate: true,
            ),
          ),
        ),
      );

      final decoration =
          tester
                  .widget<DecoratedBox>(
                    find.descendant(
                      of: find.byType(SportsAssetBadge),
                      matching: find.byType(DecoratedBox),
                    ),
                  )
                  .decoration
              as BoxDecoration;

      expect(decoration.border, isNotNull);
      expect(decoration.boxShadow, isNotEmpty);
      expect(
        decoration.color!.computeLuminance(),
        greaterThan(theme.colorScheme.surface.computeLuminance()),
      );
    });

    testWidgets('keeps the standard badge surface unchanged', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Center(
            child: SportsAssetBadge(
              size: 32,
              imageUrl: 'https://example.com/team.png',
              fallbackLabel: 'Team',
              backgroundColor: Colors.transparent,
            ),
          ),
        ),
      );

      final decoration =
          tester
                  .widget<DecoratedBox>(
                    find.descendant(
                      of: find.byType(SportsAssetBadge),
                      matching: find.byType(DecoratedBox),
                    ),
                  )
                  .decoration
              as BoxDecoration;

      expect(decoration.color, Colors.transparent);
      expect(decoration.border, isNull);
      expect(decoration.boxShadow, isNull);
    });
  });
}
