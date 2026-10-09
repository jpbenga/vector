import 'package:copilot/app/theme/app_theme.dart';
import 'package:copilot/core/domain/lector_recorded_radar.dart';
import 'package:copilot/core/domain/lector_radar_contributions.dart';
import 'package:copilot/core/domain/lector_temporal_state.dart';
import 'package:copilot/core/sports/domain/sport_match_history.dart';
import 'package:copilot/core/widgets/lector_workspace_navigation.dart';
import 'package:copilot/core/widgets/lector_temporal_feed.dart';
import 'package:copilot/core/widgets/lector_match_card.dart';
import 'package:copilot/core/widgets/lector_recorded_radar_panel.dart';
import 'package:copilot/core/widgets/lector_player_radar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> radarRecord() => {
  'sport': 'football',
  'provider': 'api-football',
  'fixtureId': '100',
  'kickoffAt': '2026-10-09T18:00:00Z',
  'capturedAt': '2026-10-09T10:00:00Z',
  'recordedAt': '2026-10-09T10:01:00Z',
  'profiles': [
    {
      'player': {'id': 7, 'name': 'Henrik Bjørdal'},
      'team': {'id': 2, 'name': 'Vålerenga'},
      'activity': [
        for (var n = 1; n <= 8; n++)
          {
            'fixture_id': n,
            'played_at': '2026-09-${n.toString().padLeft(2, '0')}T18:00:00Z',
            'goals': n == 7 ? 1 : 0,
            'assists': n == 8 ? 1 : 0,
            'appeared': true,
            'substitute': false,
          },
      ],
    },
  ],
};
void main() {
  test('hockey attribution requires exact team and unambiguous name', () {
    final source = radarRecord();
    final footballPlayer = (source['profiles'] as List).single as Map;
    final profile = {
      'id': 7,
      'name': 'Henrik Bjørdal',
      'team': {'id': 2, 'name': 'Vålerenga'},
      'activity': [
        for (final a in footballPlayer['activity'] as List)
          {
            'id': a['fixture_id'],
            'startsAt': a['played_at'],
            'goals': a['goals'],
            'assists': a['assists'],
          },
      ],
    };
    final record = {
      ...source,
      'sport': 'hockey',
      'profiles': [profile],
    };
    final snapshot = LectorRecordedRadar.parse(record, 'hockey', '100')!;
    final at = DateTime.parse('2026-10-09T18:40:00Z');
    SportMatchEvent event({
      String team = '2',
      String period = 'P2',
      bool assist = false,
    }) => SportMatchEvent(
      period: period,
      minute: 13,
      elapsed: 33,
      teamId: team,
      type: 'goal',
      detail: 'Normal',
      players: [assist ? 'Another player' : 'Henrik Bjørdal'],
      assists: assist ? ['Henrik Bjørdal'] : [],
    );
    expect(
      hockeyRadarContributions(snapshot, [event(), event()], at).single.label,
      'But P2 · 13′',
    );
    expect(
      hockeyRadarContributions(snapshot, [
        event(assist: true),
      ], at).single.label,
      'Passe décisive P2 · 13′',
    );
    expect(hockeyRadarContributions(snapshot, [event(team: '3')], at), isEmpty);
    expect(
      hockeyRadarContributions(snapshot, [event(period: 'PT')], at),
      isEmpty,
    );
    final ambiguous = LectorRecordedRadar.parse(
      {
        ...record,
        'profiles': [
          profile,
          {...profile, 'id': 8},
        ],
      },
      'hockey',
      '100',
    )!;
    expect(hockeyRadarContributions(ambiguous, [event()], at), isEmpty);
  });
  for (final width in [320.0, 360.0, 390.0]) {
    testWidgets(
      'five destinations fit $width with only one selected semantics',
      (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var selected = LectorWorkspaceSection.forMe;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark,
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: StatefulBuilder(
                  builder: (context, setState) => LectorWorkspaceNavigation(
                    selected: selected,
                    onChanged: (value) => setState(() => selected = value),
                  ),
                ),
              ),
            ),
          ),
        );
        for (final section in LectorWorkspaceSection.values) {
          await tester.tap(
            find.byKey(ValueKey('workspace-tab-${section.name}')),
          );
          await tester.pump();
          expect(selected, section);
          expect(
            find.byKey(ValueKey('workspace-selected-${section.name}')),
            findsOneWidget,
          );
          for (final other in LectorWorkspaceSection.values.where(
            (s) => s != section,
          )) {
            expect(
              find.byKey(ValueKey('workspace-selected-${other.name}')),
              findsNothing,
            );
          }
          for (final label in [
            'Pour moi',
            'Radar',
            'Tous',
            'Générateur',
            'Bilan',
          ]) {
            expect(find.text(label), findsOneWidget);
          }
          expect(tester.takeException(), isNull);
        }
      },
    );
  }
  testWidgets('live filter and live scores change cleanly into final state', (
    tester,
  ) async {
    final phases = [
      LectorMatchPhase.live,
      LectorMatchPhase.upcoming,
      LectorMatchPhase.finished,
    ];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: LectorTemporalFeed<LectorMatchPhase>(
            items: phases,
            phaseOf: (v) => v,
            sectionBuilder: (context, items, p) =>
                Text('matches:${items.map((v) => v.name).join(',')}'),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('temporal-filter-live')));
    await tester.pump();
    expect(find.text('matches:live'), findsOneWidget);
    expect(find.text('matches:upcoming'), findsNothing);
    final active = tester.widget<ChoiceChip>(
      find.byKey(const ValueKey('temporal-filter-live')),
    );
    expect(active.selected, true);
    expect(active.side!.width, 1.5);
    Future<void> score(bool live) => tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: LectorTeamLine(name: 'Home', score: 2, isLive: live),
        ),
      ),
    );
    await score(true);
    expect(find.byKey(const ValueKey('match-score-live')), findsOneWidget);
    await score(false);
    expect(find.byKey(const ValueKey('match-score-live')), findsNothing);
    expect(find.text('2'), findsOneWidget);
  });
  testWidgets(
    'confirmed player highlights header without rewriting historic cells',
    (tester) async {
      final snapshot = LectorRecordedRadar.parse(
        radarRecord(),
        'football',
        '100',
      )!;
      final at = DateTime.parse('2026-10-09T18:40:00Z');
      final event = {
        'type': 'Goal',
        'detail': 'Normal Goal',
        'team': {'id': 2},
        'player': {'id': 7},
        'assist': {'id': 8},
        'time': {'elapsed': 33},
      };
      final contributions = footballRadarContributions(snapshot, [
        event,
        event,
      ], at);
      expect(contributions.length, 1);
      Future<void> pump(bool live) => tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: SizedBox(
              width: 360,
              child: LectorRecordedRadarPanel(
                snapshot: snapshot,
                contributions: contributions,
                isLive: live,
              ),
            ),
          ),
        ),
      );
      await pump(true);
      expect(find.text('1 joueur signalé décisif'), findsOneWidget);
      expect(find.text('But 33′'), findsOneWidget);
      expect(find.text('LIVE'), findsOneWidget);
      final before = tester
          .widget<LectorPlayerActivityMatrix>(
            find.byType(LectorPlayerActivityMatrix),
          )
          .activity
          .map((a) => a.contributions)
          .toList();
      await pump(false);
      expect(find.text('Terminé'), findsOneWidget);
      expect(find.text('But 33′'), findsOneWidget);
      expect(
        tester
            .widget<LectorPlayerActivityMatrix>(
              find.byType(LectorPlayerActivityMatrix),
            )
            .activity
            .map((a) => a.contributions)
            .toList(),
        before,
      );
      expect(
        footballRadarContributions(snapshot, [
          {...event, 'detail': 'Own Goal'},
        ], at),
        isEmpty,
      );
      expect(
        footballRadarContributions(snapshot, [
          {
            ...event,
            'team': {'id': 3},
          },
        ], at),
        isEmpty,
      );
      expect(footballRadarContributions(snapshot, [event], null), isEmpty);
      expect(
        LectorRecordedRadar.parse(
          {...radarRecord(), 'recordedAt': '2026-10-09T19:00:00Z'},
          'football',
          '100',
        ),
        isNull,
      );
      expect(LectorRecordedRadar.parse(radarRecord(), 'hockey', '100'), isNull);
      expect(tester.takeException(), isNull);
    },
  );
}
