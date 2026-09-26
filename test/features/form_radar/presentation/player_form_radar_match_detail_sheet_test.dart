import 'package:copilot/app/theme/app_theme.dart';
import 'package:copilot/features/form_radar/presentation/player_form_radar_match_detail_sheet.dart';
import 'package:copilot/features/matches/domain/match_board_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('explains a selected Radar match without leaving the Radar', (
    tester,
  ) async {
    final profile = PlayerFormRadarProfile(
      playerId: 1,
      playerName: 'Carles Pérez',
      teamId: 2,
      teamName: 'Girona',
      leagueId: 140,
      activity: [_match(1), _match(2, goals: 1, assists: 1)],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => showPlayerFormRadarMatchDetail(
                  context,
                  profile: profile,
                  activity: profile.activity,
                  initialFixtureId: 2,
                ),
                child: const Text('Ouvrir'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    expect(find.text('Carles Pérez'), findsOneWidget);
    expect(find.text('Girona'), findsWidgets);
    expect(find.text('Girona 3 – 1 Albacete'), findsNothing);
    expect(find.text('Chronologie des actions'), findsOneWidget);
    expect(find.text('But'), findsNWidgets(2));
    expect(find.text('Passe déc.'), findsNWidgets(2));
    expect(find.text('14 sept. 2026'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

PlayerFormRadarMatchSnapshot _match(
  int fixtureId, {
  int goals = 0,
  int assists = 0,
}) => PlayerFormRadarMatchSnapshot(
  fixtureId: fixtureId,
  playedAt: DateTime(2026, 9, fixtureId == 1 ? 10 : 14),
  appeared: true,
  starter: true,
  substitute: false,
  minutes: 78,
  goals: goals,
  assists: assists,
  competitionName: 'La Liga',
  round: 'Journée 5',
  homeTeamName: 'Girona',
  homeGoals: 3,
  awayTeamName: 'Albacete',
  awayGoals: 1,
  actions: [
    if (goals > 0)
      const PlayerFormRadarActionSnapshot(
        minute: 31,
        kind: PlayerFormRadarActionKind.goal,
      ),
    if (assists > 0)
      const PlayerFormRadarActionSnapshot(
        minute: 64,
        kind: PlayerFormRadarActionKind.assist,
      ),
  ],
);
