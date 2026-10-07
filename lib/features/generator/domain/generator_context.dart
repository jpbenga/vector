import 'dart:math';

import '../../onboarding/domain/compiled_decision_profile.dart';
import '../../../core/sports/domain/sport_reading_preferences.dart';

String generatorUuid() {
  final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

String generatorDay(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

class GeneratorContext {
  GeneratorContext({
    required this.origin,
    required this.preferences,
    this.budget = 100,
    this.discovery = true,
    this.timezone = 'Europe/Paris',
  });
  final String origin, timezone;
  final bool discovery;
  final double budget;
  final Map<String, Map<String, List<String>>> preferences;
  int count(String key) =>
      preferences.values.fold(0, (sum, p) => sum + (p[key]?.length ?? 0));
  List<String> get sports => preferences.keys.toList();
  Map<String, Object?> toJson() => {
    'origin': origin,
    'scope': discovery ? 'discovery' : 'strict',
    'timezone': timezone,
    'budget': budget,
    'preferences': preferences,
  };
  GeneratorContext copyWith({double? budget, bool? discovery}) =>
      GeneratorContext(
        origin: origin,
        preferences: preferences,
        budget: budget ?? this.budget,
        discovery: discovery ?? this.discovery,
        timezone: timezone,
      );

  static Map<String, List<String>> football(CompiledDecisionProfile profile) =>
      {
        'competitions': [
          for (final p in profile.competitions.values)
            if (p.enabled) p.apiFootballLeagueId.toString(),
        ],
        'readings': [
          for (final p in profile.readings.values)
            if (p.enabled) p.id,
        ],
        'markets': [
          for (final p in profile.markets.values)
            if (p.enabled) p.id,
        ],
        'scenarios': [
          for (final p in profile.opportunityProfiles.values)
            if (p.enabled) p.id,
        ],
      };
  static Map<String, List<String>> hockey(
    SportReadingPreferences preferences,
  ) => {
    'competitions': preferences.competitionKeys.toList(),
    'readings': preferences.readingIds.toList(),
    // No permanent hockey market preference or quote catalogue exists yet.
    // The generator must not silently authorize markets on the user's behalf.
    'markets': <String>[],
  };
}

Map<String, dynamic> generatorMap(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : {};
List<Map<String, dynamic>> generatorRows(Object? value) =>
    value is List ? value.map(generatorMap).toList() : [];

class GeneratorConversation {
  GeneratorConversation(Map<String, dynamic> value)
    : json = Map.unmodifiable(value) {
    if (json['id'] is! String || json['revision'] is! int) {
      throw const FormatException('Conversation invalide');
    }
  }
  final Map<String, dynamic> json;
  String get id => json['id'] as String;
  int get revision => json['revision'] as int;
  List<Map<String, dynamic>> get tickets => generatorRows(json['tickets']);
  List<Map<String, dynamic>> get pending => generatorRows(json['pending']);
  List<Map<String, dynamic>> get messages => generatorRows(json['messages']);
  bool get saved => json['saved'] == true;
}
