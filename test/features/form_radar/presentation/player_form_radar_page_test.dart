import 'package:copilot/app/theme/app_theme.dart';
import 'package:copilot/features/form_radar/domain/team_form_radar.dart';
import 'package:copilot/features/form_radar/presentation/form_radar_signal_panel.dart';
import 'package:copilot/features/matches/presentation/widgets/match_feed_card.dart';
import 'package:copilot/features/form_radar/presentation/player_form_radar_page.dart';
import 'package:copilot/features/matches/domain/match_board_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'uses the shared card and current profile across sign in and sign out',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final match = _playerMatch();
      final profileMatch = match.copyWith(
        signals: const [
          MatchSignal(
            id: 'profile_reading',
            title: 'Lecture retenue pour mon profil',
            summary: '',
            proofs: [],
          ),
          MatchSignal(
            id: 'scenario:profile_scenario',
            title: 'Scénario retenu pour mon profil',
            summary: '',
            proofs: [],
          ),
        ],
      );
      MatchBoardItem? opened;
      Future<void> render({
        required bool connected,
        required List<MatchBoardItem> personalized,
      }) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark,
            home: Scaffold(
              body: SingleChildScrollView(
                child: PlayerFormRadarPage(
                  matches: [match],
                  radarSourceMatches: [match],
                  personalizedMatches: personalized,
                  showProfileReadings: connected,
                  selectedDate: DateTime.now(),
                  onOpenMatch: (value) => opened = value,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await render(connected: true, personalized: [profileMatch]);
      expect(find.byType(MatchFeedCard), findsOneWidget);
      expect(find.byType(FormRadarSignalPanel), findsOneWidget);
      expect(find.text('Lecture retenue pour mon profil'), findsOneWidget);
      expect(find.text('Scénario retenu pour mon profil'), findsOneWidget);
      expect(find.text('Lecture globale à masquer'), findsNothing);
      expect(find.text('Avant'), findsNothing);
      expect(
        tester.getSize(find.byType(FormRadarSignalPanel)).height,
        lessThan(180),
      );
      await tester.tap(
        find
            .descendant(
              of: find.byType(MatchFeedCard),
              matching: find.text('Club A'),
            )
            .first,
      );
      expect(opened, same(profileMatch));
      expect(tester.takeException(), isNull);

      await render(connected: true, personalized: []);
      expect(find.text('Lecture retenue pour mon profil'), findsNothing);
      expect(find.text('Scénario retenu pour mon profil'), findsNothing);
      expect(find.text('Lecture globale à masquer'), findsNothing);
      expect(find.byType(FormRadarSignalPanel), findsOneWidget);

      await render(connected: false, personalized: [profileMatch]);
      expect(find.text('Lecture retenue pour mon profil'), findsNothing);
      expect(find.text('Scénario retenu pour mon profil'), findsNothing);
      expect(find.byType(FormRadarSignalPanel), findsOneWidget);
      await tester.tap(
        find
            .descendant(
              of: find.byType(MatchFeedCard),
              matching: find.text('Club A'),
            )
            .first,
      );
      expect(opened, same(match));
      expect(tester.takeException(), isNull);
    },
  );

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

MatchBoardItem _playerMatch() => MatchBoardItem(
  fixture: const NormalizedFixture(
    id: 'radar-context',
    competition: CompetitionInfo(
      id: '61',
      name: 'Championnat',
      country: CountryInfo(code: 'FR', name: 'France'),
      season: 2026,
      apiFootballLeagueId: 61,
    ),
    homeTeam: TeamInfo(id: '1', name: 'Club A', apiFootballTeamId: 1),
    awayTeam: TeamInfo(id: '2', name: 'Club B', apiFootballTeamId: 2),
    kickoffLabel: '18:00',
    status: FixtureStatus.scheduled,
  ),
  primaryMarket: const MarketOdds(
    id: 'unavailable',
    label: 'Indisponible',
    odds: 0,
  ),
  compatibility: 0,
  signals: const [
    MatchSignal(
      id: 'unfiltered',
      title: 'Lecture globale à masquer',
      summary: '',
      proofs: [],
    ),
  ],
  analysis: MatchAnalysisData(
    playerFormRadarProfiles: [
      PlayerFormRadarProfile(
        playerId: 1,
        playerName: 'Joueur A',
        teamId: 1,
        teamName: 'Club A',
        leagueId: 61,
        activity: [
          for (var i = 0; i < 3; i++)
            PlayerFormRadarMatchSnapshot(
              fixtureId: i + 1,
              playedAt: DateTime(2026, 9, i + 1),
              appeared: true,
              starter: true,
              substitute: false,
              minutes: 90,
              goals: 1,
              assists: 0,
            ),
        ],
      ),
    ],
  ),
);
