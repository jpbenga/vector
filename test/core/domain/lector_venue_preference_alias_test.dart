import 'package:copilot/core/sports/domain/sport.dart';
import 'package:copilot/core/sports/domain/sport_reading_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'venue aliases preserve opt-in without duplicating or enabling unrelated readings',
    () {
      final preferences = SportReadingPreferences(
        sport: SportId.hockey,
        readingIds: [
          'home_winning_streak',
          'strong_home_team',
          'away_winning_streak',
        ],
      );
      expect(preferences.readingIds, {'strong_home_team', 'strong_away_team'});
      expect(preferences.isConfigured, false);
      final reloaded = SportReadingPreferences.fromJson(
        Map<String, dynamic>.from(preferences.toJson()),
        SportId.hockey,
      );
      expect(reloaded.readingIds, preferences.readingIds);
      expect(
        SportReadingPreferences(sport: SportId.hockey).readingIds,
        isEmpty,
      );
    },
  );
}
