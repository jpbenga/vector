import 'dart:convert';
import 'dart:io';

import 'package:copilot/features/matches/data/match_feed_repository.dart';
import 'package:copilot/features/matches/domain/match_board_item.dart';
import 'package:flutter_test/flutter_test.dart';

const _enabled = bool.fromEnvironment('RUN_PUBLIC_SNAPSHOT_CONTRACT');

void main() {
  test(
    'production publishes a compact snapshot that the anonymous Flutter path can read',
    () async {
      final environment = _readDotEnv(File('.env'));
      final url = environment['SUPABASE_URL'];
      final anonKey = environment['SUPABASE_ANON_KEY'];
      final syncSecret = environment['API_FOOTBALL_SYNC_SECRET'];
      expect(url, isNotNull, reason: 'SUPABASE_URL is required.');
      expect(anonKey, isNotNull, reason: 'SUPABASE_ANON_KEY is required.');
      expect(
        syncSecret,
        isNotNull,
        reason:
            'API_FOOTBALL_SYNC_SECRET is required to materialise a raw snapshot.',
      );

      final client = HttpClient();
      addTearDown(client.close);
      final raw = await _requestJson(
        client,
        Uri.parse(
          '$url/rest/v1/match_feed_snapshots?select=id&order=as_of.desc&limit=1',
        ),
        headers: {'apikey': anonKey!, 'authorization': 'Bearer $anonKey'},
      );
      final rawRows = raw as List<Object?>;
      expect(
        rawRows,
        isNotEmpty,
        reason: 'A collected raw snapshot is required.',
      );
      final rawId = (rawRows.first as Map<Object?, Object?>)['id']?.toString();
      expect(rawId, isNotNull);

      final analysed =
          await _requestJson(
                client,
                Uri.parse('$url/functions/v1/analyze-match-feed-snapshot'),
                method: 'POST',
                headers: {
                  'authorization': 'Bearer $syncSecret',
                  'content-type': 'application/json',
                },
                body: {'snapshot_id': rawId},
              )
              as Map<Object?, Object?>;
      expect(analysed['ok'], isTrue, reason: '$analysed');

      final compact =
          await _requestJson(
                client,
                Uri.parse(
                  '$url/rest/v1/match_feed_analysis_snapshots?select=source_snapshot_id,payload&source_snapshot_id=eq.$rawId&limit=1',
                ),
                headers: {
                  'apikey': anonKey,
                  'authorization': 'Bearer $anonKey',
                },
              )
              as List<Object?>;
      expect(
        compact,
        hasLength(1),
        reason:
            'The anonymous application role must read its compact snapshot.',
      );
      final row = compact.single as Map<Object?, Object?>;
      expect(row['source_snapshot_id'], rawId);
      final payload = Map<String, Object?>.from(
        row['payload'] as Map<Object?, Object?>,
      );
      final repository = const MatchFeedRepositoryFactory().create(
        MatchDataSourceMode.snapshot,
        snapshot: payload,
      );
      expect(repository.snapshotMetadata, isNotNull);
      expect(repository.allMatches(), isA<List<Object?>>());
    },
    skip: _enabled
        ? false
        : 'Run only against the deployed Supabase project with '
              '--dart-define=RUN_PUBLIC_SNAPSHOT_CONTRACT=true.',
  );
}

Future<Object?> _requestJson(
  HttpClient client,
  Uri uri, {
  String method = 'GET',
  required Map<String, String> headers,
  Object? body,
}) async {
  final request = await client.openUrl(method, uri);
  headers.forEach(request.headers.set);
  if (body != null) request.write(jsonEncode(body));
  final response = await request.close();
  final text = await utf8.decodeStream(response);
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw StateError('HTTP ${response.statusCode} for $uri: $text');
  }
  return jsonDecode(text);
}

Map<String, String> _readDotEnv(File file) {
  final values = <String, String>{};
  for (final line in file.readAsLinesSync()) {
    final separator = line.indexOf('=');
    if (separator <= 0 || line.trimLeft().startsWith('#')) continue;
    final value = line.substring(separator + 1).trim();
    final isQuoted =
        value.length >= 2 &&
        ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'")));
    values[line.substring(0, separator).trim()] = isQuoted
        ? value.substring(1, value.length - 1)
        : value;
  }
  return values;
}
