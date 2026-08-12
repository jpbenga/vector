import 'dart:convert';
import 'dart:io';

const _targetDate = '2026-07-30';
const _timezone = 'Europe/Paris';
const _season = 2026;
const _countries = ['Norway', 'Sweden', 'Finland', 'Iceland', 'Austria'];
const _cupSearches = ['Champions League'];

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
  final outputDir = Directory('var/api_football_exploration/$_targetDate');
  outputDir.createSync(recursive: true);

  final summary = _ExplorationSummary(
    targetDate: _targetDate,
    timezone: _timezone,
    season: _season,
  );

  final leagueIds = <int>{};

  for (final country in _countries) {
    final response = await client.get('/leagues', {
      'country': country,
      'season': _season.toString(),
    });
    _writeJson(outputDir, 'leagues_${_slug(country)}.json', response);

    final leagues = _responseRows(response);
    summary.countryLeagueCounts[country] = leagues.length;

    for (final league in leagues) {
      final leagueMap = _asMap(league);
      final leagueInfo = _asMap(leagueMap['league']);
      final seasons = _asList(leagueMap['seasons']);
      final currentSeason = seasons
          .map(_asMap)
          .where((season) => season['year'] == _season)
          .firstOrNull;
      final coverage = _asMap(currentSeason?['coverage']);
      final fixturesCoverage = _asMap(coverage['fixtures']);
      final standingsCoverage = coverage['standings'] == true;

      final id = _asInt(leagueInfo['id']);
      if (id != null) {
        leagueIds.add(id);
        summary.leagues.add(
          _LeagueSummary(
            id: id,
            name: _asString(leagueInfo['name']) ?? 'Unknown',
            type: _asString(leagueInfo['type']) ?? 'Unknown',
            country: country,
            standings: standingsCoverage,
            events: fixturesCoverage['events'] == true,
            lineups: fixturesCoverage['lineups'] == true,
            statisticsFixtures: fixturesCoverage['statistics_fixtures'] == true,
            statisticsPlayers: fixturesCoverage['statistics_players'] == true,
          ),
        );
      }
    }
  }

  for (final search in _cupSearches) {
    final response = await client.get('/leagues', {
      'search': search,
      'season': _season.toString(),
    });
    _writeJson(outputDir, 'leagues_search_${_slug(search)}.json', response);

    for (final league in _responseRows(response)) {
      final leagueMap = _asMap(league);
      final leagueInfo = _asMap(leagueMap['league']);
      final id = _asInt(leagueInfo['id']);
      if (id != null) {
        leagueIds.add(id);
        summary.cupSearches.add(
          _CupSearchSummary(
            id: id,
            name: _asString(leagueInfo['name']) ?? 'Unknown',
            type: _asString(leagueInfo['type']) ?? 'Unknown',
            country:
                _asString(_asMap(leagueMap['country'])['name']) ?? 'Unknown',
          ),
        );
      }
    }
  }

  for (final leagueId in leagueIds.toList()..sort()) {
    final fixtures = await client.get('/fixtures', {
      'league': leagueId.toString(),
      'season': _season.toString(),
      'date': _targetDate,
      'timezone': _timezone,
    });
    _writeJson(outputDir, 'fixtures_league_$leagueId.json', fixtures);

    final fixtureRows = _responseRows(fixtures);
    if (fixtureRows.isEmpty) {
      continue;
    }

    summary.fixtureCounts[leagueId] = fixtureRows.length;

    final oddsParams = {
      'league': leagueId.toString(),
      'season': _season.toString(),
      'date': _targetDate,
    };
    if (defaultBookmakerId != null && defaultBookmakerId.isNotEmpty) {
      oddsParams['bookmaker'] = defaultBookmakerId;
    }

    final odds = await client.get('/odds', oddsParams);
    _writeJson(outputDir, 'odds_league_$leagueId.json', odds);
    summary.oddsCounts[leagueId] = _responseRows(odds).length;
  }

  final bookmakers = await client.get('/odds/bookmakers', {});
  _writeJson(outputDir, 'odds_bookmakers.json', bookmakers);
  summary.bookmakerCount = _responseRows(bookmakers).length;

  final bets = await client.get('/odds/bets', {});
  _writeJson(outputDir, 'odds_bets.json', bets);
  summary.betCount = _responseRows(bets).length;
  summary.sampleBets.addAll(
    _responseRows(
      bets,
    ).take(40).map(_asMap).map((bet) => '${bet['id']}: ${bet['name']}'),
  );

  File('docs/api-football-exploration.md')
    ..createSync(recursive: true)
    ..writeAsStringSync(summary.toMarkdown());

  stdout.writeln('Exploration complete.');
  stdout.writeln('Raw responses: ${outputDir.path}');
  stdout.writeln('Summary: docs/api-football-exploration.md');
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

class _ExplorationSummary {
  _ExplorationSummary({
    required this.targetDate,
    required this.timezone,
    required this.season,
  });

  final String targetDate;
  final String timezone;
  final int season;
  final Map<String, int> countryLeagueCounts = {};
  final List<_LeagueSummary> leagues = [];
  final List<_CupSearchSummary> cupSearches = [];
  final Map<int, int> fixtureCounts = {};
  final Map<int, int> oddsCounts = {};
  final List<String> sampleBets = [];
  int bookmakerCount = 0;
  int betCount = 0;

  String toMarkdown() {
    final buffer = StringBuffer()
      ..writeln('# Exploration API-Football')
      ..writeln()
      ..writeln('- Date cible : `$targetDate`')
      ..writeln('- Saison : `$season`')
      ..writeln('- Fuseau : `$timezone`')
      ..writeln(
        '- Réponses brutes : `var/api_football_exploration/$targetDate/`',
      )
      ..writeln()
      ..writeln('## Pays explorés')
      ..writeln()
      ..writeln('| Pays | Compétitions trouvées |')
      ..writeln('|---|---:|');

    for (final entry in countryLeagueCounts.entries) {
      buffer.writeln('| ${entry.key} | ${entry.value} |');
    }

    buffer
      ..writeln()
      ..writeln('## Compétitions retenues')
      ..writeln()
      ..writeln(
        '| ID API | Pays | Nom | Type | Classement | Events | Lineups | Stats match | Stats joueurs | Fixtures $targetDate | Odds $targetDate |',
      )
      ..writeln('|---:|---|---|---|---|---|---|---|---|---:|---:|');

    for (final league in leagues..sort((a, b) => a.id.compareTo(b.id))) {
      buffer.writeln(
        '| ${league.id} | ${league.country} | ${league.name} | ${league.type} | ${_yesNo(league.standings)} | ${_yesNo(league.events)} | ${_yesNo(league.lineups)} | ${_yesNo(league.statisticsFixtures)} | ${_yesNo(league.statisticsPlayers)} | ${fixtureCounts[league.id] ?? 0} | ${oddsCounts[league.id] ?? 0} |',
      );
    }

    buffer
      ..writeln()
      ..writeln('## Recherches coupes')
      ..writeln()
      ..writeln('| ID API | Pays | Nom | Type |')
      ..writeln('|---:|---|---|---|');

    for (final cup in cupSearches..sort((a, b) => a.id.compareTo(b.id))) {
      buffer.writeln(
        '| ${cup.id} | ${cup.country} | ${cup.name} | ${cup.type} |',
      );
    }

    buffer
      ..writeln()
      ..writeln('## Bookmakers et marchés')
      ..writeln()
      ..writeln('- Bookmakers trouvés : `$bookmakerCount`')
      ..writeln('- Marchés trouvés : `$betCount`')
      ..writeln()
      ..writeln('### Premiers marchés retournés')
      ..writeln();

    for (final bet in sampleBets) {
      buffer.writeln('- `$bet`');
    }

    buffer
      ..writeln()
      ..writeln('## Conclusions de normalisation')
      ..writeln()
      ..writeln(
        '- Les marchés doivent être normalisés par ID API-Football quand il existe, pas par libellé bookmaker.',
      )
      ..writeln(
        '- Les valeurs de sélection bookmaker doivent être mappées vers nos marchés internes : `match_result`, `double_chance`, `goals_over_under`, etc.',
      )
      ..writeln(
        '- Les cotes doivent conserver le bookmaker d’origine pour audit et comparaison.',
      )
      ..writeln(
        '- Le moteur ne doit consommer que nos IDs internes de marchés, jamais les libellés bruts.',
      );

    return buffer.toString();
  }

  String _yesNo(bool value) => value ? 'oui' : 'non';
}

class _LeagueSummary {
  const _LeagueSummary({
    required this.id,
    required this.name,
    required this.type,
    required this.country,
    required this.standings,
    required this.events,
    required this.lineups,
    required this.statisticsFixtures,
    required this.statisticsPlayers,
  });

  final int id;
  final String name;
  final String type;
  final String country;
  final bool standings;
  final bool events;
  final bool lineups;
  final bool statisticsFixtures;
  final bool statisticsPlayers;
}

class _CupSearchSummary {
  const _CupSearchSummary({
    required this.id,
    required this.name,
    required this.type,
    required this.country,
  });

  final int id;
  final String name;
  final String type;
  final String country;
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

String _slug(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
}
