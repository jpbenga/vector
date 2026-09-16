import 'package:copilot/app/theme/app_theme.dart';
import 'package:copilot/features/matches/presentation/lector_scenarios_page.dart';
import 'package:copilot/features/matches/domain/football_scenario.dart';
import 'package:copilot/features/onboarding/domain/decision_profile.dart';
import 'package:copilot/features/onboarding/domain/onboarding_answer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'shows strict scenario contracts and only enables available scenarios',
    (tester) async {
      final savedProfiles = <DecisionProfile>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: LectorScenariosPage(
            profile: _profile(),
            onProfileChanged: (profile) async {
              savedProfiles.add(profile);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('TOUTES REQUISES'),
        findsNWidgets(FootballScenarioCatalog.values
            .where((scenario) => scenario.isAvailable)
            .length),
      );
      expect(
        find.text(
          'Supériorité classement  +  Avantage de forme  +  '
          'Écart structurel',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Indisponible'),
        findsNWidgets(FootballScenarioCatalog.values
            .where((scenario) => !scenario.isAvailable)
            .length),
      );

      final availableScenario = find.byKey(
        const ValueKey('lector-scenario-solid_favorite'),
      );
      await tester.ensureVisible(availableScenario);
      await tester.tap(availableScenario);
      await tester.pumpAndSettle();

      expect(savedProfiles, hasLength(1));
      expect(savedProfiles.single.optionIdsFor('opportunity_profiles'), [
        'solid_favorite',
      ]);

      final secondAvailableScenario = find.byKey(
        const ValueKey('lector-scenario-offensive_match'),
      );
      await tester.ensureVisible(secondAvailableScenario);
      await tester.tap(secondAvailableScenario);
      await tester.pumpAndSettle();
      expect(savedProfiles, hasLength(2));
      expect(savedProfiles.last.optionIdsFor('opportunity_profiles'),
          containsAll(['solid_favorite', 'offensive_match']));
    },
  );
}

DecisionProfile _profile() {
  return const DecisionProfile(
    onboardingVersion: 'test',
    answers: [
      OnboardingAnswer(
        questionId: 'opportunity_profiles',
        orderedOptionIds: [],
      ),
    ],
  );
}
