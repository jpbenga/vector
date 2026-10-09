import 'dart:convert';
import 'dart:io';
import 'package:copilot/core/sports/data/published_sport_feed_repository.dart';
import 'package:copilot/core/sports/domain/sport.dart';
import 'package:copilot/core/sports/domain/sport_module.dart';
import 'package:copilot/features/hockey/domain/hockey_feed_readings.dart';
import 'package:copilot/features/hockey/domain/hockey_publication_readings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final original =
      jsonDecode(
            File(
              'test/fixtures/sports/hockey_readings_compact.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  test(
    'Published readings match the native engine with preserved collection facts',
    () {
      final published = withHockeyPublicationReadings(original);
      final snapshot = SportPublicationCodec.decode(original, SportId.hockey);
      expect(published['capturedAt'], original['capturedAt']);
      expect(published['collectionId'], original['collectionId']);
      expect(published['competitions'], original['competitions']);
      expect(published['playerRadar'], original['playerRadar']);
      int count = 0;
      for (final fixture in snapshot.items) {
        final detected = const HockeyFeedReadings()
            .evaluate(fixture, snapshot)
            .where((r) => r.status == SportReadingStatus.detected)
            .toList();
        final match = (published['items'] as List).firstWhere(
          (m) => m['id'] == fixture.id.value,
        );
        final readings = match['readings'] as List;
        expect(readings.length, detected.length);
        count += readings.length;
        for (var i = 0; i < detected.length; i++) {
          expect(readings[i]['id'], detected[i].id);
          expect(readings[i]['subject_team_id'], detected[i].subject.value);
          expect(readings[i]['explanation'], detected[i].explanation);
          expect(readings[i]['sample_size'], detected[i].sampleSize);
        }
      }
      expect(count, greaterThan(0));
    },
  );
  test(
    'Remote detail keeps the calendar publication version across refreshes',
    () async {
      final calls = <Map<String, dynamic>>[];
      final client = MockClient((request) async {
        expect(request.headers['apikey'], 'public');
        expect(request.headers.containsKey('authorization'), isFalse);
        final args = jsonDecode(request.body) as Map<String, dynamic>;
        calls.add(args);
        return http.Response(jsonEncode(original), 200);
      });
      final repository = PublishedSportFeedRepository(
        sport: SportId.hockey,
        source: SupabaseSportPublicationSource(
          projectUrl: Uri.parse('https://test.supabase.co'),
          publicKey: 'public',
          client: client,
        ),
      );
      final day = DateTime(2026, 10, 4);
      await repository.load(day);
      await repository.loadMatch(
        day,
        (original['items'] as List).first['id'] as String,
      );
      expect(calls.map((v) => v['p_section']), ['day', 'match']);
      expect(
        DateTime.parse(calls.last['p_captured_at'] as String),
        DateTime.parse(original['capturedAt'] as String),
      );
      expect(calls.last['p_sport'], 'hockey');
    },
  );
}
