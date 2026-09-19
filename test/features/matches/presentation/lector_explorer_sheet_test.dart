import 'package:copilot/core/theme/app_theme.dart';
import 'package:copilot/features/matches/presentation/lector_explorer_sheet.dart';
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
        orderedOptionIds: ['structural_level_gap'],
      ),
      OnboardingAnswer(
        questionId: 'opportunity_profiles',
        orderedOptionIds: ['solid_favorite'],
      ),
    ],
  );

  test('exploration selection changes only readings and scenarios', () {
    final selection = LectorExplorationSelection(
      readingIds: const {'positive_streak'},
      scenarioIds: const {'ranking_gap'},
    );

    final effectiveProfile = selection.applyTo(profile);

    expect(effectiveProfile.optionIdsFor('readings'), ['positive_streak']);
    expect(effectiveProfile.optionIdsFor('opportunity_profiles'), [
      'ranking_gap',
    ]);
    expect(profile.optionIdsFor('readings'), ['structural_level_gap']);
    expect(profile.optionIdsFor('opportunity_profiles'), ['solid_favorite']);
  });

  test(
    'drops legacy statistical selections before counting or applying filters',
    () {
      const legacyProfile = DecisionProfile(
        onboardingVersion: 'test',
        answers: [
          OnboardingAnswer(
            questionId: 'readings',
            orderedOptionIds: ['high_shot_volume', 'high_card_rate'],
          ),
          OnboardingAnswer(
            questionId: 'match_types',
            orderedOptionIds: ['ranking_gap'],
          ),
        ],
      );

      final selection = LectorExplorationSelection.fromProfile(legacyProfile);

      expect(selection.readingIds, isEmpty);
      expect(selection.scenarioIds, {'ranking_gap'});
      expect(selection.activeFilterCount, 1);
      expect(selection.matchesProfile(legacyProfile), isTrue);

      final effectiveProfile = selection.applyTo(legacyProfile);
      expect(effectiveProfile.optionIdsFor('readings'), isEmpty);
      expect(effectiveProfile.optionIdsFor('opportunity_profiles'), [
        'ranking_gap',
      ]);
      expect(effectiveProfile.optionIdsFor('match_types'), isEmpty);
    },
  );

  testWidgets('sheet previews and returns a temporary exploration selection', (
    tester,
  ) async {
    LectorExplorationSelection? appliedSelection;

    await tester.pumpWidget(
      MaterialApp(
        theme: CopilotTheme.dark,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async {
                  appliedSelection = await showLectorExplorerSheet(
                    context: context,
                    profile: profile,
                    currentSelection: null,
                    resultCountFor: (selection) => selection.activeFilterCount,
                  );
                },
                child: const Text('Ouvrir'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    expect(find.text('EXPLORATION RAPIDE'), findsOneWidget);
    expect(find.text('Lectures · 1'), findsOneWidget);
    expect(find.text('Scénarios · 1'), findsOneWidget);
    expect(find.text('Voir 2 rencontres'), findsOneWidget);
    expect(find.text('Niveau, forme et lieu'), findsOneWidget);
    expect(find.text('Dynamique positive'), findsNothing);

    await tester.tap(find.text('Niveau, forme et lieu'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dynamique positive'));
    await tester.pumpAndSettle();

    expect(find.text('Lectures · 2'), findsOneWidget);
    expect(find.text('Voir 3 rencontres'), findsOneWidget);

    await tester.tap(find.text('Voir 3 rencontres'));
    await tester.pumpAndSettle();

    expect(appliedSelection, isNotNull);
    expect(appliedSelection!.readingIds, {
      'structural_level_gap',
      'positive_streak',
    });
    expect(appliedSelection!.scenarioIds, {'solid_favorite'});
  });

  testWidgets('selects and deselects all readings and scenarios', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CopilotTheme.dark,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => showLectorExplorerSheet(
                  context: context,
                  profile: profile,
                  currentSelection: null,
                  resultCountFor: (selection) => selection.activeFilterCount,
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
    await tester.tap(find.byKey(const ValueKey('explorer-select-all')));
    await tester.pumpAndSettle();

    expect(
      find.text('Lectures · ${ReadingPreferenceCatalog.values.length}'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('explorer-deselect-all')));
    await tester.pumpAndSettle();
    expect(find.text('Lectures · 0'), findsOneWidget);

    await tester.tap(find.text('Scénarios · 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('explorer-select-all')));
    await tester.pumpAndSettle();
    expect(
      find.text('Scénarios · ${OpportunityProfileCatalog.values.length}'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('explorer-deselect-all')));
    await tester.pumpAndSettle();
    expect(find.text('Scénarios · 0'), findsOneWidget);
  });
}
