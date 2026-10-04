import 'dart:convert';
import 'dart:io';

import 'package:copilot/core/identity/identity_scope.dart';
import 'package:copilot/core/identity/memory_local_key_value_store.dart';
import 'package:copilot/core/identity/scoped_persistence.dart';
import 'package:copilot/core/sports/data/scoped_sport_persistence.dart';
import 'package:copilot/core/sports/domain/sport.dart';
import 'package:copilot/core/sports/domain/sport_feed_repository.dart';
import 'package:copilot/core/sports/domain/sport_fixture.dart';
import 'package:copilot/core/sports/domain/sport_market_quote.dart';
import 'package:copilot/core/sports/domain/sport_module.dart';
import 'package:copilot/core/sports/domain/sport_policy.dart';
import 'package:copilot/core/sports/domain/sport_snapshot.dart';
import 'package:copilot/features/football/data/football_sport_feed_adapter.dart';
import 'package:copilot/features/football/domain/football_module.dart';
import 'package:copilot/features/hockey/domain/hockey_integration_scope.dart';
import 'package:copilot/features/hockey/domain/hockey_module.dart';
import 'package:copilot/features/matches/data/match_feed_repository.dart';
import 'package:copilot/features/sports/domain/sport_module_registry.dart';
import 'package:flutter_test/flutter_test.dart';

SportEntityId _id(SportId sport, SportEntityKind kind, String value) =>
    SportEntityId(sport: sport, provider: 'provider', kind: kind, value: value);

SportFixture _fixture(SportId sport) => SportFixture(
  id: _id(sport, SportEntityKind.match, '1'),
  competition: _id(sport, SportEntityKind.competition, '1'),
  competitionName: 'Competition',
  season: '2026',
  home: SportParticipant(
    id: _id(sport, SportEntityKind.team, '1'),
    name: 'Home',
  ),
  away: SportParticipant(
    id: _id(sport, SportEntityKind.team, '2'),
    name: 'Away',
  ),
  startsAt: DateTime.utc(2026, 10, 4, 18),
  status: SportFixtureStatus.finished,
  scores: {SportScoreScope.finalResult: SportScore(home: 3, away: 2)},
);

class _Source implements SportFeedRepository {
  _Source(this.sport, this.result);
  @override
  final SportId sport;
  final SportFeedResult result;
  @override
  Future<SportFeedResult> load(DateTime selectedDate) async => result;
}

SportFeedResult _publication(SportId sport, {bool empty = false}) =>
    SportFeedResult.available(
      SportSnapshot(
        sport: sport,
        schemaVersion: 1,
        capturedAt: DateTime.utc(2026, 10, 4, 10),
        windowStart: DateTime.utc(2026, 10, 4),
        windowEnd: DateTime.utc(2026, 10, 17),
        items: empty ? <SportFixture>[] : [_fixture(sport)],
        sportOf: (item) => item.sport,
      ),
    );

void main() {
  test('a sixth sport is registered without expanding a central enum', () {
    const volleyball = SportId('volleyball', 'Volley');
    final catalog = SportModuleCatalog([
      FootballModule.definition,
      HockeyModule.definition,
      const SportModuleDefinition(
        sport: volleyball,
        stage: SportModuleStage.preparation,
        capabilities: {},
      ),
    ]);
    expect(catalog.find('volleyball')!.sport, volleyball);
    expect(catalog.find('unregistered'), isNull);
    expect(const SportId('volleyball', 'Volleyball'), volleyball);
    expect(
      () => SportModuleCatalog([
        HockeyModule.definition,
        HockeyModule.definition,
      ]),
      throwsArgumentError,
    );
    expect(
      () => const SportId('../football', 'Bad').validate(),
      throwsArgumentError,
    );
  });

  test(
    'invalid configuration and unfinished scenario dependencies are rejected',
    () {
      expect(
        () =>
            const SportDataPolicy(calendarDays: 2, analysisDays: 4).validate(),
        throwsArgumentError,
      );
      expect(
        () => SportModuleCatalog([
          const SportModuleDefinition(
            sport: SportId.hockey,
            stage: SportModuleStage.preparation,
            capabilities: {},
            readings: [
              SportReadingDefinition(
                id: 'draft',
                label: 'Draft',
                description: '',
                condition: '',
                example: '',
                implemented: false,
              ),
            ],
            scenarios: [
              SportScenarioDefinition(
                id: 'scenario',
                label: '',
                description: '',
                requiredReadingIds: ['draft'],
              ),
            ],
          ),
        ]),
        throwsArgumentError,
      );
    },
  );

  test('home and away remain canonical when hockey displays away first', () {
    final fixture = _fixture(SportId.hockey);
    final displayed = fixture.displayedParticipants(
      HockeyModule.definition.participantOrder,
    );
    expect(displayed.$1, fixture.away);
    expect(displayed.$2, fixture.home);
    expect(fixture.scoreFor(SportScoreScope.finalResult)!.home, 3);
    expect(fixture.scoreFor(SportScoreScope.regulation), isNull);
    expect(
      _fixture(SportId.football)
          .displayedParticipants(FootballModule.definition.participantOrder)
          .$1
          .name,
      'Home',
    );
    expect(
      () => SportFixture(
        id: fixture.id,
        competition: fixture.competition,
        competitionName: 'Invalid',
        season: '2026',
        home: fixture.home,
        away: _fixture(SportId.football).away,
        startsAt: fixture.startsAt,
        status: fixture.status,
      ),
      throwsArgumentError,
    );
  });

  test(
    'markets separate regulation and final settlement even for the same selection',
    () {
      SportMarketQuote quote(SportScoreScope scope) => SportMarketQuote(
        match: _fixture(SportId.hockey).id,
        marketCode: 'winner',
        selectionCode: 'home',
        scope: scope,
        bookmaker: 'bookmaker',
        decimalOdds: 2.1,
        capturedAt: DateTime.utc(2026, 10, 4),
      );
      expect(
        quote(SportScoreScope.regulation).selectionKey,
        isNot(quote(SportScoreScope.finalResult).selectionKey),
      );
    },
  );

  test(
    'sport persistence keeps football keys and isolates hockey across accounts and guests',
    () async {
      final memory = MemoryLocalKeyValueStore();
      final persistence = ScopedPersistence(store: memory);
      final football = ScopedSportPersistence(
        persistence: persistence,
        sport: SportId.football,
      );
      final hockey = ScopedSportPersistence(
        persistence: persistence,
        sport: SportId.hockey,
      );
      const account = IdentityScope.account('a');
      const other = IdentityScope.account('b');
      const guest = IdentityScope.guest('a');
      await persistence.write(
        account,
        'decision_profile',
        'existing-football-profile',
      );
      expect(
        await football.read(account, 'decision_profile'),
        'existing-football-profile',
      );
      expect(await hockey.read(account, 'decision_profile'), isNull);
      await hockey.write(account, 'decision_profile', 'hockey-profile');
      expect(await hockey.read(other, 'decision_profile'), isNull);
      expect(await hockey.read(guest, 'decision_profile'), isNull);
      await hockey.delete(account, 'decision_profile');
      expect(
        await football.read(account, 'decision_profile'),
        'existing-football-profile',
      );
      expect(
        football.keyFor(account, 'decision_profile'),
        persistence.keyFor(account, 'decision_profile'),
      );
    },
  );

  test(
    'shared reader accepts an empty publication through day 14 and ages against real time',
    () async {
      final reader = ValidatedSportFeedRepository(
        delegate: _Source(
          SportId.hockey,
          _publication(SportId.hockey, empty: true),
        ),
        policy: HockeyModule.definition.dataPolicy,
        clock: () => DateTime.utc(2026, 10, 4, 12),
      );
      final result = await reader.load(DateTime.utc(2026, 10, 17));
      expect(result.isAvailable, isTrue);
      expect(result.snapshot!.items, isEmpty);
      expect(
        (await reader.load(DateTime.utc(2026, 10, 18))).unavailableReason,
        SportFeedUnavailableReason.outsideWindow,
      );
      final stale = ValidatedSportFeedRepository(
        delegate: reader.delegate,
        policy: reader.policy,
        clock: () => DateTime.utc(2026, 10, 6),
      );
      expect(
        (await stale.load(DateTime.utc(2026, 10, 6))).unavailableReason,
        SportFeedUnavailableReason.stale,
      );
    },
  );

  test(
    'shared reader rejects a football publication returned by a hockey source',
    () async {
      final reader = ValidatedSportFeedRepository(
        delegate: _Source(SportId.hockey, _publication(SportId.football)),
        policy: HockeyModule.definition.dataPolicy,
      );
      await expectLater(
        reader.load(DateTime.utc(2026, 10, 4)),
        throwsStateError,
      );
    },
  );

  test(
    'football bridge preserves real compact calendar without changing its legacy repository',
    () async {
      final payload = Map<String, Object?>.from(
        jsonDecode(
              File(
                'test/fixtures/football_calendar_14_days_compact.json',
              ).readAsStringSync(),
            )
            as Map,
      );
      final legacy = SnapshotMatchFeedRepository(snapshot: payload);
      final existing = legacy.allMatches();
      final reader = ValidatedSportFeedRepository(
        delegate: FootballSportFeedAdapter(loadFootball: (_) async => legacy),
        policy: FootballModule.definition.dataPolicy,
        clock: () => DateTime.utc(2030, 10, 4, 12),
      );
      final result = await reader.load(DateTime(2030, 10, 17));
      expect(result.isAvailable, isTrue);
      expect(result.snapshot!.items.length, existing.length);
      expect(result.snapshot!.covers(DateTime(2030, 10, 18)), isFalse);
      final last = result.snapshot!.items.singleWhere(
        (item) => item.id.value == '13',
      );
      final original = existing
          .singleWhere((item) => item.fixture.apiFootballFixtureId == 13)
          .fixture;
      expect(last.home.name, original.homeTeam.name);
      expect(last.away.name, original.awayTeam.name);
      expect(last.startsAt, original.kickoff);
      expect(
        existing
            .singleWhere((item) => item.fixture.apiFootballFixtureId == 12)
            .hasMatchResultMarket,
        isTrue,
      );
      expect(legacy.allMatches(), existing);
    },
  );

  test(
    'subscriptions are separate and requested hockey scope matches the captured catalog',
    () {
      final football = FootballModule.definition.provider!;
      final hockey = HockeyModule.definition.provider!;
      expect(football.quotaKey, isNot(hockey.quotaKey));
      expect(football.dailyLimit, 75000);
      expect(hockey.dailyLimit, 7500);
      final audit =
          jsonDecode(
                File(
                  'docs/audits/api-hockey/2026-10-04/12_leagues.json',
                ).readAsStringSync(),
              )
              as Map;
      final leagues = audit['response'] as List;
      expect(HockeyIntegrationScope.targets, hasLength(7));
      for (final target in HockeyIntegrationScope.targets) {
        final match = leagues.singleWhere(
          (row) => row['id'] == target.providerId,
        );
        expect(match['name'], target.name);
        expect(match['country']['name'], target.country);
      }
    },
  );

  test('shared domain and hockey never import football implementation', () {
    final files =
        [Directory('lib/core/sports'), Directory('lib/features/hockey')]
            .expand(
              (directory) =>
                  directory.listSync(recursive: true).whereType<File>(),
            )
            .where((file) => file.path.endsWith('.dart'));
    final prohibited = RegExp(
      r'''import\s+['"][^'"]*(?:features/matches|features/football|/matches/|/football/)[^'"]*['"]''',
    );
    expect(
      files
          .where((file) => prohibited.hasMatch(file.readAsStringSync()))
          .map((file) => file.path),
      isEmpty,
    );
  });
}
