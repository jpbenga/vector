import 'football_reading.dart';

class ReadingRule {
  const ReadingRule({
    required this.id,
    required this.minimumSampleSize,
    required this.freshnessLimit,
    required this.metricRequirements,
    required this.thresholds,
    required this.contradictionReadingIds,
    required this.message,
    required this.sourcePaths,
  });

  final String id;
  final int minimumSampleSize;
  final Duration freshnessLimit;
  final List<String> metricRequirements;
  final Map<String, double> thresholds;
  final List<String> contradictionReadingIds;
  final String message;
  final List<String> sourcePaths;
}

class FootballReadingRules {
  const FootballReadingRules._();

  static const preMatchFreshness = Duration(hours: 36);
  static const rollingWindow = 5;

  static const rankingSuperiority = ReadingRule(
    id: 'ranking_superiority',
    minimumSampleSize: 5,
    freshnessLimit: preMatchFreshness,
    metricRequirements: ['rank', 'points', 'played'],
    thresholds: {'rankGap': 3, 'pointsGap': 5},
    contradictionReadingIds: ['false_favorite', 'conflicting_signals'],
    message: 'Hiérarchie favorable au classement.',
    sourcePaths: [
      'standings[].rank',
      'standings[].points',
      'standings[].all.played',
    ],
  );

  static const structuralLevelGap = ReadingRule(
    id: 'structural_level_gap',
    minimumSampleSize: 8,
    freshnessLimit: preMatchFreshness,
    metricRequirements: ['rank', 'points'],
    thresholds: {'rankGap': 5, 'pointsGap': 8},
    contradictionReadingIds: ['false_favorite', 'conflicting_signals'],
    message: 'Écart structurel entre les équipes.',
    sourcePaths: ['standings[].rank', 'standings[].points'],
  );

  static const form = ReadingRule(
    id: 'form',
    minimumSampleSize: rollingWindow,
    freshnessLimit: preMatchFreshness,
    metricRequirements: ['form'],
    thresholds: {'positivePoints': 10, 'negativePoints': 4},
    contradictionReadingIds: ['misleading_result'],
    message: 'Dynamique récente sur cinq matchs.',
    sourcePaths: ['standings[].form', 'teams/statistics.form'],
  );

  static const homeAway = ReadingRule(
    id: 'home_away',
    minimumSampleSize: 5,
    freshnessLimit: preMatchFreshness,
    metricRequirements: ['playedHome', 'playedAway', 'wins', 'losses'],
    thresholds: {'strongRate': 0.60, 'weakLossRate': 0.45},
    contradictionReadingIds: ['conflicting_signals'],
    message: 'Split domicile/extérieur significatif.',
    sourcePaths: [
      'teams/statistics.fixtures.played.home',
      'teams/statistics.fixtures.wins.home',
      'teams/statistics.fixtures.loses.away',
    ],
  );

  static const attack = ReadingRule(
    id: 'attack',
    minimumSampleSize: 8,
    freshnessLimit: preMatchFreshness,
    metricRequirements: ['goalsForAverage'],
    thresholds: {'prolific': 1.70, 'difficulty': 0.90},
    contradictionReadingIds: ['offensive_underperformance'],
    message: 'Production offensive mesurable.',
    sourcePaths: ['teams/statistics.goals.for.average.total'],
  );

  static const defense = ReadingRule(
    id: 'defense',
    minimumSampleSize: 8,
    freshnessLimit: preMatchFreshness,
    metricRequirements: ['goalsAgainstAverage', 'cleanSheet'],
    thresholds: {'solid': 1.00, 'fragile': 1.60, 'cleanSheetRate': 0.35},
    contradictionReadingIds: ['high_xg_conceded'],
    message: 'Solidité défensive mesurable.',
    sourcePaths: [
      'teams/statistics.goals.against.average.total',
      'teams/statistics.clean_sheet.total',
    ],
  );

  static const rhythm = ReadingRule(
    id: 'goal_profile',
    minimumSampleSize: 8,
    freshnessLimit: preMatchFreshness,
    metricRequirements: ['goalsForAverage', 'goalsAgainstAverage'],
    thresholds: {'open': 2.80, 'closed': 2.10},
    contradictionReadingIds: ['conflicting_signals'],
    message: 'Profil de buts de la rencontre.',
    sourcePaths: [
      'teams/statistics.goals.for.average.total',
      'teams/statistics.goals.against.average.total',
    ],
  );

  static const expectedGoals = ReadingRule(
    id: 'expected_goals',
    minimumSampleSize: 3,
    freshnessLimit: Duration(days: 7),
    metricRequirements: ['rollingXgFor5', 'rollingXgAgainst5'],
    thresholds: {
      'highCreation': 1.50,
      'lowCreation': 0.90,
      'highConceded': 1.50,
      'divergence': 1.50,
      'strongDifference': 0.45,
    },
    contradictionReadingIds: ['misleading_result', 'conflicting_signals'],
    message: 'Production xG historique, jamais xG futuriste.',
    sourcePaths: ['fixtures/statistics[].statistics[].type=expected_goals'],
  );

  static const insufficientData = ReadingRule(
    id: 'insufficient_data',
    minimumSampleSize: 0,
    freshnessLimit: Duration.zero,
    metricRequirements: [],
    thresholds: {},
    contradictionReadingIds: [],
    message: 'Données insuffisantes pour soutenir une lecture.',
    sourcePaths: [],
  );

  static const values = [
    rankingSuperiority,
    structuralLevelGap,
    form,
    homeAway,
    attack,
    defense,
    rhythm,
    expectedGoals,
    insufficientData,
  ];

  static ReadingRule byId(String id) {
    return values.firstWhere(
      (rule) => rule.id == id,
      orElse: () => insufficientData,
    );
  }
}

class ReadingStrengthResolver {
  const ReadingStrengthResolver._();

  static ReadingStrength fromGap(double value, double moderate, double strong) {
    if (value >= strong) {
      return ReadingStrength.strong;
    }
    if (value >= moderate) {
      return ReadingStrength.moderate;
    }

    return ReadingStrength.weak;
  }
}
