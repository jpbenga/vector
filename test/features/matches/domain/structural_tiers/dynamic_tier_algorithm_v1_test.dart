import 'package:copilot/features/matches/domain/structural_tiers/competition_structural_metadata.dart';
import 'package:copilot/features/matches/domain/structural_tiers/dynamic_tier_algorithm_v1.dart';
import 'package:copilot/features/matches/domain/structural_tiers/tier_input.dart';
import 'package:copilot/features/matches/domain/structural_tiers/tier_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DynamicTierAlgorithmV1 math', () {
    test(
      'computes median, IQR and MAD-zero robust fallback deterministically',
      () {
        expect(DynamicTierAlgorithmV1.median([1, 3, 2]), 2);
        expect(DynamicTierAlgorithmV1.median([1, 2, 3, 4]), 2.5);
        expect(
          DynamicTierAlgorithmV1.interquartileRange([
            1,
            1,
            1,
            1,
            1,
            1,
            2,
            3,
            4,
            4,
            4,
          ]),
          3,
        );

        final distribution = DynamicTierAlgorithmV1.computePointDistribution(
          _rows([60, 59, 58, 45, 44, 43, 42, 41, 40, 39]),
        );

        expect(distribution.medianGap, 1);
        expect(distribution.medianPositiveGap, 1);
        expect(distribution.typicalGap, 1);
        expect(distribution.rawMad, 0);
        expect(distribution.robustScale, 1);
        expect(DynamicTierAlgorithmV1.robustZForGap(13, distribution), 12);
        expect(DynamicTierAlgorithmV1.gapRatioForGap(13, distribution), 13);
      },
    );

    test('classifies score thresholds exactly', () {
      expect(
        DynamicTierAlgorithmV1.boundaryStrengthForScore(49.999),
        BoundaryStrength.weak,
      );
      expect(
        DynamicTierAlgorithmV1.boundaryStrengthForScore(50),
        BoundaryStrength.moderate,
      );
      expect(
        DynamicTierAlgorithmV1.isSpatiallyConfirmed(
          isCandidate: true,
          segmentationValid: true,
          score: 59.999,
          strength: BoundaryStrength.moderate,
        ),
        isFalse,
      );
      expect(
        DynamicTierAlgorithmV1.isSpatiallyConfirmed(
          isCandidate: true,
          segmentationValid: true,
          score: 60,
          strength: BoundaryStrength.moderate,
        ),
        isTrue,
      );
      expect(
        DynamicTierAlgorithmV1.boundaryStrengthForScore(77.999),
        BoundaryStrength.moderate,
      );
      expect(
        DynamicTierAlgorithmV1.boundaryStrengthForScore(78),
        BoundaryStrength.strong,
      );
    });

    test('applies PPG threshold operators and survival score exactly', () {
      final upper035 = _row(1, 40, played: 20);
      final lower035 = _row(2, 33, played: 20);
      final rejected = DynamicTierAlgorithmV1.qualifyWithPpg(
        upper: upper035,
        lower: lower035,
        rawGap: 20,
        medianPlayed: 20,
        playedSpread: 3,
        rawBoundaryScore: 84.999,
      );
      final survived = DynamicTierAlgorithmV1.qualifyWithPpg(
        upper: upper035,
        lower: lower035,
        rawGap: 20,
        medianPlayed: 20,
        playedSpread: 3,
        rawBoundaryScore: 85,
      );
      final downgraded = DynamicTierAlgorithmV1.qualifyWithPpg(
        upper: _row(1, 40, played: 20),
        lower: _row(2, 27, played: 20),
        rawGap: 20,
        medianPlayed: 20,
        playedSpread: 3,
        rawBoundaryScore: 80,
      );

      expect(rejected.ppgRatio, closeTo(0.35, 0.0000001));
      expect(rejected.rejected, isTrue);
      expect(survived.ppgRatio, closeTo(0.35, 0.0000001));
      expect(survived.rejected, isFalse);
      expect(survived.downgraded, isTrue);
      expect(survived.adjustedBoundaryScore, 70);
      expect(downgraded.ppgRatio, closeTo(0.65, 0.0000001));
      expect(downgraded.downgraded, isTrue);
      expect(downgraded.adjustedBoundaryScore, 65);
    });
  });

  group('DynamicTierAlgorithmV1 snapshots', () {
    test(
      'returns unavailable for unsupported format and team-count bounds',
      () {
        final unsupported = _algorithm.buildSnapshot(
          _input([
            60,
            59,
            58,
            57,
            56,
            55,
            54,
            53,
            52,
            51,
          ], format: CompetitionFormat.splitLeague),
        );
        final tooSmall = _algorithm.buildSnapshot(
          _input([60, 59, 58, 57, 56, 55, 54, 53, 52]),
        );

        expect(unsupported.status, TierSystemStatus.unavailable);
        expect(
          unsupported.unavailabilityReasons,
          contains(TierUnavailabilityReason.unsupportedCompetition),
        );
        expect(tooSmall.status, TierSystemStatus.unavailable);
        expect(
          tooSmall.unavailabilityReasons,
          contains(TierUnavailabilityReason.teamCountOutOfRange),
        );
      },
    );

    test('returns immature for early season and severe played imbalance', () {
      final early = _algorithm.buildSnapshot(
        _input([9, 7, 6, 5, 4, 4, 3, 2, 1, 0], played: 3),
      );
      final imbalanced = _algorithm.buildSnapshot(
        _input(
          [60, 59, 58, 57, 56, 55, 54, 53, 52, 51],
          playedByRank: [20, 20, 20, 20, 20, 20, 20, 20, 20, 12],
        ),
      );

      expect(early.status, TierSystemStatus.immature);
      expect(early.teamAssignments, isEmpty);
      expect(imbalanced.status, TierSystemStatus.immature);
      expect(imbalanced.warnings, contains(TierWarning.playedImbalance));
    });

    test(
      'does not invent boundaries in compact or stretched continuous leagues',
      () {
        final compact = _algorithm.buildSnapshot(
          _input([60, 59, 58, 57, 56, 55, 54, 53, 52, 51]),
        );
        final stretched = _algorithm.buildSnapshot(
          _input([80, 74, 69, 63, 58, 52, 47, 41, 36, 30, 25, 19]),
        );

        expect(compact.status, TierSystemStatus.mature);
        expect(compact.confirmedStructuralBoundaries, isEmpty);
        expect(compact.tierPartitionBoundaries, isEmpty);
        expect(compact.tierPresence, {
          TierLabel.tier1Podium,
          TierLabel.tier3MiddleChampionship,
          TierLabel.tier5Relegation,
        });
        expect(stretched.confirmedStructuralBoundaries, isEmpty);
        expect(stretched.tierPartitionBoundaries, isEmpty);
      },
    );

    test('keeps anchors without requiring adjacent structural boundaries', () {
      final podium = _algorithm.buildSnapshot(
        _input([60, 59, 58, 57, 55, 54, 53, 52, 51, 50]),
      );
      final relegation = _algorithm.buildSnapshot(
        _input([60, 58, 57, 56, 55, 54, 53, 52, 51, 50]),
      );

      expect(podium.confirmedStructuralBoundaries, isEmpty);
      expect(podium.assignmentForTeam(1)?.assignedTier, TierLabel.tier1Podium);
      expect(relegation.confirmedStructuralBoundaries, isEmpty);
      expect(
        relegation.assignmentForTeam(10)?.assignedTier,
        TierLabel.tier5Relegation,
      );
    });

    test(
      'confirms strong anchor-adjacent boundaries without using them as Tier partitions',
      () {
        final podium = _algorithm.buildSnapshot(
          _input([60, 59, 58, 45, 44, 43, 42, 41, 40, 39]),
        );
        final relegation = _algorithm.buildSnapshot(
          _input([60, 58, 57, 56, 55, 54, 53, 52, 38, 37]),
        );

        expect(_confirmedIndexes(podium), contains(3));
        expect(_strengthAt(podium, 3), BoundaryStrength.strong);
        expect(podium.tierPartitionBoundaries, isEmpty);
        expect(_confirmedIndexes(relegation), contains(8));
        expect(_strengthAt(relegation, 8), BoundaryStrength.strong);
        expect(relegation.tierPartitionBoundaries, isEmpty);
      },
    );

    test('does not cut equal-point blocks', () {
      final snapshot = _algorithm.buildSnapshot(
        _input([50, 48, 45, 45, 45, 40, 38, 37, 36, 35]),
      );

      expect(_candidateIndexes(snapshot), isNot(contains(3)));
      expect(_candidateIndexes(snapshot), isNot(contains(4)));
      expect(
        snapshot.confirmedStructuralBoundaries.every(
          (boundary) => boundary.rawGap > 0,
        ),
        isTrue,
      );
    });

    test(
      'uses PPG to reject a false raw boundary without creating boundaries',
      () {
        final rejected = _algorithm.buildSnapshot(
          _input(
            [41, 40, 39, 36, 35, 34, 33, 32, 31, 30],
            playedByRank: [20, 20, 20, 18, 20, 20, 20, 20, 20, 20],
          ),
        );
        final noRawCandidate = _algorithm.buildSnapshot(
          _input(
            [50, 49, 48, 47, 46, 45, 44, 43, 42, 41],
            playedByRank: [20, 20, 20, 18, 20, 20, 20, 20, 20, 20],
          ),
        );

        expect(rejected.warnings, contains(TierWarning.ppgQualificationUsed));
        expect(rejected.warnings, contains(TierWarning.ppgBoundaryRejected));
        expect(_candidateAt(rejected, 3)?.ppgQualification.rejected, isTrue);
        expect(rejected.confirmedStructuralBoundaries, isEmpty);
        expect(noRawCandidate.boundaryCandidates, isEmpty);
        expect(noRawCandidate.confirmedStructuralBoundaries, isEmpty);
      },
    );

    test(
      'retains all confirmed structural boundaries while partitioning at most two',
      () {
        final first = _algorithm.buildSnapshot(
          _input([
            80,
            78,
            76,
            66,
            64,
            62,
            52,
            50,
            48,
            38,
            36,
            34,
            24,
            22,
            20,
          ], identity: 'S1'),
        );
        final snapshot = _algorithm.buildSnapshot(
          _input([
            80,
            78,
            76,
            66,
            64,
            62,
            52,
            50,
            48,
            38,
            36,
            34,
            24,
            22,
            20,
          ], identity: 'S2'),
          previousState: first.toPreviousBoundaryState(),
        );

        expect(_confirmedIndexes(snapshot), [3, 6, 9, 12]);
        expect(snapshot.tierPartitionBoundaries.length, lessThanOrEqualTo(2));
        expect(
          snapshot.tierPartitionBoundaries.every(
            (partition) =>
                _confirmedIndexes(snapshot).contains(partition.boundaryIndex),
          ),
          isTrue,
        );
        expect(snapshot.structuralBoundaryGapByRank(1, 15), 4);
      },
    );

    test(
      'produces deterministic output for identical inputs and previous state',
      () {
        final input = _input([70, 68, 67, 55, 54, 53, 42, 41, 40, 39]);
        final first = _algorithm.buildSnapshot(input);
        final second = _algorithm.buildSnapshot(input);

        expect(_confirmedIndexes(second), _confirmedIndexes(first));
        expect(_partitionIndexes(second), _partitionIndexes(first));
        expect(second.tierPresence, first.tierPresence);
        expect(
          second.teamAssignments.map((assignment) => assignment.assignedTier),
          first.teamAssignments.map((assignment) => assignment.assignedTier),
        );
      },
    );
  });

  group('DynamicTierAlgorithmV1 temporal behavior', () {
    test('same snapshot rerun does not confirm a new MODERATE boundary', () {
      final input = _input([
        60,
        58,
        57,
        53,
        52,
        51,
        48,
        47,
        46,
        42,
        41,
        40,
      ], identity: 'S1');
      final first = _algorithm.buildSnapshot(input);
      final rerun = _algorithm.buildSnapshot(
        input,
        previousState: first.toPreviousBoundaryState(),
      );

      expect(first.confirmedStructuralBoundaries, isEmpty);
      expect(first.warnings, contains(TierWarning.pendingModerateBoundary));
      expect(rerun.confirmedStructuralBoundaries, isEmpty);
      expect(rerun.warnings, contains(TierWarning.pendingModerateBoundary));
    });

    test('distinct compatible MODERATE snapshots confirm the boundary', () {
      final s1 = _algorithm.buildSnapshot(
        _input([
          60,
          58,
          57,
          53,
          52,
          51,
          48,
          47,
          46,
          42,
          41,
          40,
        ], identity: 'S1'),
      );
      final s2 = _algorithm.buildSnapshot(
        _input([
          61,
          59,
          58,
          54,
          53,
          52,
          49,
          48,
          47,
          43,
          42,
          41,
        ], identity: 'S2'),
        previousState: s1.toPreviousBoundaryState(),
      );

      expect(s2.confirmedStructuralBoundaries, isNotEmpty);
      expect(
        s2.confirmedStructuralBoundaries.every(
          (boundary) => boundary.strength == BoundaryStrength.moderate,
        ),
        isTrue,
      );
    });

    test('new STRONG boundary confirms immediately', () {
      final snapshot = _algorithm.buildSnapshot(
        _input([70, 68, 67, 55, 54, 53, 42, 41, 40, 39]),
      );

      expect(_confirmedIndexes(snapshot), [3, 6]);
      expect(
        snapshot.confirmedStructuralBoundaries.every(
          (boundary) => boundary.strength == BoundaryStrength.strong,
        ),
        isTrue,
      );
    });

    test('existing confirmed boundary persists once, then expires', () {
      final previousState = PreviousBoundaryState(
        standingsSnapshotIdentity: 'S0',
        confirmedBoundaries: [
          _confirmed(3, BoundaryStrength.strong, score: 80),
        ],
      );
      final warnings = <TierWarning>{};
      final persisted =
          DynamicTierAlgorithmV1.applyTemporalBoundaryStabilityForTesting(
            candidates: [_candidate(3, score: 55)],
            previousState: previousState,
            standingsSnapshotIdentity: 'S1',
            warnings: warnings,
          );
      final rejectedByPpg =
          DynamicTierAlgorithmV1.applyTemporalBoundaryStabilityForTesting(
            candidates: [_candidate(3, score: 70, ppgRejected: true)],
            previousState: previousState,
            standingsSnapshotIdentity: 'S1',
            warnings: <TierWarning>{},
          );
      final expired =
          DynamicTierAlgorithmV1.applyTemporalBoundaryStabilityForTesting(
            candidates: [_candidate(3, score: 55)],
            previousState: PreviousBoundaryState(
              standingsSnapshotIdentity: 'S1',
              confirmedBoundaries: [
                _confirmed(
                  3,
                  BoundaryStrength.moderate,
                  score: 55,
                  persisted: true,
                  persistenceAge: 1,
                ),
              ],
            ),
            standingsSnapshotIdentity: 'S2',
            warnings: <TierWarning>{},
          );

      expect(persisted.confirmed.single.boundaryIndex, 3);
      expect(persisted.confirmed.single.persisted, isTrue);
      expect(warnings, contains(TierWarning.boundaryPersisted));
      expect(rejectedByPpg.confirmed, isEmpty);
      expect(expired.confirmed, isEmpty);
    });
  });
  group('DynamicTierAlgorithmV1 partitioning', () {
    test(
      'global partition does not select the top two scores mechanically',
      () {
        final input = _input(
          [100, 99, 90, 89, 70, 69, 68, 67, 66, 65, 64, 50, 49, 30, 29, 28],
          podiumEnd: 2,
          relegationStart: 15,
        );
        final rows = _rows(
          input.standingsRows.map((row) => row.points).toList(),
        );
        final selected =
            DynamicTierAlgorithmV1.selectTierPartitionForTesting(rows, input, [
              _confirmed(4, BoundaryStrength.strong, score: 100),
              _confirmed(5, BoundaryStrength.strong, score: 99),
              _confirmed(12, BoundaryStrength.strong, score: 80),
            ]);

        expect(_partitionIndexesFrom(selected), isNot([4, 5]));
      },
    );

    test(
      'epsilon favors simpler partition, larger gain favors richer partition',
      () {
        final compactInput = _input([30, 30, 30, 30, 30, 30, 30, 30, 30, 30]);
        final compactSelected =
            DynamicTierAlgorithmV1.selectTierPartitionForTesting(
              compactInput.standingsRows,
              compactInput,
              [_confirmed(5, BoundaryStrength.strong, score: 90)],
            );

        final structuredInput = _input([
          100,
          99,
          98,
          80,
          79,
          78,
          60,
          59,
          40,
          39,
          20,
          19,
        ]);
        final structuredSelected =
            DynamicTierAlgorithmV1.selectTierPartitionForTesting(
              structuredInput.standingsRows,
              structuredInput,
              [
                _confirmed(6, BoundaryStrength.strong, score: 90),
                _confirmed(8, BoundaryStrength.strong, score: 88),
              ],
            );

        expect(compactSelected, isEmpty);
        expect(structuredSelected.length, 2);
      },
    );
  });

  group('DynamicTierAlgorithmV1 derived structural helpers', () {
    test('applies structural_level_gap acceptance exactly', () {
      final oneModerate = _manualSnapshot([
        _confirmed(3, BoundaryStrength.moderate, score: 65),
      ]);
      final oneStrong = _manualSnapshot([
        _confirmed(3, BoundaryStrength.strong, score: 80),
      ]);
      final twoModerate = _manualSnapshot([
        _confirmed(2, BoundaryStrength.moderate, score: 65),
        _confirmed(4, BoundaryStrength.moderate, score: 65),
      ]);
      final twoIncludingStrong = _manualSnapshot([
        _confirmed(2, BoundaryStrength.moderate, score: 65),
        _confirmed(4, BoundaryStrength.strong, score: 80),
      ]);

      expect(
        _algorithm
            .deriveStructuralLevelGap(
              oneModerate,
              subjectTeamId: 1,
              opponentTeamId: 5,
            )
            .exists,
        isFalse,
      );
      expect(
        _algorithm
            .deriveStructuralLevelGap(
              oneStrong,
              subjectTeamId: 1,
              opponentTeamId: 5,
            )
            .strength,
        StructuralLevelGapStrength.moderate,
      );
      expect(
        _algorithm
            .deriveStructuralLevelGap(
              twoModerate,
              subjectTeamId: 1,
              opponentTeamId: 5,
            )
            .strength,
        StructuralLevelGapStrength.moderate,
      );
      expect(
        _algorithm
            .deriveStructuralLevelGap(
              twoIncludingStrong,
              subjectTeamId: 1,
              opponentTeamId: 5,
            )
            .strength,
        StructuralLevelGapStrength.strong,
      );
    });

    test('requires rank and points closeness for balanced hierarchy', () {
      final balanced = _manualSnapshot([]);
      final largePointsGapSameTier = _manualSnapshot(
        [],
        points: [50, 49, 48, 30, 29, 28, 27, 26, 25, 24],
      );
      final largeRankGapSameTier = _manualSnapshot(
        [],
        assignmentTier: TierLabel.tier3MiddleChampionship,
      );
      final separated = _manualSnapshot([
        _confirmed(2, BoundaryStrength.strong, score: 80),
      ]);

      expect(
        _algorithm
            .deriveBalancedHierarchy(balanced, teamAId: 1, teamBId: 2)
            .exists,
        isTrue,
      );
      expect(
        _algorithm
            .deriveBalancedHierarchy(
              largePointsGapSameTier,
              teamAId: 1,
              teamBId: 4,
            )
            .exists,
        isFalse,
      );
      expect(
        _algorithm
            .deriveBalancedHierarchy(
              largeRankGapSameTier,
              teamAId: 1,
              teamBId: 10,
            )
            .exists,
        isFalse,
      );
      expect(
        _algorithm
            .deriveBalancedHierarchy(separated, teamAId: 1, teamBId: 3)
            .exists,
        isFalse,
      );
    });

    test('keeps KR/Vikingur same-tier structural regression non-separated', () {
      final snapshot = _manualSnapshot(
        [],
        points: [51, 47, 43, 40, 39, 38, 37, 36, 35, 34],
        assignmentTier: TierLabel.tier1Podium,
      );
      final pair = _algorithm.assessPair(
        snapshot,
        subjectTeamId: 1,
        opponentTeamId: 3,
      );

      expect(pair.sameTier, isTrue);
      expect(pair.structuralBoundaryGap, 0);
      expect(pair.structuralLevelGap.exists, isFalse);
    });
  });

  group('DynamicTierAlgorithmV1 synthetic championship battery', () {
    for (final batteryCase in _batteryCases) {
      test('case ${batteryCase.id}: ${batteryCase.name}', () {
        final first = _algorithm.buildSnapshot(batteryCase.input);
        final snapshot = batteryCase.confirmWithDistinctSecondSnapshot
            ? _algorithm.buildSnapshot(
                _input(
                  batteryCase.points,
                  played: batteryCase.played,
                  playedByRank: batteryCase.playedByRank,
                  identity: 'case-${batteryCase.id}-S2',
                ),
                previousState: first.toPreviousBoundaryState(),
              )
            : first;

        expect(snapshot.status, batteryCase.expectedStatus);
        expect(snapshot.maturity, batteryCase.expectedMaturity);
        for (final index in batteryCase.expectedConfirmedIndexes) {
          expect(_confirmedIndexes(snapshot), contains(index));
        }
        for (final index in batteryCase.expectedAbsentConfirmedIndexes) {
          expect(_confirmedIndexes(snapshot), isNot(contains(index)));
        }
        expect(snapshot.tierPartitionBoundaries.length, lessThanOrEqualTo(2));
        expect(
          snapshot.tierPartitionBoundaries.every(
            (partition) =>
                _confirmedIndexes(snapshot).contains(partition.boundaryIndex),
          ),
          isTrue,
        );
        expect(_hasNoEqualPointsBoundary(snapshot), isTrue);
        expect(
          snapshot.teamAssignments
              .map((assignment) => assignment.teamId)
              .toSet()
              .length,
          snapshot.teamAssignments.length,
        );
      });
    }
  });
}

const _algorithm = DynamicTierAlgorithmV1();

DynamicTierInput _input(
  List<int> points, {
  int played = 20,
  List<int>? playedByRank,
  int podiumEnd = 3,
  int? relegationStart,
  String identity = 'S1',
  CompetitionFormat format = CompetitionFormat.standardRoundRobin,
  double? seasonProgress,
}) {
  final resolvedRelegationStart = relegationStart ?? points.length - 1;
  return DynamicTierInput(
    competitionId: 'synthetic',
    season: 2026,
    analysisAsOf: DateTime.utc(2026, 9, 2, 10),
    competitionFormat: format,
    standingsRows: _rows(points, played: played, playedByRank: playedByRank),
    podiumAnchor: CompetitionStructuralAnchor(
      startRank: 1,
      endRank: podiumEnd,
      source: StructuralAnchorSource.lectorOverride,
    ),
    relegationAnchor: CompetitionStructuralAnchor(
      startRank: resolvedRelegationStart,
      endRank: points.length,
      source: StructuralAnchorSource.lectorOverride,
    ),
    anchorMetadataVersion: 'anchor-test-v1',
    competitionFormatVersion: 'format-test-v1',
    structuralMetadataVersion: 'structural-test-v1',
    standingsSnapshotIdentity: identity,
    seasonProgress: seasonProgress,
  );
}

List<DynamicTierInputStanding> _rows(
  List<int> points, {
  int played = 20,
  List<int>? playedByRank,
}) {
  return [
    for (var index = 0; index < points.length; index += 1)
      _row(
        index + 1,
        points[index],
        played: playedByRank == null ? played : playedByRank[index],
      ),
  ];
}

DynamicTierInputStanding _row(int rank, int points, {int played = 20}) {
  return DynamicTierInputStanding(
    teamId: rank,
    teamName: 'Team $rank',
    officialRank: rank,
    points: points,
    played: played,
  );
}

ConfirmedStructuralBoundary _confirmed(
  int index,
  BoundaryStrength strength, {
  required double score,
  bool persisted = false,
  int persistenceAge = 0,
}) {
  return ConfirmedStructuralBoundary(
    boundaryIndex: index,
    upperRank: index,
    lowerRank: index + 1,
    rawGap: 5,
    score: score,
    strength: strength,
    standingsSnapshotIdentity: 'manual',
    persisted: persisted,
    persistenceAge: persistenceAge,
  );
}

BoundaryCandidate _candidate(
  int index, {
  required double score,
  bool ppgRejected = false,
}) {
  final strength = DynamicTierAlgorithmV1.boundaryStrengthForScore(score);
  return BoundaryCandidate(
    boundaryIndex: index,
    upperRank: index,
    lowerRank: index + 1,
    rawGap: 3,
    eligible: true,
    detected: true,
    robustZ: 1.5,
    gapRatio: 3,
    segmentationGain: 0.20,
    segmentationValid: true,
    rawBoundaryScore: score,
    adjustedBoundaryScore: score,
    strength: strength,
    ppgQualification: PpgBoundaryQualification(
      active: ppgRejected,
      rejected: ppgRejected,
      downgraded: false,
      rawBoundaryScore: score,
      adjustedBoundaryScore: score,
    ),
    spatialConfirmed: DynamicTierAlgorithmV1.isSpatiallyConfirmed(
      isCandidate: !ppgRejected,
      segmentationValid: true,
      score: score,
      strength: strength,
    ),
    temporalStatus: BoundaryTemporalStatus.candidate,
  );
}

ChampionshipTierSnapshot _manualSnapshot(
  List<ConfirmedStructuralBoundary> boundaries, {
  List<int> points = const [30, 29, 28, 27, 26, 25, 24, 23, 22, 21],
  TierLabel? assignmentTier,
}) {
  final distribution = DynamicTierAlgorithmV1.computePointDistribution(
    _rows(points),
  );
  return ChampionshipTierSnapshot(
    competitionId: 'manual',
    season: 2026,
    analysisAsOf: DateTime.utc(2026, 9, 2, 10),
    tierSystemVersion: DynamicTierAlgorithmV1.tierSystemVersion,
    standingsSnapshotIdentity: 'manual',
    status: TierSystemStatus.mature,
    maturity: TierMaturity.mature,
    teamCount: points.length,
    pointDistribution: distribution,
    ppgDistribution: PpgDistributionContext(
      values: const [],
      medianPlayed: 20,
      minPlayed: 20,
      maxPlayed: 20,
      playedSpread: 0,
    ),
    boundaryCandidates: const [],
    confirmedStructuralBoundaries: boundaries,
    tierPartitionBoundaries: const [],
    tierPresence: {assignmentTier ?? TierLabel.tier3MiddleChampionship},
    teamAssignments: [
      for (var index = 0; index < points.length; index += 1)
        TeamTierAssignment(
          teamId: index + 1,
          teamName: 'Team ${index + 1}',
          officialRank: index + 1,
          points: points[index],
          played: 20,
          pointsPerGame: points[index] / 20,
          assignedTier: assignmentTier ?? TierLabel.tier3MiddleChampionship,
        ),
    ],
    warnings: const [],
    unavailabilityReasons: const [],
  );
}

List<int> _candidateIndexes(ChampionshipTierSnapshot snapshot) {
  return snapshot.boundaryCandidates
      .map((candidate) => candidate.boundaryIndex)
      .toList(growable: false);
}

BoundaryCandidate? _candidateAt(ChampionshipTierSnapshot snapshot, int index) {
  for (final candidate in snapshot.boundaryCandidates) {
    if (candidate.boundaryIndex == index) {
      return candidate;
    }
  }
  return null;
}

List<int> _confirmedIndexes(ChampionshipTierSnapshot snapshot) {
  return snapshot.confirmedStructuralBoundaries
      .map((boundary) => boundary.boundaryIndex)
      .toList(growable: false);
}

List<int> _partitionIndexes(ChampionshipTierSnapshot snapshot) {
  return snapshot.tierPartitionBoundaries
      .map((boundary) => boundary.boundaryIndex)
      .toList(growable: false);
}

List<int> _partitionIndexesFrom(List<TierPartitionBoundary> boundaries) {
  return boundaries.map((boundary) => boundary.boundaryIndex).toList();
}

BoundaryStrength? _strengthAt(ChampionshipTierSnapshot snapshot, int index) {
  return snapshot.confirmedStructuralBoundaries
      .singleWhere((boundary) => boundary.boundaryIndex == index)
      .strength;
}

bool _hasNoEqualPointsBoundary(ChampionshipTierSnapshot snapshot) {
  final points = snapshot.pointDistribution?.points;
  if (points == null) {
    return true;
  }
  for (final boundary in snapshot.confirmedStructuralBoundaries) {
    if (points[boundary.boundaryIndex - 1] == points[boundary.boundaryIndex]) {
      return false;
    }
  }
  return true;
}

class _BatteryCase {
  const _BatteryCase({
    required this.id,
    required this.name,
    required this.points,
    this.played = 20,
    this.playedByRank,
    this.expectedStatus = TierSystemStatus.mature,
    this.expectedMaturity = TierMaturity.mature,
    this.expectedConfirmedIndexes = const [],
    this.expectedAbsentConfirmedIndexes = const [],
    this.confirmWithDistinctSecondSnapshot = false,
  });

  final int id;
  final String name;
  final List<int> points;
  final int played;
  final List<int>? playedByRank;
  final TierSystemStatus expectedStatus;
  final TierMaturity expectedMaturity;
  final List<int> expectedConfirmedIndexes;
  final List<int> expectedAbsentConfirmedIndexes;
  final bool confirmWithDistinctSecondSnapshot;

  DynamicTierInput get input => _input(
    points,
    played: played,
    playedByRank: playedByRank,
    identity: 'case-$id-S1',
  );
}

final _batteryCases = <_BatteryCase>[
  const _BatteryCase(
    id: 1,
    name: 'Perfectly compact',
    points: [60, 59, 58, 57, 56, 55, 54, 53, 52, 51],
  ),
  const _BatteryCase(
    id: 2,
    name: 'Compact with one small outlier',
    points: [60, 59, 58, 56, 55, 54, 53, 52, 51, 50],
  ),
  const _BatteryCase(
    id: 3,
    name: 'Clear podium break',
    points: [60, 59, 58, 45, 44, 43, 42, 41, 40, 39],
    expectedConfirmedIndexes: [3],
  ),
  const _BatteryCase(
    id: 4,
    name: 'Podium anchor without break',
    points: [60, 59, 58, 57, 55, 54, 53, 52, 51, 50],
  ),
  const _BatteryCase(
    id: 5,
    name: 'Clear relegation break',
    points: [60, 58, 57, 56, 55, 54, 53, 52, 38, 37],
    expectedConfirmedIndexes: [8],
  ),
  const _BatteryCase(
    id: 6,
    name: 'Relegation anchor without break',
    points: [60, 58, 57, 56, 55, 54, 53, 52, 51, 50],
  ),
  const _BatteryCase(
    id: 7,
    name: 'One huge leader',
    points: [80, 60, 58, 57, 56, 55, 54, 53, 52, 51],
    expectedAbsentConfirmedIndexes: [1],
  ),
  const _BatteryCase(
    id: 8,
    name: 'One isolated bottom',
    points: [80, 79, 78, 77, 76, 75, 74, 73, 72, 50],
    expectedAbsentConfirmedIndexes: [9],
  ),
  const _BatteryCase(
    id: 9,
    name: 'Three natural groups',
    points: [70, 68, 67, 55, 54, 53, 42, 41, 40, 39],
    expectedConfirmedIndexes: [3, 6],
  ),
  const _BatteryCase(
    id: 10,
    name: 'Four natural groups',
    points: [70, 68, 67, 58, 57, 56, 45, 44, 43, 30, 29, 28],
    expectedConfirmedIndexes: [6, 9],
    confirmWithDistinctSecondSnapshot: true,
  ),
  const _BatteryCase(
    id: 11,
    name: 'Five natural groups',
    points: [
      70,
      68,
      67,
      58,
      57,
      55,
      54,
      45,
      44,
      43,
      42,
      41,
      30,
      29,
      27,
      18,
      17,
    ],
    expectedConfirmedIndexes: [3, 7, 12, 15],
    confirmWithDistinctSecondSnapshot: true,
  ),
  const _BatteryCase(
    id: 12,
    name: 'Stretched continuous',
    points: [80, 74, 69, 63, 58, 52, 47, 41, 36, 30, 25, 19],
  ),
  const _BatteryCase(
    id: 13,
    name: 'Multiple similar large gaps',
    points: [80, 73, 66, 59, 52, 45, 38, 31, 24, 17],
  ),
  const _BatteryCase(
    id: 14,
    name: 'Equal-points block',
    points: [50, 48, 45, 45, 45, 40, 38, 37, 36, 35],
    confirmWithDistinctSecondSnapshot: true,
  ),
  const _BatteryCase(
    id: 15,
    name: 'Quasi-equality',
    points: [50, 48, 45, 44, 44, 40, 38, 37, 36, 35],
  ),
  const _BatteryCase(
    id: 16,
    name: 'Games-in-hand mild',
    points: [40, 36, 35, 34, 33, 32, 31, 30, 29, 28],
    playedByRank: [20, 19, 20, 20, 20, 20, 20, 20, 20, 20],
  ),
  const _BatteryCase(
    id: 17,
    name: 'Games-in-hand severe false break',
    points: [40, 36, 35, 34, 33, 32, 31, 30, 29, 28],
    playedByRank: [20, 18, 20, 20, 20, 20, 20, 20, 20, 20],
  ),
  const _BatteryCase(
    id: 18,
    name: 'Early season',
    points: [9, 7, 6, 5, 4, 4, 3, 2, 1, 0],
    played: 3,
    expectedStatus: TierSystemStatus.immature,
    expectedMaturity: TierMaturity.immature,
  ),
  const _BatteryCase(
    id: 19,
    name: 'Mature 24-team league',
    points: [
      75,
      73,
      72,
      68,
      67,
      66,
      62,
      61,
      60,
      59,
      58,
      57,
      53,
      52,
      51,
      50,
      49,
      48,
      44,
      43,
      42,
      38,
      37,
      36,
    ],
    confirmWithDistinctSecondSnapshot: true,
  ),
  const _BatteryCase(
    id: 20,
    name: 'Noisy borderline',
    points: [60, 58, 57, 53, 52, 51, 48, 47, 46, 42, 41, 40],
  ),
  const _BatteryCase(
    id: 21,
    name: 'Repeated execution remains pending',
    points: [60, 58, 57, 53, 52, 51, 48, 47, 46, 42, 41, 40],
  ),
  const _BatteryCase(
    id: 22,
    name: 'Distinct snapshot confirms moderate',
    points: [60, 58, 57, 53, 52, 51, 48, 47, 46, 42, 41, 40],
    confirmWithDistinctSecondSnapshot: true,
  ),
  const _BatteryCase(
    id: 23,
    name: 'Strong immediate',
    points: [70, 68, 67, 55, 54, 53, 42, 41, 40, 39],
    expectedConfirmedIndexes: [3, 6],
  ),
  const _BatteryCase(
    id: 24,
    name: 'More than two structural boundaries',
    points: [80, 78, 76, 66, 64, 62, 52, 50, 48, 38, 36, 34, 24, 22, 20],
    expectedConfirmedIndexes: [3, 6, 9, 12],
    confirmWithDistinctSecondSnapshot: true,
  ),
  const _BatteryCase(
    id: 25,
    name: 'Negligible partition gain',
    points: [30, 29, 28, 27, 26, 25, 24, 23, 22, 21],
  ),
  const _BatteryCase(
    id: 26,
    name: 'Severe played imbalance',
    points: [60, 59, 58, 57, 56, 55, 54, 53, 52, 51],
    playedByRank: [20, 20, 20, 20, 20, 20, 20, 20, 20, 12],
    expectedStatus: TierSystemStatus.immature,
    expectedMaturity: TierMaturity.immature,
  ),
];
