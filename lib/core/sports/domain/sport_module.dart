import 'sport.dart';
import 'sport_policy.dart';

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

class SportMarketDefinition {
  const SportMarketDefinition({
    required this.id,
    required this.label,
    required this.description,
  });
  final String id, label, description;
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
    this.markets = const [],
    this.participantOrder = SportParticipantOrder.homeAway,
    this.dataPolicy = const SportDataPolicy(),
    this.provider,
    this.scenarios = const [],
  });

  final SportId sport;
  final SportParticipantOrder participantOrder;
  final SportDataPolicy dataPolicy;
  final SportProviderPolicy? provider;
  final SportModuleStage stage;
  final Set<SportCapability> capabilities;
  final List<SportReadingDefinition> readings;
  final List<SportMarketDefinition> markets;
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

/// Context types and algorithms remain discipline specific. Shared consumers
/// receive explainable assessments, never sport-specific provider payloads.
abstract interface class SportReadingEngine<Context> {
  SportId get sport;
  String get rulesVersion;
  List<SportReadingAssessment> analyze(Context context);
}
