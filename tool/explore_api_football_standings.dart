import 'dart:convert';
import 'dart:io';

const _season = 2026;
const _outputDir = 'var/api_football_exploration/focus_2026_08_04';
const _leagueIds = [
  2,
  3,
  848,
  103,
  104,
  113,
  114,
  164,
  165,
  218,
  219,
  244,
  245,
  1087,
];

Future<void> main() async {
  final env = _readEnv();
  final key = env['API_FOOTBALL_KEY'];
  final baseUrl =
      env['API_FOOTBALL_BASE_URL'] ?? 'https://v3.football.api-sports.io';

  if (key == null || key.trim().isEmpty) {
    stderr.writeln('API_FOOTBALL_KEY is missing in .env');
    exitCode = 1;
    return;
  }

  final client = _ApiFootballClient(baseUrl: baseUrl, apiKey: key);
  final outputDir = Directory(_outputDir)..createSync(recursive: true);
  final rows = <_StandingsRow>[];

  for (final leagueId in _leagueIds) {
    final standings = await client.get('/standings', {
      'league': leagueId.toString(),
      'season': _season.toString(),
    });
    _writeJson(outputDir, 'standings_$leagueId.json', standings);
    rows.add(
      _StandingsRow(
        leagueId: leagueId,
        standingsRows: _countStandingRows(standings),
      ),
    );
  }

  File('docs/api-football-standings-exploration.md')
    ..createSync(recursive: true)
    ..writeAsStringSync(_toMarkdown(rows));

  stdout.writeln('Standings exploration complete.');
  stdout.writeln('Raw responses: ${outputDir.path}');
  stdout.writeln('Summary: docs/api-football-standings-exploration.md');
}

String _toMarkdown(List<_StandingsRow> rows) {
  final buffer = StringBuffer()
    ..writeln('# Exploration classements API-Football')
    ..writeln()
    ..writeln('- Saison : `$_season`')
    ..writeln('- Réponses brutes : `$_outputDir/standings_{leagueId}.json`')
    ..writeln()
    ..writeln('| ID API ligue | Équipes classées |')
    ..writeln('|---:|---:|');

  for (final row in rows) {
    buffer.writeln('| ${row.leagueId} | ${row.standingsRows} |');
  }

  return buffer.toString();
}

int _countStandingRows(Map<String, Object?> payload) {
  var count = 0;

  for (final responseRow in _asList(payload['response'])) {
    final league = _asMap(_asMap(responseRow)['league']);
    for (final group in _asList(league['standings'])) {
      count += _asList(group).length;
    }
  }

  return count;
}

class _StandingsRow {
  const _StandingsRow({required this.leagueId, required this.standingsRows});

  final int leagueId;
  final int standingsRows;
}

class _ApiFootballClient {
  const _ApiFootballClient({required this.baseUrl, required this.apiKey});

  final String baseUrl;
  final String apiKey;

  Future<Map<String, Object?>> get(
    String path,
    Map<String, String> query,
  ) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final request = await HttpClient().getUrl(uri);
    request.headers.set('x-apisports-key', apiKey);
    request.headers.set('accept', 'application/json');

    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'API-Football ${response.statusCode} for $path: $body',
        uri: uri,
      );
    }

    final json = jsonDecode(body);
    if (json is! Map<String, Object?>) {
      throw FormatException('Unexpected JSON payload for $path');
    }

    return json;
  }
}

void _writeJson(
  Directory outputDir,
  String fileName,
  Map<String, Object?> json,
) {
  final file = File('${outputDir.path}/$fileName');
  const encoder = JsonEncoder.withIndent('  ');
  file.writeAsStringSync(encoder.convert(json));
}

Map<String, String> _readEnv() {
  final file = File('.env');
  if (!file.existsSync()) {
    return const {};
  }

  final env = <String, String>{};
  for (final line in file.readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#') || !trimmed.contains('=')) {
      continue;
    }

    final separator = trimmed.indexOf('=');
    env[trimmed.substring(0, separator).trim()] = _unquote(
      trimmed.substring(separator + 1).trim(),
    );
  }

  return env;
}

String _unquote(String value) {
  if (value.length < 2) {
    return value;
  }

  final first = value.substring(0, 1);
  final last = value.substring(value.length - 1);
  if ((first == '"' && last == '"') || (first == "'" && last == "'")) {
    return value.substring(1, value.length - 1);
  }

  return value;
}

Map<String, Object?> _asMap(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }

  if (value is Map) {
    return {
      for (final entry in value.entries)
        if (entry.key != null) entry.key.toString(): entry.value,
    };
  }

  return const {};
}

List<Object?> _asList(Object? value) {
  if (value is List<Object?>) {
    return value;
  }

  if (value is List) {
    return value;
  }

  return const [];
}
