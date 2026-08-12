import 'dart:convert';
import 'dart:io';

const _timezone = 'Europe/Paris';
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
const _dates = [
  '2026-08-04',
  '2026-08-05',
  '2026-08-06',
  '2026-08-07',
  '2026-08-08',
  '2026-08-09',
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

  final outputDir = Directory(_outputDir)..createSync(recursive: true);
  final teams = _teamsFromFocusedFixtures(outputDir);
  final client = _ApiFootballClient(baseUrl: baseUrl, apiKey: key);
  final rows = <_TeamAnalysisRow>[];

  for (final team in teams) {
    final statistics = await client.get('/teams/statistics', {
      'league': team.leagueId.toString(),
      'season': _season.toString(),
      'team': team.teamId.toString(),
      'date': team.fixtureDate,
    });
    _writeJson(
      outputDir,
      'team_statistics_${team.leagueId}_${team.teamId}.json',
      statistics,
    );
    final recentFixtures = await client.get('/fixtures', {
      'league': team.leagueId.toString(),
      'season': _season.toString(),
      'team': team.teamId.toString(),
      'last': '5',
      'timezone': _timezone,
    });
    _writeJson(
      outputDir,
      'recent_fixtures_${team.leagueId}_${team.teamId}.json',
      recentFixtures,
    );
    rows.add(
      _TeamAnalysisRow(
        leagueId: team.leagueId,
        teamId: team.teamId,
        teamName: team.teamName,
        hasStatistics: _asMap(statistics['response']).isNotEmpty,
        recentFixtures: _asList(recentFixtures['response']).length,
      ),
    );
  }

  File('docs/api-football-team-analysis-exploration.md')
    ..createSync(recursive: true)
    ..writeAsStringSync(_toMarkdown(rows));

  stdout.writeln('Team analysis exploration complete.');
  stdout.writeln('Teams explored: ${teams.length}');
  stdout.writeln('Raw responses: ${outputDir.path}');
  stdout.writeln('Summary: docs/api-football-team-analysis-exploration.md');
}

List<_TeamFixtureRef> _teamsFromFocusedFixtures(Directory outputDir) {
  final refs = <String, _TeamFixtureRef>{};

  for (final leagueId in _leagueIds) {
    for (final date in _dates) {
      final file = File('${outputDir.path}/fixtures_${leagueId}_$date.json');
      if (!file.existsSync()) {
        continue;
      }

      final payload = jsonDecode(file.readAsStringSync());
      for (final fixtureRow in _asList(_asMap(payload)['response'])) {
        final row = _asMap(fixtureRow);
        final league = _asMap(row['league']);
        final teams = _asMap(row['teams']);
        final home = _asMap(teams['home']);
        final away = _asMap(teams['away']);
        final season = _asInt(league['season']) ?? _season;
        if (season != _season) {
          continue;
        }

        _addTeamRef(refs, leagueId, date, home);
        _addTeamRef(refs, leagueId, date, away);
      }
    }
  }

  return refs.values.toList()..sort((a, b) {
    final leagueComparison = a.leagueId.compareTo(b.leagueId);
    if (leagueComparison != 0) {
      return leagueComparison;
    }

    return a.teamName.compareTo(b.teamName);
  });
}

void _addTeamRef(
  Map<String, _TeamFixtureRef> refs,
  int leagueId,
  String fixtureDate,
  Map<String, Object?> team,
) {
  final teamId = _asInt(team['id']);
  final teamName = _asString(team['name']);
  if (teamId == null) {
    return;
  }

  refs.putIfAbsent(
    '$leagueId:$teamId',
    () => _TeamFixtureRef(
      leagueId: leagueId,
      teamId: teamId,
      teamName: teamName ?? 'Team $teamId',
      fixtureDate: fixtureDate,
    ),
  );
}

String _toMarkdown(List<_TeamAnalysisRow> rows) {
  final withStats = rows.where((row) => row.hasStatistics).length;
  final buffer = StringBuffer()
    ..writeln('# Exploration statistiques équipes API-Football')
    ..writeln()
    ..writeln('- Saison : `$_season`')
    ..writeln('- Fuseau : `$_timezone`')
    ..writeln(
      '- Réponses brutes : `$_outputDir/team_statistics_{leagueId}_{teamId}.json`',
    )
    ..writeln(
      '- Formes détaillées : `$_outputDir/recent_fixtures_{leagueId}_{teamId}.json`',
    )
    ..writeln('- Équipes explorées : `${rows.length}`')
    ..writeln('- Réponses exploitables : `$withStats`')
    ..writeln()
    ..writeln(
      '| ID API ligue | ID API équipe | Équipe | Statistiques | 5 derniers matchs |',
    )
    ..writeln('|---:|---:|---|---|---:|');

  for (final row in rows) {
    buffer.writeln(
      '| ${row.leagueId} | ${row.teamId} | ${row.teamName} | ${row.hasStatistics ? 'oui' : 'non'} | ${row.recentFixtures} |',
    );
  }

  return buffer.toString();
}

class _TeamFixtureRef {
  const _TeamFixtureRef({
    required this.leagueId,
    required this.teamId,
    required this.teamName,
    required this.fixtureDate,
  });

  final int leagueId;
  final int teamId;
  final String teamName;
  final String fixtureDate;
}

class _TeamAnalysisRow {
  const _TeamAnalysisRow({
    required this.leagueId,
    required this.teamId,
    required this.teamName,
    required this.hasStatistics,
    required this.recentFixtures,
  });

  final int leagueId;
  final int teamId;
  final String teamName;
  final bool hasStatistics;
  final int recentFixtures;
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

void _writeJson(
  Directory outputDir,
  String fileName,
  Map<String, Object?> payload,
) {
  const encoder = JsonEncoder.withIndent('  ');
  File(
    '${outputDir.path}/$fileName',
  ).writeAsStringSync(encoder.convert(payload));
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

int? _asInt(Object? value) {
  return switch (value) {
    final int number => number,
    final num number => number.toInt(),
    final String text => int.tryParse(text),
    _ => null,
  };
}

String? _asString(Object? value) {
  return switch (value) {
    final String text => text,
    final Object object => object.toString(),
    _ => null,
  };
}
