/// Stable domain keys; provider IDs never identify a sport on their own.
final class SportId {
  const SportId(this.key, this.label);

  static const football = SportId('football', 'Football');
  static const hockey = SportId('hockey', 'Hockey');
  static const basketball = SportId('basketball', 'Basket');
  static const baseball = SportId('baseball', 'Baseball');
  static const americanFootball = SportId(
    'american-football',
    'Football américain',
  );
  static const values = [
    football,
    hockey,
    basketball,
    baseball,
    americanFootball,
  ];

  final String key;
  final String label;

  // The built-in parser is only for historic callers. Runtime navigation
  // resolves keys through the registered module catalog, including new sports.
  static SportId parse(String key) => values.firstWhere(
    (sport) => sport.key == key,
    orElse: () => throw FormatException('Unknown sport: $key'),
  );

  void validate() {
    if (!RegExp(r'^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$').hasMatch(key) ||
        label.trim().isEmpty) {
      throw ArgumentError('A sport needs a stable URL key and a label.');
    }
  }

  @override
  bool operator ==(Object other) => other is SportId && key == other.key;

  @override
  int get hashCode => key.hashCode;
}

enum SportEntityKind { competition, season, team, player, match }

/// IDs may overlap between sports, providers, and entity types.
class SportEntityId {
  SportEntityId({
    required this.sport,
    required this.provider,
    required this.kind,
    required this.value,
  }) {
    if (provider.trim().isEmpty || value.trim().isEmpty) {
      throw ArgumentError('Provider and entity ID must be explicit.');
    }
  }

  final SportId sport;
  final String provider;
  final SportEntityKind kind;
  final String value;

  String get key => [
    sport.key,
    provider,
    kind.name,
    value,
  ].map(Uri.encodeComponent).join(':');

  @override
  bool operator ==(Object other) => other is SportEntityId && key == other.key;

  @override
  int get hashCode => key.hashCode;
}

/// Separate new preferences, caches and selections by identity AND discipline.
/// Football's existing keys remain untouched during the gradual migration.
String sportStorageKey({
  required SportId sport,
  required String identityKey,
  required String resource,
}) => [
  'lector',
  'sports',
  'v1',
  sport.key,
  identityKey,
  resource,
].map(Uri.encodeComponent).join(':');
