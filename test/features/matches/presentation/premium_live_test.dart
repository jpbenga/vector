import 'package:copilot/app/theme/app_theme.dart';
import 'package:copilot/core/widgets/lector_live_badge.dart';
import 'package:copilot/core/widgets/lector_temporal_feed.dart';
import 'package:copilot/core/domain/lector_temporal_state.dart';
import 'package:copilot/core/widgets/lector_match_detail_view.dart';
import 'package:copilot/features/matches/application/live_match_controller.dart';
import 'package:copilot/features/matches/data/live_match_repository.dart';
import 'package:copilot/features/matches/domain/live_match_state.dart';
import 'package:copilot/features/matches/presentation/widgets/live_match_list_builder.dart';
import 'package:copilot/features/matches/presentation/widgets/football_live_stats.dart';
import 'package:copilot/features/appearance/data/appearance_preview_fixture.dart';
import 'package:copilot/features/matches/domain/match_board_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

LiveMatchState state(int id, String status) => LiveMatchState(
  fixtureId: id,
  status: status,
  elapsed: 71,
  capturedAt: DateTime.now(),
);

class Repository implements LiveMatchRepository {
  void Function(LiveMatchState)? emit;
  Set<int> ids = {};
  @override
  Future<List<LiveMatchState>> load(Set<int> values) async {
    ids = values;
    return [];
  }

  @override
  void subscribe(
    Set<int> values,
    void Function(LiveMatchState) onState,
    void Function() onReconnect,
  ) {
    emit = onState;
  }

  @override
  Future<void> unsubscribe() async {}
}

void main() {
  testWidgets(
    'filters watch hidden fixtures, move live to finished, and keep only eligible ids',
    (tester) async {
      final repository = Repository();
      // The controller is injected: no Supabase, credentials or provider calls.
      final live = LiveMatchController(repository, observeLifecycle: false);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: LiveMatchListBuilder(
              fixtureIds: {1, 2, 3},
              controller: live,
              builder: (_, received) => LectorTemporalFeed<int>(
                items: [1, 2, 3],
                phaseOf: (id) =>
                    received[id]?.temporal.phase ?? LectorMatchPhase.upcoming,
                sectionBuilder: (_, items, phase) => Column(
                  children: [for (final id in items) Text('match $id')],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 110));
      repository.emit!(state(1, '2H'));
      repository.emit!(state(3, 'FT'));
      await tester.pump();
      expect(find.text('Live 1'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('temporal-filter-live')),
          matching: find.byIcon(Icons.circle),
        ),
        findsOneWidget,
      );
      expect(find.text('À venir 1'), findsOneWidget);
      expect(find.text('Terminés 1'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('match 1')).dy,
        lessThan(tester.getTopLeft(find.text('match 2')).dy),
      );
      await tester.tap(find.byKey(const ValueKey('temporal-filter-live')));
      await tester.pumpAndSettle();
      expect(find.text('match 2'), findsNothing);
      expect(repository.ids, {1, 2, 3}); // Hidden upcoming remains subscribed.
      repository.emit!(state(2, '1H'));
      await tester.pump();
      expect(find.text('match 2'), findsOneWidget);
      repository.emit!(state(99, '2H'));
      await tester.pump();
      expect(find.text('match 99'), findsNothing);
      repository.emit!(state(1, 'FT'));
      repository.emit!(state(2, 'FT'));
      await tester.pump();
      expect(find.byKey(const ValueKey('temporal-filter-live')), findsNothing);
      expect(find.text('match 3'), findsOneWidget);
      expect(find.text('Terminés 3'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await live.dispose();
    },
  );

  testWidgets(
    'compact clock adapts to football and hockey and distinguishes late data',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Column(
              children: [
                LectorLiveBadge(state: state(1, 'HT').temporal),
                const LectorLiveBadge(
                  state: LectorTemporalState(
                    phase: LectorMatchPhase.live,
                    period: 'P2',
                    clock: '12:34',
                  ),
                ),
                LectorLiveBadge(
                  state: LectorTemporalState(
                    phase: LectorMatchPhase.live,
                    clock: '71′',
                    capturedAt: DateTime.now().subtract(
                      const Duration(minutes: 5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.text('MT'), findsOneWidget);
      expect(find.text('P2 · 12:34'), findsOneWidget);
      expect(find.byIcon(Icons.pause_circle_outline_rounded), findsOneWidget);
    },
  );

  testWidgets(
    'Stats opens for live, stays available at final, and respects manual tab selection',
    (tester) async {
      Future<void> pump({bool live = true}) => tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: LectorMatchDetailView(
            hero: const Text('Match'),
            synthesis: const Text('Avant match'),
            stats: const Text('Faits actuels'),
            openStats: live,
            tabBuilder: (_, index) => Text('analyse $index'),
          ),
        ),
      );
      await pump();
      expect(find.text('Faits actuels'), findsOneWidget);
      await tester.tap(find.text('Forme'));
      await tester.pump();
      expect(find.text('analyse 2'), findsOneWidget);
      await pump(live: false);
      expect(find.text('analyse 2'), findsOneWidget);
      expect(find.text('Stats'), findsOneWidget);
    },
  );

  testWidgets(
    'Stats binds team ids, preserves zero and never fills missing values with season averages',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final f = appearancePreviewMatch.fixture;
      final match = appearancePreviewMatch.copyWith(
        fixture: NormalizedFixture(
          id: f.id,
          apiFootballFixtureId: 1,
          competition: f.competition,
          homeTeam: TeamInfo(
            id: 'home',
            name: 'Domicile',
            apiFootballTeamId: 1,
          ),
          awayTeam: TeamInfo(
            id: 'away',
            name: 'Extérieur',
            apiFootballTeamId: 2,
          ),
          kickoffLabel: f.kickoffLabel,
          status: FixtureStatus.live,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: FootballLiveStats(
            match: match,
            state: LiveMatchState(
              fixtureId: 1,
              status: '2H',
              capturedAt: DateTime.now(),
              statistics: [
                {
                  'team': {'id': 2},
                  'statistics': [
                    {'type': 'Total Shots', 'value': 7},
                  ],
                },
                {
                  'team': {'id': 1},
                  'statistics': [
                    {'type': 'Total Shots', 'value': 0},
                    {'type': 'Ball Possession', 'value': null},
                  ],
                },
                {
                  'team': {'id': 99},
                  'statistics': [
                    {'type': 'Total Shots', 'value': 999},
                  ],
                },
              ],
            ),
          ),
        ),
      );
      expect(find.text('0'), findsWidgets);
      expect(find.text('7'), findsWidgets);
      expect(find.text('999'), findsNothing);
      expect(find.text('Possession'), findsNothing);
    },
  );
}
