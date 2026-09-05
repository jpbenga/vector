class DynamicTierParameters {
  const DynamicTierParameters._();

  static const supportedMinTeams = 10;
  static const supportedMaxTeams = 24;

  static const minMedianPlayedMature = 6;
  static const minMinPlayedMature = 4;
  static const minSeasonProgressMature = 0.25;
  static const maxPlayedSpreadBalanced = 2;
  static const maxPlayedSpreadUsableRatio = 0.33;

  static const ppgAdjacentPlayedDiffTrigger = 2;
  static const ppgGlobalSpreadTrigger = 3;

  static const minRawGapCandidate = 3;
  static const candidateRobustZ = 2.5;
  static const candidateGapRatio = 3.0;

  static const madNormalizationFactor = 1.4826;
  static const iqrNormalizationFactor = 1.349;
  static const minRobustScale = 1.0;
  static const madZeroMedianPositiveFactor = 0.5;

  static const segmentationGainMin = 0.20;

  static const boundaryScoreScale = 100.0;
  static const boundaryScoreZWeight = 0.45;
  static const boundaryScoreRatioWeight = 0.30;
  static const boundaryScoreSegmentWeight = 0.25;

  static const zComponentSaturation = 4.0;
  static const gapRatioComponentOffset = 1.0;
  static const gapRatioComponentSpan = 3.0;
  static const segmentationGainSaturation = 0.35;

  static const boundaryScoreConfirm = 60.0;
  static const boundaryScoreStrong = 78.0;
  static const boundaryScoreWeakMax = 50.0;

  static const segmentMinSizeDefault = 2;

  static const maxTierPartitionBoundaries = 2;
  static const tierPartitionGainEpsilon = 0.02;

  static const ppgRejectRatio = 0.35;
  static const ppgDowngradeRatio = 0.65;
  static const ppgDowngradePoints = 15.0;
  static const ppgExtremeRawBreakSurvivalScore = 85.0;

  static const temporalConfirmModerateSnapshots = 2;
  static const temporalPersistenceSnapshots = 1;
  static const temporalCompatiblePositionDrift = 1;

  static const balancedRankGapRatio = 0.15;
  static const balancedPointsGapTypicalMultiplier = 2.0;
  static const balancedPointsGapAbsoluteFloor = 4.0;
}
