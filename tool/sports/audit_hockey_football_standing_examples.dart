import 'dart:convert';
import 'dart:io';

import 'package:copilot/features/matches/domain/match_context_key_builder.dart';
import 'package:copilot/features/matches/domain/match_context_key_models.dart';

/// Fictional, fully specified leagues for explaining the actual football
/// standing-zone calculation. Does not alter the app or its publications.
void main() {
  final scenarios =
      <({String id, List<({int points, int games})> rows, int a, int b})>[
        (
          id: 'isolated_leader',
          rows: [
            for (final p in [20, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2])
              (points: p, games: 10),
          ],
          a: 0,
          b: 2,
        ),
        (
          id: 'isolated_bottom',
          rows: [
            for (final p in [18, 17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 0])
              (points: p, games: 10),
          ],
          a: 8,
          b: 11,
        ),
        (
          id: 'opposite_isolated_zones',
          rows: [
            for (final p in [20, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 0])
              (points: p, games: 10),
          ],
          a: 0,
          b: 11,
        ),
        (
          id: 'same_high_zone',
          rows: [
            for (final p in [20, 19, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1])
              (points: p, games: 10),
          ],
          a: 0,
          b: 1,
        ),
        (
          id: 'continuous_standings',
          rows: [
            for (final p in [18, 17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7])
              (points: p, games: 10),
          ],
          a: 0,
          b: 11,
        ),
        (
          id: 'same_ppg_different_games',
          rows: [
            (points: 24, games: 15),
            for (final p in [20, 19, 18, 17, 16, 15, 14, 13, 12, 11, 10])
              (points: p, games: 10),
          ],
          a: 0,
          b: 5,
        ),
      ];
  final results = <Map<String, Object?>>[];
  for (final s in scenarios) {
    final values = [
      for (var i = 0; i < s.rows.length; i++)
        ChampionshipContextValue(
          teamId: i,
          teamName: i == s.a
              ? 'Équipe A'
              : i == s.b
              ? 'Équipe B'
              : 'Équipe ${i + 1}',
          value: s.rows[i].points / s.rows[i].games,
        ),
    ];
    final d = const ChampionshipContextReferenceBuilder().distributionForValues(
      metric: ChampionshipContextMetric.pointsPerGame,
      values: values,
    )!;
    final az = d.zoneForTeam(s.a), bz = d.zoneForTeam(s.b);
    results.add({
      'id': s.id,
      'a': {
        'points': s.rows[s.a].points,
        'games': s.rows[s.a].games,
        'ppg': s.rows[s.a].points / s.rows[s.a].games,
        'zone': az?.side.name,
      },
      'b': {
        'points': s.rows[s.b].points,
        'games': s.rows[s.b].games,
        'ppg': s.rows[s.b].points / s.rows[s.b].games,
        'zone': bz?.side.name,
      },
      'high': d.highZone?.values.map((v) => v.teamName).toList(),
      'low': d.lowZone?.values.map((v) => v.teamName).toList(),
      'detected': (az != null || bz != null) && az != bz,
      'upperFence': d.upperFence,
      'allTeams': [
        for (var i = 0; i < s.rows.length; i++)
          {
            'team': values[i].teamName,
            'points': s.rows[i].points,
            'games': s.rows[i].games,
            'ppg': values[i].value,
          },
      ],
    });
  }
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(results));
}
