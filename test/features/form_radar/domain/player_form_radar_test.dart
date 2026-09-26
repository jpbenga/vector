import 'package:flutter_test/flutter_test.dart';

import 'package:copilot/features/form_radar/domain/player_form_radar.dart';
import 'package:copilot/features/matches/domain/match_board_item.dart';

void main() {
  PlayerFormRadarProfile profile({
    required int id,
    required String name,
    required List<int> contributions,
  }) {
    return PlayerFormRadarProfile(
      playerId: id,
      playerName: name,
      teamId: id,
      teamName: 'Équipe $id',
      leagueId: 1,
      activity: [
        for (final indexed in contributions.indexed)
          PlayerFormRadarMatchSnapshot(
            fixtureId: indexed.$1 + 1,
            playedAt: DateTime(2026, 9, indexed.$1 + 1),
            appeared: true,
            starter: true,
            substitute: false,
            minutes: 90,
            goals: indexed.$2,
            assists: 0,
          ),
      ],
    );
  }

  test('rewards an uninterrupted run beyond the three recent matches', () {
    final shorterRun = profile(
      id: 1,
      name: 'Pic récent',
      contributions: [0, 0, 0, 1, 1, 1],
    );
    final longerRun = profile(
      id: 2,
      name: 'Série continue',
      contributions: [1, 1, 1, 1, 1, 1],
    );

    final ranked = PlayerFormRadarRanker.rank([shorterRun, longerRun]);

    expect(ranked.map((entry) => entry.profile.playerName), [
      'Série continue',
      'Pic récent',
    ]);
    expect(ranked.first.recentDecisiveMatches, 3);
    expect(ranked.first.decisiveStreak, 6);
  });

  test('does not retain a player with one isolated recent contribution', () {
    final isolated = profile(
      id: 1,
      name: 'Pic isolé',
      contributions: [0, 0, 0, 0, 0, 1],
    );

    expect(PlayerFormRadarRanker.rank([isolated]), isEmpty);
  });
}
