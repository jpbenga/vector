import 'dart:convert';
import 'dart:io';

const _timezone = 'Europe/Paris';
const _season = 2026;
const _dates = [
  '2026-08-04',
  '2026-08-05',
  '2026-08-06',
  '2026-08-07',
  '2026-08-08',
  '2026-08-09',
];
const _outputDir = 'var/api_football_exploration/focus_2026_08_04';
const _focusLeagues = {
  2: 'UEFA Champions League',
  3: 'UEFA Europa League',
  848: 'UEFA Europa Conference League',
  62: 'France - Ligue 2',
  88: 'Netherlands - Eredivisie',
  94: 'Portugal - Primeira Liga',
  98: 'Japan - J1 League',
  103: 'Norway - Eliteserien',
  113: 'Sweden - Allsvenskan',
  119: 'Denmark - Superliga',
  144: 'Belgium - Jupiler Pro League',
  164: 'Iceland - Urvalsdeild',
  179: 'Scotland - Premiership',
  169: 'China - Super League',
  207: 'Switzerland - Super League',
  218: 'Austria - Bundesliga',
  244: 'Finland - Veikkausliiga',
  286: 'Serbia - Super Liga',
  292: 'South Korea - K League 1',
};

Future<void> main() async {
  final env = _readEnv();
  final key = env['API_FOOTBALL_KEY'];
  final baseUrl =
      env['API_FOOTBALL_BASE_URL'] ?? 'https://v3.football.api-sports.io';
  final defaultBookmakerId = env['API_FOOTBALL_BOOKMAKER_ID'];

  if (key == null || key.trim().isEmpty) {
    stderr.writeln('API_FOOTBALL_KEY is missing in .env');
    exitCode = 1;
    return;
  }

  final client = _ApiFootballClient(baseUrl: baseUrl, apiKey: key);
  final outputDir = Directory(_outputDir);
  outputDir.createSync(recursive: true);

  final rows = <_FocusRow>[];

  for (final entry in _focusLeagues.entries) {
    final leagueId = entry.key;
    final leagueName = entry.value;

    final leagueInfo = await client.get('/leagues', {
      'id': leagueId.toString(),
      'season': _season.toString(),
    });
    _writeJson(outputDir, 'league_$leagueId.json', leagueInfo);

    for (final date in _dates) {
      final fixtures = await client.get('/fixtures', {
        'league': leagueId.toString(),
        'season': _season.toString(),
        'date': date,
        'timezone': _timezone,
      });
      _writeJson(outputDir, 'fixtures_${leagueId}_$date.json', fixtures);

      final fixtureCount = _responseRows(fixtures).length;
      var oddsCount = 0;
      if (fixtureCount > 0) {
        final oddsParams = {
          'league': leagueId.toString(),
          'season': _season.toString(),
          'date': date,
        };
        if (defaultBookmakerId != null && defaultBookmakerId.isNotEmpty) {
          oddsParams['bookmaker'] = defaultBookmakerId;
        }

        final odds = await client.get('/odds', oddsParams);
        _writeJson(outputDir, 'odds_${leagueId}_$date.json', odds);
        oddsCount = _responseRows(odds).length;
      }

      rows.add(
        _FocusRow(
          leagueId: leagueId,
          leagueName: leagueName,
          date: date,
          fixtures: fixtureCount,
          odds: oddsCount,
        ),
      );
    }
  }

  final searchChampionsLeague = await client.get('/leagues', {
    'search': 'champions',
  });
  _writeJson(outputDir, 'leagues_search_champions.json', searchChampionsLeague);

  File('docs/api-football-focused-exploration.md')
    ..createSync(recursive: true)
    ..writeAsStringSync(_toMarkdown(rows));

  stdout.writeln('Focused exploration complete.');
  stdout.writeln('Raw responses: ${outputDir.path}');
  stdout.writeln('Summary: docs/api-football-focused-exploration.md');
}

String _toMarkdown(List<_FocusRow> rows) {
  final buffer = StringBuffer()
    ..writeln('# Exploration ciblée API-Football')
    ..writeln()
    ..writeln('- Saison : `$_season`')
    ..writeln('- Fuseau : `$_timezone`')
    ..writeln('- Fenêtre : `${_dates.first}` -> `${_dates.last}`')
    ..writeln('- Réponses brutes : `$_outputDir/`')
    ..writeln()
    ..writeln('## Fixtures et cotes')
    ..writeln()
    ..writeln('| ID API | Ligue | Date | Fixtures | Odds |')
    ..writeln('|---:|---|---|---:|---:|');

  for (final row in rows) {
    if (row.fixtures == 0 && row.odds == 0) {
      continue;
    }

    buffer.writeln(
      '| ${row.leagueId} | ${row.leagueName} | ${row.date} | ${row.fixtures} | ${row.odds} |',
    );
  }

  return buffer.toString();
}

class _FocusRow {
  const _FocusRow({
    required this.leagueId,
    required this.leagueName,
    required this.date,
    required this.fixtures,
    required this.odds,
  });

  final int leagueId;
  final String leagueName;
  final String date;
  final int fixtures;
  final int odds;
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

List<Object?> _responseRows(Map<String, Object?> response) {
  return _asList(response['response']);
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

void _writeJson(
  Directory outputDir,
  String fileName,
  Map<String, Object?> payload,
) {
  final encoder = JsonEncoder.withIndent('  ');
  File(
    '${outputDir.path}/$fileName',
  ).writeAsStringSync(encoder.convert(payload));
}
