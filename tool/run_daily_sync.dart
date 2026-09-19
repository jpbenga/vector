import 'dart:convert';
import 'dart:io';

const _projectUrl = 'https://ednvvxxvlawaagjyshkj.supabase.co';

Future<void> main(List<String> arguments) async {
  final leagueIds = arguments.map(int.tryParse).whereType<int>().toList();
  if (leagueIds.isEmpty || leagueIds.length != arguments.length) {
    stderr.writeln(
      'Usage: dart tool/run_daily_sync.dart <league-id> [<league-id> ...]',
    );
    exitCode = 64;
    return;
  }
  final secret = _readEnv(File('.env'))['API_FOOTBALL_SYNC_SECRET'];
  if (secret == null || secret.isEmpty) {
    stderr.writeln('API_FOOTBALL_SYNC_SECRET is missing from .env.');
    exitCode = 78;
    return;
  }

  final client = HttpClient();
  try {
    for (final leagueId in leagueIds) {
      final request = await client.postUrl(
        Uri.parse('$_projectUrl/functions/v1/daily-football-sync'),
      );
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $secret');
      request.write(
        jsonEncode({
          'league_ids': [leagueId],
          'results_days_back': 7,
          'future_days': 3,
          'api_request_delay_ms': 750,
          'include_team_statistics': true,
          'include_recent_form': true,
          'include_expected_goals': true,
          'include_player_statistics': true,
          'recent_form_days_back': 180,
          'recent_form_matches': 5,
        }),
      );
      final response = await request.close();
      final body = await utf8.decodeStream(response);
      stdout.writeln(
        'league=$leagueId status=${response.statusCode} body=$body',
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        exitCode = 1;
      }
    }
  } finally {
    client.close(force: true);
  }
}

Map<String, String> _readEnv(File file) {
  if (!file.existsSync()) return const {};
  final values = <String, String>{};
  for (final line in file.readAsLinesSync()) {
    if (!line.contains('=') || line.trimLeft().startsWith('#')) continue;
    final separator = line.indexOf('=');
    var value = line.substring(separator + 1).trim();
    if (value.length >= 2 &&
        ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'")))) {
      value = value.substring(1, value.length - 1);
    }
    values[line.substring(0, separator).trim()] = value;
  }
  return values;
}
