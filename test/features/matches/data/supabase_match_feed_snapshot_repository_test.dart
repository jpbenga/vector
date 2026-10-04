import 'package:copilot/app/theme/app_theme.dart';
import 'package:copilot/features/matches/data/supabase_match_feed_snapshot_repository.dart';
import 'package:copilot/features/matches/data/match_feed_repository.dart';
import 'package:copilot/features/matches/domain/live_match_state.dart';
import 'package:copilot/features/matches/presentation/widgets/match_feed_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('selects only the newest metadata row for each league', () {
    final ids = selectMatchFeedSnapshotRowIds([
      {
        'id': 'latest-61',
        'scope': 'league',
        'league_ids': [61],
      },
      {
        'id': 'latest-62',
        'scope': 'league',
        'league_ids': [62],
      },
      {
        'id': 'old-61',
        'scope': 'league',
        'league_ids': [61],
      },
      {
        'id': 'latest-98',
        'scope': 'league',
        'league_ids': [98],
      },
      {
        'id': 'old-62',
        'scope': 'league',
        'league_ids': [62],
      },
    ]);

    expect(ids, ['latest-61', 'latest-62', 'latest-98']);
  });

  test('retains a global snapshot once for unrefreshed leagues', () {
    final ids = selectMatchFeedSnapshotRowIds([
      {
        'id': 'latest-61',
        'scope': 'league',
        'league_ids': [61],
      },
      {'id': 'global', 'scope': 'global', 'league_ids': <int>[]},
      {'id': 'old-global', 'scope': 'global', 'league_ids': <int>[]},
    ]);

    expect(ids, ['latest-61', 'global']);
  });

  test('keeps date-covered rows before latest Radar fallback rows', () {
    final ids = selectMatchFeedSnapshotRowIds([
      {
        'id': 'covered-61',
        'scope': 'league',
        'league_ids': [61],
      },
      {
        'id': 'latest-62',
        'scope': 'league',
        'league_ids': [62],
      },
      {
        'id': 'older-61',
        'scope': 'league',
        'league_ids': [61],
      },
    ]);

    expect(ids, ['covered-61', 'latest-62']);
  });

  group('mergeMatchFeedSnapshotPayloads', () {
    testWidgets('contextual standings cannot hide another league calendar', (
      tester,
    ) async {
      final european = _payload(
        leagueId: 3,
        capturedAt: '2026-10-04T09:57:10.904Z',
        fixtureId: 3001,
        teamId: 31,
      );
      // Existing production compact payloads have no scope in their JSON.
      european.remove('season_by_league');
      final raw = european['raw'] as Map<String, Object?>;
      (raw['standings'] as List).add({
        'league': {'id': 95},
      });
      final portugal = _payload(
        leagueId: 95,
        capturedAt: '2026-10-04T00:36:23.694Z',
        fixtureId: 1576482,
        teamId: 231,
      );
      portugal.remove('season_by_league');
      final portugalRaw = portugal['raw'] as Map<String, Object?>;
      final fixture = (portugalRaw['fixtures'] as List).single as Map;
      fixture['fixture'] = {
        'id': 1576482,
        'date': '2026-10-04T12:00:00+02:00',
        'status': {'short': 'NS'},
      };
      fixture['teams'] = {
        'home': {'id': 231, 'name': 'Farense'},
        'away': {'id': 223, 'name': 'Chaves'},
      };
      final payload = mergeMatchFeedSnapshotRows([
        {
          'scope': 'league',
          'league_ids': [3],
          'payload': european,
        },
        {
          'scope': 'league',
          'league_ids': [95],
          'payload': portugal,
        },
      ])!;
      final matches = SnapshotMatchFeedRepository(
        snapshot: payload,
      ).allMatches();
      expect(matches, hasLength(2));
      final match = matches.singleWhere((m) => m.id == 'api-fixture-1576482');
      expect(match.homeTeam.name, 'Farense');
      expect(match.awayTeam.name, 'Chaves');
      expect(match.competition.apiFootballLeagueId, 95);
      expect(match.fixture.kickoff?.toUtc(), DateTime.utc(2026, 10, 4, 10));
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: SingleChildScrollView(
              child: MatchFeedCard(
                match: match,
                onTap: () {},
                radarEntries: const [],
                showReadings: false,
                liveState: LiveMatchState(
                  fixtureId: 1576482,
                  status: '1H',
                  elapsed: 35,
                  homeGoals: 1,
                  awayGoals: 0,
                  capturedAt: DateTime.now(),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Farense'), findsOneWidget);
      expect(find.text('Chaves'), findsOneWidget);
      expect(find.text('35′ · En direct'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('an explicitly empty publication replaces its older calendar', () {
      final latest = _payload(
        leagueId: 95,
        capturedAt: '2026-10-04T09:00:00Z',
        fixtureId: 1,
        teamId: 231,
      );
      latest['raw'] = <String, Object?>{'fixtures': <Object?>[]};
      latest.remove('season_by_league');
      final old = _payload(
        leagueId: 95,
        capturedAt: '2026-10-03T09:00:00Z',
        fixtureId: 1576482,
        teamId: 231,
      );
      final merged = mergeMatchFeedSnapshotRows([
        {
          'scope': 'league',
          'league_ids': [95],
          'payload': latest,
        },
        {
          'scope': 'league',
          'league_ids': [95],
          'payload': old,
        },
      ])!;
      expect((merged['raw'] as Map)['fixtures'], isEmpty);
    });

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
      expect(raw['head_to_head'], hasLength(2));
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

    test('feeds the snapshot repository with mixed league seasons', () {
      final payload = mergeMatchFeedSnapshotPayloads([
        _payload(
          leagueId: 62,
          season: 2026,
          capturedAt: '2026-08-14T00:08:00.000Z',
          fixtureId: 6201,
          teamId: 621,
        ),
        _payload(
          leagueId: 98,
          season: 2027,
          capturedAt: '2026-08-15T11:43:00.000Z',
          fixtureId: 1554009,
          teamId: 981,
        ),
      ]);

      expect(payload, isNotNull);
      final repository = SnapshotMatchFeedRepository(snapshot: payload!);
      final matches = repository.allMatches();

      expect(matches, hasLength(2));
      expect(
        matches.map((match) => match.competition.name),
        containsAll(['League 62', 'League 98']),
      );
      expect(
        matches
            .firstWhere((match) => match.competition.name == 'League 98')
            .competition
            .season,
        2027,
      );
    });
  });
}

Map<String, Object?> _payload({
  required int leagueId,
  int season = 2026,
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
    'season_by_league': {leagueId.toString(): season},
    'bookmaker_priority': [
      {'id': 16, 'name': 'Unibet'},
    ],
    'raw': {
      'fixtures': [
        {
          'fixture': {'id': fixtureId},
          'league': {
            'id': leagueId,
            'name': 'League $leagueId',
            'season': season,
          },
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
      'head_to_head': [
        {
          'fixture': {'id': fixtureId},
          'matches': const <Object?>[],
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
      'head_to_head': const <Object?>[],
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
