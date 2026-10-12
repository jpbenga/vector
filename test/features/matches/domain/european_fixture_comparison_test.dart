import 'package:copilot/features/matches/domain/european_fixture_comparison.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('decoder rejects unsupported/incomplete publication', () {
    expect(EuropeanFixtureComparison.decode({}), isNull);
    expect(EuropeanFixtureComparison.decode({'schemaVersion': 2}), isNull);
  });
  test('pre-match standing and result cutoffs survive decoding', () {
    final comparison = EuropeanFixtureComparison.decode({
      'schemaVersion': 1,
      'fixtureId': 100,
      'kickoffAt': '2026-10-13T19:00:00Z',
      'home': {
        'teamId': 1,
        'name': 'Home',
        'domesticStanding': {
          'teamId': 1,
          'teamName': 'Home',
          'rank': 2,
          'observedAt': '2026-10-14T09:00:00Z',
        },
        'domesticRecentMatches': [
          {
            'fixtureId': 1,
            'playedAt': '2026-10-01T18:00:00Z',
            'goalsFor': 2,
            'goalsAgainst': 1,
            'opponentName': 'Earlier',
          },
          {
            'fixtureId': 2,
            'playedAt': '2026-10-14T18:00:00Z',
            'goalsFor': 0,
            'goalsAgainst': 1,
            'opponentName': 'Future',
          },
        ],
      },
      'away': {'teamId': 2, 'name': 'Away'},
    })!;
    expect(comparison.home.domesticStanding, isNull);
    expect(comparison.home.domesticMatches.map((m) => m.fixtureId), [1]);
    expect(comparison.away.domesticMatches, isEmpty);
    expect(comparison.away.europeanSummary, isNull);
  });
}
