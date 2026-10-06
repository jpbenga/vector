import '../../domain/lector_victory_series.dart';
import 'sport.dart';

/// Explicit opt-in. Keys belong to one discipline; nothing is enabled by default.
class SportReadingPreferences {
  SportReadingPreferences({
    required this.sport,
    Iterable<String> competitionKeys = const [],
    Iterable<String> readingIds = const [],
  }) : competitionKeys = Set.unmodifiable(competitionKeys),
       readingIds = Set.unmodifiable(readingIds.map(canonicalVenueReadingId));

  final SportId sport;
  final Set<String> competitionKeys, readingIds;
  bool get isConfigured => competitionKeys.isNotEmpty && readingIds.isNotEmpty;
  bool follows(SportEntityId competition) =>
      competition.sport == sport && competitionKeys.contains(competition.key);

  Map<String, Object> toJson() => {
    'version': 1,
    'sport': sport.key,
    'competitions': competitionKeys.toList()..sort(),
    'readings': readingIds.toList()..sort(),
  };

  factory SportReadingPreferences.fromJson(
    Map<String, dynamic> json,
    SportId sport,
  ) {
    if (json['version'] != 1 || json['sport'] != sport.key) {
      throw const FormatException(
        'Preferences belong to another sport/version.',
      );
    }
    Set<String> strings(String key) {
      final value = json[key];
      if (value is! List || value.any((v) => v is! String)) {
        throw FormatException('Invalid preference list: $key');
      }
      return value.cast<String>().toSet();
    }

    final competitions = strings('competitions');
    if (competitions.any((key) {
      final parts = key.split(':');
      return parts.length != 4 ||
          parts[0] != sport.key ||
          parts[1].trim().isEmpty ||
          parts[2] != SportEntityKind.competition.name ||
          parts[3].trim().isEmpty;
    })) {
      throw const FormatException('Cross-sport competition preferences.');
    }
    return SportReadingPreferences(
      sport: sport,
      competitionKeys: competitions,
      readingIds: strings('readings'),
    );
  }
}
