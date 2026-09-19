import 'package:copilot/core/theme/app_theme.dart';
import 'package:copilot/features/matches/presentation/lector_preferences_sheet.dart';
import 'package:copilot/features/onboarding/domain/decision_profile.dart';
import 'package:copilot/features/onboarding/domain/onboarding_answer.dart';
import 'package:copilot/features/onboarding/domain/decision_profile_catalogs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const profile = DecisionProfile(
    onboardingVersion: 'test',
    answers: [
      OnboardingAnswer(
        questionId: 'readings',
        orderedOptionIds: ['structural_level_gap', 'strong_home_team'],
      ),
    ],
  );

  Future<void> openSheet(
    WidgetTester tester, {
    required ValueChanged<DecisionProfile> onSaved,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CopilotTheme.dark,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () => showReadingPreferencesSheet(
                  context: context,
                  profile: profile,
                  onProfileChanged: (updated) async => onSaved(updated),
                ),
                child: const Text('Ouvrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('selects all, clears all, then saves one complete theme', (
    tester,
  ) async {
    DecisionProfile? saved;
    await openSheet(tester, onSaved: (profile) => saved = profile);

    expect(find.text('Niveau, forme et lieu'), findsOneWidget);
    expect(find.text('2 lectures suivies'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('reading-select-all')));
    await tester.pumpAndSettle();
    expect(
      find.text('${ReadingPreferenceCatalog.values.length} lectures suivies'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('reading-deselect-all')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('reading-select-group-ranking_form')),
    );
    await tester.tap(
      find.byKey(const ValueKey('reading-select-group-ranking_form')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.optionIdsFor('readings'), [
      'structural_level_gap',
      'positive_streak',
      'negative_streak',
      'improving_form',
      'declining_form',
      'strong_home_team',
      'weak_home_team',
      'strong_away_team',
      'weak_away_team',
      'home_away_advantage',
      'away_home_advantage',
    ]);
  });

  testWidgets(
    'does not expose statistical projections as selectable readings',
    (tester) async {
      DecisionProfile? saved;
      await openSheet(tester, onSaved: (profile) => saved = profile);

      await tester.enterText(
        find.byKey(const ValueKey('reading-search')),
        'corner',
      );
      await tester.pumpAndSettle();

      expect(find.text('Tirs, corners et cartons'), findsNothing);
      expect(find.text('Potentiel corners'), findsNothing);
      expect(find.text('Intensité des cartons'), findsNothing);
      expect(saved, isNull);
    },
  );

  testWidgets('mobile sheet filters to followed readings', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await openSheet(tester, onSaved: (_) {});
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('reading-followed-summary')));
    await tester.pumpAndSettle();

    expect(find.text('Écart de niveau structurel'), findsOneWidget);
    expect(find.text('Dynamique négative'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
