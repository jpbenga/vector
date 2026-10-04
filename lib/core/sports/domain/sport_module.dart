import 'sport.dart';

enum SportModuleStage { active, preparation, planned }

enum SportCapability {
  fixtures,
  standings,
  recentForm,
  readings,
  scenarios,
  teamRadar,
  playerRadar,
  eventTimeline,
  liveScores,
  outcomeBilan,
}

class SportReadingDefinition {
  const SportReadingDefinition({
    required this.id,
    required this.label,
    required this.description,
    required this.condition,
    required this.example,
    this.implemented = true,
  });

  final String id;
  final String label;
  final String description;
  final String condition;
  final String example;
  final bool implemented;
}

class SportScenarioDefinition {
  const SportScenarioDefinition({
    required this.id,
    required this.label,
    required this.description,
    required this.requiredReadingIds,
  });

  final String id;
  final String label;
  final String description;
  final List<String> requiredReadingIds;
}

/// Configuration describes availability and rules; algorithms stay in modules.
class SportModuleDefinition {
  const SportModuleDefinition({
    required this.sport,
    required this.stage,
    required this.capabilities,
    this.readings = const [],
    this.scenarios = const [],
  });

  final SportId sport;
  final SportModuleStage stage;
  final Set<SportCapability> capabilities;
  final List<SportReadingDefinition> readings;
  final List<SportScenarioDefinition> scenarios;
}

enum SportReadingStatus { detected, notDetected, insufficientData }

class SportReadingAssessment {
  const SportReadingAssessment({
    required this.id,
    required this.subject,
    required this.match,
    required this.status,
    required this.explanation,
    required this.sampleSize,
    required this.asOf,
    this.evidence = const {},
  });

  final String id;
  final SportEntityId subject;
  final SportEntityId match;
  final SportReadingStatus status;
  final String explanation;
  final int sampleSize;
  final DateTime asOf;
  final Map<String, Object> evidence;
}
