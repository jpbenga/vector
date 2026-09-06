import 'package:copilot/features/matches/domain/match_board_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses one local calendar day for offset API fixture instants', () {
    final fixture = NormalizedFixture(
      id: 'fixture',
      competition: const CompetitionInfo(
        id: '61',
        name: 'Ligue 1',
        country: CountryInfo(code: 'FR', name: 'France'),
        season: 2026,
      ),
      homeTeam: const TeamInfo(id: 'home', name: 'Home'),
      awayTeam: const TeamInfo(id: 'away', name: 'Away'),
      kickoffLabel: '00:30',
      kickoff: DateTime.parse('2026-08-09T00:30:00+02:00'),
      status: FixtureStatus.scheduled,
    );

    final fixtureDay = lectorLocalCalendarDateForFixture(fixture);

    expect(fixtureDay, lectorLocalCalendarDate(fixture.kickoff!));
  });
}
