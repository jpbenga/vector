import 'api_football_match_adapter.dart';
import 'championship_tier_snapshot_engine.dart';
import 'championship_tier_temporal_state_store.dart';
import '../../onboarding/domain/profile_compiler.dart';
import '../../onboarding/domain/decision_profile.dart';
import '../../opportunities/domain/opportunity.dart';
import '../domain/match_board_item.dart';
import '../domain/match_context_key_builder.dart';
import '../domain/match_context_key_models.dart';
import '../domain/opportunity_engine_v2.dart';
import '../domain/structural_tiers/competition_structural_metadata.dart';
import '../domain/structural_tiers/tier_input.dart';
import '../domain/structural_tiers/tier_models.dart';

abstract interface class MatchFeedRepository {
  MatchDataSourceMode get mode;

  MatchFeedSnapshotMetadata? get snapshotMetadata;

  List<MatchBoardItem> allMatches();

  List<Opportunity> opportunitiesFor(DecisionProfile profile);

  List<MatchBoardItem> personalizedFor(DecisionProfile profile);

  MatchBoardItem analyzeFor(DecisionProfile profile, MatchBoardItem match);
}

class MatchFeedRepositoryFactory {
  const MatchFeedRepositoryFactory();

  MatchFeedRepository create(
    MatchDataSourceMode mode, {
    Map<String, Object?>? snapshot,
  }) {
    return switch (mode) {
      MatchDataSourceMode.demo => const DemoMatchFeedRepository(),
      MatchDataSourceMode.snapshot =>
        snapshot == null
            ? const UnavailableMatchFeedRepository(
                mode: MatchDataSourceMode.snapshot,
                reason: 'Snapshot match data requires a loaded JSON snapshot.',
              )
            : SnapshotMatchFeedRepository(snapshot: snapshot),
      MatchDataSourceMode.api => const UnavailableMatchFeedRepository(
        mode: MatchDataSourceMode.api,
        reason: 'API match data must go through a secure backend first.',
      ),
    };
  }
}

class MatchFeedSnapshotMetadata {
  const MatchFeedSnapshotMetadata({
    required this.source,
    required this.capturedAt,
    required this.timezone,
    required this.matchCount,
    this.windowStart,
    this.windowEnd,
  });

  factory MatchFeedSnapshotMetadata.fromSnapshot(
    Map<String, Object?> snapshot, {
    required List<MatchBoardItem> matches,
  }) {
    final capturedAt = _parseDateTime(snapshot['captured_at']);
    final explicitWindowStart =
        _parseDate(snapshot['window_start']) ??
        _parseDate(_asMap(snapshot['window'])['start']);
    final explicitWindowEnd =
        _parseDate(snapshot['window_end']) ??
        _parseDate(_asMap(snapshot['window'])['end']);
    final inferredWindow = _inferWindow(matches);

    return MatchFeedSnapshotMetadata(
      source: snapshot['source']?.toString() ?? 'unknown',
      capturedAt: capturedAt,
      timezone: snapshot['timezone']?.toString() ?? 'local',
      matchCount: matches.length,
      windowStart: explicitWindowStart ?? inferredWindow.$1,
      windowEnd: explicitWindowEnd ?? inferredWindow.$2,
    );
  }

  final String source;
  final DateTime? capturedAt;
  final String timezone;
  final int matchCount;
  final DateTime? windowStart;
  final DateTime? windowEnd;

  bool get isEmpty => matchCount == 0;

  bool covers(DateTime date) {
    final day = _dateOnly(date);
    final start = windowStart;
    final end = windowEnd;
    if (start != null && day.isBefore(start)) {
      return false;
    }
    if (end != null && day.isAfter(end)) {
      return false;
    }
    return start != null || end != null;
  }

  bool isObsolete(DateTime now) {
    final today = _dateOnly(now);
    final end = windowEnd;
    if (end != null && end.isBefore(today)) {
      return true;
    }

    final captured = capturedAt?.toLocal();
    if (captured == null) {
      return true;
    }

    return _dateOnly(captured).isBefore(today);
  }

  static (DateTime?, DateTime?) _inferWindow(List<MatchBoardItem> matches) {
    DateTime? start;
    DateTime? end;
    for (final match in matches) {
      final day = lectorLocalCalendarDateForFixture(match.fixture);
      if (day == null) {
        continue;
      }
      if (start == null || day.isBefore(start)) {
        start = day;
      }
      if (end == null || day.isAfter(end)) {
        end = day;
      }
    }
    return (start, end);
  }
}

class SnapshotMatchFeedRepository implements MatchFeedRepository {
  factory SnapshotMatchFeedRepository({
    required Map<String, Object?> snapshot,
    ApiFootballMatchAdapter adapter = const ApiFootballMatchAdapter(),
    CompetitionStructuralMetadataRepository metadataRepository =
        const StaticCompetitionStructuralMetadataRepository(),
    ChampionshipTierSnapshotEngine? tierSnapshotEngine,
    OpportunityEngineV2 opportunityEngine = const OpportunityEngineV2(),
  }) {
    final matches = adapter.fromSnapshot(snapshot);
    final engine =
        tierSnapshotEngine ??
        ChampionshipTierSnapshotEngine(
          temporalStateStore: InMemoryChampionshipTierTemporalStateStore(),
        );
    final enrichedMatches = _attachStructuralRelations(
      matches: matches,
      snapshot: snapshot,
      metadataRepository: metadataRepository,
      tierSnapshotEngine: engine,
    );
    final matchesWithContextKeys = _attachContextKeys(enrichedMatches);
    return SnapshotMatchFeedRepository._(
      matches: matchesWithContextKeys,
      snapshotMetadata: MatchFeedSnapshotMetadata.fromSnapshot(
        snapshot,
        matches: matchesWithContextKeys,
      ),
      opportunityEngine: opportunityEngine,
      intelligencesByFixtureId: {
        for (final match in matchesWithContextKeys)
          match.id: opportunityEngine.buildIntelligence(match),
      },
    );
  }

  const SnapshotMatchFeedRepository._({
    required this._matches,
    required this.snapshotMetadata,
    required this._opportunityEngine,
    required this._intelligencesByFixtureId,
  });

  final List<MatchBoardItem> _matches;
  final OpportunityEngineV2 _opportunityEngine;
  final Map<String, MatchIntelligence> _intelligencesByFixtureId;

  @override
  MatchDataSourceMode get mode => MatchDataSourceMode.snapshot;

  @override
  final MatchFeedSnapshotMetadata snapshotMetadata;

  @override
  List<MatchBoardItem> allMatches() => List.unmodifiable(_matches);

  @override
  List<Opportunity> opportunitiesFor(DecisionProfile profile) {
    final compiledProfile = const ProfileCompiler().compile(profile);
    return _opportunityEngine.opportunitiesFromIntelligence(
      _intelligencesByFixtureId.values,
      compiledProfile,
    );
  }

  @override
  List<MatchBoardItem> personalizedFor(DecisionProfile profile) {
    final compiledProfile = const ProfileCompiler().compile(profile);
    final matches =
        [
          for (final intelligence in _intelligencesByFixtureId.values)
            _opportunityEngine.personalizeMatchFromIntelligence(
              intelligence,
              compiledProfile,
            ),
        ].where((match) {
          return match.profileStatus == MatchProfileStatus.inProfile &&
              (match.thesis != null || match.signals.isNotEmpty);
        }).toList();

    matches.sort(_comparePersonalizedMatches);
    return matches;
  }

  @override
  MatchBoardItem analyzeFor(DecisionProfile profile, MatchBoardItem match) {
    final intelligence = _intelligencesByFixtureId[match.id];
    final compiledProfile = const ProfileCompiler().compile(profile);
    return _opportunityEngine.personalizeMatchFromIntelligence(
      intelligence ?? _opportunityEngine.buildIntelligence(match),
      compiledProfile,
    );
  }
}

int _comparePersonalizedMatches(MatchBoardItem a, MatchBoardItem b) {
  final relevanceComparison = b.profileRelevance.total.compareTo(
    a.profileRelevance.total,
  );
  if (relevanceComparison != 0) {
    return relevanceComparison;
  }

  final aKickoff = a.fixture.kickoff;
  final bKickoff = b.fixture.kickoff;
  if (aKickoff != null && bKickoff != null) {
    final kickoffComparison = aKickoff.compareTo(bKickoff);
    if (kickoffComparison != 0) {
      return kickoffComparison;
    }
  } else if (aKickoff != null) {
    return -1;
  } else if (bKickoff != null) {
    return 1;
  }

  return a.homeTeam.name.compareTo(b.homeTeam.name);
}

List<MatchBoardItem> _attachStructuralRelations({
  required List<MatchBoardItem> matches,
  required Map<String, Object?> snapshot,
  required CompetitionStructuralMetadataRepository metadataRepository,
  required ChampionshipTierSnapshotEngine tierSnapshotEngine,
}) {
  if (matches.isEmpty) {
    return matches;
  }

  final sourceMetadata = DynamicTierSourceMetadata.fromSnapshotPayload(
    snapshot,
  );
  final snapshotsByCompetition = <String, ChampionshipTierSnapshot?>{};

  ChampionshipTierSnapshot? snapshotFor(MatchBoardItem match) {
    final key = '${match.competition.id}:${match.competition.season}';
    if (snapshotsByCompetition.containsKey(key)) {
      return snapshotsByCompetition[key];
    }

    final standings = match.analysis.leagueStandings;
    final analysisAsOf =
        match.analysis.asOf ??
        sourceMetadata.sourceAsOf ??
        match.fixture.kickoff;
    final metadata = metadataRepository.metadataFor(
      competitionId: match.competition.id,
      season: match.competition.season,
    );
    final result = tierSnapshotEngine.buildSnapshot(
      competitionId: match.competition.id,
      season: match.competition.season,
      analysisAsOf: analysisAsOf,
      leagueStandings: standings,
      metadata: metadata,
      sourceMetadata: sourceMetadata,
    );

    snapshotsByCompetition[key] = result.snapshot;
    return result.snapshot;
  }

  return [
    for (final match in matches) _attachRelation(match, snapshotFor(match)),
  ];
}

MatchBoardItem _attachRelation(
  MatchBoardItem match,
  ChampionshipTierSnapshot? snapshot,
) {
  final homeTeamId = match.homeTeam.apiFootballTeamId;
  final awayTeamId = match.awayTeam.apiFootballTeamId;
  if (snapshot == null || homeTeamId == null || awayTeamId == null) {
    return match;
  }

  return match.copyWith(
    analysis: match.analysis.copyWith(
      championshipTierSnapshot: snapshot,
      structuralRelation: MatchStructuralRelation.fromSnapshot(
        snapshot: snapshot,
        homeTeamId: homeTeamId,
        awayTeamId: awayTeamId,
      ),
    ),
  );
}

List<MatchBoardItem> _attachContextKeys(List<MatchBoardItem> matches) {
  const referenceBuilder = ChampionshipContextReferenceBuilder();
  const keyBuilder = MatchContextKeyBuilder();
  final references = <String, ChampionshipContextReference?>{};

  ChampionshipContextReference? referenceFor(MatchBoardItem match) {
    final asOf = match.analysis.asOf;
    if (asOf == null) {
      return null;
    }
    final structuralIdentity =
        match.analysis.championshipTierSnapshot?.standingsSnapshotIdentity ??
        ([...match.analysis.leagueStandings]
              ..sort((left, right) => left.teamId.compareTo(right.teamId)))
            .map(
              (standing) =>
                  '${standing.teamId}:${standing.rank}:${standing.points}:${standing.played}:${standing.form}:${standing.goalsFor}:${standing.goalsAgainst}',
            )
            .join('|');
    final key =
        '${match.competition.id}:${match.competition.season}:${asOf.toUtc().toIso8601String()}:$structuralIdentity';
    return references.putIfAbsent(key, () => referenceBuilder.build(match));
  }

  MatchBoardItem withContextKeys(MatchBoardItem match) {
    final reference = referenceFor(match);
    final contextKeys = keyBuilder.build(match, reference: reference);
    final relation = match.analysis.structuralRelation;
    final structureCanBeEvaluated =
        relation?.tierStatus == TierSystemStatus.mature &&
        relation?.tierMaturity == TierMaturity.mature;
    final hasContextReference =
        (reference?.distributions.isNotEmpty ?? false) ||
        structureCanBeEvaluated;
    return match.copyWith(
      analysis: match.analysis.copyWith(
        contextKeys: contextKeys,
        contextKeyAvailability: contextKeys.isNotEmpty
            ? MatchContextKeyAvailability.available
            : hasContextReference
            ? MatchContextKeyAvailability.noRemarkableFact
            : MatchContextKeyAvailability.unavailable,
      ),
    );
  }

  return [for (final match in matches) withContextKeys(match)];
}

DateTime? _parseDateTime(Object? value) {
  if (value is! String || value.trim().isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}

DateTime? _parseDate(Object? value) {
  final parsed = _parseDateTime(value);
  if (parsed == null) {
    return null;
  }
  return _dateOnly(parsed.toLocal());
}

DateTime _dateOnly(DateTime value) {
  return lectorLocalCalendarDate(value);
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

class UnavailableMatchFeedRepository implements MatchFeedRepository {
  const UnavailableMatchFeedRepository({
    required this.mode,
    required this.reason,
  });

  @override
  final MatchDataSourceMode mode;

  final String reason;

  @override
  MatchFeedSnapshotMetadata? get snapshotMetadata => null;

  @override
  List<MatchBoardItem> allMatches() {
    throw StateError(reason);
  }

  @override
  List<Opportunity> opportunitiesFor(DecisionProfile profile) {
    throw StateError(reason);
  }

  @override
  List<MatchBoardItem> personalizedFor(DecisionProfile profile) {
    throw StateError(reason);
  }

  @override
  MatchBoardItem analyzeFor(DecisionProfile profile, MatchBoardItem match) {
    throw StateError(reason);
  }
}

class DemoMatchFeedRepository implements MatchFeedRepository {
  const DemoMatchFeedRepository();

  static const _opportunityEngine = OpportunityEngineV2();

  @override
  MatchDataSourceMode get mode => MatchDataSourceMode.demo;

  @override
  MatchFeedSnapshotMetadata? get snapshotMetadata => null;

  @override
  List<Opportunity> opportunitiesFor(DecisionProfile profile) {
    final compiledProfile = const ProfileCompiler().compile(profile);
    return _opportunityEngine.opportunitiesFromIntelligence(
      _intelligences(),
      compiledProfile,
    );
  }

  @override
  List<MatchBoardItem> personalizedFor(DecisionProfile profile) {
    final compiledProfile = const ProfileCompiler().compile(profile);
    final matches =
        [
          for (final intelligence in _intelligences())
            _opportunityEngine.personalizeMatchFromIntelligence(
              intelligence,
              compiledProfile,
            ),
        ].where((match) {
          return match.profileStatus == MatchProfileStatus.inProfile &&
              (match.thesis != null || match.signals.isNotEmpty);
        }).toList();

    matches.sort(_comparePersonalizedMatches);
    return matches;
  }

  @override
  MatchBoardItem analyzeFor(DecisionProfile profile, MatchBoardItem match) {
    final compiledProfile = const ProfileCompiler().compile(profile);
    final intelligence = _intelligences().firstWhere(
      (intelligence) => intelligence.match.id == match.id,
      orElse: () => _opportunityEngine.buildIntelligence(match),
    );
    return _opportunityEngine.personalizeMatchFromIntelligence(
      intelligence,
      compiledProfile,
    );
  }

  @override
  List<MatchBoardItem> allMatches() {
    const rawMatches = [
      MatchBoardItem(
        fixture: NormalizedFixture(
          id: 'ars-eve',
          competition: _premierLeague,
          kickoffLabel: '16:00',
          homeTeam: TeamInfo(
            id: 'arsenal',
            name: 'Arsenal',
            apiFootballTeamId: 42,
            logoUrl: 'https://media.api-sports.io/football/teams/42.png',
          ),
          awayTeam: TeamInfo(
            id: 'everton',
            name: 'Everton',
            apiFootballTeamId: 45,
            logoUrl: 'https://media.api-sports.io/football/teams/45.png',
          ),
          status: FixtureStatus.scheduled,
        ),
        primaryMarket: MarketOdds(
          id: 'double_chance_1x',
          label: 'Double Chance 1X',
          odds: 1.42,
        ),
        availableMarkets: [
          MatchMarket(
            id: 'doubleChance',
            label: 'Double chance',
            selections: [
              MarketOdds(id: 'double_chance_1x', label: '1X', odds: 1.42),
            ],
            bookmakerName: 'Demo Bookmaker',
          ),
        ],
        compatibility: 94,
        signals: [
          MatchSignal(
            id: 'arsenal_home_strength',
            title: 'Arsenal très solide à domicile',
            summary: 'Arsenal reste sur une série positive dans son stade.',
            proofs: [
              '5 victoires sur les 5 derniers matchs à domicile.',
              'Aucune défaite à domicile depuis 14 matchs de championnat.',
            ],
          ),
          MatchSignal(
            id: 'everton_away_fragility',
            title: 'Everton voyage mal',
            summary: 'Everton concède beaucoup hors de ses bases.',
            proofs: [
              '4 défaites sur les 5 derniers déplacements.',
              '11 buts encaissés sur cette série extérieure.',
            ],
          ),
          MatchSignal(
            id: 'table_gap',
            title: 'Écart net au classement',
            summary: 'Le contexte général donne plus de garanties au favori.',
            proofs: [
              'Arsenal 2e, Everton 15e.',
              '16 points d’écart entre les deux équipes.',
            ],
          ),
        ],
      ),
      MatchBoardItem(
        fixture: NormalizedFixture(
          id: 'ben-bra',
          competition: _ligaPortugal,
          kickoffLabel: '19:00',
          homeTeam: TeamInfo(
            id: 'benfica',
            name: 'Benfica',
            apiFootballTeamId: 211,
            logoUrl: 'https://media.api-sports.io/football/teams/211.png',
          ),
          awayTeam: TeamInfo(
            id: 'braga',
            name: 'Braga',
            apiFootballTeamId: 217,
            logoUrl: 'https://media.api-sports.io/football/teams/217.png',
          ),
          status: FixtureStatus.scheduled,
        ),
        primaryMarket: MarketOdds(
          id: 'home_win',
          label: 'Victoire Benfica',
          odds: 1.85,
        ),
        availableMarkets: [
          MatchMarket(
            id: 'matchResult',
            label: '1 N 2',
            selections: [
              MarketOdds(id: 'home', label: 'Domicile', odds: 1.85),
              MarketOdds(id: 'draw', label: 'Nul', odds: 3.70),
              MarketOdds(id: 'away', label: 'Extérieur', odds: 4.50),
            ],
            bookmakerName: 'Demo Bookmaker',
          ),
        ],
        compatibility: 91,
        signals: [
          MatchSignal(
            id: 'benfica_unbeaten_home',
            title: 'Benfica invaincu à domicile',
            summary: 'La dynamique à domicile reste très favorable.',
            proofs: [
              '9 matchs sans défaite à domicile.',
              '7 victoires et 2 nuls sur la série.',
            ],
          ),
          MatchSignal(
            id: 'braga_less_reliable_away',
            title: 'Braga moins fiable à l’extérieur',
            summary: 'Les déplacements récents apportent moins de garanties.',
            proofs: [
              '1 victoire sur les 6 derniers matchs à l’extérieur.',
              'Moyenne de 1.8 but encaissé par déplacement récent.',
            ],
          ),
        ],
      ),
      MatchBoardItem(
        fixture: NormalizedFixture(
          id: 'lil-nan',
          competition: _ligue1,
          kickoffLabel: '21:00',
          homeTeam: TeamInfo(
            id: 'lille',
            name: 'Lille',
            apiFootballTeamId: 79,
            logoUrl: 'https://media.api-sports.io/football/teams/79.png',
          ),
          awayTeam: TeamInfo(
            id: 'nantes',
            name: 'Nantes',
            apiFootballTeamId: 83,
            logoUrl: 'https://media.api-sports.io/football/teams/83.png',
          ),
          status: FixtureStatus.scheduled,
        ),
        primaryMarket: MarketOdds(
          id: 'double_chance_1x',
          label: 'Double Chance 1X',
          odds: 1.55,
        ),
        availableMarkets: [
          MatchMarket(
            id: 'doubleChance',
            label: 'Double chance',
            selections: [
              MarketOdds(id: 'double_chance_1x', label: '1X', odds: 1.55),
            ],
            bookmakerName: 'Demo Bookmaker',
          ),
        ],
        compatibility: 88,
        signals: [
          MatchSignal(
            id: 'lille_home_control',
            title: 'Lille protège bien son terrain',
            summary: 'La base défensive rend le scénario plus lisible.',
            proofs: [
              '3 clean sheets sur les 5 derniers matchs.',
              'Meilleure défense à domicile de la période.',
            ],
          ),
          MatchSignal(
            id: 'nantes_unstable',
            title: 'Nantes en manque de stabilité',
            summary: 'La dynamique récente reste irrégulière.',
            proofs: [
              '1 victoire sur les 6 derniers matchs.',
              'Défense très exposée sur les dernières journées.',
            ],
          ),
        ],
      ),
      MatchBoardItem(
        fixture: NormalizedFixture(
          id: 'psv-twe',
          competition: _eredivisie,
          kickoffLabel: '18:45',
          homeTeam: TeamInfo(
            id: 'psv',
            name: 'PSV',
            apiFootballTeamId: 197,
            logoUrl: 'https://media.api-sports.io/football/teams/197.png',
          ),
          awayTeam: TeamInfo(
            id: 'twente',
            name: 'Twente',
            apiFootballTeamId: 415,
            logoUrl: 'https://media.api-sports.io/football/teams/415.png',
          ),
          status: FixtureStatus.scheduled,
        ),
        primaryMarket: MarketOdds(
          id: 'over_2_5',
          label: 'Over 2.5',
          odds: 1.68,
        ),
        availableMarkets: [
          MatchMarket(
            id: 'goalsTotal',
            label: 'Over / Under buts',
            selections: [
              MarketOdds(id: 'over_2_5', label: 'Over 2.5', odds: 1.68),
              MarketOdds(id: 'under_2_5', label: 'Under 2.5', odds: 2.18),
            ],
            bookmakerName: 'Demo Bookmaker',
          ),
        ],
        compatibility: 83,
        signals: [
          MatchSignal(
            id: 'productive_attacks',
            title: 'Deux attaques productives',
            summary: 'Le volume offensif des deux équipes est élevé.',
            proofs: [
              'PSV : 2.4 buts par match sur les 6 dernières journées.',
              'Twente : 1.9 but par match sur la même période.',
            ],
          ),
          MatchSignal(
            id: 'open_h2h',
            title: 'Confrontations ouvertes',
            summary: 'Les duels récents dépassent souvent deux buts.',
            proofs: [
              'Over 2.5 validé lors des 4 derniers duels.',
              'Moyenne de 3.6 buts par match sur cette série.',
            ],
          ),
        ],
      ),
      MatchBoardItem(
        fixture: NormalizedFixture(
          id: 'nap-tor',
          competition: _serieA,
          kickoffLabel: '20:45',
          homeTeam: TeamInfo(
            id: 'napoli',
            name: 'Napoli',
            apiFootballTeamId: 492,
            logoUrl: 'https://media.api-sports.io/football/teams/492.png',
          ),
          awayTeam: TeamInfo(
            id: 'torino',
            name: 'Torino',
            apiFootballTeamId: 503,
            logoUrl: 'https://media.api-sports.io/football/teams/503.png',
          ),
          status: FixtureStatus.scheduled,
        ),
        primaryMarket: MarketOdds(
          id: 'home_win',
          label: 'Victoire Napoli',
          odds: 1.52,
        ),
        availableMarkets: [
          MatchMarket(
            id: 'matchResult',
            label: '1 N 2',
            selections: [
              MarketOdds(id: 'home', label: 'Domicile', odds: 1.52),
              MarketOdds(id: 'draw', label: 'Nul', odds: 4.20),
              MarketOdds(id: 'away', label: 'Extérieur', odds: 6.20),
            ],
            bookmakerName: 'Demo Bookmaker',
          ),
        ],
        compatibility: 79,
        signals: [
          MatchSignal(
            id: 'napoli_confident',
            title: 'Napoli en dynamique positive',
            summary: 'La dynamique récente offre une base cohérente.',
            proofs: [
              '4 victoires sur les 5 derniers matchs.',
              'Toutes obtenues avec au moins 2 buts marqués.',
            ],
          ),
          MatchSignal(
            id: 'torino_away_fragility',
            title: 'Torino fragile hors domicile',
            summary: 'Les déplacements récents restent peu convaincants.',
            proofs: [
              '1 seul point pris sur les 5 derniers déplacements.',
              'Difficulté à marquer contre les équipes du top 8.',
            ],
          ),
        ],
      ),
    ];
    return List.unmodifiable(
      _attachContextKeys(rawMatches.map(_withDemoAnalysis).toList()),
    );
  }

  List<MatchIntelligence> _intelligences() {
    return [
      for (final match in allMatches())
        _opportunityEngine.buildIntelligence(match),
    ];
  }
}

MatchBoardItem _withDemoAnalysis(MatchBoardItem match) {
  final homeId = match.homeTeam.apiFootballTeamId!;
  final awayId = match.awayTeam.apiFootballTeamId!;
  final standings = <TeamStandingSnapshot>[
    TeamStandingSnapshot(
      teamId: homeId,
      teamName: match.homeTeam.name,
      rank: 1,
      points: 15,
      played: 5,
      wins: 5,
      draws: 0,
      losses: 0,
      goalsFor: 16,
      goalsAgainst: 3,
      form: 'WWWWW',
    ),
    TeamStandingSnapshot(
      teamId: awayId,
      teamName: match.awayTeam.name,
      rank: 10,
      points: 2,
      played: 5,
      wins: 0,
      draws: 2,
      losses: 3,
      goalsFor: 3,
      goalsAgainst: 15,
      form: 'DDLLL',
    ),
    for (var index = 0; index < 8; index++)
      TeamStandingSnapshot(
        teamId: 900000 + index,
        teamName: 'Equipe demo ${index + 1}',
        rank: index + 2,
        points: 13 - index,
        played: 5,
        wins: 4 - (index ~/ 3),
        draws: index % 3,
        losses: index ~/ 4,
        goalsFor: 13 - index,
        goalsAgainst: 5 + index,
        form: index.isEven ? 'WWDWL' : 'WDLWD',
      ),
  ]..sort((a, b) => (a.rank ?? 0).compareTo(b.rank ?? 0));

  final homeStanding = standings.firstWhere(
    (standing) => standing.teamId == homeId,
  );
  final awayStanding = standings.firstWhere(
    (standing) => standing.teamId == awayId,
  );
  return match.copyWith(
    compatibility: 0,
    signals: const [],
    analysis: MatchAnalysisData(
      asOf: DateTime.utc(2026, 9, 5, 12),
      homeStanding: homeStanding,
      awayStanding: awayStanding,
      leagueStandings: standings,
    ),
  );
}

const _england = CountryInfo(
  code: 'GB-ENG',
  name: 'Angleterre',
  flagUrl: 'https://media.api-sports.io/flags/gb.svg',
);
const _france = CountryInfo(
  code: 'FR',
  name: 'France',
  flagUrl: 'https://media.api-sports.io/flags/fr.svg',
);
const _portugal = CountryInfo(
  code: 'PT',
  name: 'Portugal',
  flagUrl: 'https://media.api-sports.io/flags/pt.svg',
);
const _italy = CountryInfo(
  code: 'IT',
  name: 'Italie',
  flagUrl: 'https://media.api-sports.io/flags/it.svg',
);
const _netherlands = CountryInfo(
  code: 'NL',
  name: 'Pays-Bas',
  flagUrl: 'https://media.api-sports.io/flags/nl.svg',
);

const _premierLeague = CompetitionInfo(
  id: '39',
  name: 'Premier League',
  country: _england,
  season: 2025,
  apiFootballLeagueId: 39,
  logoUrl: 'https://media.api-sports.io/football/leagues/39.png',
);

const _ligue1 = CompetitionInfo(
  id: '61',
  name: 'Ligue 1',
  country: _france,
  season: 2025,
  apiFootballLeagueId: 61,
  logoUrl: 'https://media.api-sports.io/football/leagues/61.png',
);

const _ligaPortugal = CompetitionInfo(
  id: '94',
  name: 'Liga Portugal',
  country: _portugal,
  season: 2025,
  apiFootballLeagueId: 94,
  logoUrl: 'https://media.api-sports.io/football/leagues/94.png',
);

const _serieA = CompetitionInfo(
  id: '135',
  name: 'Serie A',
  country: _italy,
  season: 2025,
  apiFootballLeagueId: 135,
  logoUrl: 'https://media.api-sports.io/football/leagues/135.png',
);

const _eredivisie = CompetitionInfo(
  id: '88',
  name: 'Eredivisie',
  country: _netherlands,
  season: 2025,
  apiFootballLeagueId: 88,
  logoUrl: 'https://media.api-sports.io/football/leagues/88.png',
);
