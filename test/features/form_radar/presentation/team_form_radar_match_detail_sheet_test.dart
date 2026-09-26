import 'package:copilot/app/theme/app_theme.dart';
import 'package:copilot/features/form_radar/domain/team_form_radar.dart';
import 'package:copilot/features/form_radar/presentation/team_form_radar_match_detail_sheet.dart';
import 'package:copilot/features/matches/domain/match_board_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows collective match details and the shared event timeline', (
    tester,
  ) async {
    final profile = TeamFormRadarProfile(
      teamId: 1,
      teamName: 'Brighton',
      leagueId: 39,
      leagueName: 'Premier League',
      activity: [_match],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => showTeamFormRadarMatchDetail(
                  context,
                  profile: profile,
                  initialIndex: 0,
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

    expect(find.text('Brighton'), findsWidgets);
    expect(find.text('Tottenham'), findsOneWidget);
    expect(find.text('2 – 1'), findsOneWidget);
    expect(find.text('Victoire · +3 pts'), findsOneWidget);
    expect(find.text('Statistiques du match'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();

    expect(find.text('Événements clés'), findsOneWidget);
    expect(find.text('Pedro'), findsOneWidget);
    expect(find.text('Son'), findsOneWidget);
    expect(find.text('Welbeck'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

final _match = TeamRecentMatchSnapshot(
  fixtureId: 7,
  opponentName: 'Tottenham',
  venue: RecentMatchVenue.home,
  result: 'W',
  goalsFor: 2,
  goalsAgainst: 1,
  playedAt: DateTime(2026, 9, 28),
  statistics: TeamRecentMatchStatisticsSnapshot(
    shotsFor: 14,
    shotsAgainst: 9,
    shotsOnTargetFor: 6,
    shotsOnTargetAgainst: 3,
    expectedGoalsFor: 1.82,
    expectedGoalsAgainst: .91,
    possessionFor: 58,
    possessionAgainst: 42,
  ),
  events: [
    TeamRecentMatchEventSnapshot(
      minute: 12,
      teamId: 1,
      teamName: 'Brighton',
      playerName: 'Pedro',
    ),
    TeamRecentMatchEventSnapshot(
      minute: 46,
      teamId: 2,
      teamName: 'Tottenham',
      playerName: 'Son',
    ),
    TeamRecentMatchEventSnapshot(
      minute: 67,
      teamId: 1,
      teamName: 'Brighton',
      playerName: 'Welbeck',
    ),
  ],
);
