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

  PlayerFormRadarProfile contextProfile({
    required int league,
    required DateTime end,
    List<int> contributions = const [1, 1, 1],
    int team = 2,
    int player = 19617,
  }) => PlayerFormRadarProfile(
    playerId: player,
    playerName: 'M. Olise',
    teamId: team,
    teamName: team == 2 ? 'France' : 'Bayern',
    leagueId: league,
    activity: [
      for (final indexed in contributions.indexed)
        PlayerFormRadarMatchSnapshot(
          fixtureId: indexed.$1 + 1,
          playedAt: end.subtract(
            Duration(days: contributions.length - indexed.$1 - 1),
          ),
          appeared: true,
          starter: true,
          substitute: false,
          minutes: 90,
          goals: indexed.$2,
          assists: 0,
        ),
    ],
  );

  test(
    'Olise appears once with the latest France evidence across competitions',
    () {
      final worldCup = contextProfile(league: 1, end: DateTime(2026, 7, 18));
      final nations = contextProfile(league: 5, end: DateTime(2026, 10, 2));
      for (final input in [
        [worldCup, nations],
        [nations, worldCup],
      ]) {
        final ranked = PlayerFormRadarRanker.rank(input);
        expect(ranked, hasLength(1));
        expect(ranked.single.profile, same(nations));
        expect(ranked.single.recentContributions, 3);
      }
    },
  );

  test('old hot evidence cannot revive a player whose current form cooled', () {
    final old = contextProfile(league: 1, end: DateTime(2026, 7, 18));
    final current = contextProfile(
      league: 5,
      end: DateTime(2026, 10, 2),
      contributions: [0, 0, 0],
    );
    expect(PlayerFormRadarRanker.rank([old, current]), isEmpty);
    expect(PlayerFormRadarRanker.rank([current, old]), isEmpty);
  });

  test(
    'club and national team contexts stay independent and names are not IDs',
    () {
      final france = contextProfile(league: 5, end: DateTime(2026, 10, 2));
      final club = contextProfile(
        league: 78,
        team: 157,
        end: DateTime(2026, 9, 30),
      );
      final namesake = contextProfile(
        league: 5,
        player: 999,
        end: DateTime(2026, 10, 2),
      );
      expect(
        PlayerFormRadarRanker.rank([france, club, namesake]),
        hasLength(3),
      );
    },
  );

  test('a player missing from the current team sample cannot use old form', () {
    final old = contextProfile(league: 1, end: DateTime(2026, 7, 18));
    final currentTeammate = contextProfile(
      league: 5,
      player: 999,
      end: DateTime(2026, 10, 2),
    );
    final ranked = PlayerFormRadarRanker.rank([old, currentTeammate]);
    expect(ranked, hasLength(1));
    expect(ranked.single.profile.playerId, 999);
    expect(
      PlayerFormRadarRanker.latestProfiles(
        [old],
        latestTeamMatchDates: {2: DateTime(2026, 10, 2)},
      ),
      isEmpty,
    );
  });

  test('equal dates retain richer evidence regardless of input order', () {
    final short = contextProfile(league: 1, end: DateTime(2026, 10, 2));
    final long = contextProfile(
      league: 5,
      end: DateTime(2026, 10, 2),
      contributions: [1, 1, 1, 1, 1],
    );
    expect(
      PlayerFormRadarRanker.rank([short, long]).single.profile,
      same(long),
    );
    expect(
      PlayerFormRadarRanker.rank([long, short]).single.profile,
      same(long),
    );
  });

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
