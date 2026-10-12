import 'package:copilot/core/identity/scoped_persistence.dart';
import 'package:copilot/core/theme/app_theme.dart';
import 'package:copilot/features/shortlist/application/shortlist_controller.dart';
import 'package:copilot/features/shortlist/domain/shortlist.dart';
import 'package:copilot/features/shortlist/presentation/shortlist_page.dart';
import 'package:copilot/features/shortlist/presentation/shortlist_view.dart';
import 'package:copilot/features/shortlist/presentation/shortlist_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'shortlist_test.dart' show Repo, Store, now, snapshot;

void main() {
  setUpAll(() => initializeDateFormatting('fr'));
  test(
    'sorting and filtering keep unavailable fixtures and ignore inactive readings',
    () {
      final fixtures = [
        ShortlistFixture({
          'sport': 'football',
          'fixtureId': '1',
          'competition': 'A',
          'kickoff': now.add(const Duration(hours: 4)).toIso8601String(),
          'status': 'NS',
          'readings': [
            {'id': 'positive_streak'},
            {'id': 'negative_streak', 'status': 'notDetected'},
          ],
        }),
        ShortlistFixture({
          'sport': 'hockey',
          'fixtureId': '1',
          'competition': 'B',
          'kickoff': now.add(const Duration(hours: 2)).toIso8601String(),
          'status': 'scheduled',
          'readings': <Map<String, Object?>>[],
        }),
        ShortlistFixture({
          'sport': 'football',
          'fixtureId': '2',
          'available': false,
        }),
      ];
      expect(
        shortlistVisibleFixtures(
          fixtures,
          sort: ShortlistSort.dateAscending,
          filter: const ShortlistViewFilter(),
        ).map((f) => f.key),
        ['hockey:1', 'football:1', 'football:2'],
      );
      expect(
        shortlistVisibleFixtures(
          fixtures,
          sort: ShortlistSort.readings,
          filter: const ShortlistViewFilter(withReadings: true),
        ).map((f) => f.key),
        ['football:1'],
      );
      expect(fixtures, hasLength(3));
      final conflicting = ShortlistFixture({
        'readings': [
          {'id': 'positive_streak'},
          {'id': 'standing_advantage'},
          {'id': 'negative_streak'},
        ],
      });
      expect(fixtures.first.readingCount, 1);
      expect(conflicting.readingCount, 3);
    },
  );
  testWidgets(
    'postponed and cancelled matches have explicit labels and large detail targets',
    (tester) async {
      for (final entry in {
        'postponed': 'Reporté',
        'cancelled': 'Annulé',
        'unknown': 'Indisponible',
      }.entries) {
        final fixture = ShortlistFixture({
          'sport': 'football',
          'fixtureId': '1',
          'home': 'Atalanta',
          'away': 'Venezia',
          'status': entry.key,
          'kickoff': now.add(const Duration(hours: 2)).toIso8601String(),
          'readings': [
            {'id': 'positive_streak'},
            {'id': 'standing_advantage'},
            {'id': 'negative_streak'},
          ],
        });
        await tester.pumpWidget(
          MaterialApp(
            theme: CopilotTheme.dark,
            home: Scaffold(
              body: SizedBox(
                width: 390,
                child: ShortlistFixtureTile(
                  fixture: fixture,
                  now: now,
                  selected: false,
                  onSelected: (_) {},
                  onRemove: () {},
                  onOpen: () {},
                ),
              ),
            ),
          ),
        );
        expect(find.text(entry.value), findsOneWidget);
        expect(find.text('Vigilance'), findsNothing);
        expect(find.text('Avantage'), findsNothing);
        expect(find.text('Forme +'), findsNothing);
        expect(find.text('3 lectures'), findsNothing);
        expect(find.text('Lectures à actualiser'), findsNothing);
        final size = tester.getSize(find.byTooltip('Voir Atalanta – Venezia'));
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
        expect(tester.takeException(), isNull);
      }
    },
  );
  testWidgets(
    'selection is independent of removing; hidden selections remain available',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = Repo(),
          controller = ShortlistController(
            repository: repo,
            persistence: ScopedPersistence(store: Store()),
            clock: () => now,
          );
      await controller.bindAccount('a');
      await tester.pumpWidget(
        MaterialApp(
          theme: CopilotTheme.dark,
          home: ShortlistPage(controller: controller),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('shortlist-select:football:1')),
      );
      await tester.pump();
      expect(controller.selected, {'football:1'});
      expect(repo.calls.every((action) => action == 'read'), true);
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const ValueKey('shortlist-compare')),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const ValueKey('shortlist-filters')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('shortlist-sport-filter-all')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hockey').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Appliquer les filtres'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('shortlist-fixture:football:1')),
        findsNothing,
      );
      expect(controller.selected, {'football:1'});
      await tester.tap(find.byKey(const ValueKey('shortlist-select:hockey:1')));
      await tester.pump();
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const ValueKey('shortlist-compare')),
            )
            .onPressed,
        isNotNull,
      );
      expect(controller.items, hasLength(2));
      repo.execute = (action) async =>
          snapshot(keys: const ['football:1'], revision: 2);
      await tester.tap(find.byKey(const ValueKey('shortlist-remove:hockey:1')));
      await tester.pumpAndSettle();
      expect(repo.calls.last, 'remove');
      expect(repo.calls, isNot(contains('clear')));
      expect(controller.items.map((f) => f.key), ['football:1']);
      expect(controller.selected, {'football:1'});
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );
  testWidgets(
    'large text fits the simplified Shortlist without changing saved fixtures',
    (tester) async {
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = Repo(),
          controller = ShortlistController(
            repository: repo,
            persistence: ScopedPersistence(store: Store()),
            clock: () => now,
          );
      await controller.bindAccount('a');
      await tester.pumpWidget(
        MaterialApp(
          theme: CopilotTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: ShortlistPage(controller: controller),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('shortlist-nav-radar')), findsNothing);
      expect(
        find.byKey(const ValueKey('shortlist-status-upcoming')),
        findsNothing,
      );
      expect(find.byTooltip('Vider la Shortlist'), findsNothing);
      expect(find.text('Vider la liste'), findsNothing);
      expect(find.byKey(const ValueKey('shortlist-prepare')), findsOneWidget);
      expect(find.byKey(const ValueKey('shortlist-compare')), findsOneWidget);
      expect(controller.items, hasLength(2));
      expect(repo.calls.every((action) => action == 'read'), true);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );
}
