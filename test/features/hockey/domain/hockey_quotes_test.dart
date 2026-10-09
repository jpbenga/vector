import 'dart:convert';
import 'dart:io';
import 'package:copilot/core/sports/data/sport_publication_codec.dart';
import 'package:copilot/core/sports/domain/sport.dart';
import 'package:copilot/core/sports/domain/sport_fixture.dart';
import 'package:copilot/core/sports/domain/sport_reading_preferences.dart';
import 'package:copilot/features/generator/domain/generator_context.dart';
import 'package:copilot/features/hockey/presentation/hockey_quote_presentation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'legacy hockey preferences keep choices, require explicit market opt-in and transmit it',
    () {
      final legacy = SportReadingPreferences.fromJson({
        'version': 1,
        'sport': 'hockey',
        'competitions': ['hockey:api-hockey:competition:35'],
        'readings': ['winning_streak'],
      }, SportId.hockey);
      expect(legacy.isConfigured, isTrue);
      expect(GeneratorContext.hockey(legacy)['markets'], isEmpty);
      final configured = SportReadingPreferences(
        sport: SportId.hockey,
        competitionKeys: legacy.competitionKeys,
        readingIds: legacy.readingIds,
        marketIds: ['result_regulation'],
      );
      expect(
        SportReadingPreferences.fromJson(
          configured.toJson(),
          SportId.hockey,
        ).marketIds,
        {'result_regulation'},
      );
      expect(GeneratorContext.hockey(configured)['markets'], [
        'result_regulation',
      ]);
    },
  );
  test(
    'price age is independent of the snapshot, scoped labels and coherent bookmaker use the football quote component',
    () {
      final payload =
          jsonDecode(
                File(
                  'test/fixtures/sports/nhl_compact.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final at = DateTime.parse(
        payload['capturedAt'] as String,
      ).add(const Duration(hours: 1));
      final raw = (payload['items'] as List).first as Map<String, dynamic>;
      raw['startsAt'] = at.add(const Duration(hours: 3)).toIso8601String();
      raw['status'] = 'scheduled';
      raw['quotes'] = [
        for (final b in ['Book A', 'Book B'])
          for (final c in ['home', 'draw', 'away'])
            {
              'marketCode': 'result_regulation',
              'selectionCode': c,
              'scope': 'regulation',
              'bookmaker': b,
              'decimalOdds': 2.2,
              'capturedAt': at.toIso8601String(),
            },
      ];
      // Keep the fixture's calendar/window from the source fixture; quote times
      // need not equal the immutable analytic publication timestamp.
      final f = SportPublicationCodec.decode(
        payload,
        SportId.hockey,
      ).items.first;
      expect(f.quotes.length, 6);
      expect(f.quotes.first.scope, SportScoreScope.regulation);
      final markets = hockeyOddsMarkets(f, at);
      expect(markets.length, 1);
      expect(markets.single.label, contains('60 minutes'));
      expect(markets.single.selections.length, 3);
      expect(markets.single.recordedAt, at);
      expect(hockeyOddsMarkets(f, at.add(const Duration(hours: 49))), isEmpty);
    },
  );
}
