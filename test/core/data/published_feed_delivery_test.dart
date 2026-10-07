import 'dart:convert';
import 'package:copilot/core/data/published_feed_delivery.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'other local calendars retain the full reader instead of dropping midnight games',
    () async {
      var requests = 0;
      final gateway = PublishedFeedDelivery(
        projectUrl: Uri.parse('https://db.test'),
        publicKey: 'public',
        localOffset: (_) => Duration.zero,
        client: MockClient((_) async {
          requests++;
          return http.Response('{}', 200);
        }),
      );
      expect(await gateway.loadDay('football', DateTime(2026, 10, 7)), isNull);
      expect(requests, 0);
    },
  );

  test(
    'cold calendar reads only a pointer and a day file; details and radar are deferred',
    () async {
      final paths = <String>[];
      final responses = <String, Object>{
        '/delivery/football/2026-10-07/manifest.json': {
          'schemaVersion': 1,
          'sport': 'football',
          'day': '2026-10-07',
          'path': 'delivery/football/version/day.json',
        },
        '/delivery/football/version/day.json': {
          'raw': {'fixtures': <Object?>[]},
          'delivery': {
            'sport': 'football',
            'day': '2026-10-07',
            'detailPaths': {
              'match': {
                'path': 'delivery/football/version/match.json',
                'context': 'delivery/football/version/context.json',
              },
            },
            'radarPaths': ['delivery/football/version/radar.json'],
          },
        },
        '/delivery/football/version/match.json': {
          'raw': {
            'fixtures': [
              {'id': 1},
            ],
          },
        },
        '/delivery/football/version/context.json': {
          'raw': {
            'standings': [
              {'rank': 1},
            ],
          },
        },
        '/delivery/football/version/radar.json': {
          'raw': {
            'player_form_radar': [
              {'id': 2},
            ],
          },
        },
      };
      final gateway = PublishedFeedDelivery(
        localOffset: (_) => const Duration(hours: 2),
        projectUrl: Uri.parse('https://db.test'),
        publicKey: 'public',
        hostedBaseUrl: Uri.parse('https://demo.test/'),
        client: MockClient((request) async {
          paths.add(request.url.path);
          expect(request.headers.containsKey('authorization'), isFalse);
          return http.Response(jsonEncode(responses[request.url.path]), 200);
        }),
      );
      final day = await gateway.loadDay('football', DateTime(2026, 10, 7));
      expect(paths, hasLength(2));
      expect(
        identical(
          day,
          await gateway.loadDay('football', DateTime(2026, 10, 7)),
        ),
        isTrue,
      );
      final detail = await gateway.detail(day!, 'match');
      expect((detail!['raw'] as Map)['standings'], hasLength(1));
      expect((detail['raw'] as Map)['fixtures'], hasLength(1));
      expect(paths, hasLength(4));
      await gateway.radar(day);
      expect(paths, hasLength(5));
    },
  );
  test(
    'unavailable deployment is distinct from errors and cross-sport manifests are rejected',
    () async {
      var status = 404;
      final gateway = PublishedFeedDelivery(
        localOffset: (_) => const Duration(hours: 2),
        projectUrl: Uri.parse('https://db.test'),
        publicKey: 'public',
        client: MockClient(
          (request) async => http.Response(
            jsonEncode([
              {
                'manifest': {
                  'schemaVersion': 1,
                  'sport': 'hockey',
                  'day': '2026-10-08',
                  'path': 'delivery/hockey/version/day.json',
                },
              },
            ]),
            status,
          ),
        ),
      );
      expect(await gateway.loadDay('football', DateTime(2026, 10, 7)), isNull);
      status = 200;
      await expectLater(
        gateway.loadDay('football', DateTime(2026, 10, 8)),
        throwsFormatException,
      );
      expect(
        () => gateway.loadArtifact('https://other.test/secret'),
        throwsFormatException,
      );
      expect(
        () => gateway.loadArtifact('delivery/football/../secret.json'),
        throwsFormatException,
      );
    },
  );
}
