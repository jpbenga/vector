import 'package:flutter/material.dart';
import 'package:copilot/core/theme/app_theme.dart';
import 'package:copilot/core/widgets/lector_match_detail_view.dart';
import 'package:copilot/features/appearance/data/appearance_preview_fixture.dart';
import 'package:copilot/features/matches/domain/match_board_item.dart';
import 'package:copilot/features/matches/domain/live_match_state.dart';
import 'package:copilot/features/matches/presentation/widgets/lector_match_hero.dart';
import 'package:copilot/features/matches/presentation/widgets/football_live_stats.dart';

// Explicitly isolated demonstration data. No credentials, provider calls or
// production feeds; run only with -t tool/previews/football_stats_preview.dart.
final match = appearancePreviewMatch.copyWith(
  fixture: NormalizedFixture(
    id: 'stats-fixture',
    apiFootballFixtureId: 7,
    competition: const CompetitionInfo(
      id: 'preview-nations',
      name: 'UEFA Nations League',
      country: CountryInfo(code: 'World', name: 'International'),
      season: 2026,
      logoUrl: 'https://media.api-sports.io/football/leagues/5.png',
    ),
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

void main() => runApp(
  MaterialApp(
    theme: CopilotTheme.dark,
    debugShowCheckedModeBanner: false,
    home: _Preview(),
  ),
);

class _Preview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = live();
    return LectorMatchDetailView(
      openStats: true,
      hero: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Exemple visuel · données de démonstration',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          LectorMatchHero(match: state.overlay(match), state: state),
        ],
      ),
      synthesis: const SizedBox.shrink(),
      stats: FootballLiveStats(match: match, state: state),
      tabBuilder: (_, _) => const Text('Aperçu du composant Stats'),
    );
  }
}
