import 'package:copilot/core/widgets/lector_match_stats.dart';
import 'package:copilot/core/theme/app_theme.dart';
import 'package:copilot/features/appearance/data/appearance_preview_fixture.dart';
import 'package:copilot/features/matches/domain/live_match_state.dart';
import 'package:copilot/features/matches/domain/match_board_item.dart';
import 'package:copilot/features/matches/presentation/widgets/football_live_stats.dart';
import 'package:copilot/features/matches/presentation/widgets/lector_match_hero.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final match = appearancePreviewMatch.copyWith(
  fixture: NormalizedFixture(
    id: 'stats-fixture',
    apiFootballFixtureId: 7,
    competition: appearancePreviewMatch.competition,
    homeTeam: const TeamInfo(id: 'a', name: 'Pays-Bas', apiFootballTeamId: 1),
    awayTeam: const TeamInfo(id: 'b', name: 'Serbie', apiFootballTeamId: 2),
    kickoffLabel: '20:00',
    status: FixtureStatus.live,
  ),
);
List<Map<String, dynamic>> statistics() => [
  {
    'team': {'id': 1},
    'statistics': [
      {'type': 'Ball Possession', 'value': '58%'},
      {'type': 'Total Shots', 'value': 12},
      {'type': 'Shots on Goal', 'value': 5},
      {'type': 'Corner Kicks', 'value': 4},
      {'type': 'Fouls', 'value': 10},
      {'type': 'Offsides', 'value': 1},
      {'type': 'Yellow Cards', 'value': 1},
      {'type': 'Red Cards', 'value': 0},
    ],
  },
  {
    'team': {'id': 2},
    'statistics': [
      {'type': 'Ball Possession', 'value': '42%'},
      {'type': 'Total Shots', 'value': 8},
      {'type': 'Shots on Goal', 'value': 3},
      {'type': 'Corner Kicks', 'value': 2},
      {'type': 'Fouls', 'value': 14},
      {'type': 'Offsides', 'value': 2},
      {'type': 'Yellow Cards', 'value': 2},
      {'type': 'Red Cards', 'value': 0},
    ],
  },
];
Map<String, dynamic> event(
  int time,
  int team,
  String type,
  String detail, {
  int? extra,
}) => {
  'time': {'elapsed': time, 'extra': extra},
  'team': {'id': team},
  'type': type,
  'detail': detail,
  'player': {'name': 'Joueur'},
};
LiveMatchState live({
  List<Map<String, dynamic>>? events,
  bool sparse = false,
}) => LiveMatchState(
  fixtureId: 7,
  status: '2H',
  elapsed: 71,
  capturedAt: DateTime.now(),
  statisticsCapturedAt: DateTime.now(),
  homeGoals: 1,
  awayGoals: 1,
  halftimeHomeGoals: 1,
  halftimeAwayGoals: 0,
  statistics: sparse ? [] : statistics(),
  events:
      events ??
      [
        event(62, 2, 'Goal', 'Normal Goal'),
        event(31, 1, 'Goal', 'Normal Goal'),
        event(38, 1, 'Card', 'Yellow Card'),
      ],
);

void main() {
  test(
    'factual reading handles a draw and halftime comeback without claims about unmeasured play',
    () {
      final facts = FootballMatchFacts(match, live());
      expect(facts.summary, contains('a davantage le ballon'));
      expect(facts.summary, contains('produit davantage de tirs'));
      expect(
        facts.summary,
        contains('Serbie est revenu à égalité depuis la mi-temps'),
      );
      expect(facts.summary, isNot(contains('domine')));
      expect(facts.summary, isNot(contains('transition')));
      expect(FootballMatchFacts(match, live(sparse: true)).summary, isNull);
    },
  );
  test(
    'score history reconciles with goals and disappears when events are incomplete or ambiguous',
    () {
      final events = FootballMatchFacts(match, live()).events;
      expect(events.map((e) => e.scoreLabel), ['1 – 0', '1 – 0', '1 – 1']);
      expect(
        FootballMatchFacts(
          match,
          live(events: [event(62, 2, 'Goal', 'Normal Goal')]),
        ).events.single.scoreLabel,
        isNull,
      );
      final future = FootballMatchFacts(
        match,
        live(
          events: [
            event(31, 1, 'Goal', 'Normal Goal'),
            event(80, 2, 'Goal', 'Normal Goal'),
          ],
        ),
      );
      expect(future.events.single.scoreLabel, isNull);
      final own = FootballMatchFacts(
        match,
        live(
          events: [
            event(31, 1, 'Goal', 'Own Goal'),
            event(62, 2, 'Goal', 'Normal Goal'),
          ],
        ),
      );
      expect(own.events.every((e) => e.scoreLabel == null), isTrue);
      expect(
        FootballMatchFacts(
          match,
          live(events: [event(38, 1, 'Card', 'Second Yellow card')]),
        ).events.single.kind,
        LectorMatchEventKind.dismissal,
      );
    },
  );
  test(
    'added time stays on half boundary and foreign teams cannot enter Stats',
    () {
      final facts = FootballMatchFacts(
        match,
        live(
          events: [
            event(45, 1, 'Goal', 'Normal Goal', extra: 3),
            event(46, 2, 'Card', 'Yellow Card'),
            event(64, 99, 'Goal', 'Normal Goal'),
          ],
        ),
      );
      expect(facts.events.length, 2);
      expect(facts.events.first.clock, '45+3′');
      expect(facts.events.first.position, 45);
      expect(facts.events.first.order, lessThan(facts.events.last.order!));
    },
  );
  testWidgets('a shootout alone does not invent an extra-time period', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FootballLiveStats(
              match: match,
              state: LiveMatchState(
                fixtureId: 7,
                status: 'PEN',
                capturedAt: DateTime.now(),
                homeGoals: 1,
                awayGoals: 1,
              ),
            ),
          ),
        ),
      ),
    );
    final stats = tester.widget<LectorMatchStats>(
      find.byType(LectorMatchStats),
    );
    expect(stats.periods.map((p) => p.label), ['1re période', '2e période']);
    expect(tester.takeException(), isNull);
  });
  for (final light in [true, false]) {
    testWidgets(
      'football footprint is readable on mobile, raw facts collapse and newest events come first ($light)',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: light ? CopilotTheme.light : CopilotTheme.dark,
            home: Scaffold(
              body: SingleChildScrollView(
                child: FootballLiveStats(match: match, state: live()),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(Image), findsNothing);
        expect(find.text('À cet instant'), findsOneWidget);
        expect(find.text('71′'), findsWidgets);
        expect(find.text('Cartons rouges'), findsNothing);
        await tester.scrollUntilVisible(
          find.text('But · Serbie'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(
          tester.getTopLeft(find.text('But · Serbie')).dy,
          lessThan(tester.getTopLeft(find.text('But · Pays-Bas')).dy),
        );
        await tester.scrollUntilVisible(
          find.text('Statistiques détaillées'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('Statistiques détaillées'));
        await tester.pumpAndSettle();
        expect(find.text('Cartons rouges'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'hero makes live clock prominent and shows received halftime score',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = live();
      await tester.pumpWidget(
        MaterialApp(
          theme: CopilotTheme.dark,
          home: Scaffold(
            body: LectorMatchHero(match: state.overlay(match), state: state),
          ),
        ),
      );
      expect(find.text('71′ · En direct'), findsOneWidget);
      expect(find.text('MT 1–0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
