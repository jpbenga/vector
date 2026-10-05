import 'package:copilot/app/theme/app_theme.dart';
import 'package:copilot/features/form_radar/domain/player_form_radar.dart';
import 'package:copilot/features/form_radar/presentation/form_radar_signal_panel.dart';
import 'package:copilot/features/matches/domain/match_board_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'match preview shows four unique players and expands on request',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final profiles = [
        for (var id = 0; id < 8; id++) _profile(id: id, name: 'Joueur $id'),
      ];
      final entries = [
        ...PlayerFormRadarRanker.rank(profiles),
        ...PlayerFormRadarRanker.rank([profiles.first]),
      ];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: SingleChildScrollView(
              child: FormRadarSignalPanel(entries: entries),
            ),
          ),
        ),
      );
      expect(find.text('8 signaux de forme'), findsOneWidget);
      expect(find.text('Joueur 0'), findsOneWidget);
      expect(find.text('Joueur 3'), findsOneWidget);
      expect(find.text('Joueur 4'), findsNothing);
      expect(find.text('Voir les 8 joueurs'), findsOneWidget);
      await tester.tap(find.text('Voir les 8 joueurs'));
      await tester.pump();
      for (var id = 0; id < 8; id++) {
        expect(find.text('Joueur $id'), findsOneWidget);
      }
      await tester.ensureVisible(find.text('Réduire la liste'));
      await tester.tap(find.text('Réduire la liste'));
      await tester.pump();
      expect(find.text('Joueur 4'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('shows the full activity history inside a match signal', (
    tester,
  ) async {
    final entry = PlayerFormRadarRanker.rank([_profile()]).single;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: SizedBox(
            width: 390,
            child: FormRadarSignalPanel(entries: [entry]),
          ),
        ),
      ),
    );

    expect(find.text('Signaux Form Radar'), findsOneWidget);
    expect(find.text('Avant'), findsOneWidget);
    expect(find.text('3 récents'), findsOneWidget);
    expect(find.text('K. Mbappé'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

PlayerFormRadarProfile _profile({int id = 278, String name = 'K. Mbappé'}) =>
    PlayerFormRadarProfile(
      playerId: id,
      playerName: name,
      teamId: 541,
      teamName: 'Real Madrid',
      leagueId: 140,
      activity: [
        for (var index = 0; index < 7; index++)
          PlayerFormRadarMatchSnapshot(
            fixtureId: index + 1,
            playedAt: DateTime(2026, 9, index + 1),
            appeared: true,
            starter: true,
            substitute: false,
            minutes: 90,
            goals: index >= 4 ? 1 : 0,
            assists: 0,
          ),
      ],
    );
