import 'dart:convert';
import 'dart:io';

/// Produces a reviewable API-Football competition inventory without printing
/// secrets. It intentionally makes one provider request: GET /leagues.
Future<void> main() async {
  final env = _readEnv(File('.env'));
  final apiKey = env['API_FOOTBALL_KEY'];
  final baseUrl =
      env['API_FOOTBALL_BASE_URL'] ?? 'https://v3.football.api-sports.io';
  final supabaseUrl = env['SUPABASE_URL'];
  final serviceRoleKey = env['SUPABASE_SERVICE_ROLE_KEY'];

  if (apiKey == null || apiKey.isEmpty) {
    stderr.writeln('API_FOOTBALL_KEY is missing from .env.');
    exitCode = 2;
    return;
  }

  final providerResponse = await _get(Uri.parse('$baseUrl/leagues'), {
    'x-apisports-key': apiKey,
  });
  if (providerResponse.statusCode != HttpStatus.ok) {
    stderr.writeln('API-Football returned ${providerResponse.statusCode}.');
    exitCode = 1;
    return;
  }

  final providerPayload =
      jsonDecode(providerResponse.body) as Map<String, dynamic>;
  final rows =
      (providerPayload['response'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(_Competition.fromApi)
          .toList()
        ..sort((left, right) {
          final country = left.country.compareTo(right.country);
          if (country != 0) return country;
          final type = left.type.compareTo(right.type);
          if (type != 0) return type;
          return left.name.compareTo(right.name);
        });

  final generatedAt = DateTime.now().toUtc();
  final stamp = generatedAt.toIso8601String().substring(0, 10);
  final csvFile = File('docs/competition-catalog-api-$stamp.csv');
  final summaryFile = File('docs/competition-catalog-api-$stamp.md');
  csvFile.writeAsStringSync(_toCsv(rows));

  final budgetRows = await _fetchBudgetRows(
    supabaseUrl: supabaseUrl,
    serviceRoleKey: serviceRoleKey,
  );
  summaryFile.writeAsStringSync(
    _toMarkdown(
      generatedAt: generatedAt,
      competitions: rows,
      rateLimitHeaders: providerResponse.headers,
      budgetRows: budgetRows,
      csvPath: csvFile.path,
    ),
  );

  stdout.writeln('COMPETITIONS_TOTAL=${rows.length}');
  stdout.writeln('LEAGUES=${rows.where((row) => row.type == 'League').length}');
  stdout.writeln('CUPS=${rows.where((row) => row.type == 'Cup').length}');
  for (final entry in _readRateLimits(providerResponse.headers).entries) {
    stdout.writeln('${entry.key}=${entry.value}');
  }
  if (budgetRows.isNotEmpty) {
    for (final row in budgetRows) {
      stdout.writeln('BUDGET_${row.date}=${row.requests}');
    }
  } else {
    stdout.writeln('BUDGET=unavailable');
  }
  stdout.writeln('CSV=${csvFile.path}');
  stdout.writeln('SUMMARY=${summaryFile.path}');
}

Map<String, String> _readEnv(File file) {
  final values = <String, String>{};
  for (final line in file.readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final separator = trimmed.indexOf('=');
    if (separator <= 0) continue;
    final rawValue = trimmed.substring(separator + 1).trim();
    final quoted =
        rawValue.length >= 2 &&
        ((rawValue.startsWith('"') && rawValue.endsWith('"')) ||
            (rawValue.startsWith("'") && rawValue.endsWith("'")));
    values[trimmed.substring(0, separator).trim()] = quoted
        ? rawValue.substring(1, rawValue.length - 1)
        : rawValue;
  }
  return values;
}

Future<_HttpResult> _get(Uri uri, Map<String, String> headers) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(uri);
    headers.forEach(request.headers.set);
    final response = await request.close();
    final responseHeaders = <String, String>{};
    response.headers.forEach((name, values) {
      responseHeaders[name.toLowerCase()] = values.join(', ');
    });
    return _HttpResult(
      statusCode: response.statusCode,
      headers: responseHeaders,
      body: await response.transform(utf8.decoder).join(),
    );
  } finally {
    client.close(force: true);
  }
}

Future<List<_BudgetDay>> _fetchBudgetRows({
  required String? supabaseUrl,
  required String? serviceRoleKey,
}) async {
  if (supabaseUrl == null ||
      supabaseUrl.isEmpty ||
      serviceRoleKey == null ||
      serviceRoleKey.isEmpty) {
    return const [];
  }
  final response = await _get(
    Uri.parse(
      '$supabaseUrl/rest/v1/api_football_request_budget_days'
      '?select=budget_date,request_count,updated_at&order=budget_date.desc&limit=3',
    ),
    {'apikey': serviceRoleKey, 'authorization': 'Bearer $serviceRoleKey'},
  );
  if (response.statusCode != HttpStatus.ok) return const [];
  final payload = jsonDecode(response.body) as List<dynamic>;
  return payload
      .whereType<Map>()
      .map(
        (row) => _BudgetDay(
          date: row['budget_date']?.toString() ?? 'unknown',
          requests: (row['request_count'] as num?)?.toInt() ?? 0,
          updatedAt: row['updated_at']?.toString(),
        ),
      )
      .toList(growable: false);
}

Map<String, String> _readRateLimits(Map<String, String> headers) => {
  for (final entry in headers.entries)
    if (entry.key.startsWith('x-ratelimit')) entry.key: entry.value,
};

String _toCsv(List<_Competition> rows) {
  String escape(String value) => '"${value.replaceAll('"', '""')}"';
  final buffer = StringBuffer(
    'api_league_id,name,type,country,country_code,season_count,current_season,logo_url,flag_url\n',
  );
  for (final row in rows) {
    buffer.writeln(
      [
        row.id,
        row.name,
        row.type,
        row.country,
        row.countryCode,
        row.seasonCount,
        row.currentSeason ?? '',
        row.logoUrl,
        row.flagUrl,
      ].map((value) => escape(value.toString())).join(','),
    );
  }
  return buffer.toString();
}

String _toMarkdown({
  required DateTime generatedAt,
  required List<_Competition> competitions,
  required Map<String, String> rateLimitHeaders,
  required List<_BudgetDay> budgetRows,
  required String csvPath,
}) {
  final byType = <String, int>{};
  final byCountry = <String, int>{};
  for (final competition in competitions) {
    byType.update(competition.type, (value) => value + 1, ifAbsent: () => 1);
    byCountry.update(
      competition.country,
      (value) => value + 1,
      ifAbsent: () => 1,
    );
  }
  final topCountries = byCountry.entries.toList()
    ..sort((left, right) => right.value.compareTo(left.value));
  final buffer = StringBuffer()
    ..writeln('# Inventaire API-Football des compétitions')
    ..writeln()
    ..writeln('Généré le `${generatedAt.toIso8601String()}`.')
    ..writeln()
    ..writeln('- Compétitions retournées : **${competitions.length}**')
    ..writeln(
      '- Types : ${byType.entries.map((entry) => '${entry.key} ${entry.value}').join(', ')}',
    )
    ..writeln('- Export complet : `$csvPath`')
    ..writeln()
    ..writeln('## Quota fournisseur après l’inventaire')
    ..writeln();
  if (rateLimitHeaders.isEmpty) {
    buffer.writeln(
      'Aucun en-tête de quota fourni par l’API pour cette requête.',
    );
  } else {
    for (final entry in rateLimitHeaders.entries) {
      buffer.writeln('- `${entry.key}` : `${entry.value}`');
    }
  }
  buffer
    ..writeln()
    ..writeln('## Compteur de requêtes Supabase')
    ..writeln();
  if (budgetRows.isEmpty) {
    buffer.writeln('Indisponible depuis cette configuration locale.');
  } else {
    for (final day in budgetRows) {
      buffer.writeln('- `${day.date}` : **${day.requests}** réservations');
    }
  }
  buffer
    ..writeln()
    ..writeln('## Pays les plus représentés')
    ..writeln()
    ..writeln('| Pays | Compétitions |')
    ..writeln('| --- | ---: |');
  for (final entry in topCountries.take(30)) {
    buffer.writeln('| ${entry.key} | ${entry.value} |');
  }
  return buffer.toString();
}

final class _HttpResult {
  const _HttpResult({
    required this.statusCode,
    required this.headers,
    required this.body,
  });

  final int statusCode;
  final Map<String, String> headers;
  final String body;
}

final class _BudgetDay {
  const _BudgetDay({
    required this.date,
    required this.requests,
    required this.updatedAt,
  });

  final String date;
  final int requests;
  final String? updatedAt;
}

final class _Competition {
  const _Competition({
    required this.id,
    required this.name,
    required this.type,
    required this.country,
    required this.countryCode,
    required this.seasonCount,
    required this.currentSeason,
    required this.logoUrl,
    required this.flagUrl,
  });

  factory _Competition.fromApi(Map row) {
    final league = (row['league'] as Map?) ?? const {};
    final country = (row['country'] as Map?) ?? const {};
    final seasons = (row['seasons'] as List?) ?? const [];
    String? currentSeason;
    for (final season in seasons.whereType<Map>()) {
      if (season['current'] == true) {
        currentSeason = season['year']?.toString();
        break;
      }
    }
    return _Competition(
      id: (league['id'] as num?)?.toInt() ?? -1,
      name: league['name']?.toString() ?? 'Sans nom',
      type: league['type']?.toString() ?? 'Unknown',
      country: country['name']?.toString() ?? 'World',
      countryCode: country['code']?.toString() ?? '',
      seasonCount: seasons.length,
      currentSeason: currentSeason,
      logoUrl: league['logo']?.toString() ?? '',
      flagUrl: country['flag']?.toString() ?? '',
    );
  }

  final int id;
  final String name;
  final String type;
  final String country;
  final String countryCode;
  final int seasonCount;
  final String? currentSeason;
  final String logoUrl;
  final String flagUrl;
}
