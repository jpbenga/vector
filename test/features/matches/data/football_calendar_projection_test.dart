import 'dart:convert';
import 'package:copilot/features/matches/data/supabase_match_feed_snapshot_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'calendar loads one compact projection; only an opened fixture loads its source and Radar keeps its independent scope',
    () async {
      final calls = <String>[];
      final payload = <String, Object?>{
        'schema_version': 1,
        'captured_at': '2026-10-17T06:00:00Z',
        'window_start': '2026-10-17',
        'window_end': '2026-10-17',
        'raw': {
          'fixtures': [
            {
              'fixture': {'id': 123, 'date': '2026-10-17T18:00:00Z'},
              'league': {'id': 61},
              'teams': {
                'home': {'id': 1},
                'away': {'id': 2},
              },
            },
          ],
        },
        'computed': {'fixtures': <Object?>[]},
      };
      final row = {
        'id': 'source-61',
        'scope': 'league',
        'league_ids': [61],
        'payload': payload,
      };
      final client = SupabaseClient(
        'https://server.test',
        'public',
        httpClient: MockClient((request) async {
          calls.add(request.url.path);
          if (request.url.path.endsWith('read_football_calendar')) {
            expect(jsonDecode(request.body)['p_day'], '2026-10-17');
            return http.Response(
              jsonEncode([row]),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          expect(request.url.queryParameters['id'], 'in.(source-61)');
          return http.Response(
            jsonEncode([row]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      final reader = SupabaseMatchFeedSnapshotRepository(client);
      await reader.loadLatestForDate(DateTime(2026, 10, 17));
      expect(calls, ['/rest/v1/rpc/read_football_calendar']);
      await reader.loadDetails(DateTime(2026, 10, 17), 'api-fixture-123');
      expect(calls.last, '/rest/v1/match_feed_analysis_snapshots');
      await reader.loadRadar(DateTime(2026, 10, 17));
      expect(calls.last, '/rest/v1/rpc/read_football_calendar');
    },
  );
}
