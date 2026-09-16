import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'package:copilot/features/matches/data/match_feed_repository.dart';
import 'package:copilot/features/matches/domain/football_analyzer.dart';
import 'package:copilot/features/matches/domain/football_reading.dart';
import 'package:copilot/features/onboarding/domain/decision_profile_catalogs.dart';

/// Publishes only readings that a server-owned snapshot supported before kickoff.
/// Run with SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY in a trusted scheduler.
Future<void> main(List<String> arguments) async {
  final url = Platform.environment['SUPABASE_URL'];
  final key = Platform.environment['SUPABASE_SERVICE_ROLE_KEY'];
  if (url == null || key == null || url.isEmpty || key.isEmpty) {
    throw StateError(
      'SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required.',
    );
  }
  final dayArgument = arguments
      .where((arg) => arg.startsWith('--date='))
      .firstOrNull;
  final date =
      dayArgument?.substring('--date='.length) ??
      DateTime.now().toLocal().toIso8601String().substring(0, 10);
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)) {
    throw ArgumentError('Expected --date=YYYY-MM-DD');
  }
  final client = _RestClient(url, key);
  try {
    final metadata = await client.getRowsPaged(
      'match_feed_snapshots',
      'select=id,captured_at&window_start=lte.$date&'
          'window_end=gte.$date&order=as_of.desc',
    );
    final fixtureIndex = await client.getRowsPaged(
      'match_feed_snapshot_fixtures',
      'select=snapshot_id,api_football_fixture_id,kickoff_at&'
          'fixture_date=eq.$date&order=created_at.desc',
    );
    final selectedByFixture = selectPreKickoffSnapshots(
      metadata: metadata,
      fixtureIndex: fixtureIndex,
    );
    final ids = selectedByFixture.values.toSet().toList(growable: false);
    final labels = {
      for (final definition in ReadingPreferenceCatalog.values)
        definition.id: definition.label,
    };
    final analyzerBytes = File(
      'lib/features/matches/domain/football_analyzer.dart',
    ).readAsBytesSync();
    final engineVersion = 'football_analyzer:${sha256.convert(analyzerBytes)}';
    var published = 0;
    var fixtures = 0;
    for (var start = 0; start < ids.length; start += 5) {
      final chunk = ids.skip(start).take(5).toList(growable: false);
      final quoted = chunk.map((id) => '"$id"').join(',');
      final rows = await client.getRows(
        'match_feed_snapshots',
        'select=id,captured_at,payload&id=in.($quoted)',
      );
      for (final row in rows) {
        final snapshotId = row['id']?.toString();
        final capturedAt = DateTime.tryParse(
          row['captured_at']?.toString() ?? '',
        );
        final payload = _map(row['payload']);
        if (snapshotId == null || capturedAt == null || payload == null) {
          continue;
        }
        final repository = SnapshotMatchFeedRepository(snapshot: payload);
        final announcements = <Map<String, Object?>>[];
        for (final match in repository.allMatches()) {
          final fixtureId = match.fixture.apiFootballFixtureId;
          final leagueId = match.competition.apiFootballLeagueId;
          final kickoff = match.fixture.kickoff;
          if (fixtureId == null ||
              leagueId == null ||
              selectedByFixture[fixtureId] != snapshotId ||
              kickoff == null ||
              !capturedAt.isBefore(kickoff) ||
              kickoff.toLocal().toIso8601String().substring(0, 10) != date) {
            continue;
          }
          fixtures += 1;
          final analysis = const FootballAnalyzer().analyze(
            match,
            asOf: capturedAt,
          );
          for (final reading in analysis.readings.where(
            (item) => item.isDetected,
          )) {
            if (!labels.containsKey(reading.id)) continue;
            final key =
                '$fixtureId:${reading.id}:${reading.subjectSide.name}:'
                '${reading.subjectTeamId}:${reading.playerId ?? 0}';
            announcements.add({
              'announcement_key': key,
              'fixture_id': fixtureId,
              'source_snapshot_id': snapshotId,
              'league_id': leagueId,
              'kickoff_at': kickoff.toUtc().toIso8601String(),
              'announced_at': capturedAt.toUtc().toIso8601String(),
              'engine_version': engineVersion,
              'reading_id': reading.id,
              'reading_label': labels[reading.id],
              'subject_side': reading.subjectSide.name,
              'subject_team_id': reading.subjectTeamId,
              'player_id': reading.playerId,
              'evidence': [
                for (final evidence in reading.evidence)
                  {
                    'label': evidence.label,
                    'source_path': evidence.sourcePath,
                    'value': _jsonValue(evidence.value),
                  },
              ],
              'sample_size': reading.sampleSize,
              'outcome_rule': _outcomeRule(reading),
              'rule_version': 1,
            });
          }
        }
        for (var offset = 0; offset < announcements.length; offset += 100) {
          published += await client.insertIgnoreDuplicates(
            'match_reading_announcements',
            announcements.skip(offset).take(100).toList(growable: false),
            conflict: 'announcement_key',
          );
        }
      }
    }
    stdout.writeln(
      'Snapshots: ${ids.length}; fixtures: $fixtures; '
      'new announcements: $published',
    );
  } finally {
    client.close();
  }
}

String? _outcomeRule(FootballReading reading) => switch (reading.id) {
  'frequent_over_25' => 'over_25',
  'frequent_under_25' => 'under_25',
  'frequent_btts' => 'btts',
  _ => null,
};

/// Picks the latest source that was actually known before each fixture began.
Map<int, String> selectPreKickoffSnapshots({
  required List<Map<String, Object?>> metadata,
  required List<Map<String, Object?>> fixtureIndex,
}) {
  final capturedBySnapshot = <String, DateTime>{
    for (final row in metadata)
      if (row['id'] != null &&
          DateTime.tryParse(row['captured_at']?.toString() ?? '') != null)
        row['id'].toString(): DateTime.parse(row['captured_at'].toString()),
  };
  final selectedByFixture = <int, String>{};
  for (final row in fixtureIndex) {
    final fixtureId = (row['api_football_fixture_id'] as num?)?.toInt();
    final snapshotId = row['snapshot_id']?.toString();
    final kickoff = DateTime.tryParse(row['kickoff_at']?.toString() ?? '');
    final captured = capturedBySnapshot[snapshotId];
    if (fixtureId == null ||
        snapshotId == null ||
        kickoff == null ||
        captured == null ||
        !captured.isBefore(kickoff)) {
      continue;
    }
    final previous = capturedBySnapshot[selectedByFixture[fixtureId]];
    if (previous == null || captured.isAfter(previous)) {
      selectedByFixture[fixtureId] = snapshotId;
    }
  }
  return selectedByFixture;
}

Map<String, Object?>? _map(Object? value) {
  if (value is! Map) return null;
  return value.map((key, item) => MapEntry(key.toString(), item));
}

Object? _jsonValue(Object? value) {
  if (value == null || value is num || value is String || value is bool) {
    return value;
  }
  if (value is DateTime) return value.toUtc().toIso8601String();
  if (value is List) return value.map(_jsonValue).toList(growable: false);
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), _jsonValue(item)));
  }
  return value.toString();
}

class _RestClient {
  _RestClient(this.baseUrl, this.key);

  final String baseUrl;
  final String key;
  final HttpClient _client = HttpClient();

  Future<List<Map<String, Object?>>> getRows(String table, String query) async {
    final request = await _client.getUrl(
      Uri.parse('$baseUrl/rest/v1/$table?$query'),
    );
    _headers(request);
    final response = await request.close();
    final body = await utf8.decoder.bind(response).join();
    if (response.statusCode >= 300) {
      throw HttpException('$table read failed: ${response.statusCode} $body');
    }
    return (jsonDecode(body) as List)
        .map((row) => _map(row))
        .whereType<Map<String, Object?>>()
        .toList(growable: false);
  }

  Future<List<Map<String, Object?>>> getRowsPaged(
    String table,
    String query,
  ) async {
    const pageSize = 200;
    final result = <Map<String, Object?>>[];
    for (var offset = 0; ; offset += pageSize) {
      final page = await getRows(
        table,
        '$query&limit=$pageSize&offset=$offset',
      );
      result.addAll(page);
      if (page.length < pageSize) return result;
    }
  }

  Future<int> insertIgnoreDuplicates(
    String table,
    List<Map<String, Object?>> rows, {
    required String conflict,
  }) async {
    if (rows.isEmpty) return 0;
    final request = await _client.postUrl(
      Uri.parse('$baseUrl/rest/v1/$table?on_conflict=$conflict'),
    );
    _headers(request);
    request.headers.set('content-type', 'application/json');
    request.headers.set(
      'prefer',
      'resolution=ignore-duplicates,return=representation',
    );
    request.write(jsonEncode(rows));
    final response = await request.close();
    final body = await utf8.decoder.bind(response).join();
    if (response.statusCode >= 300) {
      throw HttpException('$table insert failed: ${response.statusCode} $body');
    }
    return (jsonDecode(body) as List).length;
  }

  void _headers(HttpClientRequest request) {
    request.headers.set('apikey', key);
    request.headers.set('authorization', 'Bearer $key');
  }

  void close() => _client.close();
}
