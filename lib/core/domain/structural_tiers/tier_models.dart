import 'tier_parameters.dart';

enum TierLabel {
  tier1Podium,
  tier2UpperChampionship,
  tier3MiddleChampionship,
  tier4LowerChampionship,
  tier5Relegation,
}

extension TierLabelSemantics on TierLabel {
  int get ordinal {
    return switch (this) {
      TierLabel.tier1Podium => 1,
      TierLabel.tier2UpperChampionship => 2,
      TierLabel.tier3MiddleChampionship => 3,
      TierLabel.tier4LowerChampionship => 4,
      TierLabel.tier5Relegation => 5,
    };
  }

  String get code {
    return switch (this) {
      TierLabel.tier1Podium => 'TIER_1',
      TierLabel.tier2UpperChampionship => 'TIER_2',
      TierLabel.tier3MiddleChampionship => 'TIER_3',
      TierLabel.tier4LowerChampionship => 'TIER_4',
      TierLabel.tier5Relegation => 'TIER_5',
    };
  }

  String get technicalLabel {
    return switch (this) {
      TierLabel.tier1Podium => 'PODIUM',
      TierLabel.tier2UpperChampionship => 'UPPER_CHAMPIONSHIP',
      TierLabel.tier3MiddleChampionship => 'MIDDLE_CHAMPIONSHIP',
      TierLabel.tier4LowerChampionship => 'LOWER_CHAMPIONSHIP',
      TierLabel.tier5Relegation => 'RELEGATION',
    };
  }
}

enum TierMaturity { mature, immature, unavailable }

enum TierSystemStatus { mature, immature, unavailable }

enum BoundaryStrength { weak, moderate, strong }

enum BoundaryTemporalStatus { candidate, pending, confirmed, persisted }

enum TierWarning {
  playedImbalance,
  ppgQualificationUsed,
  ppgBoundaryRejected,
  ppgBoundaryDowngraded,
  anchorInternalOutlier,
  pendingModerateBoundary,
  boundaryPersisted,
}

enum TierUnavailabilityReason {
  unsupportedCompetition,
  noStandings,
  teamCountOutOfRange,
  incompleteStandings,
  invalidStandings,
  invalidStructuralMetadata,
  missingAnchorMetadata,
}

enum StructuralLevelGapStrength { moderate, strong }

class PointDistribution {
  const PointDistribution({
    required this.points,
    required this.adjacentGaps,
    required this.medianGap,
    required this.medianPositiveGap,
    required this.typicalGap,
    required this.rawMad,
    required this.iqr,
    required this.robustScale,
  });

  final List<int> points;
  final List<int> adjacentGaps;
  final double medianGap;
  final double medianPositiveGap;
  final double typicalGap;
  final double rawMad;
  final double iqr;
  final double robustScale;
}

class PpgDistributionContext {
  const PpgDistributionContext({
    required this.values,
    required this.medianPlayed,
    required this.minPlayed,
    required this.maxPlayed,
    required this.playedSpread,
  });

  final List<double> values;
  final double medianPlayed;
  final int minPlayed;
  final int maxPlayed;
  final int playedSpread;
}

class PpgBoundaryQualification {
  const PpgBoundaryQualification({
    required this.active,
    required this.rejected,
    required this.downgraded,
    required this.rawBoundaryScore,
    required this.adjustedBoundaryScore,
    this.ppgEquivalentGap,
    this.ppgRatio,
  });

  final bool active;
  final bool rejected;
  final bool downgraded;
  final double rawBoundaryScore;
  final double adjustedBoundaryScore;
  final double? ppgEquivalentGap;
  final double? ppgRatio;
}

class BoundaryCandidate {
  const BoundaryCandidate({
    required this.boundaryIndex,
    required this.upperRank,
    required this.lowerRank,
    required this.rawGap,
    required this.eligible,
    required this.detected,
    required this.robustZ,
    required this.gapRatio,
    required this.segmentationGain,
    required this.segmentationValid,
    required this.rawBoundaryScore,
    required this.adjustedBoundaryScore,
    required this.strength,
    required this.ppgQualification,
    required this.spatialConfirmed,
    required this.temporalStatus,
  });

  final int boundaryIndex;
  final int upperRank;
  final int lowerRank;
  final int rawGap;
  final bool eligible;
  final bool detected;
  final double robustZ;
  final double gapRatio;
  final double segmentationGain;
  final bool segmentationValid;
  final double rawBoundaryScore;
  final double adjustedBoundaryScore;
  final BoundaryStrength strength;
  final PpgBoundaryQualification ppgQualification;
  final bool spatialConfirmed;
  final BoundaryTemporalStatus temporalStatus;
}

class ConfirmedStructuralBoundary {
  const ConfirmedStructuralBoundary({
    required this.boundaryIndex,
    required this.upperRank,
    required this.lowerRank,
    required this.rawGap,
    required this.score,
    required this.strength,
    required this.standingsSnapshotIdentity,
    this.persisted = false,
    this.persistenceAge = 0,
  });

  final int boundaryIndex;
  final int upperRank;
  final int lowerRank;
  final int rawGap;
  final double score;
  final BoundaryStrength strength;
  final String standingsSnapshotIdentity;
  final bool persisted;
  final int persistenceAge;
}

class TierPartitionBoundary {
  const TierPartitionBoundary({
    required this.boundaryIndex,
    required this.score,
    required this.strength,
  });

  final int boundaryIndex;
  final double score;
  final BoundaryStrength strength;
}

class TeamTierAssignment {
  const TeamTierAssignment({
    required this.teamId,
    required this.teamName,
    required this.officialRank,
    required this.points,
    required this.played,
    required this.pointsPerGame,
    required this.assignedTier,
    this.group,
    this.description,
  });

  final int teamId;
  final String teamName;
  final int officialRank;
  final int points;
  final int played;
  final double pointsPerGame;
  final TierLabel assignedTier;
  final String? group;
  final String? description;
}

class ChampionshipTierSnapshot {
  const ChampionshipTierSnapshot({
    required this.competitionId,
    required this.season,
    required this.analysisAsOf,
    required this.tierSystemVersion,
    required this.standingsSnapshotIdentity,
    required this.status,
    required this.maturity,
    required this.teamCount,
    required this.pointDistribution,
    required this.ppgDistribution,
    required this.boundaryCandidates,
    required this.confirmedStructuralBoundaries,
    required this.tierPartitionBoundaries,
    required this.tierPresence,
    required this.teamAssignments,
    required this.warnings,
    required this.unavailabilityReasons,
  });

  final String competitionId;
  final int season;
  final DateTime analysisAsOf;
  final String tierSystemVersion;
  final String standingsSnapshotIdentity;
  final TierSystemStatus status;
  final TierMaturity maturity;
  final int teamCount;
  final PointDistribution? pointDistribution;
  final PpgDistributionContext? ppgDistribution;
  final List<BoundaryCandidate> boundaryCandidates;
  final List<ConfirmedStructuralBoundary> confirmedStructuralBoundaries;
  final List<TierPartitionBoundary> tierPartitionBoundaries;
  final Set<TierLabel> tierPresence;
  final List<TeamTierAssignment> teamAssignments;
  final List<TierWarning> warnings;
  final List<TierUnavailabilityReason> unavailabilityReasons;

  TeamTierAssignment? assignmentForTeam(int teamId) {
    for (final assignment in teamAssignments) {
      if (assignment.teamId == teamId) {
        return assignment;
      }
    }
    return null;
  }

  int? ordinalTierGap(int teamAId, int teamBId) {
    final a = assignmentForTeam(teamAId);
    final b = assignmentForTeam(teamBId);
    if (a == null || b == null) {
      return null;
    }
    return (a.assignedTier.ordinal - b.assignedTier.ordinal).abs();
  }

  int structuralBoundaryGapByTeam(int teamAId, int teamBId) {
    final a = assignmentForTeam(teamAId);
    final b = assignmentForTeam(teamBId);
    if (a == null || b == null) {
      return 0;
    }
    return structuralBoundaryGapByRank(a.officialRank, b.officialRank);
  }

  int structuralBoundaryGapByRank(int rankA, int rankB) {
    final lowerRank = rankA < rankB ? rankA : rankB;
    final upperRank = rankA > rankB ? rankA : rankB;
    return confirmedStructuralBoundaries
        .where(
          (boundary) =>
              boundary.boundaryIndex >= lowerRank &&
              boundary.boundaryIndex < upperRank,
        )
        .length;
  }

  List<ConfirmedStructuralBoundary> boundariesBetweenRanks(
    int rankA,
    int rankB,
  ) {
    final lowerRank = rankA < rankB ? rankA : rankB;
    final upperRank = rankA > rankB ? rankA : rankB;
    return confirmedStructuralBoundaries
        .where(
          (boundary) =>
              boundary.boundaryIndex >= lowerRank &&
              boundary.boundaryIndex < upperRank,
        )
        .toList(growable: false);
  }

  PreviousBoundaryState toPreviousBoundaryState() {
    return PreviousBoundaryState(
      standingsSnapshotIdentity: standingsSnapshotIdentity,
      confirmedBoundaries: confirmedStructuralBoundaries,
      pendingBoundaries: boundaryCandidates
          .where(
            (candidate) =>
                candidate.temporalStatus == BoundaryTemporalStatus.pending,
          )
          .map(
            (candidate) => PendingBoundaryState(
              boundaryIndex: candidate.boundaryIndex,
              score: candidate.adjustedBoundaryScore,
              strength: candidate.strength,
              standingsSnapshotIdentity: standingsSnapshotIdentity,
            ),
          )
          .toList(growable: false),
    );
  }
}

class PreviousBoundaryState {
  const PreviousBoundaryState({
    required this.standingsSnapshotIdentity,
    this.confirmedBoundaries = const [],
    this.pendingBoundaries = const [],
  });

  static const empty = PreviousBoundaryState(standingsSnapshotIdentity: '');

  final String standingsSnapshotIdentity;
  final List<ConfirmedStructuralBoundary> confirmedBoundaries;
  final List<PendingBoundaryState> pendingBoundaries;
}

class BoundaryStabilityResult {
  const BoundaryStabilityResult({
    required this.candidates,
    required this.confirmed,
  });

  final List<BoundaryCandidate> candidates;
  final List<ConfirmedStructuralBoundary> confirmed;
}

class PendingBoundaryState {
  const PendingBoundaryState({
    required this.boundaryIndex,
    required this.score,
    required this.strength,
    required this.standingsSnapshotIdentity,
  });

  final int boundaryIndex;
  final double score;
  final BoundaryStrength strength;
  final String standingsSnapshotIdentity;
}

class StructuralLevelGapAssessment {
  const StructuralLevelGapAssessment({required this.exists, this.strength});

  final bool exists;
  final StructuralLevelGapStrength? strength;
}

class BalancedHierarchyAssessment {
  const BalancedHierarchyAssessment({required this.exists});

  final bool exists;
}

class StructuralPairAssessment {
  const StructuralPairAssessment({
    required this.ordinalTierGap,
    required this.structuralBoundaryGap,
    required this.structuralLevelGap,
    required this.balancedHierarchy,
    required this.sameTier,
  });

  final int? ordinalTierGap;
  final int structuralBoundaryGap;
  final StructuralLevelGapAssessment structuralLevelGap;
  final BalancedHierarchyAssessment balancedHierarchy;
  final bool sameTier;
}

class MatchStructuralRelation {
  const MatchStructuralRelation({
    required this.competitionId,
    required this.season,
    required this.analysisAsOf,
    required this.tierSystemVersion,
    required this.standingsSnapshotIdentity,
    required this.homeTeamId,
    required this.awayTeamId,
    required this.homeTeamTier,
    required this.awayTeamTier,
    required this.sameTier,
    required this.ordinalTierGap,
    required this.structuralBoundaryGap,
    required this.confirmedBoundariesBetweenTeams,
    required this.tierMaturity,
    required this.tierStatus,
    required this.championshipTeamCount,
    required this.typicalGap,
    required this.homeOfficialRank,
    required this.awayOfficialRank,
    required this.homePoints,
    required this.awayPoints,
    required this.homeStructuralLevelGap,
    required this.awayStructuralLevelGap,
    required this.balancedHierarchy,
    required this.warnings,
  });

  factory MatchStructuralRelation.fromSnapshot({
    required ChampionshipTierSnapshot snapshot,
    required int homeTeamId,
    required int awayTeamId,
  }) {
    final home = snapshot.assignmentForTeam(homeTeamId);
    final away = snapshot.assignmentForTeam(awayTeamId);
    final boundaries = home == null || away == null
        ? const <ConfirmedStructuralBoundary>[]
        : snapshot.boundariesBetweenRanks(home.officialRank, away.officialRank);
    final sameTier =
        home != null && away != null && home.assignedTier == away.assignedTier;
    final homeStructuralLevelGap = _structuralLevelGapFor(
      subject: home,
      opponent: away,
      countedBoundaries: boundaries,
    );
    final awayStructuralLevelGap = _structuralLevelGapFor(
      subject: away,
      opponent: home,
      countedBoundaries: boundaries,
    );

    return MatchStructuralRelation(
      competitionId: snapshot.competitionId,
      season: snapshot.season,
      analysisAsOf: snapshot.analysisAsOf,
      tierSystemVersion: snapshot.tierSystemVersion,
      standingsSnapshotIdentity: snapshot.standingsSnapshotIdentity,
      homeTeamId: homeTeamId,
      awayTeamId: awayTeamId,
      homeTeamTier: home?.assignedTier,
      awayTeamTier: away?.assignedTier,
      sameTier: sameTier,
      ordinalTierGap: snapshot.ordinalTierGap(homeTeamId, awayTeamId),
      structuralBoundaryGap: boundaries.length,
      confirmedBoundariesBetweenTeams: List.unmodifiable(boundaries),
      tierMaturity: snapshot.maturity,
      tierStatus: snapshot.status,
      championshipTeamCount: snapshot.teamCount,
      typicalGap: snapshot.pointDistribution?.typicalGap,
      homeOfficialRank: home?.officialRank,
      awayOfficialRank: away?.officialRank,
      homePoints: home?.points,
      awayPoints: away?.points,
      homeStructuralLevelGap: homeStructuralLevelGap,
      awayStructuralLevelGap: awayStructuralLevelGap,
      balancedHierarchy: _balancedHierarchyFor(home, away, snapshot),
      warnings: snapshot.warnings,
    );
  }

  final String competitionId;
  final int season;
  final DateTime analysisAsOf;
  final String tierSystemVersion;
  final String standingsSnapshotIdentity;
  final int homeTeamId;
  final int awayTeamId;
  final TierLabel? homeTeamTier;
  final TierLabel? awayTeamTier;
  final bool sameTier;
  final int? ordinalTierGap;
  final int structuralBoundaryGap;
  final List<ConfirmedStructuralBoundary> confirmedBoundariesBetweenTeams;
  final TierMaturity tierMaturity;
  final TierSystemStatus tierStatus;
  final int championshipTeamCount;
  final double? typicalGap;
  final int? homeOfficialRank;
  final int? awayOfficialRank;
  final int? homePoints;
  final int? awayPoints;
  final StructuralLevelGapAssessment homeStructuralLevelGap;
  final StructuralLevelGapAssessment awayStructuralLevelGap;
  final BalancedHierarchyAssessment balancedHierarchy;
  final List<TierWarning> warnings;

  StructuralLevelGapAssessment structuralLevelGapFor(
    ReadingStructuralSide side,
  ) {
    return switch (side) {
      ReadingStructuralSide.home => homeStructuralLevelGap,
      ReadingStructuralSide.away => awayStructuralLevelGap,
    };
  }

  static StructuralLevelGapAssessment _structuralLevelGapFor({
    required TeamTierAssignment? subject,
    required TeamTierAssignment? opponent,
    required List<ConfirmedStructuralBoundary> countedBoundaries,
  }) {
    if (subject == null || opponent == null) {
      return const StructuralLevelGapAssessment(exists: false);
    }
    if (subject.officialRank >= opponent.officialRank) {
      return const StructuralLevelGapAssessment(exists: false);
    }
    final boundaryCount = countedBoundaries.length;
    final hasStrong = countedBoundaries.any(
      (boundary) => boundary.strength == BoundaryStrength.strong,
    );
    if (boundaryCount < 1 || (!hasStrong && boundaryCount < 2)) {
      return const StructuralLevelGapAssessment(exists: false);
    }
    return StructuralLevelGapAssessment(
      exists: true,
      strength: hasStrong && boundaryCount >= 2
          ? StructuralLevelGapStrength.strong
          : StructuralLevelGapStrength.moderate,
    );
  }

  static BalancedHierarchyAssessment _balancedHierarchyFor(
    TeamTierAssignment? home,
    TeamTierAssignment? away,
    ChampionshipTierSnapshot snapshot,
  ) {
    final typicalGap = snapshot.pointDistribution?.typicalGap;
    if (home == null || away == null || typicalGap == null) {
      return const BalancedHierarchyAssessment(exists: false);
    }
    if (snapshot.structuralBoundaryGapByTeam(home.teamId, away.teamId) != 0) {
      return const BalancedHierarchyAssessment(exists: false);
    }
    final rankGap = (home.officialRank - away.officialRank).abs();
    final pointsGap = (home.points - away.points).abs();
    final computedRankLimit =
        (DynamicTierParameters.balancedRankGapRatio * snapshot.teamCount)
            .ceil();
    final relativeRankLimit = computedRankLimit > 2 ? computedRankLimit : 2;
    final computedPointsLimit =
        DynamicTierParameters.balancedPointsGapTypicalMultiplier * typicalGap;
    final relativePointsLimit =
        computedPointsLimit >
            DynamicTierParameters.balancedPointsGapAbsoluteFloor
        ? computedPointsLimit
        : DynamicTierParameters.balancedPointsGapAbsoluteFloor.toDouble();
    return BalancedHierarchyAssessment(
      exists: rankGap <= relativeRankLimit && pointsGap <= relativePointsLimit,
    );
  }
}

enum ReadingStructuralSide { home, away }
