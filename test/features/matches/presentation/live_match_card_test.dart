import 'package:copilot/app/theme/app_theme.dart';
import 'package:copilot/core/theme/app_theme_controller.dart';
import 'package:copilot/features/appearance/data/appearance_preview_fixture.dart';
import 'package:copilot/features/matches/application/live_match_controller.dart';
import 'package:copilot/features/matches/data/live_match_repository.dart';
import 'package:copilot/features/matches/data/match_reading_bilan_repository.dart';
import 'package:copilot/features/matches/domain/live_match_state.dart';
import 'package:copilot/features/matches/domain/match_board_item.dart';
import 'package:copilot/features/matches/presentation/widgets/live_fixture_builder.dart';
import 'package:copilot/features/matches/presentation/widgets/match_feed_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

MatchBoardItem _match() {
  final f = appearancePreviewMatch.fixture;
  return appearancePreviewMatch.copyWith(
    fixture: NormalizedFixture(
      id: 'api-fixture-1',
      apiFootballFixtureId: 1,
      competition: f.competition,
      homeTeam: f.homeTeam,
      awayTeam: f.awayTeam,
      kickoffLabel: f.kickoffLabel,
      status: FixtureStatus.scheduled,
    ),
  );
}

LiveMatchState _state(
  String status, {
  int home = 1,
  int away = 2,
  DateTime? at,
  List<MatchReadingBilanEntry> entries = const [],
}) => LiveMatchState(
  fixtureId: 1,
  status: status,
  capturedAt: at ?? DateTime.now(),
  elapsed: status == '2H' ? 67 : null,
  homeGoals: home,
  awayGoals: away,
  readings: entries,
);
MatchReadingBilanEntry _entry(String id, String verdict) =>
    MatchReadingBilanEntry(
      explanation: null,
      announcementId: id,
      fixtureId: 1,
      kickoffAt: DateTime(2026, 10, 4, 21),
      readingId: id,
      readingLabel: id == 'positive_streak'
          ? 'Dynamique positive'
          : 'Autre lecture',
      verdict: verdict,
      announcementKind: 'reading',
      outcomeRule: 'team_not_lose',
      subjectSide: 'away',
      homeTeamName: 'Real Madrid',
      awayTeamName: 'FC Barcelone',
      homeGoals: 1,
      awayGoals: 3,
    );

void main() {
  testWidgets(
    'One shared subscription recovers scores after outage/resume without regressing finals',
    (tester) async {
      final repository = _Repository();
      final controller = LiveMatchController(
        repository,
        observeLifecycle: false,
      );
      final first = controller.watch(1);
      final second = controller.watch(1);
      expect(identical(first, second), isTrue);
      await tester.pump(const Duration(milliseconds: 110));
      expect(repository.subscriptions, 1);
      expect(repository.loads, 1);
      repository.emit(_state('2H'));
      expect(first.value!.awayGoals, 2);
      repository.fail = true;
      await controller.refresh();
      expect(first.value!.awayGoals, 2);
      repository.fail = false;
      repository.rows = [_state('FT', away: 3)];
      controller.didChangeAppLifecycleState(AppLifecycleState.paused);
      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 110));
      expect(first.value!.status, 'FT');
      repository.emit(
        _state(
          '2H',
          away: 2,
          at: DateTime.now().add(const Duration(minutes: 1)),
        ),
      );
      expect(first.value!.awayGoals, 3);
      repository.rows = [];
      await controller.refresh();
      expect(first.value!.awayGoals, 3);
      controller.unwatch(1);
      expect(repository.closed, 1);
      controller.unwatch(1);
      expect(repository.closed, 2);
      await controller.dispose();
    },
  );

  testWidgets(
    'Mounted card receives a persisted final after realtime reconnect',
    (tester) async {
      final repository = _Repository();
      final controller = LiveMatchController(
        repository,
        observeLifecycle: false,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: LiveFixtureBuilder(
              fixtureId: 1,
              controller: controller,
              builder: (context, state) => MatchFeedCard(
                match: _match(),
                liveState: state,
                radarEntries: const [],
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 110));
      repository.emit(_state('2H'));
      await tester.pump();
      expect(find.text('67′ · En direct'), findsOneWidget);
      repository.rows = [
        _state(
          'FT',
          away: 3,
          entries: [_entry('positive_streak', 'confirmed')],
        ),
      ];
      await controller.refresh();
      await tester.pump();
      expect(find.text('Terminé'), findsOneWidget);
      expect(find.text('1 confirmée'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await controller.dispose();
    },
  );

  for (final variant in AppThemeVariant.values) {
    testWidgets(
      'Live and final card preserve personalized readings at mobile width in ${variant.name}',
      (tester) async {
        tester.view.physicalSize = const Size(360, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final match = _match();
        Future<void> pump(LiveMatchState state, {bool readings = true}) =>
            tester.pumpWidget(
              MaterialApp(
                theme: AppTheme.forVariant(variant),
                home: Scaffold(
                  body: SingleChildScrollView(
                    child: MatchFeedCard(
                      match: match,
                      liveState: state,
                      showReadings: readings,
                      radarEntries: const [],
                      onTap: () {},
                    ),
                  ),
                ),
              ),
            );
        await pump(_state('2H'));
        expect(
          find.byKey(const ValueKey('live-match-status-badge')),
          findsOneWidget,
        );
        expect(find.text('67′ · En direct'), findsOneWidget);
        expect(find.text('1'), findsOneWidget);
        expect(find.text('2'), findsOneWidget);
        expect(find.text('Forme'), findsOneWidget);
        expect(find.text('Voir les lectures'), findsNothing);
        await pump(_state('HT', home: 2, away: 0));
        expect(
          find.byKey(const ValueKey('live-match-status-badge')),
          findsOneWidget,
        );
        expect(find.text('Mi-temps · En direct'), findsOneWidget);
        expect(find.text('2'), findsOneWidget);
        expect(find.text('0'), findsOneWidget);
        final finalState = _state(
          'FT',
          away: 3,
          entries: [
            _entry('positive_streak', 'confirmed'),
            _entry('inactive_reading', 'contradicted'),
          ],
        );
        await pump(finalState);
        expect(
          find.byKey(const ValueKey('live-match-status-badge')),
          findsNothing,
        );
        expect(find.text('Terminé'), findsOneWidget);
        expect(find.text('1 confirmée'), findsOneWidget);
        expect(find.textContaining('contredite'), findsNothing);
        await tester.tap(find.text('Voir les lectures'));
        await tester.pumpAndSettle();
        expect(find.text('Bilan des lectures annoncées'), findsOneWidget);
        expect(find.text('Confirmée'), findsOneWidget);
        expect(find.textContaining('Critère :'), findsOneWidget);
        expect(find.text('Autre lecture'), findsNothing);
        await tester.tap(find.byTooltip('Fermer'));
        await tester.pumpAndSettle();
        await pump(finalState, readings: false);
        expect(find.text('Voir les lectures'), findsNothing);
        expect(find.text('Forme'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  test(
    'Stale timestamp and score-only overlay do not rewrite prematch evidence',
    () {
      final match = _match();
      final state = _state(
        '2H',
        at: DateTime.now().subtract(const Duration(minutes: 4)),
      );
      expect(state.isStale(DateTime.now()), isTrue);
      final updated = state.overlay(match);
      expect(updated.fixture.score!.away, 2);
      expect(identical(updated.signals, match.signals), isTrue);
      expect(match.fixture.score, isNull);
      expect(
        _state(
          'FT',
          entries: [_entry('positive_streak', 'confirmed')],
        ).visibleReadings({}),
        isEmpty,
      );
    },
  );
}

class _Repository implements LiveMatchRepository {
  int subscriptions = 0, loads = 0, closed = 0;
  bool fail = false;
  List<LiveMatchState> rows = [];
  void Function(LiveMatchState)? _onState;
  String? _selection;
  void emit(LiveMatchState state) => _onState?.call(state);
  @override
  Future<List<LiveMatchState>> load(Set<int> fixtureIds) async {
    loads++;
    if (fail) throw StateError('offline');
    return rows;
  }

  @override
  void subscribe(
    Set<int> fixtureIds,
    void Function(LiveMatchState) onState,
    void Function() onReconnect,
  ) {
    final selection = fixtureIds.join(',');
    if (_selection == selection) return;
    _selection = selection;
    subscriptions++;
    _onState = onState;
  }

  @override
  Future<void> unsubscribe() async {
    closed++;
    _selection = null;
    _onState = null;
  }
}
