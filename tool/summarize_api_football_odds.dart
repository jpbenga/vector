import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final baseDir = Directory('var/api_football_exploration');
  if (!baseDir.existsSync()) {
    stderr.writeln('No API-Football exploration directory found.');
    exitCode = 1;
    return;
  }

  final bookmakers = _readRows(
    File('var/api_football_exploration/2026-07-30/odds_bookmakers.json'),
  ).map(_asMap).toList();
  final bets = _readRows(
    File('var/api_football_exploration/2026-07-30/odds_bets.json'),
  ).map(_asMap).toList();

  final observedBookmakers = <int, String>{};
  final observedMarkets = <int, _ObservedMarket>{};

  for (final file
      in baseDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.split('/').last.startsWith('odds_'))
          .where((file) => !file.path.endsWith('odds_bookmakers.json'))
          .where((file) => !file.path.endsWith('odds_bets.json'))) {
    for (final fixtureOdds in _readRows(file).map(_asMap)) {
      for (final bookmakerJson in _asList(fixtureOdds['bookmakers'])) {
        final bookmaker = _asMap(bookmakerJson);
        final bookmakerId = _asInt(bookmaker['id']);
        if (bookmakerId == null) {
          continue;
        }

        observedBookmakers[bookmakerId] =
            _asString(bookmaker['name']) ?? 'Unknown';

        for (final betJson in _asList(bookmaker['bets'])) {
          final bet = _asMap(betJson);
          final betId = _asInt(bet['id']);
          if (betId == null) {
            continue;
          }

          final market = observedMarkets.putIfAbsent(
            betId,
            () => _ObservedMarket(
              id: betId,
              name: _asString(bet['name']) ?? 'Unknown',
            ),
          );
          market.fixtureCount += 1;
          market.bookmakerIds.add(bookmakerId);

          for (final valueJson in _asList(bet['values'])) {
            final value = _asString(_asMap(valueJson)['value']);
            if (value != null) {
              market.values.add(value);
            }
          }
        }
      }
    }
  }

  File('docs/api-football-odds-normalization.md')
    ..createSync(recursive: true)
    ..writeAsStringSync(
      _toMarkdown(
        bookmakers: bookmakers,
        bets: bets,
        observedBookmakers: observedBookmakers,
        observedMarkets: observedMarkets,
      ),
    );

  stdout.writeln('Odds normalization summary complete.');
  stdout.writeln('Summary: docs/api-football-odds-normalization.md');
}

String _toMarkdown({
  required List<Map<String, Object?>> bookmakers,
  required List<Map<String, Object?>> bets,
  required Map<int, String> observedBookmakers,
  required Map<int, _ObservedMarket> observedMarkets,
}) {
  final buffer = StringBuffer()
    ..writeln('# Normalisation bookmakers et marchés API-Football')
    ..writeln()
    ..writeln('## Catalogues récupérés')
    ..writeln()
    ..writeln('- Bookmakers API-Football : `${bookmakers.length}`')
    ..writeln('- Marchés API-Football : `${bets.length}`')
    ..writeln(
      '- Bookmakers observés dans les snapshots de cotes : `${observedBookmakers.length}`',
    )
    ..writeln(
      '- Marchés observés dans les snapshots de cotes : `${observedMarkets.length}`',
    )
    ..writeln()
    ..writeln('Les catalogues bruts complets sont sauvegardés ici :')
    ..writeln()
    ..writeln(
      '- `var/api_football_exploration/2026-07-30/odds_bookmakers.json`',
    )
    ..writeln('- `var/api_football_exploration/2026-07-30/odds_bets.json`')
    ..writeln()
    ..writeln('## Bookmakers API-Football')
    ..writeln()
    ..writeln('| ID | Nom | Observé dans les snapshots |')
    ..writeln('|---:|---|---|');

  for (final bookmaker in bookmakers) {
    final id = _asInt(bookmaker['id']);
    final name = _asString(bookmaker['name']) ?? 'Non renseigné';
    buffer.writeln(
      '| $id | $name | ${observedBookmakers.containsKey(id) ? 'oui' : 'non'} |',
    );
  }

  final priorityMarketIds = [1, 2, 5, 8, 12, 16, 17, 45, 55, 80];
  buffer
    ..writeln()
    ..writeln('## Marchés prioritaires pour le MVP')
    ..writeln()
    ..writeln(
      '| ID API | Libellé API | Marché interne proposé | Valeurs normalisées |',
    )
    ..writeln('|---:|---|---|---|');

  for (final id in priorityMarketIds) {
    final bet = bets.firstWhere(
      (bet) => _asInt(bet['id']) == id,
      orElse: () => const {},
    );
    buffer.writeln(
      '| $id | ${_asString(bet['name']) ?? 'Inconnu'} | ${_internalMarket(id)} | ${_normalizedValues(id)} |',
    );
  }

  buffer
    ..writeln()
    ..writeln('## Marchés observés dans les snapshots')
    ..writeln()
    ..writeln(
      '| ID API | Libellé observé | Fixtures/bookmakers | Exemples de valeurs brutes |',
    )
    ..writeln('|---:|---|---:|---|');

  final observed = observedMarkets.values.toList()
    ..sort((a, b) => a.id.compareTo(b.id));
  for (final market in observed.take(80)) {
    buffer.writeln(
      '| ${market.id} | ${market.name} | ${market.fixtureCount}/${market.bookmakerIds.length} | ${market.values.take(10).join(', ')} |',
    );
  }

  buffer
    ..writeln()
    ..writeln('## Décisions techniques')
    ..writeln()
    ..writeln(
      '- Le bookmaker doit être une dimension de la cote, pas une source de vérité métier.',
    )
    ..writeln(
      '- Le moteur doit consommer `InternalMarketId` + `InternalSelectionId`, jamais le libellé brut.',
    )
    ..writeln(
      '- Les IDs API-Football des marchés sont stables pour une première normalisation, mais les `values` doivent être mappées par marché.',
    )
    ..writeln(
      '- Une même intention produit peut venir de plusieurs marchés API : par exemple `match_result`, `home_away`, `double_chance`, `result_total_goals`.',
    )
    ..writeln(
      '- Les marchés corners et cartons entrent dans le MVP : `corners_total`, `corners_match_result`, `cards_total`.',
    )
    ..writeln(
      '- Les marchés handicap/asiatiques et les marchés combinés doivent rester hors MVP tant que la convention de ligne, de signe et de composition n’est pas verrouillée.',
    );

  return buffer.toString();
}

String _internalMarket(int apiBetId) {
  return switch (apiBetId) {
    1 => '`match_result`',
    2 => '`home_away_no_draw`',
    5 => '`goals_total`',
    8 => '`both_teams_score`',
    12 => '`double_chance`',
    16 => '`team_total_home`',
    17 => '`team_total_away`',
    45 => '`corners_total`',
    55 => '`corners_match_result`',
    80 => '`cards_total`',
    _ => '`unsupported`',
  };
}

String _normalizedValues(int apiBetId) {
  return switch (apiBetId) {
    1 => '`home`, `draw`, `away`',
    2 => '`home`, `away`',
    5 => '`over:{line}`, `under:{line}`',
    8 => '`yes`, `no`',
    12 => '`home_or_draw`, `home_or_away`, `draw_or_away`',
    16 => '`home_over:{line}`, `home_under:{line}`',
    17 => '`away_over:{line}`, `away_under:{line}`',
    45 => '`over:{line}`, `under:{line}`',
    55 => '`home`, `draw`, `away`',
    80 => '`over:{line}`, `under:{line}`',
    _ => '`unsupported`',
  };
}

class _ObservedMarket {
  _ObservedMarket({required this.id, required this.name});

  final int id;
  final String name;
  final Set<int> bookmakerIds = {};
  final Set<String> values = {};
  int fixtureCount = 0;
}

List<Object?> _readRows(File file) {
  if (!file.existsSync()) {
    return const [];
  }

  final payload = jsonDecode(file.readAsStringSync());
  return _asList(_asMap(payload)['response']);
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
