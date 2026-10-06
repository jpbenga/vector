import 'package:copilot/core/widgets/lector_match_insights.dart';
import 'package:copilot/core/widgets/lector_space_widgets.dart';
import 'package:copilot/core/sports/presentation/sport_space_page.dart';
import 'package:copilot/core/sports/presentation/sport_reading_preferences_page.dart';
import 'package:copilot/core/theme/app_theme_controller.dart';
import 'package:copilot/features/appearance/presentation/appearance_page.dart';
import 'dart:async';
import 'package:copilot/app/theme/app_theme.dart';
import 'package:copilot/core/identity/identity_scope.dart';
import 'package:copilot/core/identity/scoped_persistence.dart';
import 'package:copilot/core/sports/data/sport_reading_preferences_store.dart';
import 'package:copilot/core/sports/domain/sport.dart';
import 'package:copilot/core/sports/domain/sport_feed_repository.dart';
import 'package:copilot/core/sports/domain/sport_reading_preferences.dart';
import 'package:copilot/core/sports/presentation/sport_fixture_card.dart';
import 'package:copilot/core/widgets/lector_reading_pill.dart';
import 'package:copilot/core/widgets/lector_competition_browser.dart';
import 'package:copilot/features/hockey/presentation/hockey_match_detail_page.dart';
import 'package:copilot/features/hockey/presentation/hockey_workspace.dart';
import 'package:copilot/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../../../core/sports/sport_reading_preferences_test.dart'
    show MemoryPreferencesStorage;
import '../../../fixtures/sports/hockey_readings_fixture.dart';

class _Feed implements SportFeedRepository {
  @override
  SportId get sport => SportId.hockey;
  @override
  Future<SportFeedResult> load(DateTime date) async =>
      SportFeedResult.available(hockeyReadingSnapshot(hockeyReadingFixture()));
}

class _DelayedStore extends SportReadingPreferencesStore {
  final waits = <String, Completer<SportReadingPreferences>>{};
  @override
  Future<SportReadingPreferences> load(IdentityScope scope, SportId sport) =>
      (waits[scope.id] = Completer()).future;
}

SportReadingPreferences _configured() => SportReadingPreferences(
  sport: SportId.hockey,
  competitionKeys: [hockeyReadingFixture().competition.key],
  readingIds: ['winning_streak'],
);

Widget app(
  SportReadingPreferencesStore store,
  IdentityScope scope, {
  ThemeData? theme,
}) => MaterialApp(
  theme: theme ?? AppTheme.dark,
  locale: const Locale('fr'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: HockeyWorkspace(
      repository: _Feed(),
      initialDate: readingCutoff,
      preferencesStore: store,
      preferenceScope: scope,
    ),
  ),
);

void main() {
  setUpAll(() => initializeDateFormatting('fr'));
  for (final width in [360.0, 1100.0]) {
    testWidgets(
      'settings return to the menu after appearance and save hockey readings at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final originalTheme = appThemeController.variant;
        addTearDown(() => appThemeController.select(originalTheme));
        final store = SportReadingPreferencesStore(
          persistence: ScopedPersistence(store: MemoryPreferencesStorage()),
        );
        const scope = IdentityScope.account('settings-tester');
        await tester.pumpWidget(
          ValueListenableBuilder<AppThemeVariant>(
            valueListenable: appThemeController,
            builder: (context, variant, _) =>
                app(store, scope, theme: AppTheme.forVariant(variant)),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Paramètres'));
        await tester.pumpAndSettle();
        expect(find.byType(SportSpacePage), findsOneWidget);
        expect(find.byType(LectorSpaceActionCard), findsNWidgets(4));
        expect(find.byType(AppearancePage), findsNothing);

        await tester.tap(find.text('Apparence'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const ValueKey('appearance-theme-vectorLight')),
        );
        await tester.tap(
          find.byKey(const ValueKey('appearance-theme-vectorLight')),
        );
        await tester.pumpAndSettle();
        expect(appThemeController.variant, AppThemeVariant.vectorLight);
        await tester.tap(find.byTooltip('Retour'));
        await tester.pumpAndSettle();
        expect(find.text('Mon espace'), findsOneWidget);
        expect(find.byType(AppearancePage), findsNothing);

        await tester.ensureVisible(
          find.byKey(const ValueKey('sport-space-competitions')),
        );
        await tester.tap(
          find.byKey(const ValueKey('sport-space-competitions')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Mes compétitions · Hockey'), findsOneWidget);
        expect(find.byType(SwitchListTile), findsNothing);
        await tester.tap(
          find.byKey(const ValueKey('preference-competition-35')),
        );
        await tester.ensureVisible(
          find.byKey(const ValueKey('save-sport-preferences')),
        );
        await tester.tap(find.byKey(const ValueKey('save-sport-preferences')));
        await tester.pumpAndSettle();
        expect(find.text('1 compétition(s) · 0 lecture(s)'), findsOneWidget);
        await tester.ensureVisible(
          find.byKey(const ValueKey('sport-space-readings')),
        );
        await tester.tap(find.byKey(const ValueKey('sport-space-readings')));
        await tester.pumpAndSettle();
        expect(find.text('Mes lectures · Hockey'), findsOneWidget);
        expect(find.byType(CheckboxListTile), findsNothing);
        await tester.ensureVisible(
          find.byKey(const ValueKey('preference-reading-winning_streak')),
        );
        await tester.tap(
          find.byKey(const ValueKey('preference-reading-winning_streak')),
        );
        await tester.ensureVisible(
          find.byKey(const ValueKey('save-sport-preferences')),
        );
        await tester.tap(find.byKey(const ValueKey('save-sport-preferences')));
        await tester.pumpAndSettle();
        expect(find.text('1 compétition(s) · 1 lecture(s)'), findsOneWidget);
        final saved = await store.load(scope, SportId.hockey);
        expect(saved.competitionKeys, _configured().competitionKeys);
        expect(saved.readingIds, {'winning_streak'});
        expect(
          (await store.load(scope, SportId.football)).isConfigured,
          isFalse,
        );

        await tester.tap(find.byTooltip('Retour'));
        await tester.pumpAndSettle();
        expect(find.text('Série de victoires · ≥5 · Home'), findsOneWidget);
        await tester.ensureVisible(find.byTooltip('Paramètres'));
        await tester.tap(find.byTooltip('Paramètres'));
        await tester.pumpAndSettle();
        expect(find.byType(SportSpacePage), findsOneWidget);
        expect(find.byType(AppearancePage), findsNothing);
        await tester.tap(find.byKey(const ValueKey('sport-space-readings')));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<SwitchListTile>(
                find.byKey(const ValueKey('preference-reading-winning_streak')),
              )
              .value,
          isTrue,
        );
        expect(find.byType(SportReadingPreferencesPage), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      'hockey opt-in, persisted reading and shared detail at width $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final store = SportReadingPreferencesStore(
          persistence: ScopedPersistence(store: MemoryPreferencesStorage()),
        );
        const scope = IdentityScope.account('tester');
        await tester.pumpWidget(app(store, scope));
        await tester.pumpAndSettle();
        expect(find.byType(SportFixtureCard), findsNothing);
        await tester.tap(
          find.byKey(const ValueKey('configure-hockey-preferences')),
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<CheckboxListTile>(
                find.byKey(const ValueKey('preference-competition-35')),
              )
              .value,
          isFalse,
        );
        expect(
          tester
              .widget<SwitchListTile>(
                find.byKey(const ValueKey('preference-reading-winning_streak')),
              )
              .value,
          isFalse,
        );
        await tester.tap(
          find.byKey(const ValueKey('preference-competition-35')),
        );
        await tester.ensureVisible(
          find.byKey(const ValueKey('preference-reading-winning_streak')),
        );
        await tester.tap(
          find.byKey(const ValueKey('preference-reading-winning_streak')),
        );
        await tester.ensureVisible(
          find.byKey(const ValueKey('save-sport-preferences')),
        );
        await tester.tap(find.byKey(const ValueKey('save-sport-preferences')));
        await tester.pumpAndSettle();
        expect((await store.load(scope, SportId.hockey)).readingIds, {
          'winning_streak',
        });
        expect(find.byType(SportFixtureCard), findsOneWidget);
        expect(find.byType(LectorReadingPill), findsOneWidget);
        expect(find.text('Série de victoires · ≥5 · Home'), findsOneWidget);
        await tester.ensureVisible(find.byType(SportFixtureCard));
        await tester.tap(find.byType(SportFixtureCard));
        await tester.pumpAndSettle();
        expect(find.byType(HockeyMatchDetailPage), findsOneWidget);
        expect(find.text('VOS LECTURES'), findsOneWidget);
        expect(find.text('1 lecture détectée'), findsOneWidget);
        await tester.ensureVisible(find.text('Voir le détail'));
        await tester.tap(find.text('Voir le détail'));
        await tester.pumpAndSettle();
        expect(find.text('ANALYSE LECTOR'), findsOneWidget);
        expect(find.text('Autres lectures du match'), findsOneWidget);
        expect(find.text('Lectures non détectées'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(LectorAnalysisSheet),
            matching: find.text('Série de victoires'),
          ),
          findsNWidgets(2),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'account switch clears proposals and late reads never leak across accounts',
    (tester) async {
      final store = _DelayedStore();
      await tester.pumpWidget(app(store, const IdentityScope.account('one')));
      await tester.pump();
      await tester.pumpWidget(app(store, const IdentityScope.account('two')));
      await tester.pump();
      store.waits['one']!.complete(_configured());
      await tester.pumpAndSettle();
      expect(find.byType(SportFixtureCard), findsNothing);
      store.waits['two']!.complete(
        SportReadingPreferences(sport: SportId.hockey),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SportFixtureCard), findsNothing);
      expect(
        find.byKey(const ValueKey('configure-hockey-preferences')),
        findsOneWidget,
      );
      await tester.pumpWidget(app(store, const IdentityScope.account('one')));
      await tester.pump();
      store.waits['one']!.complete(_configured());
      await tester.pumpAndSettle();
      expect(find.byType(SportFixtureCard), findsOneWidget);
      await tester.pumpWidget(app(store, const IdentityScope.account('two')));
      await tester.pump();
      expect(find.byType(SportFixtureCard), findsNothing);
      store.waits['two']!.complete(
        SportReadingPreferences(sport: SportId.hockey),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'All explores fixtures, while For me needs configured competitions',
    (tester) async {
      final store = SportReadingPreferencesStore(
        persistence: ScopedPersistence(store: MemoryPreferencesStorage()),
      );
      const scope = IdentityScope.account('tester');
      // An active reading outside followed leagues is useful during discovery.
      await store.save(
        scope,
        SportReadingPreferences(
          sport: SportId.hockey,
          competitionKeys: ['hockey:api-hockey:competition:18'],
          readingIds: ['winning_streak'],
        ),
      );
      await tester.pumpWidget(app(store, scope));
      await tester.pumpAndSettle();
      expect(find.byType(SportFixtureCard), findsNothing);
      await tester.tap(find.text('Tous'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Test country'));
      await tester.pumpAndSettle();
      final group = find.byWidgetPredicate(
        (w) => w is LectorCompetitionGroup && !w.isCountry,
      );
      await tester.tap(
        find.descendant(of: group, matching: find.text('League 35')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SportFixtureCard), findsOneWidget);
      expect(find.text('Série de victoires · ≥5 · Home'), findsOneWidget);
      await tester.tap(find.text('Pour moi'));
      await tester.pumpAndSettle();
      expect(find.byType(SportFixtureCard), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
