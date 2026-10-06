import 'package:copilot/core/sports/domain/sport_match_history.dart';
import 'package:copilot/core/sports/domain/sport.dart';
import 'package:copilot/core/sports/domain/sport_competition_context.dart';
import 'package:copilot/core/sports/domain/sport_fixture.dart';
import 'package:copilot/core/sports/domain/sport_snapshot.dart';

final readingCutoff = DateTime.utc(2026, 10, 5);
SportEntityId hockeyId(SportEntityKind kind, String value) => SportEntityId(
  sport: SportId.hockey,
  provider: 'api-hockey',
  kind: kind,
  value: value,
);
SportParticipant hockeyTeam(String name) =>
    SportParticipant(id: hockeyId(SportEntityKind.team, name), name: name);
List<SportFormResult> hockeyForm(String team, List<String> results) => [
  for (final (i, status) in results.indexed)
    SportFormResult(
      matchId: hockeyId(SportEntityKind.match, '$team-$i'),
      startsAt: readingCutoff.subtract(Duration(days: 5 - i)),
      opponent: 'Opponent',
      home: true,
      scored: status == 'L' ? 1 : 3,
      conceded: status == 'L' ? 3 : 1,
      outcome: status == 'L' ? SportFormOutcome.loss : SportFormOutcome.win,
      providerStatus: status == 'L' ? 'FT' : status,
    ),
];
SportFixture hockeyReadingFixture({
  String league = '35',
  String season = '2026',
  SportFixtureStatus status = SportFixtureStatus.scheduled,
  List<SportFormResult>? homeForm,
  SportMatchHistory? headToHead,
}) => SportFixture(
  id: hockeyId(SportEntityKind.match, 'upcoming-$league'),
  competition: hockeyId(SportEntityKind.competition, league),
  competitionName: 'League $league',
  season: season,
  home: hockeyTeam('Home'),
  away: hockeyTeam('Away'),
  startsAt: readingCutoff.add(const Duration(hours: 20)),
  calendarDate: readingCutoff,
  status: status,
  headToHead: headToHead,
  homeForm: homeForm ?? hockeyForm('Home', ['FT', 'FT', 'FT', 'AOT', 'AP']),
  awayForm: hockeyForm('Away', List.filled(5, 'L')),
);
SportStandingRow standing(String team, int points, {int? rank}) =>
    SportStandingRow(
      team: hockeyTeam(team),
      rank: rank ?? (team == 'Home' ? 1 : 12),
      played: 12,
      points: points,
      wins: 8,
      losses: 4,
    );
SportStandingTable commonTable({int homePoints = 22, int awayPoints = 8}) =>
    SportStandingTable(
      stage: 'Regular Season',
      group: 'Conference',
      rows: [
        standing('Home', homePoints),
        for (var i = 0; i < 10; i++)
          standing('Middle $i', homePoints - 1 - i, rank: i + 2),
        standing('Away', awayPoints),
      ],
    );
SportSnapshot<SportFixture> hockeyReadingSnapshot(
  SportFixture fixture, {
  bool phaseVerified = true,
  List<SportStandingTable>? tables,
  DateTime? capturedAt,
}) => SportSnapshot(
  sport: SportId.hockey,
  schemaVersion: 1,
  capturedAt: capturedAt ?? readingCutoff,
  windowStart: readingCutoff.subtract(const Duration(days: 7)),
  windowEnd: readingCutoff.add(const Duration(days: 13)),
  items: [fixture],
  sportOf: (f) => f.sport,
  competitions: [
    SportCompetitionContext(
      id: fixture.competition,
      name: fixture.competitionName,
      season: fixture.season,
      country: 'Test country',
      formPhaseVerified: phaseVerified,
      tables: tables ?? [commonTable()],
    ),
  ],
);
