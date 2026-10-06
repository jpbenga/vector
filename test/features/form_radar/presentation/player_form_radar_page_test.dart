import 'package:copilot/core/widgets/lector_player_radar.dart';
import 'package:copilot/core/widgets/lector_radar.dart';
import 'package:copilot/app/theme/app_theme.dart';
import 'package:copilot/core/identity/identity_scope.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:copilot/features/form_radar/domain/team_form_radar.dart';
import 'package:copilot/features/form_radar/presentation/form_radar_signal_panel.dart';
import 'package:copilot/features/matches/presentation/widgets/match_feed_card.dart';
import 'package:copilot/features/form_radar/presentation/player_form_radar_page.dart';
import 'package:copilot/features/matches/domain/match_board_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
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
      expect(find.byType(LectorRadarPlayerRow), findsOneWidget);
      expect(find.byType(LectorPlayerActivityMatrix), findsWidgets);
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
              teamProfiles: [
                for (var i = 1; i <= 52; i++) _team(i),
                for (var i = 53; i <= 57; i++)
                  _team(i, leagueId: 64, name: 'A Club féminin $i'),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Équipes'));
    await tester.pumpAndSettle();

    expect(find.byType(LectorRadarRankingPanel), findsOneWidget);
    expect(find.byType(LectorRadarTeamRow), findsNWidgets(10));
    expect(find.byType(LectorFormResultStrip), findsNWidgets(10));
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
    for (var page = 2; page < 5; page++) {
      await tester.tap(find.byKey(const ValueKey('team-next')));
      await tester.pumpAndSettle();
    }
    expect(find.text('41–50 sur 50'), findsOneWidget);
    expect(find.text('Équipe 50'), findsOneWidget);
    expect(find.text('Équipe 51'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'women opt-in updates players, teams and shared match cards, and stays account scoped',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final senior = _playerMatch();
      final women = _playerMatch(
        leagueId: 64,
        teamId: 3,
        teamName: 'Club féminin W',
        playerName: 'Joueuse B',
      );
      Future<void> render(String account) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark,
            home: Scaffold(
              body: SingleChildScrollView(
                child: PlayerFormRadarPage(
                  identityScope: IdentityScope.account(account),
                  matches: [senior, women],
                  radarSourceMatches: [senior, women],
                  teamProfiles: [
                    _team(1),
                    _team(3, leagueId: 64, name: 'Club féminin W'),
                  ],
                  selectedDate: DateTime(2026, 10, 3),
                  onOpenMatch: (_) {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await render('a');
      expect(find.text('Joueuse B'), findsNothing);
      expect(find.byType(MatchFeedCard), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('radar-audience-filters')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('radar-include-women')));
      await tester.tap(
        find.byKey(const ValueKey('radar-apply-audience-filters')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Joueuse B'), findsWidgets);
      expect(find.byType(MatchFeedCard), findsNWidgets(2));
      await tester.ensureVisible(find.text('Équipes'));
      await tester.tap(find.text('Équipes'));
      await tester.pumpAndSettle();
      expect(find.text('Club féminin W'), findsWidgets);
      await render('b');
      expect(find.text('Club féminin W'), findsNothing);
      await render('a');
      expect(find.text('Club féminin W'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'national youth exclusions use both team labels and competition metadata',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1400);
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
                teamProfiles: [
                  _team(1, leagueId: 10, name: 'France'),
                  _team(2, leagueId: 10, name: 'Portugal U20'),
                  _team(3, leagueId: 38, name: 'Angleterre'),
                ],
                selectedDate: DateTime(2026, 10, 3),
                onOpenMatch: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Équipes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Équipe nationale'));
      await tester.pumpAndSettle();
      expect(find.text('France'), findsOneWidget);
      expect(find.text('Portugal U20'), findsNothing);
      expect(find.text('Angleterre'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('radar-audience-filters')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('radar-include-youth')));
      await tester.tap(
        find.byKey(const ValueKey('radar-apply-audience-filters')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Portugal U20'), findsOneWidget);
      expect(find.text('Angleterre'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

TeamFormRadarProfile _team(int index, {int leagueId = 61, String? name}) =>
    TeamFormRadarProfile(
      teamId: index,
      teamName: name ?? 'Équipe ${index.toString().padLeft(2, '0')}',
      leagueId: leagueId,
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

MatchBoardItem _playerMatch({
  int leagueId = 61,
  int teamId = 1,
  String teamName = 'Club A',
  String playerName = 'Joueur A',
}) => MatchBoardItem(
  fixture: NormalizedFixture(
    id: 'radar-context-$teamId',
    competition: CompetitionInfo(
      id: '$leagueId',
      name: 'Championnat',
      country: const CountryInfo(code: 'FR', name: 'France'),
      season: 2026,
      apiFootballLeagueId: leagueId,
    ),
    homeTeam: TeamInfo(
      id: '$teamId',
      name: teamName,
      apiFootballTeamId: teamId,
    ),
    awayTeam: const TeamInfo(id: '2', name: 'Club B', apiFootballTeamId: 2),
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
        playerId: teamId,
        playerName: playerName,
        teamId: teamId,
        teamName: teamName,
        leagueId: leagueId,
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
