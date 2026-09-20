import 'dart:io';

/// Builds the human-reviewable target scope from the full API-Football audit.
/// No network request is made: it only reads the generated catalog CSV.
void main() {
  const input = 'docs/competition-catalog-api-2026-09-19.csv';
  const markdownOutput = 'docs/competition-scope-approved.md';
  const csvOutput = 'docs/competition-scope-approved.csv';

  final competitions = _readInventory(File(input));
  final sections = <_ScopeSection>[
    _ScopeSection('Déjà suivies par l’application', const [
      2,
      3,
      848,
      39,
      61,
      140,
      78,
      135,
      94,
      95,
      88,
      144,
      179,
      203,
      197,
      119,
      207,
      218,
      40,
      62,
      136,
      79,
      141,
      106,
      210,
      209,
      283,
      253,
      71,
      128,
      262,
      307,
      98,
      188,
      103,
      113,
      164,
      169,
      244,
      292,
    ], 'conserver'),
    _ScopeSection('Ajout validé — clubs européens', const [531], 'conserver'),
    _ScopeSection(
      'Ajout validé — coupes nationales européennes masculines',
      const [
        45, 48, 528, // Angleterre
        66, 526, // France
        81, 529, // Allemagne
        96, 550, // Portugal
        143, 556, // Espagne
        137, 547, // Italie
        90, 543, // Pays-Bas
        147, 519, // Belgique
        181, 185, // Écosse
        // Schweizer Cup (209) est déjà suivie par l’application.
        551, // Turquie
      ],
      'conserver',
    ),
    _ScopeSection('Ajout validé — sélections masculines', const [
      1, 32, // Coupe du Monde et qualifications Europe
      4, 5, // Euro et Ligue des Nations UEFA
      9, 6, 7, 22, 536, // Amériques, Afrique, Asie et CONCACAF
    ], 'conserver'),
    _ScopeSection('Ajout validé — championnat féminin', const [
      64,
    ], 'conserver'),
    _ScopeSection(
      'Ajout validé — compétitions féminines internationales',
      const [
        525, // UEFA Champions League Women
        1191, // UEFA Europa Cup Women
        8, // World Cup - Women
      ],
      'conserver',
    ),
  ];

  final resolved = <_ResolvedScopeEntry>[];
  for (final section in sections) {
    for (final id in section.ids) {
      final competition = competitions[id];
      if (competition == null) {
        throw StateError('API competition $id is missing from $input.');
      }
      resolved.add(_ResolvedScopeEntry(section, competition));
    }
  }

  File(markdownOutput).writeAsStringSync(_toMarkdown(resolved));
  File(csvOutput).writeAsStringSync(_toCsv(resolved));
  stdout.writeln('TOTAL=${resolved.length}');
  stdout.writeln('MARKDOWN=$markdownOutput');
  stdout.writeln('CSV=$csvOutput');
}

Map<int, _Competition> _readInventory(File file) {
  final rows = <int, _Competition>{};
  for (final line in file.readAsLinesSync().skip(1)) {
    final cells = _parseCsvRow(line);
    if (cells.length < 7) continue;
    final id = int.tryParse(cells[0]);
    if (id == null) continue;
    rows[id] = _Competition(
      id: id,
      name: cells[1],
      type: cells[2],
      country: cells[3],
      season: cells[6],
    );
  }
  return rows;
}

List<String> _parseCsvRow(String line) {
  final cells = <String>[];
  final buffer = StringBuffer();
  var quoted = false;
  for (var index = 0; index < line.length; index++) {
    final character = line[index];
    if (character == '"') {
      if (quoted && index + 1 < line.length && line[index + 1] == '"') {
        buffer.write('"');
        index++;
      } else {
        quoted = !quoted;
      }
    } else if (character == ',' && !quoted) {
      cells.add(buffer.toString());
      buffer.clear();
    } else {
      buffer.write(character);
    }
  }
  cells.add(buffer.toString());
  return cells;
}

String _toMarkdown(List<_ResolvedScopeEntry> entries) {
  final grouped = <String, List<_ResolvedScopeEntry>>{};
  for (final entry in entries) {
    grouped.putIfAbsent(entry.section.title, () => []).add(entry);
  }
  final buffer = StringBuffer()
    ..writeln('# Périmètre approuvé des compétitions')
    ..writeln()
    ..writeln(
      'Périmètre validé à partir de l’inventaire API-Football du 19 septembre 2026.',
    )
    ..writeln()
    ..writeln(
      '**${entries.length} compétitions** : 40 déjà suivies et ${entries.length - 40} ajouts validés.',
    )
    ..writeln()
    ..writeln(
      'Ce périmètre servira de source pour la carte d’identité : couleur propriétaire, cadre et cartouche.',
    )
    ..writeln();
  for (final section in grouped.entries) {
    buffer
      ..writeln('## ${section.key}')
      ..writeln()
      ..writeln('| ID API | Compétition | Pays | Type | Saison API | Statut |')
      ..writeln('| ---: | --- | --- | --- | --- | --- |');
    for (final entry in section.value) {
      final item = entry.competition;
      buffer.writeln(
        '| ${item.id} | ${item.name} | ${item.country} | ${item.type} | ${item.season.isEmpty ? '—' : item.season} | ${entry.section.status} |',
      );
    }
    buffer.writeln();
  }
  return buffer.toString();
}

String _toCsv(List<_ResolvedScopeEntry> entries) {
  String quote(String value) => '"${value.replaceAll('"', '""')}"';
  final buffer = StringBuffer(
    'api_league_id,competition,country,type,current_season,origin,decision,notes\n',
  );
  for (final entry in entries) {
    final item = entry.competition;
    buffer.writeln(
      [
        item.id,
        item.name,
        item.country,
        item.type,
        item.season,
        entry.section.status,
        '',
        '',
      ].map((value) => quote(value.toString())).join(','),
    );
  }
  return buffer.toString();
}

final class _ScopeSection {
  const _ScopeSection(this.title, this.ids, this.status);

  final String title;
  final List<int> ids;
  final String status;
}

final class _Competition {
  const _Competition({
    required this.id,
    required this.name,
    required this.type,
    required this.country,
    required this.season,
  });

  final int id;
  final String name;
  final String type;
  final String country;
  final String season;
}

final class _ResolvedScopeEntry {
  const _ResolvedScopeEntry(this.section, this.competition);

  final _ScopeSection section;
  final _Competition competition;
}
