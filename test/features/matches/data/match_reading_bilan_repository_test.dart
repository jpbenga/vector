import 'dart:convert';
import 'dart:io';

import 'package:copilot/features/matches/data/match_reading_bilan_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late HttpServer server;
  late SupabaseClient client;
  late SupabaseMatchReadingBilanRepository repository;
  final requests = <({Uri uri, Map<String, dynamic>? body})>[];
  late List<Map<String, dynamic>> Function(Uri uri) response;

  setUp(() async {
    requests.clear();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    client = SupabaseClient('http://127.0.0.1:${server.port}', 'test-anon-key');
    repository = SupabaseMatchReadingBilanRepository(client);
    server.listen((request) async {
      final body = await utf8.decoder.bind(request).join();
      requests.add((
        uri: request.uri,
        body: body.isEmpty ? null : jsonDecode(body) as Map<String, dynamic>,
      ));
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(response(request.uri)));
      await request.response.close();
    });
  });

  tearDown(() async {
    await client.dispose();
    await server.close(force: true);
  });

  test(
    'Breakdown reads all RPC pages and keeps the time and venue scope',
    () async {
      final since = DateTime.utc(2026, 9, 3);
      final until = DateTime.utc(2026, 10, 3);
      response = (uri) => [
        for (
          var i = 0;
          i < (uri.queryParameters['offset'] == '0' ? 1000 : 1);
          i++
        )
          {
            'reading_id': 'positive_streak',
            'reading_label': 'Dynamique positive',
            'league_id': i + int.parse(uri.queryParameters['offset']!),
            'competition_name': 'Championnat $i',
            'total': 3,
            'confirmed': 2,
            'contradicted': 1,
            'evaluable': 3,
            'confirmation_rate': '66.7',
            'outcome_rules': ['team_not_lose'],
          },
      ];
      final rows = await repository.loadBreakdown(
        since: since,
        until: until,
        subjectSide: 'away',
      );
      expect(rows, hasLength(1001));
      expect(rows.last.leagueId, 1000);
      expect(rows.first.confirmationPercent, 66.7);
      expect(rows.first.outcomeRules, ['team_not_lose']);
      expect(requests.map((r) => r.uri.queryParameters['offset']), [
        '0',
        '1000',
      ]);
      for (final request in requests) {
        expect(request.uri.path, '/rest/v1/rpc/match_reading_bilan_breakdown');
        expect(request.uri.queryParameters['limit'], '1000');
        expect(request.body, {
          'p_since': since.toIso8601String(),
          'p_until': until.toIso8601String(),
          'p_subject_side': 'away',
        });
      }
    },
  );

  test(
    'Reading detail applies the same scope, pending status and pagination',
    () async {
      response = (_) => [
        {
          'announcement_id': 'a',
          'fixture_id': 123,
          'kickoff_at': '2026-10-02T20:00:00Z',
          'reading_id': 'positive_streak',
          'reading_label': 'Dynamique positive',
          'league_id': 61,
          'competition_name': 'Ligue 1',
          'home_team_name': 'Club A',
          'away_team_name': 'Club B',
          'subject_side': 'home',
          'verdict': null,
        },
      ];
      final since = DateTime.utc(2026, 9, 3);
      final until = DateTime.utc(2026, 10, 3);
      final entries = await repository.loadForReading(
        readingId: 'positive_streak',
        since: since,
        until: until,
        leagueId: 61,
        subjectSide: 'home',
        verdict: 'pending',
        offset: 10,
        limit: 11,
      );
      final query = requests.single.uri.queryParameters;
      expect(query['reading_id'], 'eq.positive_streak');
      expect(query['announcement_kind'], 'eq.reading');
      expect(query['league_id'], 'eq.61');
      expect(query['subject_side'], 'eq.home');
      expect(query['verdict'], 'is.null');
      expect(requests.single.uri.queryParametersAll['kickoff_at'], [
        'gte.${since.toIso8601String()}',
        'lte.${until.toIso8601String()}',
      ]);
      expect(query['offset'], '10');
      expect(query['limit'], '11');
      expect(
        query['order'],
        'kickoff_at.desc.nullslast,announcement_id.asc.nullslast',
      );
      expect(entries.single.homeTeamName, 'Club A');
      expect(entries.single.awayTeamName, 'Club B');
      expect(entries.single.competitionName, 'Ligue 1');
      expect(entries.single.hasResult, isFalse);
    },
  );

  test(
    'Fixture detail retains scenarios and nuances for the match page',
    () async {
      response = (_) => [];
      await repository.loadForFixture(123);
      final query = requests.single.uri.queryParameters;
      expect(query['fixture_id'], 'eq.123');
      expect(query.containsKey('announcement_kind'), isFalse);
      expect(query['select'], contains('competition_name'));
    },
  );
}
