import 'compiled_decision_profile.dart';
import 'decision_profile.dart';
import 'decision_profile_catalogs.dart';
import 'onboarding_answer.dart';

class ProfileCompiler {
  const ProfileCompiler();

  static const legacyQuestionIds = {
    'analysis_elements',
    'final_decision_influences',
    'market_minimum_odds',
    'analysis_time',
    'betting_frequency',
    'match_volume_preference',
    'betting_approaches',
    'odds_importance',
    'pick_type',
    'ticket_selection_counts',
    'ticket_odds_ranges',
    'ticket_types',
  };

  CompiledDecisionProfile compile(DecisionProfile profile) {
    final competitions = _competitionPreferences(profile);
    final markets = _marketPreferences(profile);
    final opportunityProfiles = _opportunityProfilePreferences(profile);
    final state = _configurationState(
      profile: profile,
      competitions: competitions,
      markets: markets,
      opportunityProfiles: opportunityProfiles,
    );
    final ignoredLegacyQuestionIds = _ignoredLegacyQuestionIds(profile);

    return CompiledDecisionProfile(
      onboardingVersion: profile.onboardingVersion,
      profileSchemaVersion: CompiledDecisionProfile.currentSchemaVersion,
      userId: null,
      configurationState: state,
      competitions: competitions,
      markets: markets,
      matchTypes: opportunityProfiles,
      compatibility: ProfileCompatibility(
        migratedFromSchemaVersion: _migratedFromSchemaVersion(
          profile,
          ignoredLegacyQuestionIds,
        ),
        ignoredLegacyQuestionIds: ignoredLegacyQuestionIds,
      ),
    );
  }

  Map<String, CompetitionPreference> _competitionPreferences(
    DecisionProfile profile,
  ) {
    final selectedIds = _answerOptionIds(
      profile,
      'competitions',
    ).map(CompetitionCatalog.resolveId).whereType<String>().toSet();

    return {
      for (final definition in CompetitionCatalog.values)
        definition.id: CompetitionPreference(
          id: definition.id,
          apiFootballLeagueId: definition.apiFootballLeagueId,
          name: definition.name,
          enabled: selectedIds.contains(definition.id),
          legacyIds: definition.legacyIds,
        ),
    };
  }

  Map<String, MarketPreference> _marketPreferences(DecisionProfile profile) {
    final selectedIds = _answerOptionIds(profile, 'markets').toSet();

    return {
      for (final definition in MarketCatalog.values)
        definition.id: MarketPreference(
          id: definition.id,
          enabled:
              selectedIds.contains(definition.id) ||
              definition.sourceOptionIds.any(selectedIds.contains),
          sourceOptionId: definition.sourceOptionIds.first,
        ),
    };
  }

  Map<String, MatchTypePreference> _opportunityProfilePreferences(
    DecisionProfile profile,
  ) {
    final selectedIds = {
      ..._answerOptionIds(profile, 'opportunity_profiles'),
      ..._answerOptionIds(profile, 'match_types'),
    };

    return {
      for (final definition in OpportunityProfileCatalog.values)
        definition.id: MatchTypePreference(
          id: definition.id,
          enabled: selectedIds.contains(definition.id),
        ),
    };
  }

  ProfileConfigurationState _configurationState({
    required DecisionProfile profile,
    required Map<String, CompetitionPreference> competitions,
    required Map<String, MarketPreference> markets,
    required Map<String, MatchTypePreference> opportunityProfiles,
  }) {
    if (profile.answers.isEmpty) {
      return ProfileConfigurationState.notStarted;
    }

    final hasCompetition = competitions.values.any(
      (preference) => preference.enabled,
    );
    final hasMarket = markets.values.any((preference) => preference.enabled);
    final hasOpportunityProfile = opportunityProfiles.values.any(
      (preference) => preference.enabled,
    );

    if (hasCompetition && hasMarket && hasOpportunityProfile) {
      return ProfileConfigurationState.completed;
    }

    return ProfileConfigurationState.inProgress;
  }

  List<String> _ignoredLegacyQuestionIds(DecisionProfile profile) {
    return [
      for (final answer in profile.answers)
        if (legacyQuestionIds.contains(answer.questionId)) answer.questionId,
    ];
  }

  int? _migratedFromSchemaVersion(
    DecisionProfile profile,
    List<String> ignoredLegacyQuestionIds,
  ) {
    if (profile.onboardingVersion.startsWith('1.') ||
        ignoredLegacyQuestionIds.isNotEmpty) {
      return 1;
    }

    return null;
  }

  List<String> _answerOptionIds(DecisionProfile profile, String questionId) {
    final answer = _answerFor(profile, questionId);

    return answer?.orderedOptionIds ?? const [];
  }

  OnboardingAnswer? _answerFor(DecisionProfile profile, String questionId) {
    for (final answer in profile.answers) {
      if (answer.questionId == questionId) {
        return answer;
      }
    }

    return null;
  }
}
