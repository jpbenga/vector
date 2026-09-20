import '../../matches/domain/football_scenario.dart';

enum ProfileConfigurationState { notStarted, inProgress, completed }

enum PickType { prudent, normal, audacious }

class PickTypeOddsBand {
  const PickTypeOddsBand({
    required this.id,
    required this.minimumOdds,
    required this.maximumOdds,
  });

  final PickType id;
  final double minimumOdds;
  final double? maximumOdds;

  bool contains(double odds) {
    final normalizedOdds = _normalizeOdds(odds);
    final upperBound = maximumOdds;

    return normalizedOdds >= minimumOdds &&
        (upperBound == null || normalizedOdds <= upperBound);
  }
}

class PickTypeCatalog {
  const PickTypeCatalog._();

  static const prudent = PickTypeOddsBand(
    id: PickType.prudent,
    minimumOdds: 0,
    maximumOdds: 1.49,
  );

  static const normal = PickTypeOddsBand(
    id: PickType.normal,
    minimumOdds: 1.50,
    maximumOdds: 2.19,
  );

  static const audacious = PickTypeOddsBand(
    id: PickType.audacious,
    minimumOdds: 2.20,
    maximumOdds: null,
  );

  static const values = [prudent, normal, audacious];

  static PickTypeOddsBand? byId(String id) {
    final normalizedId = id.trim().toLowerCase();

    return switch (normalizedId) {
      'prudent' => prudent,
      'normal' => normal,
      'audacious' || 'audacieux' => audacious,
      _ => null,
    };
  }
}

class DecisionCompetitionDefinition {
  const DecisionCompetitionDefinition({
    required this.name,
    required this.apiFootballLeagueId,
    this.legacyIds = const [],
  });

  final String name;
  final int apiFootballLeagueId;
  final List<String> legacyIds;

  String get id => apiFootballLeagueId.toString();

  CompetitionCountryDefinition get country =>
      CompetitionCountryCatalog.byLeagueId(apiFootballLeagueId);

  String get countryCode => country.code;
  String get countryName => country.name;
  String get flagUrl => country.flagUrl;
  String get logoUrl =>
      'https://media.api-sports.io/football/leagues/$apiFootballLeagueId.png';
}

class CompetitionCountryDefinition {
  const CompetitionCountryDefinition({
    required this.code,
    required this.name,
    this.apiFlagCode,
  });

  final String code;
  final String name;
  final String? apiFlagCode;

  String get flagUrl {
    final resolvedCode = apiFlagCode ?? code;
    if (resolvedCode == 'world') {
      return '';
    }

    return 'https://media.api-sports.io/flags/$resolvedCode.svg';
  }
}

class CompetitionCountryCatalog {
  const CompetitionCountryCatalog._();

  static const unknown = CompetitionCountryDefinition(
    code: 'world',
    name: 'International',
  );

  static CompetitionCountryDefinition byLeagueId(int leagueId) {
    return _countries[_leagueCountryCodes[leagueId]] ?? unknown;
  }

  static const _countries = {
    'ar': CompetitionCountryDefinition(code: 'ar', name: 'Argentine'),
    'au': CompetitionCountryDefinition(code: 'au', name: 'Australie'),
    'at': CompetitionCountryDefinition(code: 'at', name: 'Autriche'),
    'be': CompetitionCountryDefinition(code: 'be', name: 'Belgique'),
    'br': CompetitionCountryDefinition(code: 'br', name: 'Bresil'),
    'bg': CompetitionCountryDefinition(code: 'bg', name: 'Bulgarie'),
    'cl': CompetitionCountryDefinition(code: 'cl', name: 'Chili'),
    'cn': CompetitionCountryDefinition(code: 'cn', name: 'Chine'),
    'co': CompetitionCountryDefinition(code: 'co', name: 'Colombie'),
    'kr': CompetitionCountryDefinition(code: 'kr', name: 'Coree du Sud'),
    'hr': CompetitionCountryDefinition(code: 'hr', name: 'Croatie'),
    'dk': CompetitionCountryDefinition(code: 'dk', name: 'Danemark'),
    'gb': CompetitionCountryDefinition(code: 'gb', name: 'Royaume-Uni'),
    'ec': CompetitionCountryDefinition(code: 'ec', name: 'Equateur'),
    'es': CompetitionCountryDefinition(code: 'es', name: 'Espagne'),
    'ee': CompetitionCountryDefinition(code: 'ee', name: 'Estonie'),
    'us': CompetitionCountryDefinition(code: 'us', name: 'Etats-Unis'),
    'fi': CompetitionCountryDefinition(code: 'fi', name: 'Finlande'),
    'fr': CompetitionCountryDefinition(code: 'fr', name: 'France'),
    'ge': CompetitionCountryDefinition(code: 'ge', name: 'Georgie'),
    'de': CompetitionCountryDefinition(code: 'de', name: 'Allemagne'),
    'gr': CompetitionCountryDefinition(code: 'gr', name: 'Grece'),
    'hu': CompetitionCountryDefinition(code: 'hu', name: 'Hongrie'),
    'ie': CompetitionCountryDefinition(code: 'ie', name: 'Irlande'),
    'is': CompetitionCountryDefinition(code: 'is', name: 'Islande'),
    'it': CompetitionCountryDefinition(code: 'it', name: 'Italie'),
    'jp': CompetitionCountryDefinition(code: 'jp', name: 'Japon'),
    'lt': CompetitionCountryDefinition(code: 'lt', name: 'Lituanie'),
    'mx': CompetitionCountryDefinition(code: 'mx', name: 'Mexique'),
    'nl': CompetitionCountryDefinition(code: 'nl', name: 'Pays-Bas'),
    'no': CompetitionCountryDefinition(code: 'no', name: 'Norvege'),
    'py': CompetitionCountryDefinition(code: 'py', name: 'Paraguay'),
    'pl': CompetitionCountryDefinition(code: 'pl', name: 'Pologne'),
    'pt': CompetitionCountryDefinition(code: 'pt', name: 'Portugal'),
    'cz': CompetitionCountryDefinition(code: 'cz', name: 'Republique tcheque'),
    'ro': CompetitionCountryDefinition(code: 'ro', name: 'Roumanie'),
    'sa': CompetitionCountryDefinition(code: 'sa', name: 'Arabie saoudite'),
    'rs': CompetitionCountryDefinition(code: 'rs', name: 'Serbie'),
    'sk': CompetitionCountryDefinition(code: 'sk', name: 'Slovaquie'),
    'si': CompetitionCountryDefinition(code: 'si', name: 'Slovenie'),
    'se': CompetitionCountryDefinition(code: 'se', name: 'Suede'),
    'ch': CompetitionCountryDefinition(code: 'ch', name: 'Suisse'),
    'tr': CompetitionCountryDefinition(code: 'tr', name: 'Turquie'),
    'ua': CompetitionCountryDefinition(code: 'ua', name: 'Ukraine'),
    'wls': CompetitionCountryDefinition(
      code: 'wls',
      name: 'Pays de Galles',
      apiFlagCode: 'gb-wls',
    ),
  };

  static const _leagueCountryCodes = {
    78: 'de',
    79: 'de',
    81: 'de',
    529: 'de',
    39: 'gb',
    40: 'gb',
    45: 'gb',
    48: 'gb',
    528: 'gb',
    307: 'sa',
    128: 'ar',
    218: 'at',
    144: 'be',
    147: 'be',
    519: 'be',
    71: 'br',
    172: 'bg',
    265: 'cl',
    169: 'cn',
    239: 'co',
    292: 'kr',
    210: 'hr',
    119: 'dk',
    179: 'gb',
    181: 'gb',
    185: 'gb',
    240: 'ec',
    140: 'es',
    141: 'es',
    143: 'es',
    556: 'es',
    327: 'ee',
    253: 'us',
    244: 'fi',
    61: 'fr',
    62: 'fr',
    64: 'fr',
    66: 'fr',
    526: 'fr',
    329: 'ge',
    197: 'gr',
    271: 'hu',
    357: 'ie',
    164: 'is',
    135: 'it',
    136: 'it',
    137: 'it',
    547: 'it',
    98: 'jp',
    331: 'lt',
    262: 'mx',
    103: 'no',
    284: 'py',
    88: 'nl',
    90: 'nl',
    543: 'nl',
    110: 'wls',
    106: 'pl',
    94: 'pt',
    95: 'pt',
    96: 'pt',
    550: 'pt',
    345: 'cz',
    283: 'ro',
    286: 'rs',
    334: 'sk',
    373: 'si',
    113: 'se',
    207: 'ch',
    209: 'ch',
    203: 'tr',
    551: 'tr',
    235: 'ua',
  };
}

class CompetitionCatalog {
  const CompetitionCatalog._();

  static const values = [
    DecisionCompetitionDefinition(
      name: 'UEFA Champions League',
      apiFootballLeagueId: 2,
    ),
    DecisionCompetitionDefinition(
      name: 'UEFA Europa League',
      apiFootballLeagueId: 3,
    ),
    DecisionCompetitionDefinition(
      name: 'UEFA Europa Conference League',
      apiFootballLeagueId: 848,
    ),
    DecisionCompetitionDefinition(
      name: 'Bundesliga',
      apiFootballLeagueId: 78,
      legacyIds: ['ger_bundesliga'],
    ),
    DecisionCompetitionDefinition(
      name: 'Bundesliga 2',
      apiFootballLeagueId: 79,
      legacyIds: ['ger_2_bundesliga'],
    ),
    DecisionCompetitionDefinition(
      name: 'Premier League',
      apiFootballLeagueId: 39,
      legacyIds: ['eng_premier_league'],
    ),
    DecisionCompetitionDefinition(
      name: 'Championship',
      apiFootballLeagueId: 40,
      legacyIds: ['eng_championship'],
    ),
    DecisionCompetitionDefinition(
      name: 'Saudi Pro League',
      apiFootballLeagueId: 307,
    ),
    DecisionCompetitionDefinition(
      name: 'Liga Profesional',
      apiFootballLeagueId: 128,
    ),
    DecisionCompetitionDefinition(
      name: 'Bundesliga (Autriche)',
      apiFootballLeagueId: 218,
    ),
    DecisionCompetitionDefinition(name: 'Pro League', apiFootballLeagueId: 144),
    DecisionCompetitionDefinition(
      name: 'Serie A (Bresil)',
      apiFootballLeagueId: 71,
    ),
    DecisionCompetitionDefinition(name: 'Parva Liga', apiFootballLeagueId: 172),
    DecisionCompetitionDefinition(
      name: 'Primera Division (Chili)',
      apiFootballLeagueId: 265,
    ),
    DecisionCompetitionDefinition(
      name: 'Super League (Chine)',
      apiFootballLeagueId: 169,
    ),
    DecisionCompetitionDefinition(name: 'Primera A', apiFootballLeagueId: 239),
    DecisionCompetitionDefinition(name: 'K League 1', apiFootballLeagueId: 292),
    DecisionCompetitionDefinition(name: 'HNL', apiFootballLeagueId: 210),
    DecisionCompetitionDefinition(name: 'Superliga', apiFootballLeagueId: 119),
    DecisionCompetitionDefinition(
      name: 'Premiership',
      apiFootballLeagueId: 179,
    ),
    DecisionCompetitionDefinition(name: 'Liga Pro', apiFootballLeagueId: 240),
    DecisionCompetitionDefinition(
      name: 'La Liga',
      apiFootballLeagueId: 140,
      legacyIds: ['esp_laliga'],
    ),
    DecisionCompetitionDefinition(
      name: 'La Liga 2',
      apiFootballLeagueId: 141,
      legacyIds: ['esp_laliga_2'],
    ),
    DecisionCompetitionDefinition(
      name: 'Meistriliiga',
      apiFootballLeagueId: 327,
    ),
    DecisionCompetitionDefinition(name: 'MLS', apiFootballLeagueId: 253),
    DecisionCompetitionDefinition(
      name: 'Veikkausliga',
      apiFootballLeagueId: 244,
    ),
    DecisionCompetitionDefinition(
      name: 'Ligue 1',
      apiFootballLeagueId: 61,
      legacyIds: ['fr_ligue_1'],
    ),
    DecisionCompetitionDefinition(
      name: 'Ligue 2',
      apiFootballLeagueId: 62,
      legacyIds: ['fr_ligue_2'],
    ),
    DecisionCompetitionDefinition(
      name: 'Erovnuli Liga',
      apiFootballLeagueId: 329,
    ),
    DecisionCompetitionDefinition(
      name: 'Super League (Grece)',
      apiFootballLeagueId: 197,
    ),
    DecisionCompetitionDefinition(
      name: 'OTP Bank Liga',
      apiFootballLeagueId: 271,
    ),
    DecisionCompetitionDefinition(
      name: 'Premier Division',
      apiFootballLeagueId: 357,
    ),
    DecisionCompetitionDefinition(
      name: 'Besta deild karla',
      apiFootballLeagueId: 164,
    ),
    DecisionCompetitionDefinition(
      name: 'Serie A',
      apiFootballLeagueId: 135,
      legacyIds: ['ita_serie_a'],
    ),
    DecisionCompetitionDefinition(
      name: 'Serie B',
      apiFootballLeagueId: 136,
      legacyIds: ['ita_serie_b'],
    ),
    DecisionCompetitionDefinition(name: 'J1 League', apiFootballLeagueId: 98),
    DecisionCompetitionDefinition(name: 'A Lyga', apiFootballLeagueId: 331),
    DecisionCompetitionDefinition(name: 'Liga MX', apiFootballLeagueId: 262),
    DecisionCompetitionDefinition(
      name: 'Eliteserien',
      apiFootballLeagueId: 103,
    ),
    DecisionCompetitionDefinition(
      name: 'Primera Division (Paraguay)',
      apiFootballLeagueId: 284,
    ),
    DecisionCompetitionDefinition(
      name: 'Eredivisie',
      apiFootballLeagueId: 88,
      legacyIds: ['ned_eredivisie'],
    ),
    DecisionCompetitionDefinition(
      name: 'Cymru Premier',
      apiFootballLeagueId: 110,
    ),
    DecisionCompetitionDefinition(
      name: 'Ekstraklasa',
      apiFootballLeagueId: 106,
    ),
    DecisionCompetitionDefinition(
      name: 'Liga Portugal',
      apiFootballLeagueId: 94,
      legacyIds: ['por_liga_portugal'],
    ),
    DecisionCompetitionDefinition(
      name: 'Liga Portugal 2',
      apiFootballLeagueId: 95,
      legacyIds: ['por_liga_2'],
    ),
    DecisionCompetitionDefinition(
      name: 'Fortuna Liga',
      apiFootballLeagueId: 345,
    ),
    DecisionCompetitionDefinition(name: 'Liga 1', apiFootballLeagueId: 283),
    DecisionCompetitionDefinition(name: 'Super Liga', apiFootballLeagueId: 286),
    DecisionCompetitionDefinition(name: 'Nike Liga', apiFootballLeagueId: 334),
    DecisionCompetitionDefinition(name: 'Prva Liga', apiFootballLeagueId: 373),
    DecisionCompetitionDefinition(
      name: 'Allsvenskan',
      apiFootballLeagueId: 113,
    ),
    DecisionCompetitionDefinition(
      name: 'Super League (Suisse)',
      apiFootballLeagueId: 207,
    ),
    DecisionCompetitionDefinition(name: 'Super Lig', apiFootballLeagueId: 203),
    DecisionCompetitionDefinition(
      name: 'Premier League (Ukraine)',
      apiFootballLeagueId: 235,
    ),
    DecisionCompetitionDefinition(
      name: 'Schweizer Cup',
      apiFootballLeagueId: 209,
    ),
    DecisionCompetitionDefinition(name: 'A-League', apiFootballLeagueId: 188),
    // Approved expansion: national cups, international competitions and the
    // selected women's scope. These IDs feed the same API-Football pipeline as
    // domestic leagues; the active subset is declared below.
    DecisionCompetitionDefinition(
      name: 'UEFA Super Cup',
      apiFootballLeagueId: 531,
    ),
    DecisionCompetitionDefinition(name: 'FA Cup', apiFootballLeagueId: 45),
    DecisionCompetitionDefinition(name: 'League Cup', apiFootballLeagueId: 48),
    DecisionCompetitionDefinition(
      name: 'Community Shield',
      apiFootballLeagueId: 528,
    ),
    DecisionCompetitionDefinition(
      name: 'Coupe de France',
      apiFootballLeagueId: 66,
    ),
    DecisionCompetitionDefinition(
      name: 'Trophée des Champions',
      apiFootballLeagueId: 526,
    ),
    DecisionCompetitionDefinition(name: 'DFB Pokal', apiFootballLeagueId: 81),
    DecisionCompetitionDefinition(
      name: 'Super Cup (Allemagne)',
      apiFootballLeagueId: 529,
    ),
    DecisionCompetitionDefinition(
      name: 'Taça de Portugal',
      apiFootballLeagueId: 96,
    ),
    DecisionCompetitionDefinition(
      name: 'Super Cup (Portugal)',
      apiFootballLeagueId: 550,
    ),
    DecisionCompetitionDefinition(
      name: 'Copa del Rey',
      apiFootballLeagueId: 143,
    ),
    DecisionCompetitionDefinition(
      name: 'Super Cup (Espagne)',
      apiFootballLeagueId: 556,
    ),
    DecisionCompetitionDefinition(
      name: 'Coppa Italia',
      apiFootballLeagueId: 137,
    ),
    DecisionCompetitionDefinition(
      name: 'Super Cup (Italie)',
      apiFootballLeagueId: 547,
    ),
    DecisionCompetitionDefinition(name: 'KNVB Beker', apiFootballLeagueId: 90),
    DecisionCompetitionDefinition(
      name: 'Super Cup (Pays-Bas)',
      apiFootballLeagueId: 543,
    ),
    DecisionCompetitionDefinition(
      name: 'Coupe de Belgique',
      apiFootballLeagueId: 147,
    ),
    DecisionCompetitionDefinition(
      name: 'Super Cup (Belgique)',
      apiFootballLeagueId: 519,
    ),
    DecisionCompetitionDefinition(
      name: 'FA Cup (Écosse)',
      apiFootballLeagueId: 181,
    ),
    DecisionCompetitionDefinition(
      name: 'League Cup (Écosse)',
      apiFootballLeagueId: 185,
    ),
    DecisionCompetitionDefinition(
      name: 'Super Cup (Turquie)',
      apiFootballLeagueId: 551,
    ),
    DecisionCompetitionDefinition(
      name: 'Coupe du Monde',
      apiFootballLeagueId: 1,
    ),
    DecisionCompetitionDefinition(
      name: 'Qualifications Coupe du Monde Europe',
      apiFootballLeagueId: 32,
    ),
    DecisionCompetitionDefinition(name: 'Euro', apiFootballLeagueId: 4),
    DecisionCompetitionDefinition(
      name: 'UEFA Nations League',
      apiFootballLeagueId: 5,
    ),
    DecisionCompetitionDefinition(name: 'Copa America', apiFootballLeagueId: 9),
    DecisionCompetitionDefinition(
      name: 'Coupe d’Afrique des Nations',
      apiFootballLeagueId: 6,
    ),
    DecisionCompetitionDefinition(name: 'Coupe d’Asie', apiFootballLeagueId: 7),
    DecisionCompetitionDefinition(
      name: 'CONCACAF Gold Cup',
      apiFootballLeagueId: 22,
    ),
    DecisionCompetitionDefinition(
      name: 'CONCACAF Nations League',
      apiFootballLeagueId: 536,
    ),
    DecisionCompetitionDefinition(
      name: 'Première Ligue féminine',
      apiFootballLeagueId: 64,
    ),
    DecisionCompetitionDefinition(
      name: 'UEFA Champions League Women',
      apiFootballLeagueId: 525,
    ),
    DecisionCompetitionDefinition(
      name: 'UEFA Europa Cup Women',
      apiFootballLeagueId: 1191,
    ),
    DecisionCompetitionDefinition(
      name: 'Coupe du Monde féminine',
      apiFootballLeagueId: 8,
    ),
  ];

  static DecisionCompetitionDefinition? byApiFootballLeagueId(int id) {
    for (final definition in values) {
      if (definition.apiFootballLeagueId == id) {
        return definition;
      }
    }

    return null;
  }

  static String? resolveId(String optionId) {
    final normalizedId = optionId.trim();
    for (final definition in values) {
      if (definition.id == normalizedId ||
          definition.legacyIds.contains(normalizedId)) {
        return definition.id;
      }
    }

    return null;
  }
}

class RuntimeCompetitionCatalog {
  const RuntimeCompetitionCatalog._();

  static const apiFootballLeagueIds = [
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
    // Clubs européens et coupes nationales.
    531,
    45,
    48,
    528,
    66,
    526,
    81,
    529,
    96,
    550,
    143,
    556,
    137,
    547,
    90,
    543,
    147,
    519,
    181,
    185,
    551,
    // Sélections masculines.
    1,
    32,
    4,
    5,
    9,
    6,
    7,
    22,
    536,
    // Périmètre féminin validé.
    64,
    525,
    1191,
    8,
  ];

  static final Set<int> _apiFootballLeagueIdSet = Set.unmodifiable(
    apiFootballLeagueIds,
  );

  static final List<DecisionCompetitionDefinition> values = List.unmodifiable(
    CompetitionCatalog.values.where(
      (definition) =>
          _apiFootballLeagueIdSet.contains(definition.apiFootballLeagueId),
    ),
  );

  static String? resolveId(String optionId) {
    final id = CompetitionCatalog.resolveId(optionId);
    final leagueId = id == null ? null : int.tryParse(id);
    if (leagueId == null || !_apiFootballLeagueIdSet.contains(leagueId)) {
      return null;
    }

    return id;
  }
}

class DecisionMarketDefinition {
  const DecisionMarketDefinition({
    required this.id,
    required this.sourceOptionIds,
    this.isPlayerMarket = false,
  });

  final String id;
  final List<String> sourceOptionIds;
  final bool isPlayerMarket;
}

class MarketCatalog {
  const MarketCatalog._();

  static const values = [
    DecisionMarketDefinition(
      id: 'matchResult',
      sourceOptionIds: ['match_result'],
    ),
    DecisionMarketDefinition(
      id: 'bothTeamsScore',
      sourceOptionIds: ['both_teams_score'],
    ),
    DecisionMarketDefinition(
      id: 'teamTotalHome',
      sourceOptionIds: ['team_scores'],
    ),
    DecisionMarketDefinition(
      id: 'teamTotalAway',
      sourceOptionIds: ['team_scores'],
    ),
    DecisionMarketDefinition(
      id: 'goalsTotal',
      sourceOptionIds: ['goals_over_under'],
    ),
    DecisionMarketDefinition(id: 'cornersTotal', sourceOptionIds: ['corners']),
    DecisionMarketDefinition(id: 'cardsTotal', sourceOptionIds: ['cards']),
    DecisionMarketDefinition(
      id: 'doubleChance',
      sourceOptionIds: ['double_chance'],
    ),
    DecisionMarketDefinition(
      id: 'playerAnytimeScorer',
      sourceOptionIds: ['player_scorer'],
      isPlayerMarket: true,
    ),
  ];

  static String? sourceOptionIdFor(String marketId) {
    for (final definition in values) {
      if (definition.id == marketId) {
        return definition.sourceOptionIds.first;
      }
    }

    return null;
  }

  /// Normalizes persisted canonical IDs and UI source option IDs to the IDs
  /// used by the market toggles. This keeps old profiles editable without
  /// changing which market they authorize.
  static Set<String> sourceOptionIdsFor(Iterable<String> ids) {
    final selected = ids.toSet();
    return {
      for (final definition in values)
        if (selected.contains(definition.id) ||
            definition.sourceOptionIds.any(selected.contains))
          ...definition.sourceOptionIds,
    };
  }

  static Set<String> enabledMarketIdsFor(Iterable<String> ids) {
    final selected = ids.toSet();
    return {
      for (final definition in values)
        if (selected.contains(definition.id) ||
            definition.sourceOptionIds.any(selected.contains))
          definition.id,
    };
  }
}

class OpportunityProfileDefinition {
  const OpportunityProfileDefinition({
    required this.id,
    required this.label,
    required this.displayLabel,
    required this.description,
  });

  final String id;
  final String label;
  final String displayLabel;
  final String description;

  FootballScenarioDefinition? get scenario => FootballScenarioCatalog.byId(id);

  bool get isSupported => scenario?.isAvailable ?? false;
}

/// Metadata describing a selectable football reading.
///
/// This is deliberately descriptive: thresholds and detection remain in the
/// analysis context, while a user preference only chooses which observed
/// facts may personalize "Pour moi".
class ReadingPreferenceDefinition {
  const ReadingPreferenceDefinition({
    required this.id,
    required this.label,
    required this.description,
  });

  final String id;
  final String label;
  final String description;
}

class ReadingPreferenceCatalog {
  const ReadingPreferenceCatalog._();

  static const values = [
    ReadingPreferenceDefinition(
      id: 'structural_level_gap',
      label: 'Écart de niveau structurel',
      description:
          'Une différence de niveau est confirmée par le contexte du championnat.',
    ),
    ReadingPreferenceDefinition(
      id: 'positive_streak',
      label: 'Dynamique positive',
      description: 'Une équipe enchaîne des résultats favorables.',
    ),
    ReadingPreferenceDefinition(
      id: 'negative_streak',
      label: 'Dynamique négative',
      description: 'Une équipe traverse une série défavorable.',
    ),
    ReadingPreferenceDefinition(
      id: 'improving_form',
      label: 'Forme en hausse',
      description: 'Les résultats récents progressent.',
    ),
    ReadingPreferenceDefinition(
      id: 'declining_form',
      label: 'Forme en baisse',
      description: 'Les résultats récents se dégradent.',
    ),
    ReadingPreferenceDefinition(
      id: 'strong_home_team',
      label: 'Solide à domicile',
      description: 'Une équipe se distingue dans ses matchs à domicile.',
    ),
    ReadingPreferenceDefinition(
      id: 'weak_home_team',
      label: 'Fragile à domicile',
      description: 'Une équipe rencontre des difficultés à domicile.',
    ),
    ReadingPreferenceDefinition(
      id: 'strong_away_team',
      label: 'Solide à l’extérieur',
      description: 'Une équipe se distingue dans ses matchs à l’extérieur.',
    ),
    ReadingPreferenceDefinition(
      id: 'weak_away_team',
      label: 'Fragile à l’extérieur',
      description: 'Une équipe rencontre des difficultés à l’extérieur.',
    ),
    ReadingPreferenceDefinition(
      id: 'home_away_advantage',
      label: 'Avantage domicile / extérieur',
      description:
          'Une équipe solide à domicile affronte une équipe fragile à l’extérieur.',
    ),
    ReadingPreferenceDefinition(
      id: 'away_home_advantage',
      label: 'Avantage extérieur / domicile',
      description:
          'Une équipe solide à l’extérieur affronte une équipe fragile à domicile.',
    ),
    ReadingPreferenceDefinition(
      id: 'prolific_attack',
      label: 'Attaque prolifique',
      description: 'Une équipe produit régulièrement des buts.',
    ),
    ReadingPreferenceDefinition(
      id: 'scoring_difficulty',
      label: 'Production offensive faible',
      description: 'Une équipe peine à marquer.',
    ),
    ReadingPreferenceDefinition(
      id: 'solid_defense',
      label: 'Défense solide',
      description: 'Une équipe concède peu.',
    ),
    ReadingPreferenceDefinition(
      id: 'fragile_defense',
      label: 'Défense fragile',
      description: 'Une équipe concède régulièrement.',
    ),
    ReadingPreferenceDefinition(
      id: 'frequent_clean_sheet',
      label: 'Clean sheets fréquents',
      description: 'Une équipe garde souvent sa cage inviolée.',
    ),
    ReadingPreferenceDefinition(
      id: 'frequent_over_25',
      label: 'Tendance over 2,5 buts',
      description: 'Les matchs récents dépassent souvent 2,5 buts.',
    ),
    ReadingPreferenceDefinition(
      id: 'frequent_btts',
      label: 'BTTS fréquent',
      description: 'Les deux équipes marquent régulièrement.',
    ),
    ReadingPreferenceDefinition(
      id: 'frequent_under_25',
      label: 'Tendance under 2,5 buts',
      description: 'Les matchs récents restent souvent sous 2,5 buts.',
    ),
    ReadingPreferenceDefinition(
      id: 'misleading_result',
      label: 'Résultats à nuancer',
      description: 'Les résultats ne reflètent pas entièrement les xG.',
    ),
    ReadingPreferenceDefinition(
      id: 'frequent_first_half_scoring',
      label: 'Marque souvent en première mi-temps',
      description:
          'Une équipe produit beaucoup de buts avant la pause par rapport au championnat.',
    ),
    ReadingPreferenceDefinition(
      id: 'frequent_first_half_conceding',
      label: 'Encaisse souvent en première mi-temps',
      description:
          'Une équipe concède beaucoup de buts avant la pause par rapport au championnat.',
    ),
    ReadingPreferenceDefinition(
      id: 'frequent_second_half_scoring',
      label: 'Marque souvent en seconde mi-temps',
      description:
          'Une équipe produit beaucoup de buts après la pause par rapport au championnat.',
    ),
    ReadingPreferenceDefinition(
      id: 'frequent_second_half_conceding',
      label: 'Encaisse souvent en seconde mi-temps',
      description:
          'Une équipe concède beaucoup de buts après la pause par rapport au championnat.',
    ),
    ReadingPreferenceDefinition(
      id: 'standout_decisive_player',
      label: 'Joueurs décisifs',
      description:
          'Identifie les joueurs décisifs par leurs buts, passes et leur répétition récente.',
    ),
    ReadingPreferenceDefinition(
      id: 'key_player_unavailable',
      label: 'Joueur important absent',
      description: 'Une absence déclarée concerne un joueur au rôle important.',
    ),
  ];

  static bool contains(String readingId) =>
      values.any((definition) => definition.id == readingId);

  static String? preferenceIdForReading(String readingId) {
    final ids = preferenceIdsForReading(readingId);
    return ids.isEmpty ? null : ids.first;
  }

  /// A compact snapshot may use a factual id which represents one of the
  /// readings selected in the profile. Keep this translation at the catalog
  /// boundary so the server contract, the profile and the presentation all
  /// make the same eligibility decision.
  static Set<String> preferenceIdsForReading(String readingId) {
    if (readingId == 'standout_goal_scorer' ||
        readingId == 'standout_creator') {
      return const {'standout_decisive_player'};
    }
    if (readingId == 'form_advantage') {
      return const {'positive_streak', 'improving_form'};
    }
    if (readingId == 'ranking_superiority' ||
        readingId == 'ranking_inferiority') {
      return const {'structural_level_gap'};
    }
    if (readingId == 'venue_strength') {
      return const {'strong_home_team', 'strong_away_team'};
    }
    if (readingId == 'high_xg_creation' || readingId == 'attack_in_form') {
      return const {'prolific_attack'};
    }
    if (readingId == 'low_xg_creation' ||
        readingId == 'offensive_underperformance') {
      return const {'scoring_difficulty'};
    }
    if (readingId == 'high_xg_conceded' ||
        readingId == 'defensive_underperformance') {
      return const {'fragile_defense'};
    }
    return contains(readingId) ? {readingId} : const {};
  }

  static Set<String> normalizeSelectionIds(Iterable<String> readingIds) => {
    for (final readingId in readingIds) ?preferenceIdForReading(readingId),
  };
}

/// Product navigation for the reading pickers. These categories only organise
/// available Lector readings; thresholds and source statistics stay in the
/// server analysis layer.
class ReadingPreferenceCategory {
  const ReadingPreferenceCategory({
    required this.id,
    required this.label,
    required this.readingIds,
  });

  final String id;
  final String label;
  final List<String> readingIds;
}

class ReadingPreferenceCategoryCatalog {
  const ReadingPreferenceCategoryCatalog._();

  static const values = [
    ReadingPreferenceCategory(
      id: 'ranking_form',
      label: 'Niveau, forme et lieu',
      readingIds: [
        'structural_level_gap',
        'positive_streak',
        'negative_streak',
        'improving_form',
        'declining_form',
        'strong_home_team',
        'weak_home_team',
        'strong_away_team',
        'weak_away_team',
        'home_away_advantage',
        'away_home_advantage',
      ],
    ),
    ReadingPreferenceCategory(
      id: 'attack_defense',
      label: 'Attaque et défense',
      readingIds: [
        'prolific_attack',
        'scoring_difficulty',
        'solid_defense',
        'fragile_defense',
        'frequent_clean_sheet',
      ],
    ),
    ReadingPreferenceCategory(
      id: 'goals',
      label: 'Profil de buts',
      readingIds: ['frequent_over_25', 'frequent_btts', 'frequent_under_25'],
    ),
    ReadingPreferenceCategory(
      id: 'match_periods',
      label: 'Moments du match',
      readingIds: [
        'frequent_first_half_scoring',
        'frequent_first_half_conceding',
        'frequent_second_half_scoring',
        'frequent_second_half_conceding',
      ],
    ),
    ReadingPreferenceCategory(
      id: 'availability',
      label: 'Absences importantes',
      readingIds: ['key_player_unavailable'],
    ),
    ReadingPreferenceCategory(
      id: 'context',
      label: 'Contexte et nuances',
      readingIds: ['misleading_result'],
    ),
    ReadingPreferenceCategory(
      id: 'player_statistics',
      label: 'Statistiques joueurs',
      readingIds: ['standout_decisive_player'],
    ),
  ];

  static ReadingPreferenceCategory? byId(String id) {
    for (final category in values) {
      if (category.id == id) return category;
    }
    return null;
  }
}

class OpportunityProfileCatalog {
  const OpportunityProfileCatalog._();

  static const values = [
    OpportunityProfileDefinition(
      id: 'solid_favorite',
      label: 'Favoris solides',
      displayLabel: 'Dominations attendues',
      description:
          'Supériorité au classement, avantage de forme et écart structurel réunis.',
    ),
    OpportunityProfileDefinition(
      id: 'struggling_team',
      label: 'Equipes en difficulte',
      displayLabel: 'Équipes en difficulté',
      description:
          'Mauvais résultats et production offensive faible convergent.',
    ),
    OpportunityProfileDefinition(
      id: 'offensive_match',
      label: 'Matchs ouverts',
      displayLabel: 'Matchs ouverts',
      description: 'Profil ouvert et tendance over 2,5 buts convergent.',
    ),
    OpportunityProfileDefinition(
      id: 'defensive_match',
      label: 'Matchs fermes',
      displayLabel: 'Matchs fermés',
      description: 'Profil fermé et tendance under 2,5 buts convergent.',
    ),
    OpportunityProfileDefinition(
      id: 'ranking_gap',
      label: 'Ecarts de niveau',
      displayLabel: 'Écarts de niveau',
      description:
          'Supériorité au classement et écart structurel concernent la même équipe.',
    ),
    OpportunityProfileDefinition(
      id: 'credible_outsider',
      label: 'Outsiders credibles',
      displayLabel: 'Outsiders crédibles',
      description:
          'Infériorité théorique compensée par une dynamique et une forme supérieures.',
    ),
    OpportunityProfileDefinition(
      id: 'fragile_defense',
      label: 'Defenses fragiles',
      displayLabel: 'Défenses fragiles',
      description: 'Fragilité défensive et xG concédés convergent.',
    ),
    OpportunityProfileDefinition(
      id: 'prolific_attack',
      label: 'Attaques prolifiques',
      displayLabel: 'Attaques prolifiques',
      description: 'Buts et création xG convergent pour la même équipe.',
    ),
    OpportunityProfileDefinition(
      id: 'positive_series',
      label: 'Series positives',
      displayLabel: 'Séries positives',
      description: 'Série positive et progression récente convergent.',
    ),
    OpportunityProfileDefinition(
      id: 'negative_series',
      label: 'Series negatives',
      displayLabel: 'Séries négatives',
      description: 'Série négative et dégradation récente convergent.',
    ),
  ];

  static OpportunityProfileDefinition? byId(String id) {
    for (final definition in values) {
      if (definition.id == id) {
        return definition;
      }
    }

    return null;
  }

  static bool isDirectPersonalizationReading(String readingId) {
    return ReadingPreferenceCatalog.contains(readingId);
  }
}

typedef MatchTypeDefinition = OpportunityProfileDefinition;

class MatchTypeCatalog {
  const MatchTypeCatalog._();

  static const values = OpportunityProfileCatalog.values;
}

double _normalizeOdds(double odds) => (odds * 100).round() / 100;
