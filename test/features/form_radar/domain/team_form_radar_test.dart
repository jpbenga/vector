import 'package:copilot/features/form_radar/domain/team_form_radar.dart';
import 'package:copilot/features/matches/domain/match_board_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

  test('requires three completed matches', () {
    final ranked = TeamFormRadarRanker.rank([
      _team('Trop tôt', ['W', 'W']),
    ]);

    expect(ranked, isEmpty);
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
