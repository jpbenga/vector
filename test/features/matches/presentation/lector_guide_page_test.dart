import 'package:copilot/app/theme/app_theme.dart';
import 'package:copilot/core/theme/app_theme_controller.dart';
import 'package:copilot/features/matches/presentation/lector_guide_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'The scenario example changes its verdict and opens the exact required reading',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: const LectorScenarioGuidePage(scenarioId: 'solid_favorite'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Supériorité au classement'), findsNWidgets(2));
      expect(find.text('Toutes requises'), findsOneWidget);
      expect(find.textContaining('même équipe'), findsOneWidget);
      expect(
        find.text(
          'Scénario détecté : toutes les lectures requises sont réunies.',
        ),
        findsOneWidget,
      );
      final incomplete = find.byKey(const ValueKey('guide-example-incomplete'));
      await tester.ensureVisible(incomplete);
      await tester.pumpAndSettle();
      await tester.tap(incomplete);
      await tester.pumpAndSettle();
      expect(
        find.text('Scénario non détecté : une condition requise manque.'),
        findsOneWidget,
      );
      expect(
        find.text('Lecture non détectée dans cet exemple'),
        findsOneWidget,
      );
      final link = find.byKey(
        const ValueKey('guide-reading-link-form_advantage'),
      );
      await tester.ensureVisible(link);
      await tester.pumpAndSettle();
      await tester.tap(link);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<LectorReadingGuidePage>(find.byType(LectorReadingGuidePage))
            .readingId,
        'form_advantage',
      );
      expect(
        find.textContaining('au moins 9 points de différence'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final variant in AppThemeVariant.values) {
    testWidgets(
      'Guides stay readable on narrow mobile with large text in ${variant.name}',
      (tester) async {
        tester.view.physicalSize = const Size(320, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        Widget app(Widget page) => MaterialApp(
          theme: AppTheme.forVariant(variant),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.4)),
            child: child!,
          ),
          home: page,
        );
        await tester.pumpWidget(
          app(
            const LectorReadingGuidePage(
              readingId: 'structural_level_gap',
              isFollowed: true,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Dans vos préférences'), findsOneWidget);
        expect(find.textContaining('Exemple fictif'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(
          app(
            const LectorScenarioGuidePage(
              scenarioId: 'solid_favorite',
              isFollowed: false,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final choice = find.byKey(const ValueKey('guide-example-incomplete'));
        await tester.ensureVisible(choice);
        await tester.pumpAndSettle();
        await tester.tap(choice);
        await tester.pumpAndSettle();
        expect(
          find.text('Scénario non détecté : une condition requise manque.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
