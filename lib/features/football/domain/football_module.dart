import '../../../core/sports/domain/sport.dart';
import '../../../core/sports/domain/sport_module.dart';
import '../../../core/sports/domain/sport_policy.dart';

/// The existing football engines and published feed remain the authority.
abstract final class FootballModule {
  static const definition = SportModuleDefinition(
    sport: SportId.football,
    stage: SportModuleStage.active,
    provider: SportProviderPolicy(
      provider: 'api-football',
      quotaKey: 'api-football',
      dailyLimit: 75000,
      minuteLimit: 280,
    ),
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
  );
}
