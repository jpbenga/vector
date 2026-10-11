import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:copilot/core/data/published_feed_delivery.dart';
import 'package:copilot/core/sports/data/published_sport_feed_repository.dart';
import 'package:copilot/core/sports/domain/sport.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final payload =
      jsonDecode(
            File(
              'test/fixtures/sports/hockey_readings_compact.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final captured = DateTime.parse(payload['capturedAt'] as String);
  final day = DateTime(2026, 10, 4);

  ({
    PublishedSportFeedRepository repository,
    List<String> paths,
    _Remote remote,
  })
  setup({DateTime? now, bool complete = false, bool missingDay = false}) {
    final paths = <String>[];
    final remote = _Remote();
    final delivery = PublishedFeedDelivery(
      projectUrl: Uri.parse('https://db.test'),
      publicKey: 'public',
      hostedBaseUrl: Uri.parse('https://demo.test/'),
      localOffset: (_) => const Duration(hours: 2),
      client: MockClient((request) async {
        paths.add(request.url.path);
        if (request.url.path.endsWith('context.json')) {
          return http.Response(
            jsonEncode({'competitions': payload['competitions']}),
            200,
          );
        }
        if (request.url.path.endsWith('match.json')) {
          return http.Response(
            jsonEncode({
              ...payload,
              'items': [(payload['items'] as List).first],
            }),
            200,
          );
        }
        if (request.url.path.endsWith('manifest.json')) {
          if (missingDay) return http.Response('', 404);
          return http.Response(
            jsonEncode({
              'schemaVersion': 1,
              'sport': 'hockey',
              'day': request.url.path.split('/')[3],
              'path': 'delivery/hockey/version/day.json',
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            ...payload,
            'delivery': {
              'sport': 'hockey',
              'day': '2026-10-04',
              'radarPaths': ['delivery/hockey/version/full.json'],
              'detailPaths': {
                (payload['items'] as List).first['id'] as String: {
                  'path': 'delivery/hockey/version/match.json',
                  'context': 'delivery/hockey/version/context.json',
                },
              },
            },
            'delivery_part': {
              'detailPaths': {
                (payload['items'] as List).first['id'] as String: {
                  'path': 'delivery/hockey/version/match.json',
                  'context': 'delivery/hockey/version/context.json',
                },
              },
            },
          }),
          200,
        );
      }),
    );
    return (
      repository: PublishedSportFeedRepository(
        sport: SportId.hockey,
        source: remote,
        completeSource: complete ? _Full(payload) : null,
        delivery: delivery,
        clock: () => now ?? captured.add(const Duration(hours: 1)),
      ),
      paths: paths,
      remote: remote,
    );
  }

  test(
    'cold day returns without waiting for a stalled database; Radar warms the window with shared objects',
    () async {
      final env = setup();
      final first = await env.repository.load(day);
      expect(first.isAvailable, true);
      expect(env.remote.dayCalls, 1);
      final radar = await env.repository.loadRadar(day);
      final paths = env.paths.length;
      final tomorrow = await env.repository.load(DateTime(2026, 10, 6));
      expect(tomorrow.isAvailable, true);
      expect(env.paths.length, paths);
      expect(
        identical(
          tomorrow.snapshot!.competitions.first,
          radar.snapshot!.competitions.first,
        ),
        true,
      );
      expect(env.repository.peek(DateTime(2026, 10, 17))!.isAvailable, true);
      final id = radar.snapshot!.items.first.id.value;
      env.remote.day.complete(null);
      env.remote.radar.complete(null);
      await Future<void>.delayed(Duration.zero);
      final detail = await env.repository.loadMatch(day, id);
      expect(detail.snapshot!.items, hasLength(1));
      expect(identical(detail, await env.repository.loadMatch(day, id)), true);
      expect(env.paths.length, paths + 2);
      expect(env.remote.matchCalls, 1);
    },
  );

  test(
    'background failure retains the available day and repeated visits deduplicate retries',
    () async {
      final env = setup();
      final first = await env.repository.load(day);
      env.remote.day.completeError(StateError('statement timeout'));
      await Future<void>.delayed(Duration.zero);
      expect(identical(await env.repository.load(day), first), true);
      expect(env.remote.dayCalls, 1);
      expect(env.repository.peek(day)!.isAvailable, true);
    },
  );

  test(
    'one complete snapshot serves missing archive days and full details without more downloads',
    () async {
      final env = setup(complete: true, missingDay: true);
      final first = await env.repository.load(day);
      expect(first.isAvailable, true);
      final radar = await env.repository.loadRadar(day);
      final paths = env.paths.length;
      await env.repository.load(DateTime(2026, 10, 6));
      final match = radar.snapshot!.items.first;
      final detail = await env.repository.loadMatch(day, match.id.value);
      expect(detail.snapshot!.items, hasLength(1));
      expect(identical(detail.snapshot!.items.single, match), true);
      expect(env.paths.length, paths);
      expect((env.repository.completeSource as _Full).calls, 1);
    },
  );

  test(
    'new server publication replaces the seed and detail pins its new version',
    () async {
      final env = setup();
      await env.repository.load(day);
      final newer = captured.add(const Duration(minutes: 30));
      env.remote.day.complete({
        ...payload,
        'capturedAt': newer.toIso8601String(),
      });
      await Future<void>.delayed(Duration.zero);
      expect(env.repository.peek(day)!.snapshot!.capturedAt, newer);
      env.remote.match.complete({
        ...payload,
        'capturedAt': newer.toIso8601String(),
      });
      await env.repository.loadMatch(
        day,
        (payload['items'] as List).first['id'] as String,
      );
      expect(env.remote.matchVersion, newer);
      expect(env.paths.where((path) => path.endsWith('full.json')), isEmpty);
    },
  );

  test(
    'expired CDN publication waits for the server instead of renewing its age',
    () async {
      final env = setup(now: captured.add(const Duration(hours: 40)));
      env.remote.day.complete(null);
      final result = await env.repository.load(day);
      expect(result.isAvailable, false);
      expect(env.remote.dayCalls, 1);
    },
  );
}

class _Remote implements ProgressiveSportPublicationSource {
  final day = Completer<Map<String, dynamic>?>();
  final radar = Completer<Map<String, dynamic>?>();
  final match = Completer<Map<String, dynamic>?>();
  int dayCalls = 0, matchCalls = 0;
  DateTime? matchVersion;
  @override
  Future<Map<String, dynamic>?> read(SportId sport) => radar.future;
  @override
  Future<Map<String, dynamic>?> readDay(SportId sport, DateTime date) {
    dayCalls++;
    return day.future;
  }

  @override
  Future<Map<String, dynamic>?> readMatch(
    SportId sport,
    String id,
    DateTime? version,
  ) {
    matchCalls++;
    matchVersion = version;
    return match.future;
  }
}

class _Full implements SportPublicationSource {
  _Full(this.payload);
  final Map<String, dynamic> payload;
  int calls = 0;
  @override
  Future<Map<String, dynamic>?> read(SportId sport) async {
    calls++;
    return payload;
  }
}
