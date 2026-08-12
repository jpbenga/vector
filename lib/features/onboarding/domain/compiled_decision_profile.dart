import 'decision_profile_catalogs.dart';

class CompetitionPreference {
  const CompetitionPreference({
    required this.id,
    required this.apiFootballLeagueId,
    required this.name,
    required this.enabled,
    this.legacyIds = const [],
  });

  final String id;
  final int apiFootballLeagueId;
  final String name;
  final bool enabled;
  final List<String> legacyIds;
}

class MarketPreference {
  const MarketPreference({
    required this.id,
    required this.enabled,
    this.sourceOptionId,
  });

  final String id;
  final bool enabled;
  final String? sourceOptionId;
}

class MatchTypePreference {
  const MatchTypePreference({required this.id, required this.enabled});

  final String id;
  final bool enabled;
}

class ProfileCompatibility {
  const ProfileCompatibility({
    this.migratedFromSchemaVersion,
    this.ignoredLegacyQuestionIds = const [],
  });

  final int? migratedFromSchemaVersion;
  final List<String> ignoredLegacyQuestionIds;
}

class CompiledDecisionProfile {
  const CompiledDecisionProfile({
    required this.onboardingVersion,
    required this.profileSchemaVersion,
    required this.userId,
    required this.configurationState,
    required this.competitions,
    required this.markets,
    required this.matchTypes,
    required this.compatibility,
  });

  static const currentSchemaVersion = 2;

  final String onboardingVersion;
  final int profileSchemaVersion;
  final String? userId;
  final ProfileConfigurationState configurationState;
  final Map<String, CompetitionPreference> competitions;
  final Map<String, MarketPreference> markets;
  final Map<String, MatchTypePreference> matchTypes;
  final ProfileCompatibility compatibility;

  Map<String, MatchTypePreference> get opportunityProfiles => matchTypes;

  bool get isCompleted =>
      configurationState == ProfileConfigurationState.completed;

  bool isCompetitionEnabled(String competitionId) {
    if (!isCompleted) {
      return false;
    }

    return competitions[competitionId]?.enabled ?? false;
  }

  MarketPreference? enabledMarket(String marketId) {
    if (!isCompleted) {
      return null;
    }

    final preference = markets[marketId];

    if (preference == null || !preference.enabled) {
      return null;
    }

    return preference;
  }

  bool isThesisAllowed(String thesisId) {
    if (!isCompleted) {
      return false;
    }

    final profileId = OpportunityProfileCatalog.profileIdForThesis(thesisId);
    if (profileId == null) {
      return true;
    }

    return OpportunityProfileCatalog.profileIdsForThesis(
      thesisId,
    ).any(isOpportunityProfileEnabled);
  }

  bool isMatchTypeEnabled(String matchTypeId) {
    return isOpportunityProfileEnabled(matchTypeId);
  }

  bool isOpportunityProfileEnabled(String profileId) {
    if (!isCompleted) {
      return false;
    }

    return opportunityProfiles[profileId]?.enabled ?? false;
  }
}
