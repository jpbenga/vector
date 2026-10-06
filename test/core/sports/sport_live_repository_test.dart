import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:copilot/core/sports/data/published_sport_feed_repository.dart';
import 'package:copilot/core/sports/data/sport_live_repository.dart';
import 'package:copilot/core/sports/domain/sport.dart';
import 'package:copilot/core/sports/domain/sport_fixture.dart';

void main() {
  final raw =
      jsonDecode(
            File('test/fixtures/sports/nhl_compact.json').readAsStringSync(),
          )
          as Map<String, dynamic>;
  // Start with the actual public fixture identity, in its prematch state.
  final baseJson = jsonDecode(jsonEncode(raw)) as Map<String, dynamic>;
  (baseJson['items'] as List).single['status'] = 'scheduled';
  (baseJson['items'] as List).single['providerStatus'] = 'NS';
  (baseJson['items'] as List).single['scores'] = <String, dynamic>{};
  final base = SportPublicationCodec.decode(
    baseJson,
    SportId.hockey,
  ).items.single;
  SportFixture state({
    int away = 5,
    SportFixtureStatus status = SportFixtureStatus.live,
    String? homeId,
    DateTime? at,
  }) => SportFixture(
    id: base.id,
    competition: base.competition,
    competitionName: base.competitionName,
    season: base.season,
    startsAt: base.startsAt,
    calendarDate: base.calendarDate,
    home: homeId == null
        ? base.home
        : SportParticipant(
            id: SportEntityId(
              sport: SportId.hockey,
              provider: 'api-hockey',
              kind: SportEntityKind.team,
              value: homeId,
            ),
            name: 'Foreign',
          ),
    away: base.away,
    capturedAt: at ?? DateTime.now(),
    status: status,
    providerStatus: status == SportFixtureStatus.finished ? 'FT' : 'P2',
    scores: {
      SportScoreScope(
        status == SportFixtureStatus.finished ? 'final' : 'current',
      ): SportScore(
        home: 2,
        away: away,
      ),
    },
  );
  test(
    'live overlay preserves prematch form/history, checks identities, retains scores on error and never regresses final',
    () async {
      final repo = _Fake();
      final controller = SportLiveController(
        sport: SportId.hockey,
        repository: repo,
      );
      addTearDown(controller.dispose);
      repo.rows = [state()];
      controller.watch([base]);
      await Future<void>.delayed(Duration.zero);
      final displayed = controller.display(base);
      expect(displayed.status, SportFixtureStatus.live);
      expect(displayed.scoreFor(const SportScoreScope('current'))!.away, 5);
      expect(displayed.homeForm, base.homeForm);
      expect(displayed.headToHead, same(base.headToHead));
      expect(base.status, SportFixtureStatus.scheduled);
      expect(base.scores, isEmpty);
      repo.rows = [state(away: 9, homeId: '999')];
      await controller.refresh();
      expect(
        controller
            .display(base)
            .scoreFor(const SportScoreScope('current'))!
            .away,
        5,
      );
      repo.fail = true;
      await controller.refresh();
      expect(controller.unavailable, isTrue);
      expect(controller.display(base).status, SportFixtureStatus.live);
      repo.fail = false;
      repo.rows = [state(status: SportFixtureStatus.finished)];
      await controller.refresh();
      expect(controller.display(base).status, SportFixtureStatus.finished);
      repo.rows = [state(away: 8)];
      await controller.refresh();
      expect(controller.display(base).status, SportFixtureStatus.finished);
      expect(
        controller.display(base).scoreFor(SportScoreScope.finalResult)!.away,
        5,
      );
    },
  );
  test(
    'public score transport uses no account JWT, rejects mismatched rows and preserves provider scopes',
    () async {
      final item = Map<String, dynamic>.from(
        (raw['items'] as List).single as Map,
      );
      item['status'] = 'finished';
      item['providerStatus'] = 'FT';
      item['scores'] = {
        'final': {'home': 2, 'away': 5},
        'second': {'home': 1, 'away': 4},
      };
      final row = {
        'sport': 'hockey',
        'provider': 'api-hockey',
        'fixture_id': item['id'],
        'competition_id': item['competitionId'],
        'fixture_date': item['calendarDate'],
        'captured_at': DateTime.now().toIso8601String(),
        'payload': item,
      };
      final repository = SupabaseSportLiveRepository(
        projectUrl: Uri.parse('https://example.supabase.co'),
        publicKey: 'public-key',
        client: MockClient((r) async {
          expect(r.headers['apikey'], 'public-key');
          expect(r.headers.containsKey('authorization'), isFalse);
          expect(r.url.queryParameters['sport'], 'eq.hockey');
          return http.Response(jsonEncode([row]), 200);
        }),
      );
      final states = await repository.load(SportId.hockey, {base.id.value});
      expect(states.single.scoreFor(SportScoreScope.finalResult)!.away, 5);
      expect(states.single.scoreFor(const SportScoreScope('second'))!.home, 1);
      row['competition_id'] = 'foreign';
      await expectLater(
        repository.load(SportId.hockey, {base.id.value}),
        throwsFormatException,
      );
    },
  );
  test(
    'server clock accepts valid live scores despite device clock drift, but rejects future server scores',
    () async {
      final serverNow = DateTime.now().toUtc().add(const Duration(hours: 3));
      final item = Map<String, dynamic>.from(
        (raw['items'] as List).single as Map,
      );
      item['status'] = 'live';
      item['providerStatus'] = 'P2';
      item['scores'] = {
        'current': {'home': 2, 'away': 3},
      };
      final row = {
        'sport': 'hockey',
        'provider': 'api-hockey',
        'fixture_id': item['id'],
        'competition_id': item['competitionId'],
        'fixture_date': item['calendarDate'],
        'payload': item,
        'captured_at': serverNow
            .subtract(const Duration(seconds: 5))
            .toIso8601String(),
      };
      final repository = SupabaseSportLiveRepository(
        projectUrl: Uri.parse('https://example.supabase.co'),
        publicKey: 'public-key',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode([row]),
            200,
            headers: {'date': HttpDate.format(serverNow)},
          ),
        ),
      );
      final controller = SportLiveController(
        sport: SportId.hockey,
        repository: repository,
      );
      addTearDown(controller.dispose);
      controller.watch([base]);
      await Future<void>.delayed(Duration.zero);
      expect(controller.unavailable, isFalse);
      expect(controller.display(base).status, SportFixtureStatus.live);
      expect(
        controller
            .display(base)
            .scoreFor(const SportScoreScope('current'))!
            .away,
        3,
      );
      row['captured_at'] = serverNow
          .add(const Duration(minutes: 2))
          .toIso8601String();
      await expectLater(
        repository.load(SportId.hockey, {base.id.value}),
        throwsFormatException,
      );
      await controller.refresh();
      expect(controller.unavailable, isTrue);
      expect(
        controller
            .display(base)
            .scoreFor(const SportScoreScope('current'))!
            .away,
        3,
      );
    },
  );
}

class _Fake implements SportLiveRepository {
  List<SportFixture> rows = [];
  bool fail = false;
  @override
  Future<List<SportFixture>> load(SportId sport, Set<String> ids) async {
    if (fail) throw StateError('offline');
    return rows;
  }
}
