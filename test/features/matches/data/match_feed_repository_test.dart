import 'dart:convert';

import 'package:copilot/core/config/app_config.dart';
import 'package:copilot/core/config/app_environment.dart';
import 'package:copilot/core/supabase/supabase_initializer.dart';
import 'package:copilot/features/matches/data/match_feed_repository.dart';
import 'package:copilot/features/matches/data/match_feed_repository_loader.dart';
import 'package:copilot/features/matches/data/supabase_match_feed_snapshot_repository.dart';
import 'package:copilot/features/matches/domain/match_board_item.dart';
import 'package:copilot/features/onboarding/domain/decision_profile.dart';
import 'package:copilot/features/onboarding/domain/onboarding_answer.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MatchFeedSnapshotMetadata', () {
    test('parses explicit freshness window from the snapshot contract', () {
      final repository = const MatchFeedRepositoryFactory().create(
        MatchDataSourceMode.snapshot,
        snapshot: _snapshot(
          capturedAt: '2026-08-08T08:30:00Z',
          windowStart: '2026-08-08',
          windowEnd: '2026-08-09',
        ),
      );

      final metadata = repository.snapshotMetadata;

      expect(metadata, isNotNull);
      expect(metadata!.source, 'api-football');
      expect(metadata.matchCount, 1);
      expect(metadata.windowStart, DateTime(2026, 8, 8));
      expect(metadata.windowEnd, DateTime(2026, 8, 9));
      expect(metadata.covers(DateTime(2026, 8, 8, 18)), isTrue);
      expect(metadata.covers(DateTime(2026, 8, 10)), isFalse);
      expect(metadata.isEmpty, isFalse);
    });

    test('infers a window from fixtures when legacy snapshots omit it', () {
      final repository = const MatchFeedRepositoryFactory().create(
        MatchDataSourceMode.snapshot,
        snapshot: _snapshot(
          capturedAt: '2026-08-08T08:30:00Z',
          fixtureDate: '2026-08-09T17:00:00+02:00',
        ),
      );

      final metadata = repository.snapshotMetadata;

      expect(metadata?.windowStart, DateTime(2026, 8, 9));
      expect(metadata?.windowEnd, DateTime(2026, 8, 9));
    });

    test('keeps missing snapshot mode unavailable instead of falling back', () {
      final repository = const MatchFeedRepositoryFactory().create(
        MatchDataSourceMode.snapshot,
      );

      expect(repository, isA<UnavailableMatchFeedRepository>());
      expect(repository.snapshotMetadata, isNull);
      expect(repository.allMatches, throwsStateError);
    });
  });

  group('DemoMatchFeedRepository', () {
    const repository = DemoMatchFeedRepository();

    test('exposes normalized fixtures and API-Football mapping metadata', () {
      final matches = repository.allMatches();

      expect(matches, hasLength(5));
      expect(matches.first.fixture.id, 'ars-eve');
      expect(matches.first.competition.id, '39');
      expect(matches.first.competition.apiFootballLeagueId, 39);
      expect(matches.first.homeTeam.name, 'Arsenal');
      expect(matches.first.primaryMarket.label, 'Double Chance 1X');
    });

    test('does not recommend demo matches without a sufficient thesis', () {
      const profile = DecisionProfile(
        onboardingVersion: 'test',
        answers: [
          OnboardingAnswer(
            questionId: 'competitions',
            orderedOptionIds: ['fr_ligue_1', 'eng_premier_league'],
          ),
          OnboardingAnswer(
            questionId: 'match_volume_preference',
            orderedOptionIds: [],
            scaleValue: 5,
          ),
        ],
      );

      final matches = repository.personalizedFor(profile);

      expect(matches, isEmpty);
    });

    test('derives personalized matches from canonical opportunities', () {
      const profile = DecisionProfile(
        onboardingVersion: 'test',
        answers: [
          OnboardingAnswer(
            questionId: 'competitions',
            orderedOptionIds: ['eng_premier_league'],
          ),
          OnboardingAnswer(
            questionId: 'markets',
            orderedOptionIds: ['double_chance'],
          ),
          OnboardingAnswer(
            questionId: 'opportunity_profiles',
            orderedOptionIds: ['solid_favorite'],
          ),
        ],
      );

      final opportunities = repository.opportunitiesFor(profile);
      final matches = repository.personalizedFor(profile);

      expect(opportunities, hasLength(matches.length));
      expect(matches.map((match) => match.id), [
        for (final opportunity in opportunities) opportunity.matchId,
      ]);
    });
  });

  group('MatchFeedRepositoryLoader', () {
    test('loads the remote Supabase snapshot first in auto mode', () async {
      final remote = _FakeRemoteSnapshotDataSource(
        latestForDate: _snapshot(
          capturedAt: '2026-08-12T08:00:00Z',
          windowStart: '2026-08-11',
          windowEnd: '2026-08-16',
          fixtureDate: '2026-08-12T17:00:00+02:00',
        ),
      );
      final loader = _loader(
        source: 'auto',
        configuredSupabase: true,
        remoteDataSource: remote,
        localSnapshot: _snapshot(
          capturedAt: '2026-07-30T08:00:00Z',
          windowStart: '2026-07-30',
          windowEnd: '2026-07-30',
        ),
      );

      final repository = await loader.load(now: DateTime(2026, 8, 12));

      expect(remote.latestForDateCalls, 1);
      expect(repository.snapshotMetadata?.windowStart, DateTime(2026, 8, 11));
      expect(repository.snapshotMetadata?.windowEnd, DateTime(2026, 8, 16));
    });

    test(
      'falls back to the local snapshot when remote loading fails',
      () async {
        final remote = _FakeRemoteSnapshotDataSource(
          throwsOnLatestForDate: true,
        );
        final loader = _loader(
          source: 'auto',
          configuredSupabase: true,
          remoteDataSource: remote,
          localSnapshot: _snapshot(
            capturedAt: '2026-07-30T08:00:00Z',
            windowStart: '2026-07-30',
            windowEnd: '2026-07-30',
          ),
        );

        final repository = await loader.load(now: DateTime(2026, 8, 12));

        expect(remote.latestForDateCalls, 1);
        expect(repository.snapshotMetadata?.windowStart, DateTime(2026, 7, 30));
      },
    );

    test('uses the latest remote snapshot when today is not covered', () async {
      final remote = _FakeRemoteSnapshotDataSource(
        latest: _snapshot(
          capturedAt: '2026-08-11T22:21:50Z',
          windowStart: '2026-08-11',
          windowEnd: '2026-08-16',
        ),
      );
      final loader = _loader(
        source: 'auto',
        configuredSupabase: true,
        remoteDataSource: remote,
        localSnapshot: _snapshot(
          capturedAt: '2026-07-30T08:00:00Z',
          windowStart: '2026-07-30',
          windowEnd: '2026-07-30',
        ),
      );

      final repository = await loader.load(now: DateTime(2026, 8, 20));

      expect(remote.latestForDateCalls, 1);
      expect(remote.latestCalls, 1);
      expect(repository.snapshotMetadata?.windowStart, DateTime(2026, 8, 11));
      expect(repository.snapshotMetadata?.windowEnd, DateTime(2026, 8, 16));
    });

    test('keeps snapshot mode fully local for offline debugging', () async {
      final remote = _FakeRemoteSnapshotDataSource(
        latestForDate: _snapshot(
          capturedAt: '2026-08-12T08:00:00Z',
          windowStart: '2026-08-11',
          windowEnd: '2026-08-16',
        ),
      );
      final loader = _loader(
        source: 'snapshot',
        configuredSupabase: true,
        remoteDataSource: remote,
        localSnapshot: _snapshot(
          capturedAt: '2026-07-30T08:00:00Z',
          windowStart: '2026-07-30',
          windowEnd: '2026-07-30',
        ),
      );

      final repository = await loader.load(now: DateTime(2026, 8, 12));

      expect(remote.latestForDateCalls, 0);
      expect(repository.snapshotMetadata?.windowStart, DateTime(2026, 7, 30));
    });
  });
}

MatchFeedRepositoryLoader _loader({
  required String source,
  required bool configuredSupabase,
  required MatchFeedSnapshotRemoteDataSource remoteDataSource,
  required Map<String, Object?> localSnapshot,
}) {
  final config = AppConfig(
    environment: AppEnvironment.development,
    supabaseUrl: configuredSupabase ? Uri.parse('https://example.test') : null,
    supabaseAnonKey: configuredSupabase ? 'anon-key' : null,
    matchFeedSource: source,
  );

  return MatchFeedRepositoryLoader(
    config: config,
    supabaseInitializer: SupabaseInitializer(config),
    remoteDataSource: remoteDataSource,
    assetBundle: _FakeAssetBundle(jsonEncode(localSnapshot)),
  );
}

Map<String, Object?> _snapshot({
  required String capturedAt,
  String? windowStart,
  String? windowEnd,
  String fixtureDate = '2026-08-08T17:00:00+02:00',
}) {
  final snapshot = <String, Object?>{
    'schema_version': 1,
    'source': 'api-football',
    'captured_at': capturedAt,
    'timezone': 'Europe/Paris',
    'raw': {
      'fixtures': [
        {
          'fixture': {
            'id': 1,
            'date': fixtureDate,
            'status': {'short': 'NS'},
          },
          'league': {
            'id': 61,
            'name': 'Ligue 1',
            'country': 'France',
            'season': 2026,
          },
          'teams': {
            'home': {'id': 10, 'name': 'Home'},
            'away': {'id': 11, 'name': 'Away'},
          },
        },
      ],
      'odds': <Object?>[],
    },
  };
  if (windowStart != null) {
    snapshot['window_start'] = windowStart;
  }
  if (windowEnd != null) {
    snapshot['window_end'] = windowEnd;
  }
  return snapshot;
}

class _FakeRemoteSnapshotDataSource
    implements MatchFeedSnapshotRemoteDataSource {
  _FakeRemoteSnapshotDataSource({
    this.latestForDate,
    this.latest,
    this.throwsOnLatestForDate = false,
  });

  final Map<String, Object?>? latestForDate;
  final Map<String, Object?>? latest;
  final bool throwsOnLatestForDate;
  int latestForDateCalls = 0;
  int latestCalls = 0;

  @override
  Future<Map<String, Object?>?> loadLatestForDate(DateTime date) async {
    latestForDateCalls += 1;
    if (throwsOnLatestForDate) {
      throw StateError('remote unavailable');
    }
    return latestForDate;
  }

  @override
  Future<Map<String, Object?>?> loadLatest() async {
    latestCalls += 1;
    return latest;
  }
}

class _FakeAssetBundle extends CachingAssetBundle {
  _FakeAssetBundle(this._content);

  final String _content;

  @override
  Future<ByteData> load(String key) async {
    final bytes = utf8.encode(_content);
    return ByteData.sublistView(Uint8List.fromList(bytes));
  }
}
