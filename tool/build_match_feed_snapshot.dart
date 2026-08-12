import 'dart:convert';
import 'dart:io';

const _snapshotSchemaVersion = 1;
const _source = 'api-football';
const _timezone = 'Europe/Paris';
const _defaultExplorationDir = 'var/api_football_exploration/latest';
const _defaultOutputPath = 'assets/snapshots/focused_match_feed_latest.json';
const _leagueIds = [
  2,
  3,
  62,
  88,
  94,
  98,
  103,
  113,
  119,
  144,
  164,
  169,
  179,
  207,
  218,
  244,
  286,
  292,
  848,
];

Future<void> main(List<String> arguments) async {
  final options = _SnapshotBuildOptions.fromArgs(arguments);
  final fixtures = <Object?>[];
  final odds = <Object?>[];
  final standings = <Object?>[];
  final teamStatistics = <Object?>[];
  final recentLeagueMatches = <Object?>[];

  for (final leagueId in _leagueIds) {
    standings.addAll(
      _readResponseIfPresent(
        File('${options.explorationDir}/standings_$leagueId.json'),
      ),
    );
    teamStatistics.addAll(
      _readTeamStatisticsResponsesForLeague(
        Directory(options.explorationDir),
        leagueId,
      ),
    );
    recentLeagueMatches.addAll(
      _readRecentLeagueMatchesForLeague(
        Directory(options.explorationDir),
        leagueId,
      ),
    );

    for (final date in options.dates) {
      fixtures.addAll(
        _readResponseIfPresent(
          File('${options.explorationDir}/fixtures_${leagueId}_$date.json'),
        ),
      );
      odds.addAll(
        _readResponseIfPresent(
          File('${options.explorationDir}/odds_${leagueId}_$date.json'),
        ),
      );
    }
  }

  final snapshot = {
    'schema_version': _snapshotSchemaVersion,
    'source': _source,
    'captured_at': DateTime.now().toUtc().toIso8601String(),
    'timezone': _timezone,
    'window_start': options.dates.first,
    'window_end': options.dates.last,
    'date_window': options.dates,
    'bookmaker_priority': [
      {'id': 16, 'name': 'Unibet'},
      {'id': 8, 'name': 'Bet365'},
      {'id': 4, 'name': 'Pinnacle'},
      {'id': 3, 'name': 'Betfair'},
      {'id': 11, 'name': '1xBet'},
      {'id': 6, 'name': 'Bwin'},
    ],
    'raw': {
      'fixtures': fixtures,
      'odds': odds,
      'standings': standings,
      'team_statistics': teamStatistics,
      'recent_league_matches': recentLeagueMatches,
    },
  };

  final output = File(options.outputPath)..createSync(recursive: true);
  const encoder = JsonEncoder();
  output.writeAsStringSync(encoder.convert(snapshot));

  stdout.writeln('Snapshot written: ${output.path}');
  stdout.writeln('Source directory: ${options.explorationDir}');
  stdout.writeln('Window: ${options.dates.first} -> ${options.dates.last}');
  stdout.writeln('Fixtures: ${fixtures.length}');
  stdout.writeln('Odds rows: ${odds.length}');
  stdout.writeln('Standings rows: ${standings.length}');
  stdout.writeln('Team statistics rows: ${teamStatistics.length}');
  stdout.writeln('Recent league match rows: ${recentLeagueMatches.length}');
}

class _SnapshotBuildOptions {
  const _SnapshotBuildOptions({
    required this.explorationDir,
    required this.outputPath,
    required this.dates,
  });

  factory _SnapshotBuildOptions.fromArgs(List<String> args) {
    final from = _readOption(args, '--from');
    final days = _readOption(args, '--days');
    final until = _readOption(args, '--until');
    final explorationDir =
        _readOption(args, '--exploration-dir') ?? _resolveExplorationDir();
    final outputPath = _readOption(args, '--output') ?? _defaultOutputPath;
    final start = _parseDate(from) ?? _today();
    final dates = _dateWindow(
      start: start,
      days: days == null ? null : int.tryParse(days),
      until: _parseDate(until),
    );

    if (dates.isEmpty) {
      throw StateError('Snapshot date window cannot be empty.');
    }

    return _SnapshotBuildOptions(
      explorationDir: explorationDir,
      outputPath: outputPath,
      dates: dates.map(_formatDate).toList(),
    );
  }

  final String explorationDir;
  final String outputPath;
  final List<String> dates;
}

String _resolveExplorationDir() {
  final preferred = Directory(_defaultExplorationDir);
  if (preferred.existsSync()) {
    return preferred.path;
  }

  final root = Directory('var/api_football_exploration');
  if (!root.existsSync()) {
    return _defaultExplorationDir;
  }

  final candidates =
      root
          .listSync()
          .whereType<Directory>()
          .where(
            (directory) => directory.uri.pathSegments.last.startsWith('focus_'),
          )
          .toList()
        ..sort((a, b) {
          return b.statSync().modified.compareTo(a.statSync().modified);
        });

  return candidates.isEmpty ? _defaultExplorationDir : candidates.first.path;
}

List<DateTime> _dateWindow({
  required DateTime start,
  required int? days,
  required DateTime? until,
}) {
  final normalizedStart = _dateOnly(start);
  final normalizedUntil = until == null ? null : _dateOnly(until);
  if (normalizedUntil != null && normalizedUntil.isBefore(normalizedStart)) {
    throw StateError('--until must be on or after --from.');
  }

  final length = days ?? _daysUntilEndOfWeek(normalizedStart);
  if (length < 1) {
    throw StateError('--days must be greater than zero.');
  }

  final explicitEnd = normalizedUntil;
  if (explicitEnd != null) {
    return [
      for (
        var date = normalizedStart;
        !date.isAfter(explicitEnd);
        date = date.add(const Duration(days: 1))
      )
        date,
    ];
  }

  return [
    for (var offset = 0; offset < length; offset += 1)
      normalizedStart.add(Duration(days: offset)),
  ];
}

int _daysUntilEndOfWeek(DateTime start) {
  final daysUntilSunday = DateTime.sunday - start.weekday;
  return daysUntilSunday + 1;
}

String? _readOption(List<String> args, String name) {
  final index = args.indexOf(name);
  if (index == -1) {
    return null;
  }
  final valueIndex = index + 1;
  if (valueIndex >= args.length || args[valueIndex].startsWith('--')) {
    throw StateError('Missing value for $name.');
  }
  return args[valueIndex];
}

DateTime? _parseDate(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}

DateTime _today() {
  final now = DateTime.now();
  return _dateOnly(now);
}

DateTime _dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

String _formatDate(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

List<Object?> _readTeamStatisticsResponsesForLeague(
  Directory directory,
  int leagueId,
) {
  if (!directory.existsSync()) {
    return const [];
  }

  final rows = <Object?>[];
  for (final file in directory.listSync().whereType<File>()) {
    final name = file.uri.pathSegments.last;
    if (!name.startsWith('team_statistics_${leagueId}_') ||
        !name.endsWith('.json')) {
      continue;
    }

    final payload = jsonDecode(file.readAsStringSync());
    final response = _asMap(payload)['response'];
    if (_asMap(response).isNotEmpty) {
      rows.add(response);
    }
  }

  return rows;
}

List<Object?> _readRecentLeagueMatchesForLeague(
  Directory directory,
  int leagueId,
) {
  if (!directory.existsSync()) {
    return const [];
  }

  final rows = <Object?>[];
  for (final file in directory.listSync().whereType<File>()) {
    final name = file.uri.pathSegments.last;
    final match = RegExp(
      '^recent_fixtures_${leagueId}_(\\d+)\\.json\$',
    ).firstMatch(name);
    if (match == null) {
      continue;
    }

    final teamId = int.tryParse(match.group(1) ?? '');
    if (teamId == null) {
      continue;
    }

    final recentMatches = _normalizeRecentFixturesForTeam(
      teamId,
      _readResponse(file),
    );
    if (recentMatches.isEmpty) {
      continue;
    }

    rows.add({
      'league': {'id': leagueId},
      'team': {'id': teamId},
      'matches': recentMatches,
    });
  }

  return rows;
}

List<Object?> _normalizeRecentFixturesForTeam(
  int teamId,
  List<Object?> fixtures,
) {
  final rows = <Object?>[];

  for (final fixtureJson in fixtures) {
    final root = _asMap(fixtureJson);
    final teams = _asMap(root['teams']);
    final home = _asMap(teams['home']);
    final away = _asMap(teams['away']);
    final homeTeamId = _asInt(home['id']);
    final awayTeamId = _asInt(away['id']);
    final isHome = homeTeamId == teamId;
    final isAway = awayTeamId == teamId;
    if (!isHome && !isAway) {
      continue;
    }

    final opponent = isHome ? away : home;
    final goals = _asMap(root['goals']);
    final homeGoals = _asInt(goals['home']);
    final awayGoals = _asInt(goals['away']);
    final goalsFor = isHome ? homeGoals : awayGoals;
    final goalsAgainst = isHome ? awayGoals : homeGoals;
    final result = _recentResult(goalsFor, goalsAgainst);
    if (result == null) {
      continue;
    }

    rows.add({
      'opponent': {
        'id': _asInt(opponent['id']),
        'name': _asString(opponent['name']),
        'logo': _asString(opponent['logo']),
      },
      'venue': isHome ? 'home' : 'away',
      'result': result,
      'goals': {'for': goalsFor, 'against': goalsAgainst},
    });

    if (rows.length == 5) {
      break;
    }
  }

  return rows;
}

String? _recentResult(int? goalsFor, int? goalsAgainst) {
  if (goalsFor == null || goalsAgainst == null) {
    return null;
  }
  if (goalsFor > goalsAgainst) {
    return 'W';
  }
  if (goalsFor == goalsAgainst) {
    return 'D';
  }
  return 'L';
}

List<Object?> _readResponseIfPresent(File file) {
  if (!file.existsSync()) {
    return const [];
  }

  return _readResponse(file);
}

List<Object?> _readResponse(File file) {
  if (!file.existsSync()) {
    throw StateError('Missing exploration file: ${file.path}');
  }

  final payload = jsonDecode(file.readAsStringSync());
  final response = _asMap(payload)['response'];
  if (response is List<Object?>) {
    return response;
  }

  if (response is List) {
    return response;
  }

  return const [];
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

int? _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

String? _asString(Object? value) {
  if (value == null) {
    return null;
  }
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}
