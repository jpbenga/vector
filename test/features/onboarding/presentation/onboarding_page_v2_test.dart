import 'package:copilot/features/onboarding/domain/decision_profile.dart';
import 'package:copilot/features/onboarding/domain/onboarding_answer.dart';
import 'package:copilot/features/onboarding/domain/onboarding_completion.dart';
import 'package:copilot/features/onboarding/domain/profile_compiler.dart';
import 'package:copilot/features/onboarding/presentation/onboarding_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:copilot/l10n/generated/app_localizations.dart';

void main() {
  group('OnboardingPage V3', () {
    testWidgets(
      'has four blocks and supports competition selection by country',
      (tester) async {
        await _pumpOnboarding(tester);

        expect(find.text('Compétitions suivies'), findsOneWidget);
        expect(find.text('1'), findsOneWidget);
        expect(find.text('International'), findsOneWidget);
        expect(find.text('UEFA Champions League'), findsOneWidget);
        expect(find.text('UEFA Europa League'), findsOneWidget);
        expect(find.text('UEFA Europa Conference League'), findsOneWidget);
        expect(find.text('Allemagne'), findsOneWidget);
        expect(
          find.text('Sélectionnez au moins une compétition.'),
          findsOneWidget,
        );

        await tester.tap(find.text('Continuer'));
        await tester.pumpAndSettle();
        expect(find.text('Compétitions suivies'), findsOneWidget);

        await _tapCompetition(tester, 2);
        await _tapCompetition(tester, 3);
        await _tapCompetition(tester, 2);
        await _tapCompetition(tester, 2);
        await tester.pumpAndSettle();

        expect(
          find.text('Sélectionnez au moins une compétition.'),
          findsNothing,
        );
        await tester.tap(find.text('Continuer'));
        await tester.pumpAndSettle();
        expect(find.text('Marchés joués'), findsOneWidget);
      },
    );

    testWidgets('markets include player scorer and remain required', (
      tester,
    ) async {
      await _pumpOnboarding(tester);
      await _tapCompetition(tester, 2);
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();

      expect(find.text('Buteur'), findsOneWidget);
      expect(find.text('Sélectionnez au moins un marché.'), findsOneWidget);

      await _tapText(tester, 'Buteur');
      await _tapText(tester, 'Double chance');
      await _tapText(tester, 'Buteur');
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();

      expect(find.text('Profils d’opportunités recherchés'), findsOneWidget);
    });

    testWidgets(
      'opportunity profiles are selectable and all MVP families work',
      (tester) async {
        await _pumpOnboarding(tester);
        await _reachStep(tester, 3);

        expect(
          find.text(
            'Sélectionnez au moins un profil d’opportunité disponible.',
          ),
          findsOneWidget,
        );
        expect(find.text('Équipes en difficulté'), findsOneWidget);
        expect(find.text('À venir'), findsNothing);

        await _tapText(tester, 'Équipes en difficulté');
        await tester.tap(find.text('Continuer'));
        await tester.pumpAndSettle();
        expect(find.text('Stratégies de tickets'), findsOneWidget);
      },
    );

    testWidgets('runs the full flow without strategies and compiles profile', (
      tester,
    ) async {
      OnboardingCompletion? completion;
      await _pumpOnboarding(
        tester,
        onCompleted: (value) {
          completion = value;
        },
      );

      await _completeRequiredProfile(tester, createsStrategy: false);
      await tester.tap(find.text('Accéder à mes opportunités'));
      await tester.pumpAndSettle();

      final result = completion;
      expect(result, isNotNull);
      expect(result!.ticketStrategies, isEmpty);

      final compiled = const ProfileCompiler().compile(result.profile);
      expect(compiled.profileSchemaVersion, 2);
      expect(compiled.configurationState.name, 'completed');
      expect(compiled.competitions['2']?.enabled, isTrue);
      expect(compiled.markets['doubleChance']?.enabled, isTrue);
      expect(compiled.opportunityProfiles['solid_favorite']?.enabled, isTrue);
    });

    testWidgets('keeps answers when navigating back', (tester) async {
      await _pumpOnboarding(tester);

      await _tapCompetition(tester, 2);
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();
      await _tapText(tester, 'Double chance');
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Compétitions suivies'), findsOneWidget);
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();
      expect(find.text('Marchés joués'), findsOneWidget);
      expect(find.text('Sélectionnez au moins un marché.'), findsNothing);
    });

    testWidgets(
      'normalizes legacy competition and match type ids for editing',
      (tester) async {
        await _pumpOnboarding(
          tester,
          initialProfile: const DecisionProfile(
            onboardingVersion: '1.1',
            answers: [
              OnboardingAnswer(
                questionId: 'competitions',
                orderedOptionIds: ['fr_ligue_1'],
              ),
              OnboardingAnswer(
                questionId: 'match_types',
                orderedOptionIds: ['ranking_gap'],
              ),
            ],
          ),
        );

        expect(
          find.text('Sélectionnez au moins une compétition.'),
          findsNothing,
        );
        await tester.tap(find.text('Continuer'));
        await tester.pumpAndSettle();
        await _tapText(tester, 'Double chance');
        await tester.tap(find.text('Continuer'));
        await tester.pumpAndSettle();
        expect(find.text('Écarts de niveau'), findsOneWidget);
        expect(
          find.text(
            'Sélectionnez au moins un profil d’opportunité disponible.',
          ),
          findsNothing,
        );
      },
    );

    testWidgets('cancel is available from every step and does not save', (
      tester,
    ) async {
      for (var targetStep = 1; targetStep <= 4; targetStep++) {
        var canceled = false;
        OnboardingCompletion? completion;
        await _pumpOnboarding(
          tester,
          onCancel: () {
            canceled = true;
          },
          onCompleted: (value) {
            completion = value;
          },
        );
        await _reachStep(tester, targetStep);

        await tester.tap(find.text('Annuler'));
        await tester.pumpAndSettle();

        expect(canceled, isTrue, reason: 'step $targetStep');
        expect(completion, isNull, reason: 'step $targetStep');
      }
    });

    testWidgets('creates edits deletes and completes ticket strategies', (
      tester,
    ) async {
      OnboardingCompletion? completion;
      await _pumpOnboarding(
        tester,
        onCompleted: (value) {
          completion = value;
        },
      );
      await _reachStep(tester, 4);

      await tester.tap(find.byKey(const ValueKey('create-strategy-button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('strategy-name-field')),
        'Fun',
      );
      await tester.tap(find.byType(Switch));
      await tester.enterText(
        find.byKey(const ValueKey('minimum-individual-odds-field')),
        '1.20',
      );
      await tester.enterText(
        find.byKey(const ValueKey('maximum-individual-odds-field')),
        '',
      );
      await tester.enterText(
        find.byKey(const ValueKey('minimum-selections-field')),
        '3',
      );
      await tester.enterText(
        find.byKey(const ValueKey('maximum-selections-field')),
        '5',
      );
      await tester.enterText(
        find.byKey(const ValueKey('minimum-total-odds-field')),
        '8.00',
      );
      await tester.enterText(
        find.byKey(const ValueKey('maximum-total-odds-field')),
        '',
      );
      await tester.tap(find.byKey(const ValueKey('save-strategy-button')));
      await tester.pumpAndSettle();

      expect(find.text('Fun'), findsOneWidget);
      expect(find.text('Inactive'), findsOneWidget);
      expect(find.text('Cotes individuelles : 1.20 - ouverte'), findsOneWidget);
      expect(find.text('Cote totale : 8.00 - ouverte'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('create-strategy-button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('strategy-name-field')),
        'Safe 2',
      );
      await tester.tap(find.byKey(const ValueKey('save-strategy-button')));
      await tester.pumpAndSettle();
      expect(find.text('Safe 2'), findsOneWidget);

      await tester.ensureVisible(find.byTooltip('Modifier').first);
      await tester.tap(find.byTooltip('Modifier').first);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('strategy-name-field')),
        'Fun edited',
      );
      await tester.tap(find.byKey(const ValueKey('save-strategy-button')));
      await tester.pumpAndSettle();
      expect(find.text('Fun edited'), findsOneWidget);

      await tester.ensureVisible(find.byTooltip('Modifier').last);
      await tester.tap(find.byTooltip('Modifier').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer la stratégie'));
      await tester.pumpAndSettle();
      expect(find.text('Safe 2'), findsNothing);

      await tester.tap(find.text('Voir mon profil'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Terminer la configuration'));
      await tester.pumpAndSettle();
      expect(find.text('Votre profil est prêt !'), findsOneWidget);
      await tester.tap(find.text('Accéder à mes opportunités'));
      await tester.pumpAndSettle();

      final result = completion;
      expect(result, isNotNull);
      expect(result!.ticketStrategies, hasLength(1));
      final strategy = result.ticketStrategies.single;
      expect(strategy.name, 'Fun edited');
      expect(strategy.isActive, isFalse);
      expect(strategy.pickTypes.map((type) => type.name), [
        'prudent',
        'normal',
        'audacious',
      ]);
      expect(strategy.minimumIndividualOdds, 1.20);
      expect(strategy.maximumIndividualOdds, isNull);
      expect(strategy.minimumSelections, 3);
      expect(strategy.maximumSelections, 5);
      expect(strategy.minimumTotalOdds, 8);
      expect(strategy.maximumTotalOdds, isNull);
    });
  });
}

Future<void> _pumpOnboarding(
  WidgetTester tester, {
  VoidCallback? onCancel,
  ValueChanged<OnboardingCompletion>? onCompleted,
  DecisionProfile? initialProfile,
}) async {
  tester.view.physicalSize = const Size(1200, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    MaterialApp(
      key: UniqueKey(),
      locale: const Locale('fr'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData.dark().copyWith(splashFactory: NoSplash.splashFactory),
      home: OnboardingPage(
        key: UniqueKey(),
        initialProfile: initialProfile,
        onCancel: onCancel ?? () {},
        onCompleted: onCompleted ?? (_) {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _completeRequiredProfile(
  WidgetTester tester, {
  required bool createsStrategy,
}) async {
  await _reachStep(tester, 4);
  if (createsStrategy) {
    await tester.tap(find.byKey(const ValueKey('create-strategy-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-strategy-button')));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.text('Voir mon profil'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Terminer la configuration'));
  await tester.pumpAndSettle();
}

Future<void> _reachStep(WidgetTester tester, int step) async {
  if (step <= 1) {
    return;
  }
  await _tapFirstChip(tester);
  await tester.tap(find.text('Continuer'));
  await tester.pumpAndSettle();
  if (step <= 2) {
    return;
  }
  await _tapText(tester, 'Double chance');
  await tester.tap(find.text('Continuer'));
  await tester.pumpAndSettle();
  if (step <= 3) {
    return;
  }
  await _tapText(tester, 'Favoris solides');
  await tester.tap(find.text('Continuer'));
  await tester.pumpAndSettle();
}

Future<void> _tapText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  final chipFinder = find.ancestor(
    of: finder,
    matching: find.byType(FilterChip),
  );
  final target = chipFinder.evaluate().isNotEmpty ? chipFinder.first : finder;
  expect(target, findsWidgets);
  await tester.ensureVisible(target.first);
  await tester.tap(target.first, warnIfMissed: false);
  await tester.pumpAndSettle();
}

Future<void> _tapCompetition(
  WidgetTester tester,
  int apiFootballLeagueId,
) async {
  final target = find.byKey(ValueKey('competition-$apiFootballLeagueId'));
  expect(target, findsOneWidget);
  await tester.ensureVisible(target);
  tester.widget<CheckboxListTile>(target).onChanged?.call(true);
  await tester.pumpAndSettle();
  expect(tester.widget<CheckboxListTile>(target).value, isTrue);
}

Future<void> _tapFirstChip(WidgetTester tester) async {
  await _tapCompetition(tester, 2);
}
