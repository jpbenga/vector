/// Competition rules must be selected explicitly by the provider adapter.
/// NHL rules are never a fallback for an unknown hockey championship.
class HockeyPointsRules {
  const HockeyPointsRules({
    required this.regulationWin,
    required this.overtimeWin,
    required this.shootoutWin,
    required this.overtimeLoss,
    required this.shootoutLoss,
    this.regulationLoss = 0,
  });

  static const nhlRegularSeason = HockeyPointsRules(
    regulationWin: 2,
    overtimeWin: 2,
    shootoutWin: 2,
    overtimeLoss: 1,
    shootoutLoss: 1,
  );

  static const threePointRegularSeason = HockeyPointsRules(
    regulationWin: 3,
    overtimeWin: 2,
    shootoutWin: 2,
    overtimeLoss: 1,
    shootoutLoss: 1,
  );

  final int regulationWin;
  final int overtimeWin;
  final int shootoutWin;
  final int regulationLoss;
  final int overtimeLoss;
  final int shootoutLoss;

  int points(HockeyResult result) => switch (result) {
    HockeyResult.regulationWin => regulationWin,
    HockeyResult.overtimeWin => overtimeWin,
    HockeyResult.shootoutWin => shootoutWin,
    HockeyResult.regulationLoss => regulationLoss,
    HockeyResult.overtimeLoss => overtimeLoss,
    HockeyResult.shootoutLoss => shootoutLoss,
  };

  int get maximumPointsPerGame =>
      [regulationWin, overtimeWin, shootoutWin].reduce((a, b) => a > b ? a : b);
}

enum HockeyResult {
  regulationWin,
  overtimeWin,
  shootoutWin,
  regulationLoss,
  overtimeLoss,
  shootoutLoss;

  bool get isWin => switch (this) {
    regulationWin || overtimeWin || shootoutWin => true,
    _ => false,
  };
}

/// Initial, versioned analytical hypotheses, not sporting regulations.
/// Calibrate and approve these thresholds against real hockey data later.
class HockeyReadingPolicy {
  const HockeyReadingPolicy({
    this.version = 'hockey-readings-venue-momentum-v4',
    this.formWindow = 5,
    this.minimumStandingGames = 5,
    this.formPercentageGap = .20,
    this.consecutiveWins = 3,
    this.formGapPoints = 9,
  });

  final String version;
  final int formWindow;
  final int minimumStandingGames;
  final double formPercentageGap;
  final int consecutiveWins;
  final int formGapPoints;
}
