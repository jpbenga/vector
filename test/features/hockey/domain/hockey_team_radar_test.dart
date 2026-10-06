import 'package:copilot/core/sports/domain/sport.dart';
import 'package:copilot/core/sports/domain/sport_fixture.dart';
import 'package:copilot/core/sports/domain/sport_competition_context.dart';
import 'package:copilot/features/hockey/domain/hockey_team_radar.dart';
import 'package:flutter_test/flutter_test.dart';

SportEntityId id(SportEntityKind kind, String value) => SportEntityId(
  sport: SportId.hockey,
  provider: 'api-hockey',
  kind: kind,
  value: value,
);
SportStandingRow team(String name, List<bool> wins) {
  final history = [
    for (final (i, win) in wins.indexed)
      SportFormResult(
        matchId: id(SportEntityKind.match, '$name-$i'),
        startsAt: DateTime.utc(2026, 9, i + 1),
        opponent: 'Adversaire',
        home: i.isEven,
        scored: win ? 2 : 1,
        conceded: win ? 1 : 2,
        outcome: win ? SportFormOutcome.win : SportFormOutcome.loss,
        providerStatus: i.isEven ? 'AOT' : 'FT',
      ),
  ];
  return SportStandingRow(
    team: SportParticipant(id: id(SportEntityKind.team, name), name: name),
    rank: 1,
    played: wins.length,
    points: 0,
    wins: 0,
    losses: 0,
    form: history.skip((history.length - 5).clamp(0, history.length)),
    formHistory: history,
  );
}

SportCompetitionContext competition(
  List<SportStandingRow> rows, {
  bool verified = true,
}) => SportCompetitionContext(
  id: id(SportEntityKind.competition, '35'),
  name: 'KHL',
  season: '2026',
  country: 'Russia',
  formPhaseVerified: verified,
  tables: [
    SportStandingTable(stage: 'Regular Season', group: 'East', rows: rows),
    SportStandingTable(stage: 'Regular Season', group: 'Division', rows: rows),
  ],
);
void main() {
  test(
    'radar indicates an active three-win series and keeps counting beyond five',
    () {
      final ranked = HockeyTeamRadarRanker.rank([
        competition([
          team('Three', [false, false, true, true, true]),
          team('Eight', List.filled(8, true)),
        ]),
      ]);
      for (final entry in ranked) {
        expect(entry.victorySeries.detected, true);
        expect(entry.victorySeries.exact, true);
        expect(entry.streakLabel, contains('En série'));
      }
      expect(ranked.first.victorySeries.count, 8);
    },
  );

  for (final offset in [6, 7, 8]) {
    test('uses the ${offset}th result after a five-match hockey tie', () {
      final alpha = List.filled(10, true)..[10 - offset] = false;
      final ranked = HockeyTeamRadarRanker.rank([
        competition([
          team('Alpha', alpha),
          team('Zulu', List.filled(10, true)),
        ]),
      ]);
      expect(ranked.map((e) => e.row.team.name), ['Zulu', 'Alpha']);
      expect(ranked.map((e) => e.wins), [5, 5]);
      expect(ranked.first.streak, 10);
      expect(ranked.last.streak, offset - 1);
      expect(
        ranked,
        hasLength(2),
      ); // One entry despite multiple standing groups.
    });
  }
  test(
    'recent results dominate history; unknown phase and short history excluded',
    () {
      final ranked = HockeyTeamRadarRanker.rank([
        competition([
          team('Older wins', [
            true,
            true,
            true,
            true,
            true,
            false,
            false,
            true,
            true,
            true,
          ]),
          team('Recent wins', [
            false,
            false,
            false,
            false,
            false,
            true,
            true,
            true,
            true,
            false,
          ]),
          team('Too early', [true, true, true, true]),
        ]),
      ]);
      expect(ranked.map((e) => e.row.team.name), ['Recent wins', 'Older wins']);
      expect(
        HockeyTeamRadarRanker.rank([
          competition([team('Mixed', List.filled(10, true))], verified: false),
        ]),
        isEmpty,
      );
    },
  );
}
