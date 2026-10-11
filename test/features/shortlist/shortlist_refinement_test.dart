import 'package:copilot/core/identity/scoped_persistence.dart';
import 'package:copilot/core/theme/app_theme.dart';
import 'package:copilot/core/widgets/lector_workspace_navigation.dart';
import 'package:copilot/features/shortlist/application/shortlist_controller.dart';
import 'package:copilot/features/shortlist/domain/shortlist.dart';
import 'package:copilot/features/shortlist/presentation/shortlist_page.dart';
import 'package:copilot/features/shortlist/presentation/shortlist_view.dart';
import 'package:copilot/features/shortlist/presentation/shortlist_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'shortlist_test.dart' show Repo, Store, now;

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
          now: now,
          group: 'upcoming',
          sort: ShortlistSort.dateAscending,
          filter: const ShortlistViewFilter(),
        ).map((f) => f.key),
        ['hockey:1', 'football:1'],
      );
      expect(
        shortlistVisibleFixtures(
          fixtures,
          now: now,
          group: 'upcoming',
          sort: ShortlistSort.readings,
          filter: const ShortlistViewFilter(withReadings: true),
        ).map((f) => f.key),
        ['football:1'],
      );
      expect(fixtures.first.readingTags.map((t) => t.label), ['Forme +']);
      expect(
        shortlistVisibleFixtures(
          fixtures,
          now: now,
          group: 'other',
          sort: ShortlistSort.dateAscending,
          filter: const ShortlistViewFilter(),
        ).single.key,
        'football:2',
      );
      expect(fixtures, hasLength(3));
      final conflicting = ShortlistFixture({
        'readings': [
          {'id': 'positive_streak'},
          {'id': 'standing_advantage'},
          {'id': 'negative_streak'},
        ],
      });
      expect(
        conflicting.readingTags.take(2).any((t) => t.kind == 'warning'),
        true,
      );
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
        expect(find.text('Vigilance'), findsOneWidget);
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
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );
  testWidgets(
    'large text and bottom destinations fit without changing the Shortlist',
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
      LectorWorkspaceSection? selected;
      await tester.pumpWidget(
        MaterialApp(
          theme: CopilotTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: ShortlistPage(
            controller: controller,
            onNavigate: (s) => selected = s,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('shortlist-nav-radar')));
      expect(selected, LectorWorkspaceSection.radar);
      expect(controller.items, hasLength(2));
      expect(repo.calls.every((action) => action == 'read'), true);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );
}
