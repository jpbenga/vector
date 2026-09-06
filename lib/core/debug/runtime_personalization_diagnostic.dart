import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../features/onboarding/domain/compiled_decision_profile.dart';
import '../../features/onboarding/domain/decision_profile.dart';

/// Temporary, debug-only observability for the authenticated profile and the
/// "Pour moi" funnel. It intentionally contains technical IDs only.
class RuntimePersonalizationDiagnostic {
  RuntimePersonalizationDiagnostic._();

  static final instance = RuntimePersonalizationDiagnostic._();

  final List<String> _events = [];
  String _latestProfileTrace = 'PROFILE_TRACE unavailable';
  String _latestForMeTrace = 'FOR_ME_TRACE unavailable';
  int _personalizationRun = 0;
  List<Map<String, Object?>> _profileRows = const [];

  bool get isEnabled => kDebugMode;

  String hashFor(String value) => _hash(value);

  void recordLifecycle(String event, {Map<String, Object?> fields = const {}}) {
    if (!isEnabled) return;
    _record('LIFECYCLE: $event${_formatFields(fields)}');
  }

  void recordProfile({
    required String source,
    required String? sessionUserId,
    required DecisionProfile? persistedProfile,
    required DecisionProfile effectiveProfile,
    required CompiledDecisionProfile compiledProfile,
    required bool fallbackApplied,
    required String fallbackReason,
  }) {
    if (!isEnabled) return;

    final persisted =
        persistedProfile ??
        const DecisionProfile(onboardingVersion: '2.0', answers: []);
    final persistedCompetitions = persisted.optionIdsFor('competitions');
    final persistedReadings = persisted.optionIdsFor('analysis_elements');
    final configuredReadings = persisted.optionIdsFor('readings');
    final persistedScenarios = persisted.optionIdsFor('opportunity_profiles');
    final persistedMarkets = persisted.optionIdsFor('markets');
    final effectiveCompetitions = _enabledIds(
      compiledProfile.competitions,
      (value) => value.enabled,
    );
    final effectiveScenarios = _enabledIds(
      compiledProfile.opportunityProfiles,
      (value) => value.enabled,
    );
    final effectiveReadings = _enabledIds(
      compiledProfile.readings,
      (value) => value.enabled,
    );
    final effectiveMarkets = _enabledIds(
      compiledProfile.markets,
      (value) => value.enabled,
    );
    final trace = <String>[
      'PROFILE_TRACE',
      'SESSION_USER_ID: ${sessionUserId ?? 'none'}',
      'PROFILE_SOURCE: $source',
      'RAW_DECISION_PROFILE: ${_json(effectiveProfile.toJson())}',
      'persistedCompetitions = ${_json(persistedCompetitions)}',
      'defaultCompetitions = []',
      'effectiveCompetitions = ${_json(effectiveCompetitions)}',
      'legacyPersistedReadings = ${_json(persistedReadings)}',
      'persistedReadings = ${_json(configuredReadings)}',
      'defaultReadings = []',
      'effectiveReadings = ${_json(effectiveReadings)}',
      'persistedScenarios = ${_json(persistedScenarios)}',
      'defaultScenarios = []',
      'effectiveScenarios = ${_json(effectiveScenarios)}',
      'persistedMarkets = ${_json(persistedMarkets)}',
      'defaultMarkets = []',
      'effectiveMarkets = ${_json(effectiveMarkets)}',
      'COMPILED_COMPETITIONS: ${_json(effectiveCompetitions)}',
      'COMPILED_READINGS: ${_json(effectiveReadings)}',
      'COMPILED_SCENARIOS: ${_json(effectiveScenarios)}',
      'COMPILED_MARKETS: ${_json(effectiveMarkets)}',
      'IS_COMPLETED: ${compiledProfile.isCompleted}',
      'PROFILE_HASH: ${_hash(_json(effectiveProfile.toJson()))}',
      'FALLBACK_APPLIED: $fallbackApplied',
      'REASON: $fallbackReason',
      'PROFILE_ROWS: ${_json(_profileRows)}',
      'AMBIGUOUS_ACTIVE_PROFILES: ${_profileRows.where((row) => row['is_active'] == true).length > 1}',
    ].join('\n');
    _latestProfileTrace = trace;
    _record(trace);
  }

  void recordProfileRows(List<Map<String, Object?>> rows) {
    if (!isEnabled) return;
    _profileRows = List.unmodifiable(rows);
    final activeRows = rows.where((row) => row['is_active'] == true).length;
    if (activeRows > 1) {
      _record('PROFILE_AMBIGUITY: $activeRows active profiles found');
    }
  }

  void recordForMe({
    required DateTime selectedDate,
    required String profileHash,
    required String matchIntelligenceHash,
    required int matchesOnDate,
    required int matchesInFollowedCompetitions,
    required int matchesMatchingAttention,
    required int matchesMatchingScenarios,
    required int matchesMatchingMarkets,
    required List<Map<String, Object?>> matches,
  }) {
    if (!isEnabled) return;
    _personalizationRun += 1;
    final included = matches.where((match) => match['included'] == true).length;
    final lines = <String>[
      'FOR_ME_TRACE',
      'PERSONALIZATION_RUN #$_personalizationRun',
      'profile hash: $profileHash',
      'match intelligence hash/version: $matchIntelligenceHash',
      'SELECTED_DATE: ${selectedDate.toIso8601String()}',
      'MATCHES_ON_DATE: $matchesOnDate',
      'MATCHES_IN_FOLLOWED_COMPETITIONS: $matchesInFollowedCompetitions',
      'MATCHES_MATCHING_ATTENTION: $matchesMatchingAttention',
      'MATCHES_MATCHING_SCENARIOS: $matchesMatchingScenarios',
      'MATCHES_MATCHING_MARKETS: $matchesMatchingMarkets',
      'FINAL_FOR_ME: $included',
      for (final match in matches)
        [
          'MATCH_TRACE',
          'matchId: ${match['matchId']}',
          'competitionId: ${match['competitionId']}',
          'attentionMatches: ${match['attentionMatches']}',
          'scenarioMatches: ${match['scenarioMatches']}',
          'marketMatches: ${match['marketMatches']}',
          'included=${match['included']}',
        ].join('\n'),
    ];
    _latestForMeTrace = lines.join('\n');
    _record(_latestForMeTrace);
  }

  String report() {
    return [
      'LECTOR RUNTIME PERSONALIZATION DIAGNOSTIC',
      _latestProfileTrace,
      _latestForMeTrace,
      'EVENT_ORDER:',
      ..._events,
    ].join('\n\n');
  }

  void _record(String value) {
    final timestamped = '${DateTime.now().toIso8601String()} $value';
    _events.add(timestamped);
    if (_events.length > 60) {
      _events.removeRange(0, _events.length - 60);
    }
    debugPrint(timestamped);
  }

  String _formatFields(Map<String, Object?> fields) =>
      fields.isEmpty ? '' : ' ${_json(fields)}';

  String _json(Object? value) => jsonEncode(value);

  String _hash(String value) {
    var hash = 0x811c9dc5;
    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash.toRadixString(16);
  }

  List<String> _enabledIds<T>(
    Map<String, T> preferences,
    bool Function(T value) isEnabled,
  ) {
    return [
      for (final entry in preferences.entries)
        if (isEnabled(entry.value)) entry.key,
    ]..sort();
  }
}
