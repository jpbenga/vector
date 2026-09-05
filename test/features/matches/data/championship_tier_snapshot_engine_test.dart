import 'package:copilot/features/matches/data/api_football_match_adapter.dart';
import 'package:copilot/features/matches/data/championship_tier_snapshot_engine.dart';
import 'package:copilot/features/matches/data/championship_tier_temporal_state_store.dart';
import 'package:copilot/features/matches/data/match_feed_repository.dart';
import 'package:copilot/features/matches/domain/match_board_item.dart';
import 'package:copilot/features/matches/domain/structural_tiers/competition_structural_metadata.dart';
import 'package:copilot/features/matches/domain/structural_tiers/dynamic_tier_algorithm_v1.dart';
import 'package:copilot/features/matches/domain/structural_tiers/standings_snapshot_identity.dart';
import 'package:copilot/features/matches/domain/structural_tiers/tier_input.dart';
import 'package:copilot/features/matches/domain/structural_tiers/tier_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChampionshipTierSnapshotEngine', () {
    test('keeps same-snapshot MODERATE boundaries pending', () {
      final store = InMemoryChampionshipTierTemporalStateStore();
      final engine = ChampionshipTierSnapshotEngine(temporalStateStore: store);
      final first = engine.buildSnapshot(
        competitionId: '39',
        season: 2026,
        analysisAsOf: _analysisAsOf,
        leagueStandings: _standings(_moderatePoints),
        metadata: _metadata(),
        sourceMetadata: _sourceMetadata(sourceFetchedAtHour: 8),
      );
      final rerun = engine.buildSnapshot(
        competitionId: '39',
        season: 2026,
        analysisAsOf: _analysisAsOf,
        leagueStandings: _standings(_moderatePoints),
        metadata: _metadata(),
        sourceMetadata: _sourceMetadata(sourceFetchedAtHour: 9),
      );

      expect(first.isSuccess, isTrue);
      expect(rerun.isSuccess, isTrue);
      expect(first.identity?.value, rerun.identity?.value);
      expect(first.snapshot?.confirmedStructuralBoundaries, isEmpty);
      expect(rerun.snapshot?.confirmedStructuralBoundaries, isEmpty);
      expect(
        store.read(first.identity!.lineageKey)?.pendingBoundaries,
        isNotEmpty,
      );
    });

    test('confirms a MODERATE boundary on a distinct compatible snapshot', () {
      final engine = ChampionshipTierSnapshotEngine(
        temporalStateStore: InMemoryChampionshipTierTemporalStateStore(),
      );
      final first = engine.buildSnapshot(
        competitionId: '39',
        season: 2026,
        analysisAsOf: _analysisAsOf,
        leagueStandings: _standings(_moderatePoints),
        metadata: _metadata(),
        sourceMetadata: _sourceMetadata(),
      );
      final second = engine.buildSnapshot(
        competitionId: '39',
        season: 2026,
        analysisAsOf: _analysisAsOf,
        leagueStandings: _standings(_moderatePointsShifted),
        metadata: _metadata(),
        sourceMetadata: _sourceMetadata(sourceFetchedAtHour: 9),
      );

      expect(first.identity?.value, isNot(second.identity?.value));
      expect(first.snapshot?.confirmedStructuralBoundaries, isEmpty);
      expect(second.snapshot?.confirmedStructuralBoundaries, isNotEmpty);
      expect(
        second.snapshot?.confirmedStructuralBoundaries.every(
          (boundary) => boundary.strength == BoundaryStrength.moderate,
        ),
        isTrue,
      );
    });

    test('does not count multiple same-league reads as temporal events', () {
      final engine = ChampionshipTierSnapshotEngine(
        temporalStateStore: InMemoryChampionshipTierTemporalStateStore(),
      );

      final first = engine.buildSnapshot(
        competitionId: '39',
        season: 2026,
        analysisAsOf: _analysisAsOf,
        leagueStandings: _standings(_moderatePoints),
        metadata: _metadata(),
        sourceMetadata: _sourceMetadata(),
      );
      final second = engine.buildSnapshot(
        competitionId: '39',
        season: 2026,
        analysisAsOf: _analysisAsOf,
        leagueStandings: _standings(_moderatePoints),
        metadata: _metadata(),
        sourceMetadata: _sourceMetadata(sourceFetchedAtHour: 9),
      );
      final third = engine.buildSnapshot(
        competitionId: '39',
        season: 2026,
        analysisAsOf: _analysisAsOf,
        leagueStandings: _standings(_moderatePoints),
        metadata: _metadata(),
        sourceMetadata: _sourceMetadata(sourceFetchedAtHour: 10),
      );

      expect(first.identity?.value, second.identity?.value);
      expect(second.identity?.value, third.identity?.value);
      expect(first.snapshot, same(second.snapshot));
      expect(second.snapshot, same(third.snapshot));
      expect(third.snapshot?.confirmedStructuralBoundaries, isEmpty);
    });

    test('preserves STRONG immediate confirmation', () {
      final engine = ChampionshipTierSnapshotEngine(
        temporalStateStore: InMemoryChampionshipTierTemporalStateStore(),
      );

      final result = engine.buildSnapshot(
        competitionId: '39',
        season: 2026,
        analysisAsOf: _analysisAsOf,
        leagueStandings: _standings([70, 68, 67, 55, 54, 53, 42, 41, 40, 39]),
        metadata: _metadata(relegationStart: 9, relegationEnd: 10),
        sourceMetadata: _sourceMetadata(),
      );

      expect(result.isSuccess, isTrue);
      expect(result.snapshot?.confirmedStructuralBoundaries, isNotEmpty);
      expect(
        result.snapshot?.confirmedStructuralBoundaries.every(
          (boundary) => boundary.strength == BoundaryStrength.strong,
        ),
        isTrue,
      );
    });

    test('stores and carries one-snapshot persistence state', () {
      final store = InMemoryChampionshipTierTemporalStateStore();
      final key = const ChampionshipTierTemporalLineageKey(
        competitionId: '39',
        season: 2026,
        tierSystemVersion: DynamicTierAlgorithmV1.tierSystemVersion,
        anchorMetadataVersion: 'anchor-test-v1',
        competitionFormatVersion: 'format-test-v1',
      );
      store.write(
        key,
        PreviousBoundaryState(
          standingsSnapshotIdentity: 'S0',
          confirmedBoundaries: [_confirmed(3, persistenceAge: 0)],
        ),
      );
      expect(store.read(key)?.confirmedBoundaries.single.persistenceAge, 0);

      store.write(
        key,
        PreviousBoundaryState(
          standingsSnapshotIdentity: 'S1',
          confirmedBoundaries: [
            _confirmed(3, persisted: true, persistenceAge: 1),
          ],
        ),
      );

      final carried = store.read(key);
      expect(carried?.confirmedBoundaries.single.persisted, isTrue);
      expect(carried?.confirmedBoundaries.single.persistenceAge, 1);
    });

    test('rejects post-analysis source snapshots', () {
      final engine = ChampionshipTierSnapshotEngine(
        temporalStateStore: InMemoryChampionshipTierTemporalStateStore(),
      );

      final accepted = engine.buildSnapshot(
        competitionId: '39',
        season: 2026,
        analysisAsOf: _analysisAsOf,
        leagueStandings: _standings(_moderatePoints),
        metadata: _metadata(),
        sourceMetadata: DynamicTierSourceMetadata(sourceAsOf: _analysisAsOf),
      );
      final rejected = engine.buildSnapshot(
        competitionId: '39',
        season: 2026,
        analysisAsOf: _analysisAsOf,
        leagueStandings: _standings(_moderatePoints),
        metadata: _metadata(),
        sourceMetadata: DynamicTierSourceMetadata(
          sourceAsOf: _analysisAsOf.add(const Duration(minutes: 1)),
        ),
      );

      expect(accepted.isSuccess, isTrue);
      expect(rejected.isSuccess, isFalse);
      expect(
        rejected.errors,
        contains(
          ChampionshipTierSnapshotEngineError.sourceSnapshotAfterAnalysis,
        ),
      );
      expect(
        rejected.inputErrors,
        contains(DynamicTierInputBuildError.sourceSnapshotAfterAnalysis),
      );
    });

    test('builds identity from real snapshot payload shape after adapter', () {
      final sourceSnapshot = _snapshotPayload();
      final matches = const ApiFootballMatchAdapter().fromSnapshot(
        sourceSnapshot,
      );
      final standings = matches.single.analysis.leagueStandings;
      final sourceMetadata = DynamicTierSourceMetadata.fromSnapshotPayload(
        sourceSnapshot,
      );
      final result =
          ChampionshipTierSnapshotEngine(
            temporalStateStore: InMemoryChampionshipTierTemporalStateStore(),
          ).buildSnapshot(
            competitionId: matches.single.competition.id,
            season: matches.single.competition.season,
            analysisAsOf: DateTime.utc(2026, 9, 2, 8),
            leagueStandings: standings,
            metadata: _metadata(relegationStart: 9, relegationEnd: 10),
            sourceMetadata: sourceMetadata,
          );

      expect(matches.single.competition.id, '39');
      expect(standings, hasLength(10));
      expect(standings.first.description, 'Promotion');
      expect(result.isSuccess, isTrue);
      expect(result.identity?.canonicalStandingsStateHash.value, isNotEmpty);
      expect(
        result.snapshot?.standingsSnapshotIdentity,
        result.identity?.value,
      );
    });

    test(
      'repository attaches one shared Tier relation per competition snapshot',
      () {
        final engine = _CountingChampionshipTierSnapshotEngine();
        final repository = SnapshotMatchFeedRepository(
          snapshot: _snapshotPayload(twoFixtures: true),
          metadataRepository: _SingleCompetitionMetadataRepository(
            _metadata(relegationStart: 9, relegationEnd: 10),
          ),
          tierSnapshotEngine: engine,
        );
        final matches = repository.allMatches();

        expect(matches, hasLength(2));
        expect(engine.buildCount, 1);
        expect(
          matches.map((match) => match.analysis.structuralRelation),
          everyElement(isNotNull),
        );
        expect(
          matches
              .map(
                (match) => match
                    .analysis
                    .structuralRelation!
                    .standingsSnapshotIdentity,
              )
              .toSet(),
          hasLength(1),
        );
      },
    );
  });
}

final _analysisAsOf = DateTime.utc(2026, 9, 2, 12);
const _moderatePoints = [60, 58, 57, 53, 52, 51, 48, 47, 46, 42, 41, 40];
const _moderatePointsShifted = [61, 59, 58, 54, 53, 52, 49, 48, 47, 43, 42, 41];

DynamicTierSourceMetadata _sourceMetadata({int sourceFetchedAtHour = 8}) {
  return DynamicTierSourceMetadata(
    sourceAsOf: _analysisAsOf,
    sourceFetchedAt: DateTime.utc(2026, 9, 2, sourceFetchedAtHour),
    providerSnapshotVersion: '1',
  );
}

CompetitionStructuralMetadata _metadata({
  int relegationStart = 11,
  int relegationEnd = 12,
}) {
  return CompetitionStructuralMetadata(
    competitionId: '39',
    season: 2026,
    competitionFormat: CompetitionFormat.standardRoundRobin,
    supportStatus: StructuralSupportStatus.supportedV1,
    podiumAnchor: const CompetitionStructuralAnchor(
      startRank: 1,
      endRank: 3,
      source: StructuralAnchorSource.lectorOverride,
    ),
    relegationAnchor: CompetitionStructuralAnchor(
      startRank: relegationStart,
      endRank: relegationEnd,
      source: StructuralAnchorSource.lectorOverride,
    ),
    anchorMetadataVersion: 'anchor-test-v1',
    competitionFormatVersion: 'format-test-v1',
    structuralMetadataVersion: 'structural-test-v1',
  );
}

List<TeamStandingSnapshot> _standings(List<int> points) {
  return [
    for (var index = 0; index < points.length; index += 1)
      TeamStandingSnapshot(
        teamId: index + 1,
        teamName: 'Team ${index + 1}',
        rank: index + 1,
        points: points[index],
        played: 20,
        group: 'Premier League',
      ),
  ];
}

ConfirmedStructuralBoundary _confirmed(
  int index, {
  bool persisted = false,
  int persistenceAge = 0,
}) {
  return ConfirmedStructuralBoundary(
    boundaryIndex: index,
    upperRank: index,
    lowerRank: index + 1,
    rawGap: 4,
    score: 55,
    strength: BoundaryStrength.moderate,
    standingsSnapshotIdentity: 'S0',
    persisted: persisted,
    persistenceAge: persistenceAge,
  );
}

Map<String, Object?> _snapshotPayload({bool twoFixtures = false}) {
  return {
    'schema_version': 1,
    'source': 'api-football',
    'captured_at': '2026-09-02T07:55:00Z',
    'as_of': '2026-09-02T07:55:00Z',
    'raw': {
      'fixtures': [
        {
          'fixture': {
            'id': 1,
            'date': '2026-09-03T20:00:00Z',
            'status': {'short': 'NS'},
          },
          'league': {
            'id': 39,
            'name': 'Premier League',
            'country': 'England',
            'season': 2026,
          },
          'teams': {
            'home': {'id': 1, 'name': 'Team 1'},
            'away': {'id': 2, 'name': 'Team 2'},
          },
        },
        if (twoFixtures)
          {
            'fixture': {
              'id': 2,
              'date': '2026-09-03T18:00:00Z',
              'status': {'short': 'NS'},
            },
            'league': {
              'id': 39,
              'name': 'Premier League',
              'country': 'England',
              'season': 2026,
            },
            'teams': {
              'home': {'id': 3, 'name': 'Team 3'},
              'away': {'id': 8, 'name': 'Team 8'},
            },
          },
      ],
      'standings': [
        {
          'league': {
            'id': 39,
            'season': 2026,
            'standings': [
              [
                for (var index = 0; index < 10; index += 1)
                  {
                    'rank': index + 1,
                    'team': {'id': index + 1, 'name': 'Team ${index + 1}'},
                    'points': [70, 68, 67, 55, 54, 53, 42, 41, 40, 39][index],
                    'group': 'Premier League',
                    'description': index == 0
                        ? 'Promotion'
                        : index == 9
                        ? 'Relegation'
                        : null,
                    'all': {'played': 20},
                  },
              ],
            ],
          },
        },
      ],
      'odds': const <Object?>[],
      'team_statistics': const <Object?>[],
      'recent_league_matches': const <Object?>[],
      'expected_goals': const <Object?>[],
      'predictions': const <Object?>[],
    },
  };
}

class _SingleCompetitionMetadataRepository
    implements CompetitionStructuralMetadataRepository {
  const _SingleCompetitionMetadataRepository(this.metadata);

  final CompetitionStructuralMetadata metadata;

  @override
  CompetitionStructuralMetadata? metadataFor({
    required String competitionId,
    required int season,
  }) {
    if (metadata.competitionId == competitionId && metadata.season == season) {
      return metadata;
    }
    return null;
  }
}

class _CountingChampionshipTierSnapshotEngine
    extends ChampionshipTierSnapshotEngine {
  _CountingChampionshipTierSnapshotEngine()
    : super(temporalStateStore: InMemoryChampionshipTierTemporalStateStore());

  int buildCount = 0;

  @override
  ChampionshipTierSnapshotEngineResult buildSnapshot({
    required String competitionId,
    required int season,
    required DateTime? analysisAsOf,
    required List<TeamStandingSnapshot> leagueStandings,
    required CompetitionStructuralMetadata? metadata,
    double? seasonProgress,
    DynamicTierSourceMetadata sourceMetadata =
        const DynamicTierSourceMetadata(),
  }) {
    buildCount += 1;
    return super.buildSnapshot(
      competitionId: competitionId,
      season: season,
      analysisAsOf: analysisAsOf,
      leagueStandings: leagueStandings,
      metadata: metadata,
      seasonProgress: seasonProgress,
      sourceMetadata: sourceMetadata,
    );
  }
}
