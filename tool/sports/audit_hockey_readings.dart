import 'dart:convert';
import 'dart:io';
import 'package:copilot/core/sports/data/published_sport_feed_repository.dart';
import 'package:copilot/core/sports/domain/sport.dart';
import 'package:copilot/core/sports/domain/sport_module.dart';
import 'package:copilot/features/hockey/domain/hockey_feed_readings.dart';

/// Offline inspection of the exact compact publication consumed by Flutter.
/// Never changes preferences, publishes predictions or calls the provider.
void main(List<String> args) {
  final path = args.isEmpty ? 'var/sports/hockey/published.json' : args.single;
  final snapshot = SportPublicationCodec.decode(
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>,
    SportId.hockey,
  );
  const adapter = HockeyFeedReadings();
  final leagues = <String, Map<String, Object>>{};
  final examples = <Map<String, Object>>[];
  for (final fixture in snapshot.items) {
    final values = adapter.evaluate(fixture, snapshot);
    final detected = values
        .where((r) => r.status == SportReadingStatus.detected)
        .toList();
    final row = leagues.putIfAbsent(
      fixture.competition.value,
      () => {
        'league': fixture.competitionName,
        'fixtures': 0,
        'fixturesWithReadings': 0,
        'detected': {for (final id in HockeyFeedReadings.readingIds) id: 0},
      },
    );
    row['fixtures'] = (row['fixtures'] as int) + 1;
    if (detected.isNotEmpty) {
      row['fixturesWithReadings'] = (row['fixturesWithReadings'] as int) + 1;
      examples.add({
        'matchId': fixture.id.key,
        'date': fixture.startsAt!.toIso8601String(),
        'league': fixture.competitionName,
        'away': fixture.away.name,
        'home': fixture.home.name,
        'readings': [
          for (final r in detected)
            {
              'id': r.id,
              'team': r.subject == fixture.home.id
                  ? fixture.home.name
                  : fixture.away.name,
              'explanation': r.explanation,
              'sampleSize': r.sampleSize,
            },
        ],
      });
    }
    final counts = row['detected'] as Map<String, int>;
    for (final r in detected) {
      counts[r.id] = counts[r.id]! + 1;
    }
  }
  stdout.writeln(
    const JsonEncoder.withIndent('  ').convert({
      'source': path,
      'capturedAt': snapshot.capturedAt.toIso8601String(),
      'policy': adapter.engine.rulesVersion,
      'leagues': leagues,
      'examples': examples,
    }),
  );
}
