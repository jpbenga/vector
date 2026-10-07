import 'dart:convert';
import 'dart:io';
import 'package:copilot/core/sports/data/published_sport_feed_repository.dart';
import 'package:copilot/core/sports/domain/sport.dart';
import 'package:copilot/features/hockey/domain/hockey_feed_readings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'hockey daily projection preserves reading outcomes and sample sizes',
    () {
      final full = SportPublicationCodec.decode(
        jsonDecode(
              File(
                'test/fixtures/sports/hockey_enriched_compact.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>,
        SportId.hockey,
      );
      final day = SportPublicationCodec.decode(
        jsonDecode(
              File('test/fixtures/delivery/hockey_day.json').readAsStringSync(),
            )
            as Map<String, dynamic>,
        SportId.hockey,
      );
      const engine = HockeyFeedReadings();
      for (final fixture in day.items) {
        final original = full.items.singleWhere((f) => f.id == fixture.id);
        expect(
          [
            for (final r in engine.evaluate(fixture, day))
              [
                r.id,
                r.subject.key,
                r.status,
                r.sampleSize,
                r.explanation,
                r.evidence,
              ],
          ],
          [
            for (final r in engine.evaluate(original, full))
              [
                r.id,
                r.subject.key,
                r.status,
                r.sampleSize,
                r.explanation,
                r.evidence,
              ],
          ],
        );
      }
      expect(day.items, isNotEmpty);
    },
  );
}
