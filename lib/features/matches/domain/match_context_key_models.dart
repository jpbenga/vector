enum MatchContextKeyFamily {
  hierarchy,
  structure,
  form,
  venue,
  attack,
  defense,
  opposition,
}

enum MatchContextKeyAvailability { unavailable, noRemarkableFact, available }

enum ChampionshipContextMetric { pointsPerGame, form, goalsFor, goalsAgainst }

enum ChampionshipContextZoneSide { high, low }

class MatchContextKeyHighlight {
  const MatchContextKeyHighlight({
    required this.teamId,
    required this.direction,
  });

  final int teamId;
  final ChampionshipContextZoneSide direction;
}

class ChampionshipContextValue {
  const ChampionshipContextValue({
    required this.teamId,
    required this.teamName,
    required this.value,
  });

  final int teamId;
  final String teamName;
  final double value;
}

class ChampionshipContextZone {
  const ChampionshipContextZone({
    required this.side,
    required this.values,
    required this.separationGap,
    required this.upperFence,
    required this.internalSpan,
  });

  final ChampionshipContextZoneSide side;
  final List<ChampionshipContextValue> values;
  final double separationGap;
  final double upperFence;
  final double internalSpan;

  bool containsTeam(int teamId) =>
      values.any((value) => value.teamId == teamId);
}

class ChampionshipContextDistribution {
  const ChampionshipContextDistribution({
    required this.metric,
    required this.values,
    required this.positiveGaps,
    required this.q1,
    required this.q3,
    required this.iqr,
    required this.upperFence,
    this.highZone,
    this.lowZone,
  });

  final ChampionshipContextMetric metric;
  final List<ChampionshipContextValue> values;
  final List<double> positiveGaps;
  final double q1;
  final double q3;
  final double iqr;
  final double upperFence;
  final ChampionshipContextZone? highZone;
  final ChampionshipContextZone? lowZone;

  ChampionshipContextZone? zoneForTeam(int teamId) {
    final high = highZone;
    if (high?.containsTeam(teamId) ?? false) {
      return high;
    }
    final low = lowZone;
    if (low?.containsTeam(teamId) ?? false) {
      return low;
    }
    return null;
  }

  ChampionshipContextValue? valueForTeam(int teamId) {
    for (final value in values) {
      if (value.teamId == teamId) {
        return value;
      }
    }
    return null;
  }
}

class ChampionshipContextReference {
  const ChampionshipContextReference({
    required this.competitionId,
    required this.season,
    required this.standingsSnapshotIdentity,
    required this.analysisAsOf,
    required this.teamCount,
    required this.distributions,
  });

  final String competitionId;
  final int season;
  final String standingsSnapshotIdentity;
  final DateTime analysisAsOf;
  final int teamCount;
  final Map<ChampionshipContextMetric, ChampionshipContextDistribution>
  distributions;

  ChampionshipContextDistribution? distributionFor(
    ChampionshipContextMetric metric,
  ) {
    return distributions[metric];
  }
}

class MatchContextKey {
  const MatchContextKey({
    required this.family,
    required this.semanticScope,
    required this.subjectTeamIds,
    required this.facts,
    required this.sourcePaths,
    this.highlights = const [],
    this.sourceFamilies = const {},
  });

  final MatchContextKeyFamily family;
  final String semanticScope;
  final List<int> subjectTeamIds;
  final Map<String, Object?> facts;
  final List<String> sourcePaths;
  final List<MatchContextKeyHighlight> highlights;
  final Set<MatchContextKeyFamily> sourceFamilies;
}
