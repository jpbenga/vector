import '../../../core/sports/domain/sport.dart';
import '../../../core/sports/domain/sport_module.dart';
import '../../hockey/domain/hockey_module.dart';

/// The legacy football pipeline is the active football module. Migrate its
/// adapters incrementally rather than copying it into each new discipline.
abstract final class SportModuleRegistry {
  static const modules = [
    SportModuleDefinition(
      sport: SportId.football,
      stage: SportModuleStage.active,
      capabilities: {
        SportCapability.fixtures,
        SportCapability.standings,
        SportCapability.recentForm,
        SportCapability.readings,
        SportCapability.scenarios,
        SportCapability.teamRadar,
        SportCapability.playerRadar,
        SportCapability.eventTimeline,
        SportCapability.liveScores,
        SportCapability.outcomeBilan,
      },
    ),
    HockeyModule.definition,
    SportModuleDefinition(
      sport: SportId.basketball,
      stage: SportModuleStage.planned,
      capabilities: {},
    ),
    SportModuleDefinition(
      sport: SportId.baseball,
      stage: SportModuleStage.planned,
      capabilities: {},
    ),
    SportModuleDefinition(
      sport: SportId.americanFootball,
      stage: SportModuleStage.planned,
      capabilities: {},
    ),
  ];

  static SportModuleDefinition forSport(SportId sport) =>
      modules.firstWhere((module) => module.sport == sport);
}
