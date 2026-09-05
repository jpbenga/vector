import 'dart:convert';

import 'package:copilot/core/config/app_config.dart';
import 'package:copilot/core/config/app_environment.dart';
import 'package:copilot/core/supabase/supabase_initializer.dart';
import 'package:copilot/features/matches/data/api_football_match_adapter.dart';
import 'package:copilot/features/matches/data/match_feed_repository.dart';
import 'package:copilot/features/matches/data/match_feed_repository_loader.dart';
import 'package:copilot/features/matches/data/supabase_match_feed_snapshot_repository.dart';
import 'package:copilot/features/matches/domain/football_analyzer.dart';
import 'package:copilot/features/matches/domain/football_reading.dart';
import 'package:copilot/features/matches/domain/match_board_item.dart';
import 'package:copilot/features/matches/domain/opportunity_engine_v2.dart';
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

  group('SnapshotMatchFeedRepository personalization', () {
    test('applies first saved preferences immediately to Pour moi', () {
      final analyzer = _CountingFootballAnalyzer({
        'fixture-domination': _dominationReadings(),
        'fixture-open': _openMatchReadings('fixture-open'),
      });
      final repository = _personalizationRepository(analyzer);

      expect(repository.personalizedFor(_emptyProfile()), isEmpty);
      expect(analyzer.calls, 2);

      final matches = repository.personalizedFor(
        _profile(markets: ['double_chance'], profiles: ['ranking_gap']),
      );

      expect(matches.map((match) => match.id), ['fixture-domination']);
      expect(matches.single.thesis?.id, 'expected_domination');
      expect(analyzer.calls, 2);
    });

    test('applies preference modifications immediately', () {
      final analyzer = _CountingFootballAnalyzer({
        'fixture-domination': _dominationReadings(),
        'fixture-open': _openMatchReadings('fixture-open'),
      });
      final repository = _personalizationRepository(analyzer);

      final rankingOnly = repository.personalizedFor(
        _profile(markets: ['double_chance'], profiles: ['ranking_gap']),
      );
      final offensiveOnly = repository.personalizedFor(
        _profile(markets: ['goals_over_under'], profiles: ['offensive_match']),
      );

      expect(rankingOnly.map((match) => match.id), ['fixture-domination']);
      expect(offensiveOnly.map((match) => match.id), ['fixture-open']);
      expect(offensiveOnly.single.thesis?.id, 'convergent_open_match');
      expect(analyzer.calls, 2);
    });

    test(
      'keeps reading-only matches in Pour moi without creating opportunities',
      () {
        final analyzer = _CountingFootballAnalyzer({
          'fixture-domination': _dominationReadings(),
          'fixture-open': _openMatchReadings('fixture-open'),
          'fixture-form': [
            _reading(
              'positive_streak',
              'home-form',
              side: ReadingSubjectSide.home,
              kind: ReadingEvidenceKind.form,
            ),
          ],
        });
        final repository = _personalizationRepository(
          analyzer,
          extraMatches: [
            _personalizationMatch(
              fixtureId: 'fixture-form',
              homeTeamId: 'home-form',
              awayTeamId: 'away-form',
              markets: const [],
            ),
          ],
        );
        final profile = _profile(
          markets: ['double_chance'],
          profiles: ['positive_series'],
        );

        final opportunities = repository.opportunitiesFor(profile);
        final matches = repository.personalizedFor(profile);

        expect(
          opportunities.map((opportunity) => opportunity.matchId),
          isNot(contains('fixture-form')),
        );
        expect(matches.map((match) => match.id), contains('fixture-form'));
        final readingOnlyMatch = matches.singleWhere(
          (match) => match.id == 'fixture-form',
        );
        expect(readingOnlyMatch.thesis, isNull);
        expect(readingOnlyMatch.signals.single.id, 'positive_streak');
        expect(readingOnlyMatch.compatibility, greaterThan(0));
        expect(analyzer.calls, 3);
      },
    );

    test(
      'does not require market preferences to show reading-only matches',
      () {
        final analyzer = _CountingFootballAnalyzer({
          'fixture-domination': _dominationReadings(),
          'fixture-open': _openMatchReadings('fixture-open'),
          'fixture-form': [
            _reading(
              'positive_streak',
              'home-form',
              side: ReadingSubjectSide.home,
              kind: ReadingEvidenceKind.form,
            ),
          ],
        });
        final repository = _personalizationRepository(
          analyzer,
          extraMatches: [
            _personalizationMatch(
              fixtureId: 'fixture-form',
              homeTeamId: 'home-form',
              awayTeamId: 'away-form',
              markets: const [],
            ),
          ],
        );
        final profile = _profile(
          markets: const [],
          profiles: ['positive_series'],
        );

        final opportunities = repository.opportunitiesFor(profile);
        final matches = repository.personalizedFor(profile);

        expect(opportunities, isEmpty);
        expect(matches.map((match) => match.id), contains('fixture-form'));
        final readingOnlyMatch = matches.singleWhere(
          (match) => match.id == 'fixture-form',
        );
        expect(readingOnlyMatch.thesis, isNull);
        expect(readingOnlyMatch.signals.single.id, 'positive_streak');
      },
    );

    test('removes matches that only matched a deleted preference', () {
      final analyzer = _CountingFootballAnalyzer({
        'fixture-domination': _dominationReadings(),
        'fixture-open': _openMatchReadings('fixture-open'),
      });
      final repository = _personalizationRepository(analyzer);

      final beforeRemoval = repository.personalizedFor(
        _profile(
          markets: ['double_chance', 'goals_over_under'],
          profiles: ['ranking_gap', 'offensive_match'],
        ),
      );
      final afterRemoval = repository.personalizedFor(
        _profile(markets: ['goals_over_under'], profiles: ['offensive_match']),
      );

      expect(
        beforeRemoval.map((match) => match.id),
        containsAll(['fixture-domination', 'fixture-open']),
      );
      expect(afterRemoval.map((match) => match.id), ['fixture-open']);
      expect(analyzer.calls, 2);
    });

    test('does not run new football analysis on preference-only changes', () {
      final analyzer = _CountingFootballAnalyzer({
        'fixture-domination': _dominationReadings(),
        'fixture-open': _openMatchReadings('fixture-open'),
      });
      final repository = _personalizationRepository(analyzer);

      expect(analyzer.calls, 2);

      repository.opportunitiesFor(
        _profile(markets: ['double_chance'], profiles: ['ranking_gap']),
      );
      repository.opportunitiesFor(
        _profile(markets: ['goals_over_under'], profiles: ['offensive_match']),
      );
      repository.analyzeFor(
        _profile(markets: ['double_chance'], profiles: ['ranking_gap']),
        repository.allMatches().first,
      );

      expect(analyzer.calls, 2);
    });

    test('keeps saved preferences applied after profile reload', () {
      final analyzer = _CountingFootballAnalyzer({
        'fixture-domination': _dominationReadings(),
        'fixture-open': _openMatchReadings('fixture-open'),
      });
      final repository = _personalizationRepository(analyzer);
      final saved = _profile(
        markets: ['goals_over_under'],
        profiles: ['offensive_match'],
      );
      final reloaded = DecisionProfile.fromJson(saved.toJson());

      final matches = repository.personalizedFor(reloaded);

      expect(matches.map((match) => match.id), ['fixture-open']);
      expect(matches.single.thesis?.id, 'convergent_open_match');
      expect(analyzer.calls, 2);
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

SnapshotMatchFeedRepository _personalizationRepository(
  _CountingFootballAnalyzer analyzer, {
  List<MatchBoardItem> extraMatches = const [],
}) {
  return SnapshotMatchFeedRepository(
    snapshot: _intelligenceSnapshot(),
    adapter: _StaticMatchAdapter([
      _personalizationMatch(
        fixtureId: 'fixture-domination',
        homeTeamId: 'home-domination',
        awayTeamId: 'away-domination',
        markets: const [
          MatchMarket(
            id: 'doubleChance',
            label: 'Double chance',
            selections: [
              MarketOdds(
                id: 'double_chance_1x',
                label: '1X',
                odds: 1.42,
                apiFootballValue: 'Home/Draw',
              ),
            ],
          ),
        ],
      ),
      _personalizationMatch(
        fixtureId: 'fixture-open',
        homeTeamId: 'home-open',
        awayTeamId: 'away-open',
        markets: const [
          MatchMarket(
            id: 'goalsTotal',
            label: 'Over / Under buts',
            selections: [
              MarketOdds(
                id: 'over_2_5',
                label: 'Over 2.5',
                odds: 1.74,
                apiFootballValue: 'Over 2.5',
              ),
            ],
          ),
        ],
      ),
      ...extraMatches,
    ]),
    opportunityEngine: OpportunityEngineV2(analyzer: analyzer),
  );
}

DecisionProfile _emptyProfile() {
  return const DecisionProfile(onboardingVersion: 'test', answers: []);
}

DecisionProfile _profile({
  required List<String> markets,
  required List<String> profiles,
}) {
  return DecisionProfile(
    onboardingVersion: 'test',
    answers: [
      const OnboardingAnswer(
        questionId: 'competitions',
        orderedOptionIds: ['eng_premier_league'],
      ),
      OnboardingAnswer(questionId: 'markets', orderedOptionIds: markets),
      OnboardingAnswer(
        questionId: 'opportunity_profiles',
        orderedOptionIds: profiles,
      ),
    ],
  );
}

Map<String, Object?> _intelligenceSnapshot() {
  return const {
    'schema_version': 1,
    'source': 'api-football',
    'captured_at': '2026-08-08T08:30:00Z',
    'timezone': 'Europe/Paris',
    'raw': {
      'fixtures': <Object?>[],
      'odds': <Object?>[],
      'standings': <Object?>[],
      'team_statistics': <Object?>[],
      'recent_league_matches': <Object?>[],
      'expected_goals': <Object?>[],
      'predictions': <Object?>[],
    },
  };
}

MatchBoardItem _personalizationMatch({
  required String fixtureId,
  required String homeTeamId,
  required String awayTeamId,
  required List<MatchMarket> markets,
}) {
  return MatchBoardItem(
    fixture: NormalizedFixture(
      id: fixtureId,
      competition: const CompetitionInfo(
        id: '39',
        name: 'Premier League',
        country: CountryInfo(code: 'GB', name: 'Angleterre'),
        season: 2026,
      ),
      homeTeam: TeamInfo(id: homeTeamId, name: 'Home'),
      awayTeam: TeamInfo(id: awayTeamId, name: 'Away'),
      kickoffLabel: '20:00',
      kickoff: DateTime.utc(2026, 8, 8, 18),
      status: FixtureStatus.scheduled,
    ),
    primaryMarket: const MarketOdds(
      id: 'market_unavailable',
      label: 'Marché indisponible',
      odds: 0,
    ),
    availableMarkets: markets,
    analysis: MatchAnalysisData(asOf: DateTime.utc(2026, 8, 8, 8, 30)),
    compatibility: 0,
    signals: const [],
  );
}

List<FootballReading> _dominationReadings() {
  return [
    _reading(
      'structural_level_gap',
      'home-domination',
      side: ReadingSubjectSide.home,
      kind: ReadingEvidenceKind.standing,
    ),
    _reading(
      'ranking_superiority',
      'home-domination',
      side: ReadingSubjectSide.home,
      kind: ReadingEvidenceKind.standing,
    ),
    _reading(
      'positive_streak',
      'home-domination',
      side: ReadingSubjectSide.home,
      kind: ReadingEvidenceKind.form,
    ),
    _reading(
      'weak_away_team',
      'away-domination',
      side: ReadingSubjectSide.away,
      kind: ReadingEvidenceKind.homeAway,
    ),
  ];
}

List<FootballReading> _openMatchReadings(String fixtureId) {
  return [
    _reading(
      'open_match_profile',
      fixtureId,
      side: ReadingSubjectSide.match,
      kind: ReadingEvidenceKind.sample,
    ),
    _reading(
      'frequent_over_25',
      fixtureId,
      side: ReadingSubjectSide.match,
      kind: ReadingEvidenceKind.sample,
    ),
    _reading(
      'high_xg_creation',
      'home-open',
      side: ReadingSubjectSide.home,
      kind: ReadingEvidenceKind.expectedGoals,
    ),
  ];
}

FootballReading _reading(
  String id,
  String subjectTeamId, {
  required ReadingSubjectSide side,
  required ReadingEvidenceKind kind,
}) {
  return FootballReading(
    id: id,
    subjectTeamId: subjectTeamId,
    subjectSide: side,
    status: ReadingStatus.detected,
    strength: ReadingStrength.strong,
    evidence: [ReadingEvidence(label: id, kind: kind, sourcePath: 'test')],
    warnings: const [],
    asOf: DateTime.utc(2026, 8, 8, 8, 30),
    sampleSize: 10,
  );
}

class _StaticMatchAdapter extends ApiFootballMatchAdapter {
  const _StaticMatchAdapter(this.matches);

  final List<MatchBoardItem> matches;

  @override
  List<MatchBoardItem> fromSnapshot(Map<String, Object?> snapshot) {
    return matches;
  }
}

class _CountingFootballAnalyzer extends FootballAnalyzer {
  _CountingFootballAnalyzer(this._readingsByFixtureId);

  final Map<String, List<FootballReading>> _readingsByFixtureId;
  int calls = 0;

  @override
  FootballAnalysis analyze(MatchBoardItem match, {DateTime? asOf}) {
    calls += 1;
    return FootballAnalysis(
      fixtureId: match.id,
      asOf: asOf ?? match.analysis.asOf ?? DateTime.utc(2026, 8, 8, 8, 30),
      readings: _readingsByFixtureId[match.id] ?? const [],
    );
  }
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
