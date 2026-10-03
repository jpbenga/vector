import 'package:copilot/app/theme/app_theme.dart';
import 'package:copilot/features/form_radar/domain/team_form_radar.dart';
import 'package:copilot/features/form_radar/presentation/player_form_radar_page.dart';
import 'package:copilot/features/matches/domain/match_board_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('limits team radar to fifty entries and paginates by ten', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: SingleChildScrollView(
            child: PlayerFormRadarPage(
              matches: const [],
              selectedDate: DateTime(2026, 10, 1),
              onOpenMatch: (_) {},
              teamProfiles: [for (var i = 1; i <= 52; i++) _team(i)],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Équipes'));
    await tester.pumpAndSettle();

    expect(find.text('Top 50'), findsOneWidget);
    expect(find.text('1–10 sur 50'), findsOneWidget);
    expect(find.text('Équipe 01'), findsOneWidget);
    expect(find.text('Équipe 11'), findsNothing);
    expect(find.text('Équipe 51'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('team-next')));
    await tester.pumpAndSettle();

    expect(find.text('11–20 sur 50'), findsOneWidget);
    expect(find.text('Équipe 11'), findsOneWidget);
    expect(find.text('Équipe 51'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

TeamFormRadarProfile _team(int index) => TeamFormRadarProfile(
  teamId: index,
  teamName: 'Équipe ${index.toString().padLeft(2, '0')}',
  leagueId: 61,
  leagueName: 'Championnat',
  activity: [
    for (var match = 0; match < 5; match++)
      TeamRecentMatchSnapshot(
        fixtureId: index * 10 + match,
        opponentName: 'Adversaire $match',
        venue: RecentMatchVenue.home,
        result: 'W',
        goalsFor: 2,
        goalsAgainst: 0,
      ),
  ],
);
