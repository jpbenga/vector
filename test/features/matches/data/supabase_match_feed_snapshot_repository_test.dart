import 'package:copilot/features/matches/data/supabase_match_feed_snapshot_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('mergeMatchFeedSnapshotPayloads', () {
    test('merges league scoped snapshots into one feed payload', () {
      final payload = mergeMatchFeedSnapshotPayloads([
        _payload(
          leagueId: 61,
          capturedAt: '2026-08-14T00:04:00.000Z',
          fixtureId: 6101,
          teamId: 611,
        ),
        _payload(
          leagueId: 62,
          capturedAt: '2026-08-14T00:08:00.000Z',
          fixtureId: 6201,
          teamId: 621,
        ),
      ]);

      expect(payload, isNotNull);
      expect(payload?['captured_at'], '2026-08-14T00:08:00.000Z');
      expect(payload?['window_start'], '2026-08-14');
      expect(payload?['window_end'], '2026-08-17');
      expect(payload?['season_by_league'], {'61': 2026, '62': 2026});

      final raw = payload?['raw'] as Map<String, Object?>;
      expect(raw['fixtures'], hasLength(2));
      expect(raw['odds'], hasLength(2));
      expect(raw['standings'], hasLength(2));
      expect(raw['team_statistics'], hasLength(2));
      expect(raw['recent_league_matches'], hasLength(2));
    });

    test('keeps the newest snapshot for a duplicated league', () {
      final payload = mergeMatchFeedSnapshotPayloads([
        _payload(
          leagueId: 61,
          capturedAt: '2026-08-14T00:08:00.000Z',
          fixtureId: 6102,
          teamId: 612,
        ),
        _payload(
          leagueId: 61,
          capturedAt: '2026-08-13T00:08:00.000Z',
          fixtureId: 6101,
          teamId: 611,
        ),
      ]);

      final raw = payload?['raw'] as Map<String, Object?>;
      final fixtures = raw['fixtures'] as List<Object?>;
      final fixture = fixtures.single as Map<String, Object?>;
      final fixtureMeta = fixture['fixture'] as Map<String, Object?>;

      expect(fixtureMeta['id'], 6102);
    });

    test('uses the previous global feed for leagues not refreshed yet', () {
      final payload = mergeMatchFeedSnapshotPayloads([
        _payload(
          leagueId: 62,
          capturedAt: '2026-08-14T00:08:00.000Z',
          fixtureId: 6202,
          teamId: 622,
        ),
        _globalPayload(
          capturedAt: '2026-08-13T00:08:00.000Z',
          fixtures: [
            _fixture(leagueId: 61, fixtureId: 6101, teamId: 611),
            _fixture(leagueId: 62, fixtureId: 6201, teamId: 621),
          ],
        ),
      ]);

      final raw = payload?['raw'] as Map<String, Object?>;
      final fixtureIds = (raw['fixtures'] as List<Object?>)
          .map((entry) => entry as Map<String, Object?>)
          .map((entry) => entry['fixture'] as Map<String, Object?>)
          .map((fixture) => fixture['id'])
          .toList();

      expect(fixtureIds, containsAll([6101, 6202]));
      expect(fixtureIds, isNot(contains(6201)));
    });
  });
}

Map<String, Object?> _payload({
  required int leagueId,
  required String capturedAt,
  required int fixtureId,
  required int teamId,
}) {
  return {
    'schema_version': 1,
    'source': 'api-football',
    'captured_at': capturedAt,
    'timezone': 'Europe/Paris',
    'window_start': '2026-08-14',
    'window_end': '2026-08-17',
    'date_window': ['2026-08-14', '2026-08-15', '2026-08-16', '2026-08-17'],
    'season_by_league': {leagueId.toString(): 2026},
    'bookmaker_priority': [
      {'id': 16, 'name': 'Unibet'},
    ],
    'raw': {
      'fixtures': [
        {
          'fixture': {'id': fixtureId},
          'league': {'id': leagueId, 'name': 'League $leagueId'},
          'teams': {
            'home': {'id': teamId},
            'away': {'id': teamId + 1},
          },
        },
      ],
      'odds': [
        {
          'fixture': {'id': fixtureId},
          'league': {'id': leagueId},
        },
      ],
      'standings': [
        {
          'league': {'id': leagueId},
        },
      ],
      'team_statistics': [
        {
          'league': {'id': leagueId},
          'team': {'id': teamId},
        },
      ],
      'recent_league_matches': [
        {
          'league': {'id': leagueId},
          'team': {'id': teamId},
          'fixtures': const <Object?>[],
        },
      ],
      'expected_goals': [
        {
          'team': {'id': teamId},
          'average_for': 1.2,
        },
      ],
      'predictions': const <Object?>[],
    },
  };
}

Map<String, Object?> _globalPayload({
  required String capturedAt,
  required List<Map<String, Object?>> fixtures,
}) {
  return {
    'schema_version': 1,
    'source': 'api-football',
    'captured_at': capturedAt,
    'timezone': 'Europe/Paris',
    'window_start': '2026-08-14',
    'window_end': '2026-08-17',
    'date_window': ['2026-08-14', '2026-08-15', '2026-08-16', '2026-08-17'],
    'season_by_league': {'61': 2026, '62': 2026},
    'bookmaker_priority': [
      {'id': 16, 'name': 'Unibet'},
    ],
    'raw': {
      'fixtures': fixtures,
      'odds': const <Object?>[],
      'standings': const <Object?>[],
      'team_statistics': const <Object?>[],
      'recent_league_matches': const <Object?>[],
      'expected_goals': const <Object?>[],
      'predictions': const <Object?>[],
    },
  };
}

Map<String, Object?> _fixture({
  required int leagueId,
  required int fixtureId,
  required int teamId,
}) {
  return {
    'fixture': {'id': fixtureId},
    'league': {'id': leagueId, 'name': 'League $leagueId'},
    'teams': {
      'home': {'id': teamId},
      'away': {'id': teamId + 1},
    },
  };
}
