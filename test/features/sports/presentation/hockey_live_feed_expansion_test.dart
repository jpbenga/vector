import 'package:copilot/app/theme/app_theme.dart';
import 'package:copilot/core/identity/identity_scope.dart';
import 'package:copilot/core/identity/scoped_persistence.dart';
import 'package:copilot/core/sports/data/sport_live_repository.dart';
import 'package:copilot/core/sports/data/sport_reading_preferences_store.dart';
import 'package:copilot/core/sports/domain/sport.dart';
import 'package:copilot/core/sports/domain/sport_feed_repository.dart';
import 'package:copilot/core/sports/domain/sport_fixture.dart';
import 'package:copilot/core/sports/domain/sport_reading_preferences.dart';
import 'package:copilot/core/sports/domain/sport_snapshot.dart';
import 'package:copilot/core/sports/presentation/sport_fixture_card.dart';
import 'package:copilot/core/widgets/lector_competition_browser.dart';
import 'package:copilot/features/hockey/presentation/hockey_workspace.dart';
import 'package:copilot/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../../../core/sports/sport_reading_preferences_test.dart'
    show MemoryPreferencesStorage;
import '../../../fixtures/sports/hockey_readings_fixture.dart';

SportFixture fixture(int index, {bool live = false}) {
  final base = hockeyReadingFixture(league: index == 2 ? '16' : '35');
  return SportFixture(
    id: hockeyId(SportEntityKind.match, '$index'),
    competition: base.competition,
    competitionName: base.competitionName,
    season: base.season,
    home: base.home,
    away: base.away,
    startsAt: base.startsAt,
    calendarDate: base.calendarDate,
    status: live ? SportFixtureStatus.live : SportFixtureStatus.scheduled,
    providerStatus: live ? 'P2' : 'NS',
    capturedAt: live ? DateTime.now() : readingCutoff,
    homeForm: base.homeForm,
    awayForm: base.awayForm,
  );
}

class _Feed implements SportFeedRepository {
  @override
  SportId get sport => SportId.hockey;
  @override
  Future<SportFeedResult> load(DateTime date) async =>
      SportFeedResult.available(
        SportSnapshot<SportFixture>(
          sport: sport,
          schemaVersion: 1,
          capturedAt: readingCutoff,
          windowStart: readingCutoff,
          windowEnd: readingCutoff.add(const Duration(days: 13)),
          items: [for (var i = 0; i < 4; i++) fixture(i)],
          sportOf: (f) => f.sport,
          competitions: [
            for (final league in ['35', '16'])
              ...hockeyReadingSnapshot(
                hockeyReadingFixture(league: league),
              ).competitions,
          ],
        ),
      );
}

class _Scores implements SportLiveRepository {
  @override
  Future<List<SportFixture>> load(SportId sport, Set<String> ids) async => [
    for (var i = 0; i < 3; i++) fixture(i, live: true),
  ];
}

void main() {
  setUpAll(() => initializeDateFormatting('fr'));
  for (final mode in ['Pour moi', 'Tous']) {
    testWidgets('Live shows every hockey match expanded in $mode', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 2500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = SportReadingPreferencesStore(
        persistence: ScopedPersistence(store: MemoryPreferencesStorage()),
      );
      const scope = IdentityScope.account('live-expansion');
      await store.save(
        scope,
        SportReadingPreferences(
          sport: SportId.hockey,
          competitionKeys: [
            fixture(0).competition.key,
            fixture(2).competition.key,
          ],
          readingIds: ['winning_streak'],
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: HockeyWorkspace(
              repository: _Feed(),
              liveRepository: _Scores(),
              preferencesStore: store,
              preferenceScope: scope,
              initialDate: readingCutoff,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (mode == 'Tous') {
        await tester.tap(find.text('Tous').first);
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byKey(const ValueKey('temporal-filter-live')));
      await tester.pumpAndSettle();
      final cards = tester.widgetList<SportFixtureCard>(
        find.byType(SportFixtureCard),
      );
      expect(cards.map((c) => c.fixture.id.value).toSet(), {'0', '1', '2'});
      expect(
        cards.every((c) => c.fixture.status == SportFixtureStatus.live),
        isTrue,
      );
      if (mode == 'Tous') {
        expect(
          tester
              .widgetList<LectorCompetitionGroup>(
                find.byType(LectorCompetitionGroup),
              )
              .every((group) => group.forceExpanded),
          isTrue,
        );
        await tester.tap(find.text('Test country'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('League 35'));
        await tester.pumpAndSettle();
        expect(find.byType(SportFixtureCard), findsNWidgets(3));
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }
}
