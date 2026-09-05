import 'dart:math' as math;

import 'competition_structural_metadata.dart';
import 'tier_input.dart';
import 'tier_models.dart';
import 'tier_parameters.dart';

class DynamicTierAlgorithmV1 {
  const DynamicTierAlgorithmV1();

  static const algorithmName = 'DynamicTierAlgorithmV1';
  static const tierSystemVersion = 'tier-v1';

  ChampionshipTierSnapshot buildSnapshot(
    DynamicTierInput input, {
    PreviousBoundaryState previousState = PreviousBoundaryState.empty,
  }) {
    final orderedRows = [...input.standingsRows]
      ..sort((a, b) => a.officialRank.compareTo(b.officialRank));
    final unavailabilityReasons = _validateInput(input, orderedRows);
    if (unavailabilityReasons.isNotEmpty) {
      return _snapshot(
        input,
        status: TierSystemStatus.unavailable,
        maturity: TierMaturity.unavailable,
        unavailabilityReasons: unavailabilityReasons,
      );
    }

    final ppgContext = _computePpgContext(orderedRows);
    final maturityWarnings = <TierWarning>{};
    if (ppgContext.playedSpread >
        DynamicTierParameters.maxPlayedSpreadBalanced) {
      maturityWarnings.add(TierWarning.playedImbalance);
    }
    if (_isImmature(input, ppgContext)) {
      if (_hasSeverePlayedImbalance(ppgContext)) {
        maturityWarnings.add(TierWarning.playedImbalance);
      }
      return _snapshot(
        input,
        status: TierSystemStatus.immature,
        maturity: TierMaturity.immature,
        ppgDistribution: ppgContext,
        warnings: maturityWarnings,
      );
    }

    final pointDistribution = computePointDistribution(orderedRows);
    final warnings = <TierWarning>{...maturityWarnings};
    final candidates = _buildBoundaryCandidates(
      input,
      orderedRows,
      pointDistribution,
      ppgContext,
      warnings,
    );

    final temporalResult = _applyTemporalBoundaryStability(
      candidates,
      previousState,
      input.standingsSnapshotIdentity,
      warnings,
    );
    final confirmedStructuralBoundaries = temporalResult.confirmed;
    final candidatesWithTemporalStatus = temporalResult.candidates;
    final tierPartitionBoundaries = _selectBestTierPartition(
      orderedRows,
      input,
      confirmedStructuralBoundaries,
    );
    final assignments = _assignTierLabels(
      orderedRows,
      input,
      tierPartitionBoundaries,
    );

    return _snapshot(
      input,
      status: TierSystemStatus.mature,
      maturity: TierMaturity.mature,
      pointDistribution: pointDistribution,
      ppgDistribution: ppgContext,
      boundaryCandidates: candidatesWithTemporalStatus,
      confirmedStructuralBoundaries: confirmedStructuralBoundaries,
      tierPartitionBoundaries: tierPartitionBoundaries,
      teamAssignments: assignments,
      tierPresence: assignments.map((assignment) => assignment.assignedTier),
      warnings: warnings,
    );
  }

  static PointDistribution computePointDistribution(
    List<DynamicTierInputStanding> orderedRows,
  ) {
    final points = orderedRows.map((row) => row.points).toList(growable: false);
    final gaps = <int>[];
    for (var i = 0; i < points.length - 1; i += 1) {
      gaps.add(points[i] - points[i + 1]);
    }

    final positiveGaps = gaps.where((gap) => gap > 0).toList(growable: false);
    final medianGap = median(gaps);
    final medianPositiveGap = positiveGaps.isEmpty ? 0.0 : median(positiveGaps);
    final typicalGap = math.max(
      DynamicTierParameters.minRobustScale,
      medianPositiveGap,
    );
    final rawMad = median(
      gaps.map((gap) => (gap - medianGap).abs()).toList(growable: false),
    );
    final iqr = interquartileRange(gaps);
    final madScale = rawMad * DynamicTierParameters.madNormalizationFactor;
    final iqrScale = iqr / DynamicTierParameters.iqrNormalizationFactor;
    final fallbackScale = [
      DynamicTierParameters.minRobustScale,
      iqrScale,
      medianPositiveGap * DynamicTierParameters.madZeroMedianPositiveFactor,
    ].reduce(math.max);
    final robustScale = rawMad > 0 ? madScale : fallbackScale;

    return PointDistribution(
      points: List.unmodifiable(points),
      adjacentGaps: List.unmodifiable(gaps),
      medianGap: medianGap,
      medianPositiveGap: medianPositiveGap,
      typicalGap: typicalGap,
      rawMad: rawMad,
      iqr: iqr,
      robustScale: robustScale,
    );
  }

  static double median(Iterable<num> values) {
    final sorted = values.map((value) => value.toDouble()).toList()..sort();
    if (sorted.isEmpty) {
      return 0;
    }
    final middle = sorted.length ~/ 2;
    if (sorted.length.isOdd) {
      return sorted[middle];
    }
    return (sorted[middle - 1] + sorted[middle]) / 2;
  }

  // Tukey hinges with the median excluded for odd-length lists.
  static double interquartileRange(Iterable<num> values) {
    final sorted = values.map((value) => value.toDouble()).toList()..sort();
    if (sorted.length < 2) {
      return 0;
    }
    final middle = sorted.length ~/ 2;
    final lower = sorted.sublist(0, middle);
    final upper = sorted.length.isEven
        ? sorted.sublist(middle)
        : sorted.sublist(middle + 1);
    return median(upper) - median(lower);
  }

  static double robustZForGap(int gap, PointDistribution distribution) {
    return math.max(
      0,
      (gap - distribution.medianGap) / distribution.robustScale,
    );
  }

  static double gapRatioForGap(int gap, PointDistribution distribution) {
    return gap / distribution.typicalGap;
  }

  static double segmentationGainForSplit(List<int> points, int boundaryIndex) {
    final split = boundaryIndex;
    final upper = points.sublist(0, split);
    final lower = points.sublist(split);
    final totalDispersion = medianAbsoluteDeviation(points);
    final upperDispersion = medianAbsoluteDeviation(upper);
    final lowerDispersion = medianAbsoluteDeviation(lower);
    final weightedSegmentDispersion =
        (upper.length * upperDispersion + lower.length * lowerDispersion) /
        points.length;
    return (totalDispersion - weightedSegmentDispersion) /
        math.max(totalDispersion, DynamicTierParameters.minRobustScale);
  }

  static double medianAbsoluteDeviation(Iterable<num> values) {
    final source = values.toList(growable: false);
    if (source.isEmpty) {
      return 0;
    }
    final center = median(source);
    return median(source.map((value) => (value - center).abs()));
  }

  static double boundaryEvidenceScore({
    required double robustZ,
    required double gapRatio,
    required double segmentationGain,
  }) {
    final zComponent = _clamp(
      robustZ / DynamicTierParameters.zComponentSaturation,
    );
    final ratioComponent = _clamp(
      (gapRatio - DynamicTierParameters.gapRatioComponentOffset) /
          DynamicTierParameters.gapRatioComponentSpan,
    );
    final segComponent = _clamp(
      segmentationGain / DynamicTierParameters.segmentationGainSaturation,
    );
    return DynamicTierParameters.boundaryScoreScale *
        (DynamicTierParameters.boundaryScoreZWeight * zComponent +
            DynamicTierParameters.boundaryScoreRatioWeight * ratioComponent +
            DynamicTierParameters.boundaryScoreSegmentWeight * segComponent);
  }

  static BoundaryStrength boundaryStrengthForScore(double score) {
    if (score < DynamicTierParameters.boundaryScoreWeakMax) {
      return BoundaryStrength.weak;
    }
    if (score < DynamicTierParameters.boundaryScoreStrong) {
      return BoundaryStrength.moderate;
    }
    return BoundaryStrength.strong;
  }

  static bool isSpatiallyConfirmed({
    required bool isCandidate,
    required bool segmentationValid,
    required double score,
    required BoundaryStrength strength,
  }) {
    return isCandidate &&
        segmentationValid &&
        score >= DynamicTierParameters.boundaryScoreConfirm &&
        strength != BoundaryStrength.weak;
  }

  static List<TierPartitionBoundary> selectTierPartitionForTesting(
    List<DynamicTierInputStanding> orderedRows,
    DynamicTierInput input,
    List<ConfirmedStructuralBoundary> confirmed,
  ) {
    return _selectBestTierPartition(orderedRows, input, confirmed);
  }

  static BoundaryStabilityResult applyTemporalBoundaryStabilityForTesting({
    required List<BoundaryCandidate> candidates,
    required PreviousBoundaryState previousState,
    required String standingsSnapshotIdentity,
    required Set<TierWarning> warnings,
  }) {
    return _applyTemporalBoundaryStability(
      candidates,
      previousState,
      standingsSnapshotIdentity,
      warnings,
    );
  }

  static PpgBoundaryQualification qualifyWithPpg({
    required DynamicTierInputStanding upper,
    required DynamicTierInputStanding lower,
    required int rawGap,
    required double medianPlayed,
    required int playedSpread,
    required double rawBoundaryScore,
  }) {
    final playedDiff = (upper.played - lower.played).abs();
    final active =
        playedDiff >= DynamicTierParameters.ppgAdjacentPlayedDiffTrigger ||
        playedSpread >= DynamicTierParameters.ppgGlobalSpreadTrigger;
    if (!active) {
      return PpgBoundaryQualification(
        active: false,
        rejected: false,
        downgraded: false,
        rawBoundaryScore: rawBoundaryScore,
        adjustedBoundaryScore: rawBoundaryScore,
      );
    }

    final upperPpg = upper.points / upper.played;
    final lowerPpg = lower.points / lower.played;
    final ppgEquivalentGap = (upperPpg - lowerPpg).abs() * medianPlayed;
    final ppgRatio =
        ppgEquivalentGap /
        math.max(rawGap.toDouble(), DynamicTierParameters.minRobustScale);

    if (_lte(ppgRatio, DynamicTierParameters.ppgRejectRatio) &&
        rawBoundaryScore <
            DynamicTierParameters.ppgExtremeRawBreakSurvivalScore) {
      return PpgBoundaryQualification(
        active: true,
        rejected: true,
        downgraded: false,
        rawBoundaryScore: rawBoundaryScore,
        adjustedBoundaryScore: rawBoundaryScore,
        ppgEquivalentGap: ppgEquivalentGap,
        ppgRatio: ppgRatio,
      );
    }
    if (_lte(ppgRatio, DynamicTierParameters.ppgDowngradeRatio)) {
      return PpgBoundaryQualification(
        active: true,
        rejected: false,
        downgraded: true,
        rawBoundaryScore: rawBoundaryScore,
        adjustedBoundaryScore:
            rawBoundaryScore - DynamicTierParameters.ppgDowngradePoints,
        ppgEquivalentGap: ppgEquivalentGap,
        ppgRatio: ppgRatio,
      );
    }

    return PpgBoundaryQualification(
      active: true,
      rejected: false,
      downgraded: false,
      rawBoundaryScore: rawBoundaryScore,
      adjustedBoundaryScore: rawBoundaryScore,
      ppgEquivalentGap: ppgEquivalentGap,
      ppgRatio: ppgRatio,
    );
  }

  StructuralPairAssessment assessPair(
    ChampionshipTierSnapshot snapshot, {
    required int subjectTeamId,
    required int opponentTeamId,
  }) {
    final subject = snapshot.assignmentForTeam(subjectTeamId);
    final opponent = snapshot.assignmentForTeam(opponentTeamId);
    final ordinalGap = snapshot.ordinalTierGap(subjectTeamId, opponentTeamId);
    final structuralBoundaryGap = snapshot.structuralBoundaryGapByTeam(
      subjectTeamId,
      opponentTeamId,
    );
    final sameTier =
        subject != null &&
        opponent != null &&
        subject.assignedTier == opponent.assignedTier;

    return StructuralPairAssessment(
      ordinalTierGap: ordinalGap,
      structuralBoundaryGap: structuralBoundaryGap,
      structuralLevelGap: deriveStructuralLevelGap(
        snapshot,
        subjectTeamId: subjectTeamId,
        opponentTeamId: opponentTeamId,
      ),
      balancedHierarchy: deriveBalancedHierarchy(
        snapshot,
        teamAId: subjectTeamId,
        teamBId: opponentTeamId,
      ),
      sameTier: sameTier,
    );
  }

  StructuralLevelGapAssessment deriveStructuralLevelGap(
    ChampionshipTierSnapshot snapshot, {
    required int subjectTeamId,
    required int opponentTeamId,
  }) {
    final subject = snapshot.assignmentForTeam(subjectTeamId);
    final opponent = snapshot.assignmentForTeam(opponentTeamId);
    if (subject == null || opponent == null) {
      return const StructuralLevelGapAssessment(exists: false);
    }
    if (subject.officialRank >= opponent.officialRank) {
      return const StructuralLevelGapAssessment(exists: false);
    }
    final counted = snapshot.boundariesBetweenRanks(
      subject.officialRank,
      opponent.officialRank,
    );
    final structuralBoundaryGap = counted.length;
    final hasStrong = counted.any(
      (boundary) => boundary.strength == BoundaryStrength.strong,
    );
    if (structuralBoundaryGap < 1 ||
        (!hasStrong && structuralBoundaryGap < 2)) {
      return const StructuralLevelGapAssessment(exists: false);
    }
    return StructuralLevelGapAssessment(
      exists: true,
      strength: hasStrong && structuralBoundaryGap >= 2
          ? StructuralLevelGapStrength.strong
          : StructuralLevelGapStrength.moderate,
    );
  }

  BalancedHierarchyAssessment deriveBalancedHierarchy(
    ChampionshipTierSnapshot snapshot, {
    required int teamAId,
    required int teamBId,
  }) {
    final teamA = snapshot.assignmentForTeam(teamAId);
    final teamB = snapshot.assignmentForTeam(teamBId);
    final typicalGap = snapshot.pointDistribution?.typicalGap;
    if (teamA == null || teamB == null || typicalGap == null) {
      return const BalancedHierarchyAssessment(exists: false);
    }
    if (snapshot.structuralBoundaryGapByTeam(teamAId, teamBId) != 0) {
      return const BalancedHierarchyAssessment(exists: false);
    }
    final rankGap = (teamA.officialRank - teamB.officialRank).abs();
    final pointsGap = (teamA.points - teamB.points).abs();
    final relativeRankLimit = math.max(
      2,
      (DynamicTierParameters.balancedRankGapRatio * snapshot.teamCount).ceil(),
    );
    final relativePointsLimit = math.max(
      DynamicTierParameters.balancedPointsGapAbsoluteFloor,
      DynamicTierParameters.balancedPointsGapTypicalMultiplier * typicalGap,
    );
    return BalancedHierarchyAssessment(
      exists: rankGap <= relativeRankLimit && pointsGap <= relativePointsLimit,
    );
  }

  static double _clamp(double value) => value.clamp(0.0, 1.0);

  static bool _lte(double value, double threshold) {
    return value < threshold || (value - threshold).abs() < 0.000000000001;
  }

  static List<TierUnavailabilityReason> _validateInput(
    DynamicTierInput input,
    List<DynamicTierInputStanding> orderedRows,
  ) {
    final reasons = <TierUnavailabilityReason>{};
    final n = orderedRows.length;
    if (n == 0) {
      reasons.add(TierUnavailabilityReason.noStandings);
    }
    if (input.competitionFormat != CompetitionFormat.standardRoundRobin) {
      reasons.add(TierUnavailabilityReason.unsupportedCompetition);
    }
    if (n < DynamicTierParameters.supportedMinTeams ||
        n > DynamicTierParameters.supportedMaxTeams) {
      reasons.add(TierUnavailabilityReason.teamCountOutOfRange);
    }
    final seenRanks = <int>{};
    var previousPoints = orderedRows.isEmpty ? null : orderedRows.first.points;
    for (final row in orderedRows) {
      if (!seenRanks.add(row.officialRank)) {
        reasons.add(TierUnavailabilityReason.invalidStandings);
      }
      if (row.officialRank < 1 || row.officialRank > n) {
        reasons.add(TierUnavailabilityReason.invalidStandings);
      }
      if (previousPoints != null && row.points > previousPoints) {
        reasons.add(TierUnavailabilityReason.invalidStandings);
      }
      previousPoints = row.points;
      if (row.played < 0) {
        reasons.add(TierUnavailabilityReason.incompleteStandings);
      }
    }
    if (input.podiumAnchor.startRank < 1 ||
        input.relegationAnchor.endRank > n ||
        input.podiumAnchor.endRank >= input.relegationAnchor.startRank) {
      reasons.add(TierUnavailabilityReason.invalidStructuralMetadata);
    }
    return reasons.toList(growable: false);
  }

  static PpgDistributionContext _computePpgContext(
    List<DynamicTierInputStanding> rows,
  ) {
    final played = rows.map((row) => row.played).toList(growable: false);
    final values = rows
        .map((row) => row.played == 0 ? 0.0 : row.points / row.played)
        .toList(growable: false);
    final minPlayed = played.reduce(math.min);
    final maxPlayed = played.reduce(math.max);
    return PpgDistributionContext(
      values: List.unmodifiable(values),
      medianPlayed: median(played),
      minPlayed: minPlayed,
      maxPlayed: maxPlayed,
      playedSpread: maxPlayed - minPlayed,
    );
  }

  static bool _isImmature(
    DynamicTierInput input,
    PpgDistributionContext ppgContext,
  ) {
    final seasonProgress = input.seasonProgress;
    return ppgContext.medianPlayed <
            DynamicTierParameters.minMedianPlayedMature ||
        ppgContext.minPlayed < DynamicTierParameters.minMinPlayedMature ||
        (seasonProgress != null &&
            seasonProgress < DynamicTierParameters.minSeasonProgressMature) ||
        _hasSeverePlayedImbalance(ppgContext);
  }

  static bool _hasSeverePlayedImbalance(PpgDistributionContext ppgContext) {
    final severeThreshold = math.max(
      4,
      (DynamicTierParameters.maxPlayedSpreadUsableRatio *
              ppgContext.medianPlayed)
          .ceil(),
    );
    return ppgContext.playedSpread > severeThreshold;
  }

  static List<BoundaryCandidate> _buildBoundaryCandidates(
    DynamicTierInput input,
    List<DynamicTierInputStanding> rows,
    PointDistribution distribution,
    PpgDistributionContext ppgContext,
    Set<TierWarning> warnings,
  ) {
    final candidates = <BoundaryCandidate>[];
    for (
      var gapIndex = 0;
      gapIndex < distribution.adjacentGaps.length;
      gapIndex += 1
    ) {
      final boundaryIndex = gapIndex + 1;
      final rawGap = distribution.adjacentGaps[gapIndex];
      final robustZ = robustZForGap(rawGap, distribution);
      final gapRatio = gapRatioForGap(rawGap, distribution);
      final detected =
          rawGap >= DynamicTierParameters.minRawGapCandidate &&
          (robustZ >= DynamicTierParameters.candidateRobustZ ||
              gapRatio >= DynamicTierParameters.candidateGapRatio);
      final eligible =
          rawGap > 0 && !_insideMandatoryAnchor(input, boundaryIndex);
      if (!detected) {
        continue;
      }

      final segmentationGain = segmentationGainForSplit(
        distribution.points,
        boundaryIndex,
      );
      final segmentationValid =
          boundaryIndex >= DynamicTierParameters.segmentMinSizeDefault &&
          distribution.points.length - boundaryIndex >=
              DynamicTierParameters.segmentMinSizeDefault &&
          segmentationGain >= DynamicTierParameters.segmentationGainMin;
      final rawBoundaryScore = boundaryEvidenceScore(
        robustZ: robustZ,
        gapRatio: gapRatio,
        segmentationGain: segmentationGain,
      );

      if (!eligible) {
        warnings.add(TierWarning.anchorInternalOutlier);
        candidates.add(
          _candidate(
            rows: rows,
            boundaryIndex: boundaryIndex,
            rawGap: rawGap,
            eligible: false,
            detected: true,
            robustZ: robustZ,
            gapRatio: gapRatio,
            segmentationGain: segmentationGain,
            segmentationValid: segmentationValid,
            rawBoundaryScore: rawBoundaryScore,
            ppgQualification: PpgBoundaryQualification(
              active: false,
              rejected: false,
              downgraded: false,
              rawBoundaryScore: rawBoundaryScore,
              adjustedBoundaryScore: rawBoundaryScore,
            ),
            temporalStatus: BoundaryTemporalStatus.candidate,
          ),
        );
        continue;
      }

      final ppgQualification = qualifyWithPpg(
        upper: rows[gapIndex],
        lower: rows[gapIndex + 1],
        rawGap: rawGap,
        medianPlayed: ppgContext.medianPlayed,
        playedSpread: ppgContext.playedSpread,
        rawBoundaryScore: rawBoundaryScore,
      );
      if (ppgQualification.active) {
        warnings.add(TierWarning.ppgQualificationUsed);
      }
      if (ppgQualification.rejected) {
        warnings.add(TierWarning.ppgBoundaryRejected);
      }
      if (ppgQualification.downgraded) {
        warnings.add(TierWarning.ppgBoundaryDowngraded);
      }

      candidates.add(
        _candidate(
          rows: rows,
          boundaryIndex: boundaryIndex,
          rawGap: rawGap,
          eligible: true,
          detected: true,
          robustZ: robustZ,
          gapRatio: gapRatio,
          segmentationGain: segmentationGain,
          segmentationValid: segmentationValid,
          rawBoundaryScore: rawBoundaryScore,
          ppgQualification: ppgQualification,
          temporalStatus: BoundaryTemporalStatus.candidate,
        ),
      );
    }
    return candidates;
  }

  static BoundaryCandidate _candidate({
    required List<DynamicTierInputStanding> rows,
    required int boundaryIndex,
    required int rawGap,
    required bool eligible,
    required bool detected,
    required double robustZ,
    required double gapRatio,
    required double segmentationGain,
    required bool segmentationValid,
    required double rawBoundaryScore,
    required PpgBoundaryQualification ppgQualification,
    required BoundaryTemporalStatus temporalStatus,
  }) {
    final score = ppgQualification.adjustedBoundaryScore;
    final strength = boundaryStrengthForScore(score);
    return BoundaryCandidate(
      boundaryIndex: boundaryIndex,
      upperRank: rows[boundaryIndex - 1].officialRank,
      lowerRank: rows[boundaryIndex].officialRank,
      rawGap: rawGap,
      eligible: eligible,
      detected: detected,
      robustZ: robustZ,
      gapRatio: gapRatio,
      segmentationGain: segmentationGain,
      segmentationValid: segmentationValid,
      rawBoundaryScore: rawBoundaryScore,
      adjustedBoundaryScore: score,
      strength: strength,
      ppgQualification: ppgQualification,
      spatialConfirmed: isSpatiallyConfirmed(
        isCandidate: eligible && detected && !ppgQualification.rejected,
        segmentationValid: segmentationValid,
        score: score,
        strength: strength,
      ),
      temporalStatus: temporalStatus,
    );
  }

  static bool _insideMandatoryAnchor(
    DynamicTierInput input,
    int boundaryIndex,
  ) {
    final upperRank = boundaryIndex;
    final lowerRank = boundaryIndex + 1;
    final podium = input.podiumAnchor;
    final relegation = input.relegationAnchor;
    return (podium.containsRank(upperRank) && podium.containsRank(lowerRank)) ||
        (relegation.containsRank(upperRank) &&
            relegation.containsRank(lowerRank));
  }

  static BoundaryStabilityResult _applyTemporalBoundaryStability(
    List<BoundaryCandidate> candidates,
    PreviousBoundaryState previousState,
    String standingsSnapshotIdentity,
    Set<TierWarning> warnings,
  ) {
    final updatedCandidates = [...candidates];
    final confirmed = <ConfirmedStructuralBoundary>[];
    final spatialConfirmed = updatedCandidates
        .where((candidate) => candidate.spatialConfirmed)
        .toList(growable: false);

    final usedSpatial = <int>{};
    for (final previous in previousState.confirmedBoundaries) {
      final compatibleSpatial = _bestCompatibleCandidate(
        previous.boundaryIndex,
        spatialConfirmed,
        usedSpatial,
      );
      if (compatibleSpatial != null) {
        usedSpatial.add(compatibleSpatial.boundaryIndex);
        confirmed.add(
          _confirmedBoundary(compatibleSpatial, standingsSnapshotIdentity),
        );
        _replaceTemporalStatus(
          updatedCandidates,
          compatibleSpatial.boundaryIndex,
          BoundaryTemporalStatus.confirmed,
        );
        continue;
      }

      final compatibleCandidate = _bestCompatibleCandidate(
        previous.boundaryIndex,
        updatedCandidates
            .where(
              (candidate) =>
                  candidate.eligible &&
                  candidate.detected &&
                  !candidate.ppgQualification.rejected &&
                  candidate.adjustedBoundaryScore >=
                      DynamicTierParameters.boundaryScoreWeakMax,
            )
            .toList(growable: false),
        usedSpatial,
      );
      if (compatibleCandidate != null &&
          previous.persistenceAge <
              DynamicTierParameters.temporalPersistenceSnapshots) {
        usedSpatial.add(compatibleCandidate.boundaryIndex);
        warnings.add(TierWarning.boundaryPersisted);
        confirmed.add(
          _confirmedBoundary(
            compatibleCandidate,
            standingsSnapshotIdentity,
            persisted: true,
            persistenceAge: previous.persistenceAge + 1,
          ),
        );
        _replaceTemporalStatus(
          updatedCandidates,
          compatibleCandidate.boundaryIndex,
          BoundaryTemporalStatus.persisted,
        );
      }
    }

    for (final candidate in spatialConfirmed) {
      if (usedSpatial.contains(candidate.boundaryIndex)) {
        continue;
      }
      if (candidate.strength == BoundaryStrength.strong) {
        confirmed.add(_confirmedBoundary(candidate, standingsSnapshotIdentity));
        _replaceTemporalStatus(
          updatedCandidates,
          candidate.boundaryIndex,
          BoundaryTemporalStatus.confirmed,
        );
        continue;
      }

      final previousPending = _bestCompatiblePending(
        candidate.boundaryIndex,
        previousState.pendingBoundaries,
        previousState.standingsSnapshotIdentity,
        standingsSnapshotIdentity,
      );
      if (candidate.strength == BoundaryStrength.moderate &&
          previousPending != null) {
        confirmed.add(_confirmedBoundary(candidate, standingsSnapshotIdentity));
        _replaceTemporalStatus(
          updatedCandidates,
          candidate.boundaryIndex,
          BoundaryTemporalStatus.confirmed,
        );
      } else {
        warnings.add(TierWarning.pendingModerateBoundary);
        _replaceTemporalStatus(
          updatedCandidates,
          candidate.boundaryIndex,
          BoundaryTemporalStatus.pending,
        );
      }
    }

    confirmed.sort((a, b) => a.boundaryIndex.compareTo(b.boundaryIndex));
    return BoundaryStabilityResult(
      candidates: List.unmodifiable(updatedCandidates),
      confirmed: List.unmodifiable(confirmed),
    );
  }

  static BoundaryCandidate? _bestCompatibleCandidate(
    int boundaryIndex,
    List<BoundaryCandidate> candidates,
    Set<int> used,
  ) {
    BoundaryCandidate? best;
    for (final candidate in candidates) {
      if (used.contains(candidate.boundaryIndex) ||
          !_compatibleBoundaryIndex(boundaryIndex, candidate.boundaryIndex)) {
        continue;
      }
      if (best == null ||
          candidate.adjustedBoundaryScore > best.adjustedBoundaryScore ||
          (candidate.adjustedBoundaryScore == best.adjustedBoundaryScore &&
              candidate.boundaryIndex < best.boundaryIndex)) {
        best = candidate;
      }
    }
    return best;
  }

  static PendingBoundaryState? _bestCompatiblePending(
    int boundaryIndex,
    List<PendingBoundaryState> pending,
    String previousSnapshotIdentity,
    String currentSnapshotIdentity,
  ) {
    if (previousSnapshotIdentity == currentSnapshotIdentity) {
      return null;
    }
    PendingBoundaryState? best;
    for (final candidate in pending) {
      if (candidate.standingsSnapshotIdentity == currentSnapshotIdentity ||
          !_compatibleBoundaryIndex(boundaryIndex, candidate.boundaryIndex)) {
        continue;
      }
      if (best == null ||
          candidate.score > best.score ||
          (candidate.score == best.score &&
              candidate.boundaryIndex < best.boundaryIndex)) {
        best = candidate;
      }
    }
    return best;
  }

  static bool _compatibleBoundaryIndex(int previousIndex, int currentIndex) {
    return (previousIndex - currentIndex).abs() <=
        DynamicTierParameters.temporalCompatiblePositionDrift;
  }

  static ConfirmedStructuralBoundary _confirmedBoundary(
    BoundaryCandidate candidate,
    String standingsSnapshotIdentity, {
    bool persisted = false,
    int persistenceAge = 0,
  }) {
    return ConfirmedStructuralBoundary(
      boundaryIndex: candidate.boundaryIndex,
      upperRank: candidate.upperRank,
      lowerRank: candidate.lowerRank,
      rawGap: candidate.rawGap,
      score: candidate.adjustedBoundaryScore,
      strength: candidate.strength,
      standingsSnapshotIdentity: standingsSnapshotIdentity,
      persisted: persisted,
      persistenceAge: persistenceAge,
    );
  }

  static void _replaceTemporalStatus(
    List<BoundaryCandidate> candidates,
    int boundaryIndex,
    BoundaryTemporalStatus status,
  ) {
    final index = candidates.indexWhere(
      (candidate) => candidate.boundaryIndex == boundaryIndex,
    );
    if (index == -1) {
      return;
    }
    final candidate = candidates[index];
    candidates[index] = BoundaryCandidate(
      boundaryIndex: candidate.boundaryIndex,
      upperRank: candidate.upperRank,
      lowerRank: candidate.lowerRank,
      rawGap: candidate.rawGap,
      eligible: candidate.eligible,
      detected: candidate.detected,
      robustZ: candidate.robustZ,
      gapRatio: candidate.gapRatio,
      segmentationGain: candidate.segmentationGain,
      segmentationValid: candidate.segmentationValid,
      rawBoundaryScore: candidate.rawBoundaryScore,
      adjustedBoundaryScore: candidate.adjustedBoundaryScore,
      strength: candidate.strength,
      ppgQualification: candidate.ppgQualification,
      spatialConfirmed: candidate.spatialConfirmed,
      temporalStatus: status,
    );
  }

  static List<TierPartitionBoundary> _selectBestTierPartition(
    List<DynamicTierInputStanding> rows,
    DynamicTierInput input,
    List<ConfirmedStructuralBoundary> confirmed,
  ) {
    final middleStart = input.podiumAnchor.endRank + 1;
    final middleEnd = input.relegationAnchor.startRank - 1;
    if (middleStart > middleEnd) {
      return const [];
    }
    final middlePoints = rows
        .where(
          (row) =>
              row.officialRank >= middleStart && row.officialRank <= middleEnd,
        )
        .map((row) => row.points)
        .toList(growable: false);
    final middleBoundaries = confirmed
        .where(
          (boundary) =>
              boundary.boundaryIndex >= middleStart &&
              boundary.boundaryIndex < middleEnd,
        )
        .toList(growable: false);

    var best = const _PartitionEvaluation(
      selected: [],
      globalSegmentationGain: 0,
      minSegmentSize: 0,
      scoreSum: 0,
    );

    final combinations = _boundaryCombinations(middleBoundaries);
    for (final selected in combinations) {
      final evaluation = _evaluatePartition(
        middlePoints,
        middleStart,
        selected,
      );
      if (evaluation == null) {
        continue;
      }
      if (_isBetterPartition(evaluation, best)) {
        best = evaluation;
      }
    }

    return best.selected
        .map(
          (boundary) => TierPartitionBoundary(
            boundaryIndex: boundary.boundaryIndex,
            score: boundary.score,
            strength: boundary.strength,
          ),
        )
        .toList(growable: false);
  }

  static List<List<ConfirmedStructuralBoundary>> _boundaryCombinations(
    List<ConfirmedStructuralBoundary> boundaries,
  ) {
    final sorted = [...boundaries]
      ..sort((a, b) => a.boundaryIndex.compareTo(b.boundaryIndex));
    final combinations = <List<ConfirmedStructuralBoundary>>[const []];
    for (final boundary in sorted) {
      combinations.add([boundary]);
    }
    for (var i = 0; i < sorted.length; i += 1) {
      for (var j = i + 1; j < sorted.length; j += 1) {
        combinations.add([sorted[i], sorted[j]]);
      }
    }
    return combinations;
  }

  static _PartitionEvaluation? _evaluatePartition(
    List<int> middlePoints,
    int middleStartRank,
    List<ConfirmedStructuralBoundary> selected,
  ) {
    final sortedSelected = [...selected]
      ..sort((a, b) => a.boundaryIndex.compareTo(b.boundaryIndex));
    final splitOffsets = sortedSelected
        .map((boundary) => boundary.boundaryIndex - middleStartRank + 1)
        .toList(growable: false);
    final segments = <List<int>>[];
    var start = 0;
    for (final splitOffset in splitOffsets) {
      segments.add(middlePoints.sublist(start, splitOffset));
      start = splitOffset;
    }
    segments.add(middlePoints.sublist(start));

    if (segments.any(
      (segment) => segment.length < DynamicTierParameters.segmentMinSizeDefault,
    )) {
      return null;
    }

    final totalDispersion = medianAbsoluteDeviation(middlePoints);
    final weightedWithinSegmentMad =
        segments.fold<double>(
          0,
          (sum, segment) =>
              sum + segment.length * medianAbsoluteDeviation(segment),
        ) /
        middlePoints.length;
    final gain =
        (totalDispersion - weightedWithinSegmentMad) /
        math.max(totalDispersion, DynamicTierParameters.minRobustScale);
    final minSegmentSize = segments
        .map((segment) => segment.length)
        .reduce(math.min);
    final scoreSum = sortedSelected.fold<double>(
      0,
      (sum, boundary) => sum + boundary.score,
    );
    return _PartitionEvaluation(
      selected: sortedSelected,
      globalSegmentationGain: gain,
      minSegmentSize: minSegmentSize,
      scoreSum: scoreSum,
    );
  }

  static bool _isBetterPartition(
    _PartitionEvaluation candidate,
    _PartitionEvaluation current,
  ) {
    final gainDiff =
        candidate.globalSegmentationGain - current.globalSegmentationGain;
    if (gainDiff.abs() > DynamicTierParameters.tierPartitionGainEpsilon) {
      return gainDiff > 0;
    }
    if (candidate.selected.length != current.selected.length) {
      return candidate.selected.length < current.selected.length;
    }
    if (candidate.minSegmentSize != current.minSegmentSize) {
      return candidate.minSegmentSize > current.minSegmentSize;
    }
    if (candidate.scoreSum != current.scoreSum) {
      return candidate.scoreSum > current.scoreSum;
    }
    return _lexicographicBoundaryIndexes(
          candidate.selected,
        ).compareTo(_lexicographicBoundaryIndexes(current.selected)) <
        0;
  }

  static String _lexicographicBoundaryIndexes(
    List<ConfirmedStructuralBoundary> boundaries,
  ) {
    return boundaries
        .map((boundary) => boundary.boundaryIndex.toString().padLeft(2, '0'))
        .join(',');
  }

  static List<TeamTierAssignment> _assignTierLabels(
    List<DynamicTierInputStanding> rows,
    DynamicTierInput input,
    List<TierPartitionBoundary> partitionBoundaries,
  ) {
    final assignments = <TeamTierAssignment>[];
    final sortedPartitions = [...partitionBoundaries]
      ..sort((a, b) => a.boundaryIndex.compareTo(b.boundaryIndex));
    for (final row in rows) {
      final tier = _tierForRank(row.officialRank, input, sortedPartitions);
      assignments.add(
        TeamTierAssignment(
          teamId: row.teamId,
          teamName: row.teamName,
          officialRank: row.officialRank,
          points: row.points,
          played: row.played,
          pointsPerGame: row.points / row.played,
          assignedTier: tier,
          group: row.group,
          description: row.description,
        ),
      );
    }
    return List.unmodifiable(assignments);
  }

  static TierLabel _tierForRank(
    int rank,
    DynamicTierInput input,
    List<TierPartitionBoundary> partitionBoundaries,
  ) {
    if (input.podiumAnchor.containsRank(rank)) {
      return TierLabel.tier1Podium;
    }
    if (input.relegationAnchor.containsRank(rank)) {
      return TierLabel.tier5Relegation;
    }
    if (partitionBoundaries.isEmpty) {
      return TierLabel.tier3MiddleChampionship;
    }
    if (partitionBoundaries.length == 1) {
      return rank <= partitionBoundaries.single.boundaryIndex
          ? TierLabel.tier2UpperChampionship
          : TierLabel.tier4LowerChampionship;
    }
    if (rank <= partitionBoundaries[0].boundaryIndex) {
      return TierLabel.tier2UpperChampionship;
    }
    if (rank <= partitionBoundaries[1].boundaryIndex) {
      return TierLabel.tier3MiddleChampionship;
    }
    return TierLabel.tier4LowerChampionship;
  }

  static ChampionshipTierSnapshot _snapshot(
    DynamicTierInput input, {
    required TierSystemStatus status,
    required TierMaturity maturity,
    PointDistribution? pointDistribution,
    PpgDistributionContext? ppgDistribution,
    Iterable<BoundaryCandidate> boundaryCandidates = const [],
    Iterable<ConfirmedStructuralBoundary> confirmedStructuralBoundaries =
        const [],
    Iterable<TierPartitionBoundary> tierPartitionBoundaries = const [],
    Iterable<TierLabel> tierPresence = const [],
    Iterable<TeamTierAssignment> teamAssignments = const [],
    Iterable<TierWarning> warnings = const [],
    Iterable<TierUnavailabilityReason> unavailabilityReasons = const [],
  }) {
    return ChampionshipTierSnapshot(
      competitionId: input.competitionId,
      season: input.season,
      analysisAsOf: input.analysisAsOf,
      tierSystemVersion: tierSystemVersion,
      standingsSnapshotIdentity: input.standingsSnapshotIdentity,
      status: status,
      maturity: maturity,
      teamCount: input.standingsRows.length,
      pointDistribution: pointDistribution,
      ppgDistribution: ppgDistribution,
      boundaryCandidates: List.unmodifiable(boundaryCandidates),
      confirmedStructuralBoundaries: List.unmodifiable(
        confirmedStructuralBoundaries,
      ),
      tierPartitionBoundaries: List.unmodifiable(tierPartitionBoundaries),
      tierPresence: Set.unmodifiable(tierPresence),
      teamAssignments: List.unmodifiable(teamAssignments),
      warnings: List.unmodifiable(warnings),
      unavailabilityReasons: List.unmodifiable(unavailabilityReasons),
    );
  }
}

class _PartitionEvaluation {
  const _PartitionEvaluation({
    required this.selected,
    required this.globalSegmentationGain,
    required this.minSegmentSize,
    required this.scoreSum,
  });

  final List<ConfirmedStructuralBoundary> selected;
  final double globalSegmentationGain;
  final int minSegmentSize;
  final double scoreSum;
}
