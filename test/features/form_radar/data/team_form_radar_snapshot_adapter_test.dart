import 'package:copilot/features/form_radar/data/team_form_radar_snapshot_adapter.dart';
import 'package:copilot/features/form_radar/domain/team_form_radar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps a team eligible when the daily fixture feed is empty', () {
    final profiles = const TeamFormRadarSnapshotAdapter().fromSnapshot({
      'raw': {
        'fixtures': const <Object?>[],
        'recent_league_matches': [
          _recentRow(
            leagueId: 140,
            leagueName: 'Championnat national',
            fixtureIds: const [1, 2, 3],
            dates: const [
              '2026-08-20T19:00:00Z',
              '2026-08-27T19:00:00Z',
              '2026-09-03T19:00:00Z',
            ],
          ),
          _recentRow(
            leagueId: 2,
            leagueName: 'Compétition continentale',
            fixtureIds: const [4, 5],
            dates: const ['2026-09-08T19:00:00Z', '2026-09-12T19:00:00Z'],
          ),
        ],
      },
    });

    expect(profiles, hasLength(1));
    final team = profiles.single;
    expect(team.teamName, 'Équipe test');
    expect(team.leagueName, 'Toutes compétitions');
    expect(team.competitionNames.keys, containsAll([140, 2]));
    expect(team.activity.map((match) => match.fixtureId), [1, 2, 3, 4, 5]);
    expect(TeamFormRadarRanker.rank(profiles).single.points, 15);
  });
  test('preserves deduplicated prior results for sixth-match tie breaking', () {
    Map<String, Object?> row(int teamId, String name, String sixth) {
      final row = _recentRow(
        leagueId: 1,
        leagueName: 'Ligue',
        fixtureIds: List.generate(10, (i) => teamId * 100 + i),
        dates: List.generate(
          10,
          (i) => DateTime.utc(2026, 9, i + 1).toIso8601String(),
        ),
      );
      (row['team'] as Map)['id'] = teamId;
      (row['team'] as Map)['name'] = name;
      final matches = row['matches'] as List;
      (matches[4] as Map)['result'] = sixth;
      matches.add(matches[4]);
      return row;
    }

    final profiles = const TeamFormRadarSnapshotAdapter().fromSnapshot({
      'raw': {
        'recent_league_matches': [row(1, 'Alpha', 'L'), row(2, 'Zulu', 'W')],
      },
    });
    expect(profiles.every((p) => p.activity.length == 10), isTrue);
    final ranked = TeamFormRadarRanker.rank(profiles);
    expect(ranked.map((e) => e.profile.teamName), ['Zulu', 'Alpha']);
    expect(ranked.map((e) => e.points), [15, 15]);
  });
}

Map<String, Object?> _recentRow({
  required int leagueId,
  required String leagueName,
  required List<int> fixtureIds,
  required List<String> dates,
}) => {
  'league': {'id': leagueId},
  'team': {
    'id': 529,
    'name': 'Équipe test',
    'logo': 'https://example.test/team.png',
  },
  'matches': [
    for (var index = 0; index < fixtureIds.length; index++)
      {
        'fixture': {'id': fixtureIds[index], 'date': dates[index]},
        'competition_name': leagueName,
        'team_logo': 'https://example.test/team.png',
        'opponent': {'id': 900 + index, 'name': 'Adversaire $index'},
        'venue': index.isEven ? 'home' : 'away',
        'result': 'W',
        'goals': {'for': 2, 'against': 0},
      },
  ],
};
