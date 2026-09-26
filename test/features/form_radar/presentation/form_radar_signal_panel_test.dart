import 'package:copilot/app/theme/app_theme.dart';
import 'package:copilot/features/form_radar/domain/player_form_radar.dart';
import 'package:copilot/features/form_radar/presentation/form_radar_signal_panel.dart';
import 'package:copilot/features/matches/domain/match_board_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
    expect(find.text('Historique'), findsOneWidget);
    expect(find.text('3 récents'), findsOneWidget);
    expect(find.text('K. Mbappé'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

PlayerFormRadarProfile _profile() => PlayerFormRadarProfile(
  playerId: 278,
  playerName: 'K. Mbappé',
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
