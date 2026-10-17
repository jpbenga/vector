import 'package:copilot/features/form_radar/domain/team_form_radar.dart';
import 'package:copilot/features/matches/domain/match_board_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'weakest ranking uses the full eligible pool, fewer points and then the sixth result',
    () {
      final ranked = TeamFormRadarRanker.rank([
        _team('Aucune preuve', ['L', 'L', 'L', 'L']),
        _team('Nuls', ['D', 'D', 'D', 'D', 'D']),
        _team('Victoire ancienne', ['W', 'L', 'L', 'L', 'L', 'L']),
        _team('Défaites', ['L', 'L', 'L', 'L', 'L', 'L']),
        _team('Inconnu', ['?', 'L', 'L', 'L', 'L']),
      ], weakest: true);
      expect(ranked.map((e) => e.profile.teamName), [
        'Défaites',
        'Victoire ancienne',
        'Nuls',
      ]);
      expect(ranked.first.points, 0);
      expect(ranked.first.streakLabel, contains('perdues'));
      expect(ranked.last.points, 5);
    },
  );

  test('radar distinguishes three wins from a five-game unbeaten run', () {
    final ranked = TeamFormRadarRanker.rank([
      _team('Série', ['L', 'D', 'W', 'W', 'W']),
      _team('Invaincu', ['W', 'D', 'W', 'D', 'W']),
    ]);
    final hot = ranked.singleWhere((r) => r.profile.teamName == 'Série');
    expect(hot.victorySeries.count, 3);
    expect(hot.victorySeries.exact, true);
    expect(hot.streakLabel, contains('En série'));
    final unbeaten = ranked.singleWhere(
      (r) => r.profile.teamName == 'Invaincu',
    );
    expect(unbeaten.victorySeries.detected, false);
    expect(unbeaten.streakLabel, 'Invaincu · 5');
  });

  test('ranks teams by five-match points before recent form', () {
    final ranked = TeamFormRadarRanker.rank([
      _team('Régulière', ['W', 'D', 'W', 'D', 'W']),
      _team('Pic récent', ['L', 'L', 'W', 'W', 'W']),
    ]);

    expect(ranked.map((entry) => entry.profile.teamName), [
      'Régulière',
      'Pic récent',
    ]);
    expect(ranked.first.points, 11);
    expect(ranked.last.recentPoints, 9);
  });

  test('requires five completed matches', () {
    final ranked = TeamFormRadarRanker.rank([
      _team('Trop tôt', ['W', 'W', 'W', 'W']),
    ]);

    expect(ranked, isEmpty);
  });

  test('uses the sixth result to resolve a five-match tie', () {
    final ranked = TeamFormRadarRanker.rank([
      _team('Eibar', ['L', 'W', 'W', 'W', 'W', 'W']),
      _team('Barcelone', ['W', 'W', 'W', 'W', 'W', 'W']),
    ]);

    expect(ranked.map((entry) => entry.profile.teamName), [
      'Barcelone',
      'Eibar',
    ]);
    expect(ranked.first.points, 15);
    expect(ranked.last.points, 15);
  });

  test('continues with the seventh result when the sixth is tied', () {
    final ranked = TeamFormRadarRanker.rank([
      _team('Eibar', ['L', 'W', 'W', 'W', 'W', 'W', 'W']),
      _team('Bayern', ['W', 'W', 'W', 'W', 'W', 'W', 'W']),
    ]);

    expect(ranked.map((entry) => entry.profile.teamName), ['Bayern', 'Eibar']);
  });
}

TeamFormRadarProfile _team(String name, List<String> results) =>
    TeamFormRadarProfile(
      teamId: name.hashCode,
      teamName: name,
      leagueId: 1,
      leagueName: 'Ligue test',
      activity: [
        for (final indexed in results.indexed)
          TeamRecentMatchSnapshot(
            opponentName: 'Adversaire',
            venue: RecentMatchVenue.home,
            result: indexed.$2,
            playedAt: DateTime(2026, 9, indexed.$1 + 1),
          ),
      ],
    );
