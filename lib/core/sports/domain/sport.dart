/// Stable domain keys; provider IDs never identify a sport on their own.
enum SportId {
  football('football', 'Football'),
  hockey('hockey', 'Hockey'),
  basketball('basketball', 'Basket'),
  baseball('baseball', 'Baseball'),
  americanFootball('american-football', 'Football américain');

  const SportId(this.key, this.label);
  final String key;
  final String label;

  static SportId parse(String key) => values.firstWhere(
    (sport) => sport.key == key,
    orElse: () => throw FormatException('Unknown sport: $key'),
  );
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
