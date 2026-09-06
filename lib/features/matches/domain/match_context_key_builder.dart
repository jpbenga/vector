import 'match_board_item.dart';
import 'match_context_key_models.dart';
import 'structural_tiers/tier_models.dart';

class ChampionshipContextReferenceBuilder {
  const ChampionshipContextReferenceBuilder();

  static const minimumDistributionTeamCount = 10;

  ChampionshipContextReference? build(MatchBoardItem match) {
    final analysis = match.analysis;
    final asOf = analysis.asOf;
    final standings = analysis.leagueStandings;
    if (asOf == null || standings.isEmpty) {
      return null;
    }

    final distributions =
        <ChampionshipContextMetric, ChampionshipContextDistribution>{
          if (_valuesFor(
                standings,
                valueFor: (standing) {
                  final played = standing.played;
                  final points = standing.points;
                  return played == null || played <= 0 || points == null
                      ? null
                      : points / played;
                },
              )
              case final values
              when values.length >= minimumDistributionTeamCount)
            ChampionshipContextMetric.pointsPerGame: _distribution(
              ChampionshipContextMetric.pointsPerGame,
              values,
            ),
          if (_valuesFor(
                standings,
                valueFor: (standing) => _formPoints(standing)?.toDouble(),
              )
              case final values
              when values.length >= minimumDistributionTeamCount)
            ChampionshipContextMetric.form: _distribution(
              ChampionshipContextMetric.form,
              values,
            ),
          if (_valuesFor(
                standings,
                valueFor: (standing) {
                  final played = standing.played;
                  final goals = standing.goalsFor;
                  return played == null || played <= 0 || goals == null
                      ? null
                      : goals / played;
                },
              )
              case final values
              when values.length >= minimumDistributionTeamCount)
            ChampionshipContextMetric.goalsFor: _distribution(
              ChampionshipContextMetric.goalsFor,
              values,
            ),
          if (_valuesFor(
                standings,
                valueFor: (standing) {
                  final played = standing.played;
                  final goals = standing.goalsAgainst;
                  return played == null || played <= 0 || goals == null
                      ? null
                      : goals / played;
                },
              )
              case final values
              when values.length >= minimumDistributionTeamCount)
            ChampionshipContextMetric.goalsAgainst: _distribution(
              ChampionshipContextMetric.goalsAgainst,
              values,
            ),
        };

    return ChampionshipContextReference(
      competitionId: match.competition.id,
      season: match.competition.season,
      standingsSnapshotIdentity: _standingsIdentity(match, standings, asOf),
      analysisAsOf: asOf,
      teamCount: standings.length,
      distributions: Map.unmodifiable(distributions),
    );
  }

  ChampionshipContextDistribution _distribution(
    ChampionshipContextMetric metric,
    List<ChampionshipContextValue> values,
  ) {
    values.sort((a, b) => b.value.compareTo(a.value));
    final gaps = <double>[
      for (var index = 0; index < values.length - 1; index += 1)
        values[index].value - values[index + 1].value,
    ];
    final positiveGaps = gaps.where((gap) => gap > 0).toList()..sort();
    final q1 = _lowerQuartile(positiveGaps);
    final q3 = _upperQuartile(positiveGaps);
    final iqr = q3 - q1;
    final upperFence = q3 + 1.5 * iqr;
    final zones = _isolatedEdgeZones(
      values: values,
      gaps: gaps,
      upperFence: upperFence,
    );

    return ChampionshipContextDistribution(
      metric: metric,
      values: List.unmodifiable(values),
      positiveGaps: List.unmodifiable(positiveGaps),
      q1: q1,
      q3: q3,
      iqr: iqr,
      upperFence: upperFence,
      highZone: zones.high,
      lowZone: zones.low,
    );
  }

  ({ChampionshipContextZone? high, ChampionshipContextZone? low})
  _isolatedEdgeZones({
    required List<ChampionshipContextValue> values,
    required List<double> gaps,
    required double upperFence,
  }) {
    final highCandidates = <ChampionshipContextZone>[];
    final lowCandidates = <ChampionshipContextZone>[];
    for (var index = 0; index < gaps.length; index += 1) {
      final gap = gaps[index];
      if (gap <= upperFence) {
        continue;
      }
      final highValues = values.sublist(0, index + 1);
      final lowValues = values.sublist(index + 1);
      final highSpan = _span(highValues);
      final lowSpan = _span(lowValues);

      // A boundary identifies the compact edge it isolates, never both of its
      // complementary groups. This stays relative to the same distribution.
      if (highSpan < gap && highSpan < lowSpan) {
        highCandidates.add(
          _zone(
            side: ChampionshipContextZoneSide.high,
            values: highValues,
            separationGap: gap,
            upperFence: upperFence,
            internalSpan: highSpan,
          ),
        );
      } else if (lowSpan < gap && lowSpan < highSpan) {
        lowCandidates.add(
          _zone(
            side: ChampionshipContextZoneSide.low,
            values: lowValues,
            separationGap: gap,
            upperFence: upperFence,
            internalSpan: lowSpan,
          ),
        );
      }
    }

    return (
      high: _strongestUniqueZone(highCandidates),
      low: _strongestUniqueZone(lowCandidates),
    );
  }

  static ChampionshipContextZone _zone({
    required ChampionshipContextZoneSide side,
    required List<ChampionshipContextValue> values,
    required double separationGap,
    required double upperFence,
    required double internalSpan,
  }) {
    return ChampionshipContextZone(
      side: side,
      values: List.unmodifiable(values),
      separationGap: separationGap,
      upperFence: upperFence,
      internalSpan: internalSpan,
    );
  }

  static double _span(List<ChampionshipContextValue> values) {
    return values.first.value - values.last.value;
  }

  static ChampionshipContextZone? _strongestUniqueZone(
    List<ChampionshipContextZone> candidates,
  ) {
    if (candidates.isEmpty) {
      return null;
    }
    final strongestGap = candidates
        .map((candidate) => candidate.separationGap)
        .reduce((a, b) => a > b ? a : b);
    final strongest = candidates
        .where((candidate) => candidate.separationGap == strongestGap)
        .toList(growable: false);
    return strongest.length == 1 ? strongest.single : null;
  }

  static List<ChampionshipContextValue> _valuesFor(
    List<TeamStandingSnapshot> standings, {
    required double? Function(TeamStandingSnapshot) valueFor,
  }) {
    return [
      for (final standing in standings)
        if (valueFor(standing) case final value?)
          ChampionshipContextValue(
            teamId: standing.teamId,
            teamName: standing.teamName,
            value: value,
          ),
    ];
  }

  static int? _formPoints(TeamStandingSnapshot standing) {
    final normalized = (standing.form ?? '').toUpperCase().replaceAll(
      RegExp('[^WDL]'),
      '',
    );
    if (normalized.isEmpty) {
      return null;
    }
    final windowLength = normalized.length > 5 ? 5 : normalized.length;
    return normalized.substring(0, windowLength).split('').fold<int>(0, (
      score,
      result,
    ) {
      return score +
          (result == 'W'
              ? 3
              : result == 'D'
              ? 1
              : 0);
    });
  }

  static String _standingsIdentity(
    MatchBoardItem match,
    List<TeamStandingSnapshot> standings,
    DateTime asOf,
  ) {
    final structuralIdentity =
        match.analysis.championshipTierSnapshot?.standingsSnapshotIdentity;
    if (structuralIdentity != null && structuralIdentity.isNotEmpty) {
      return structuralIdentity;
    }
    final rows = [...standings]..sort((a, b) => a.teamId.compareTo(b.teamId));
    return '${match.competition.id}:${match.competition.season}:${asOf.toUtc().toIso8601String()}:${rows.map((row) => '${row.teamId}:${row.rank}:${row.points}:${row.played}:${row.form}:${row.goalsFor}:${row.goalsAgainst}').join('|')}';
  }

  static double _lowerQuartile(List<double> sortedValues) {
    if (sortedValues.isEmpty) {
      return double.infinity;
    }
    final middle = sortedValues.length ~/ 2;
    return _median(sortedValues.sublist(0, middle));
  }

  static double _upperQuartile(List<double> sortedValues) {
    if (sortedValues.isEmpty) {
      return double.infinity;
    }
    final middle = sortedValues.length ~/ 2;
    final upper = sortedValues.length.isEven
        ? sortedValues.sublist(middle)
        : sortedValues.sublist(middle + 1);
    return _median(upper);
  }

  static double _median(List<double> values) {
    if (values.isEmpty) {
      return double.infinity;
    }
    final middle = values.length ~/ 2;
    return values.length.isOdd
        ? values[middle]
        : (values[middle - 1] + values[middle]) / 2;
  }
}

class MatchContextKeyBuilder {
  const MatchContextKeyBuilder();

  List<MatchContextKey> build(
    MatchBoardItem match, {
    ChampionshipContextReference? reference,
  }) {
    if (!_isEligibleMatch(match, reference)) {
      return const [];
    }
    final homeId = match.homeTeam.apiFootballTeamId;
    final awayId = match.awayTeam.apiFootballTeamId;
    if (homeId == null || awayId == null) {
      return const [];
    }

    final hierarchy = _hierarchyKey(match, reference!, homeId, awayId);
    final structure = _structureKey(match, homeId, awayId);
    final form = _formKey(match, reference, homeId, awayId);
    final attack = _attackKey(match, reference, homeId, awayId);
    final defense = _defenseKey(match, reference, homeId, awayId);
    final opposition = _oppositionKey(match, reference, homeId, awayId);

    final candidates = <MatchContextKey>[
      ?hierarchy,
      ?structure,
      ?form,
      ?attack,
      ?defense,
      ?opposition,
    ];
    return List.unmodifiable(_deduplicate(candidates, homeId, awayId).take(4));
  }

  static bool _isEligibleMatch(
    MatchBoardItem match,
    ChampionshipContextReference? reference,
  ) {
    final asOf = match.analysis.asOf;
    final kickoff = match.fixture.kickoff;
    return reference != null &&
        match.fixture.status == FixtureStatus.scheduled &&
        asOf != null &&
        kickoff != null &&
        !asOf.isAfter(kickoff) &&
        reference.competitionId == match.competition.id &&
        reference.season == match.competition.season &&
        reference.analysisAsOf == asOf;
  }

  MatchContextKey? _hierarchyKey(
    MatchBoardItem match,
    ChampionshipContextReference reference,
    int homeId,
    int awayId,
  ) {
    final relation = match.analysis.structuralRelation;
    if (relation?.balancedHierarchy.exists ?? false) {
      return null;
    }
    final home = match.analysis.homeStanding;
    final away = match.analysis.awayStanding;
    final distribution = reference.distributionFor(
      ChampionshipContextMetric.pointsPerGame,
    );
    if (home == null ||
        away == null ||
        distribution == null ||
        home.rank == null ||
        away.rank == null ||
        home.points == null ||
        away.points == null ||
        home.played == null ||
        away.played == null) {
      return null;
    }
    final homeZone = distribution.zoneForTeam(homeId);
    final awayZone = distribution.zoneForTeam(awayId);
    if (_sameZone(homeZone, awayZone)) {
      return null;
    }
    if (homeZone == null && awayZone == null) {
      return null;
    }
    return MatchContextKey(
      family: MatchContextKeyFamily.hierarchy,
      semanticScope: 'official_positioning',
      subjectTeamIds: [homeId, awayId],
      facts: {
        'homeRank': home.rank!,
        'awayRank': away.rank!,
        'homePoints': home.points!,
        'awayPoints': away.points!,
        'homePlayed': home.played!,
        'awayPlayed': away.played!,
        'homeZone': homeZone?.side.name,
        'awayZone': awayZone?.side.name,
      },
      highlights: _highlights(homeId, homeZone, awayId, awayZone),
      sourcePaths: const [
        'standings[].rank',
        'standings[].points',
        'standings[].all.played',
      ],
      sourceFamilies: const {MatchContextKeyFamily.hierarchy},
    );
  }

  MatchContextKey? _structureKey(MatchBoardItem match, int homeId, int awayId) {
    final relation = match.analysis.structuralRelation;
    if (relation == null ||
        relation.tierStatus != TierSystemStatus.mature ||
        relation.tierMaturity != TierMaturity.mature ||
        relation.sameTier ||
        relation.confirmedBoundariesBetweenTeams.isEmpty ||
        relation.homeTeamTier == null ||
        relation.awayTeamTier == null) {
      return null;
    }
    final homeTier = relation.homeTeamTier!;
    final awayTier = relation.awayTeamTier!;
    return MatchContextKey(
      family: MatchContextKeyFamily.structure,
      semanticScope: 'championship_structure',
      subjectTeamIds: [homeId, awayId],
      facts: {
        'homeTier': homeTier.code,
        'awayTier': awayTier.code,
        'boundaryCount': relation.structuralBoundaryGap,
        'boundaryStrengths': [
          for (final boundary in relation.confirmedBoundariesBetweenTeams)
            boundary.strength.name,
        ],
      },
      sourcePaths: const [
        'MatchStructuralRelation.confirmedBoundariesBetweenTeams',
      ],
      sourceFamilies: const {MatchContextKeyFamily.structure},
    );
  }

  MatchContextKey? _formKey(
    MatchBoardItem match,
    ChampionshipContextReference reference,
    int homeId,
    int awayId,
  ) {
    final distribution = reference.distributionFor(
      ChampionshipContextMetric.form,
    );
    final home = match.analysis.homeStanding;
    final away = match.analysis.awayStanding;
    if (distribution == null || home == null || away == null) {
      return null;
    }
    final homeZone = distribution.zoneForTeam(homeId);
    final awayZone = distribution.zoneForTeam(awayId);
    if (homeZone == null && awayZone == null) {
      return null;
    }
    final homeForm = _normalizedForm(home.form);
    final awayForm = _normalizedForm(away.form);
    if (homeForm == null || awayForm == null) {
      return null;
    }
    return MatchContextKey(
      family: MatchContextKeyFamily.form,
      semanticScope: 'recent_form',
      subjectTeamIds: [homeId, awayId],
      facts: {
        'homeForm': homeForm,
        'awayForm': awayForm,
        'homePoints': _formScore(homeForm),
        'awayPoints': _formScore(awayForm),
        'homeZone': homeZone?.side.name,
        'awayZone': awayZone?.side.name,
      },
      highlights: _highlights(homeId, homeZone, awayId, awayZone),
      sourcePaths: const ['standings[].form'],
      sourceFamilies: const {MatchContextKeyFamily.form},
    );
  }

  MatchContextKey? _attackKey(
    MatchBoardItem match,
    ChampionshipContextReference reference,
    int homeId,
    int awayId,
  ) {
    return _rateKey(
      match: match,
      reference: reference,
      homeId: homeId,
      awayId: awayId,
      family: MatchContextKeyFamily.attack,
      metric: ChampionshipContextMetric.goalsFor,
      semanticScope: 'offensive_production',
      rateFact: 'goalsForPerGame',
      sourcePath: 'standings[].all.goals.for',
    );
  }

  MatchContextKey? _defenseKey(
    MatchBoardItem match,
    ChampionshipContextReference reference,
    int homeId,
    int awayId,
  ) {
    return _rateKey(
      match: match,
      reference: reference,
      homeId: homeId,
      awayId: awayId,
      family: MatchContextKeyFamily.defense,
      metric: ChampionshipContextMetric.goalsAgainst,
      semanticScope: 'defensive_exposure',
      rateFact: 'goalsAgainstPerGame',
      sourcePath: 'standings[].all.goals.against',
    );
  }

  MatchContextKey? _rateKey({
    required MatchBoardItem match,
    required ChampionshipContextReference reference,
    required int homeId,
    required int awayId,
    required MatchContextKeyFamily family,
    required ChampionshipContextMetric metric,
    required String semanticScope,
    required String rateFact,
    required String sourcePath,
  }) {
    final distribution = reference.distributionFor(metric);
    if (distribution == null) {
      return null;
    }
    final homeValue = distribution.valueForTeam(homeId);
    final awayValue = distribution.valueForTeam(awayId);
    final homeZone = distribution.zoneForTeam(homeId);
    final awayZone = distribution.zoneForTeam(awayId);
    if (homeValue == null ||
        awayValue == null ||
        (homeZone == null && awayZone == null)) {
      return null;
    }
    return MatchContextKey(
      family: family,
      semanticScope: semanticScope,
      subjectTeamIds: [homeId, awayId],
      facts: {
        'home$rateFact': homeValue.value,
        'away$rateFact': awayValue.value,
        'homeZone': homeZone?.side.name,
        'awayZone': awayZone?.side.name,
      },
      highlights: _highlights(homeId, homeZone, awayId, awayZone),
      sourcePaths: [sourcePath, 'standings[].all.played'],
      sourceFamilies: {family},
    );
  }

  MatchContextKey? _oppositionKey(
    MatchBoardItem match,
    ChampionshipContextReference reference,
    int homeId,
    int awayId,
  ) {
    final attack = reference.distributionFor(
      ChampionshipContextMetric.goalsFor,
    );
    final defense = reference.distributionFor(
      ChampionshipContextMetric.goalsAgainst,
    );
    if (attack == null || defense == null) {
      return null;
    }
    final directions = <({int attackTeamId, int defenseTeamId})>[
      if (attack.zoneForTeam(homeId)?.side ==
              ChampionshipContextZoneSide.high &&
          defense.zoneForTeam(awayId)?.side == ChampionshipContextZoneSide.high)
        (attackTeamId: homeId, defenseTeamId: awayId),
      if (attack.zoneForTeam(awayId)?.side ==
              ChampionshipContextZoneSide.high &&
          defense.zoneForTeam(homeId)?.side == ChampionshipContextZoneSide.high)
        (attackTeamId: awayId, defenseTeamId: homeId),
    ];
    if (directions.isEmpty) {
      return null;
    }
    final direction = directions.first;
    final attackValue = attack.valueForTeam(direction.attackTeamId)!;
    final defenseValue = defense.valueForTeam(direction.defenseTeamId)!;
    return MatchContextKey(
      family: MatchContextKeyFamily.opposition,
      semanticScope: 'attack_against_exposed_defense',
      subjectTeamIds: [direction.attackTeamId, direction.defenseTeamId],
      facts: {
        'attackTeamId': direction.attackTeamId,
        'defenseTeamId': direction.defenseTeamId,
        'goalsForPerGame': attackValue.value,
        'goalsAgainstPerGame': defenseValue.value,
      },
      sourcePaths: const [
        'standings[].all.goals.for',
        'standings[].all.goals.against',
        'standings[].all.played',
      ],
      sourceFamilies: const {
        MatchContextKeyFamily.attack,
        MatchContextKeyFamily.defense,
      },
    );
  }

  static List<MatchContextKeyHighlight> _highlights(
    int homeId,
    ChampionshipContextZone? homeZone,
    int awayId,
    ChampionshipContextZone? awayZone,
  ) {
    return List.unmodifiable([
      if (homeZone case final zone?)
        MatchContextKeyHighlight(teamId: homeId, direction: zone.side),
      if (awayZone case final zone?)
        MatchContextKeyHighlight(teamId: awayId, direction: zone.side),
    ]);
  }

  List<MatchContextKey> _deduplicate(
    List<MatchContextKey> candidates,
    int homeId,
    int awayId,
  ) {
    MatchContextKey? hierarchy = _first(
      candidates,
      MatchContextKeyFamily.hierarchy,
    );
    final structure = _first(candidates, MatchContextKeyFamily.structure);
    if (hierarchy != null && structure != null) {
      hierarchy = MatchContextKey(
        family: MatchContextKeyFamily.hierarchy,
        semanticScope: 'championship_positioning',
        subjectTeamIds: [homeId, awayId],
        facts: {...hierarchy.facts, ...structure.facts},
        sourcePaths: [...hierarchy.sourcePaths, ...structure.sourcePaths],
        highlights: hierarchy.highlights,
        sourceFamilies: const {
          MatchContextKeyFamily.hierarchy,
          MatchContextKeyFamily.structure,
        },
      );
    }
    final opposition = _first(candidates, MatchContextKeyFamily.opposition);
    final form = _first(candidates, MatchContextKeyFamily.form);
    final result = <MatchContextKey>[
      ?hierarchy,
      if (hierarchy == null) ?structure,
      ?form,
      ?opposition,
      for (final family in [
        MatchContextKeyFamily.attack,
        MatchContextKeyFamily.defense,
      ])
        if (_first(candidates, family) case final key?)
          if (opposition == null || !_absorbedByOpposition(key, opposition))
            key,
    ];
    result.sort(
      (a, b) => _familyPriority(a.family).compareTo(_familyPriority(b.family)),
    );
    return result;
  }

  static MatchContextKey? _first(
    Iterable<MatchContextKey> keys,
    MatchContextKeyFamily family,
  ) {
    for (final key in keys) {
      if (key.family == family) {
        return key;
      }
    }
    return null;
  }

  static bool _absorbedByOpposition(
    MatchContextKey key,
    MatchContextKey opposition,
  ) {
    return key.subjectTeamIds.toSet().containsAll(opposition.subjectTeamIds);
  }

  static bool _sameZone(
    ChampionshipContextZone? first,
    ChampionshipContextZone? second,
  ) {
    return first != null &&
        second != null &&
        first.side == second.side &&
        first.values
            .map((value) => value.teamId)
            .toSet()
            .containsAll(second.values.map((value) => value.teamId));
  }

  static String? _normalizedForm(String? form) {
    final normalized = (form ?? '').toUpperCase().replaceAll(
      RegExp('[^WDL]'),
      '',
    );
    if (normalized.isEmpty) {
      return null;
    }
    return normalized.substring(
      0,
      normalized.length > 5 ? 5 : normalized.length,
    );
  }

  static int _formScore(String form) {
    return form.split('').fold<int>(0, (score, result) {
      return score +
          (result == 'W'
              ? 3
              : result == 'D'
              ? 1
              : 0);
    });
  }

  static int _familyPriority(MatchContextKeyFamily family) {
    return switch (family) {
      MatchContextKeyFamily.structure => 0,
      MatchContextKeyFamily.hierarchy => 1,
      MatchContextKeyFamily.form => 2,
      MatchContextKeyFamily.opposition => 3,
      MatchContextKeyFamily.attack => 4,
      MatchContextKeyFamily.defense => 5,
      MatchContextKeyFamily.venue => 6,
    };
  }
}
