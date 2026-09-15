import 'football_reading.dart';

enum FootballScenarioScope { team, match }

enum ScenarioRequirementSubject {
  subject,
  opponent,
  home,
  away,
  match,
  bothTeams,
  atLeastOneTeam,
}

enum FootballScenarioAvailability { available, pendingReadings }

class ScenarioReadingRequirement {
  const ScenarioReadingRequirement({
    required this.readingId,
    required this.subject,
  });

  final String readingId;
  final ScenarioRequirementSubject subject;
}

class FootballScenarioDefinition {
  const FootballScenarioDefinition({
    required this.id,
    required this.scope,
    required this.requirements,
    this.availability = FootballScenarioAvailability.available,
  });

  final String id;
  final FootballScenarioScope scope;
  final List<ScenarioReadingRequirement> requirements;
  final FootballScenarioAvailability availability;

  bool get isAvailable =>
      availability == FootballScenarioAvailability.available;
}

class FootballScenarioMatch {
  const FootballScenarioMatch({
    required this.scenarioId,
    required this.subjectTeamId,
    required this.subjectSide,
    required this.supportingReadings,
  });

  final String scenarioId;
  final String subjectTeamId;
  final ReadingSubjectSide subjectSide;
  final List<FootballReading> supportingReadings;
}

class FootballScenarioCatalog {
  const FootballScenarioCatalog._();

  static const values = <FootballScenarioDefinition>[
    FootballScenarioDefinition(
      id: 'solid_favorite',
      scope: FootballScenarioScope.team,
      requirements: [
        ScenarioReadingRequirement(
          readingId: 'ranking_superiority',
          subject: ScenarioRequirementSubject.subject,
        ),
        ScenarioReadingRequirement(
          readingId: 'form_advantage',
          subject: ScenarioRequirementSubject.subject,
        ),
        ScenarioReadingRequirement(
          readingId: 'structural_level_gap',
          subject: ScenarioRequirementSubject.subject,
        ),
      ],
    ),
    FootballScenarioDefinition(
      id: 'struggling_team',
      scope: FootballScenarioScope.team,
      requirements: [
        ScenarioReadingRequirement(
          readingId: 'negative_streak',
          subject: ScenarioRequirementSubject.subject,
        ),
        ScenarioReadingRequirement(
          readingId: 'scoring_difficulty',
          subject: ScenarioRequirementSubject.subject,
        ),
        ScenarioReadingRequirement(
          readingId: 'fragile_defense',
          subject: ScenarioRequirementSubject.subject,
        ),
      ],
    ),
    FootballScenarioDefinition(
      id: 'offensive_match',
      scope: FootballScenarioScope.match,
      availability: FootballScenarioAvailability.pendingReadings,
      requirements: [
        ScenarioReadingRequirement(
          readingId: 'open_match_profile',
          subject: ScenarioRequirementSubject.match,
        ),
        ScenarioReadingRequirement(
          readingId: 'prolific_attack',
          subject: ScenarioRequirementSubject.home,
        ),
        ScenarioReadingRequirement(
          readingId: 'prolific_attack',
          subject: ScenarioRequirementSubject.away,
        ),
        ScenarioReadingRequirement(
          readingId: 'fragile_defense',
          subject: ScenarioRequirementSubject.atLeastOneTeam,
        ),
      ],
    ),
    FootballScenarioDefinition(
      id: 'defensive_match',
      scope: FootballScenarioScope.match,
      availability: FootballScenarioAvailability.pendingReadings,
      requirements: [
        ScenarioReadingRequirement(
          readingId: 'closed_match_profile',
          subject: ScenarioRequirementSubject.match,
        ),
        ScenarioReadingRequirement(
          readingId: 'solid_defense',
          subject: ScenarioRequirementSubject.bothTeams,
        ),
        ScenarioReadingRequirement(
          readingId: 'scoring_difficulty',
          subject: ScenarioRequirementSubject.bothTeams,
        ),
      ],
    ),
    FootballScenarioDefinition(
      id: 'ranking_gap',
      scope: FootballScenarioScope.team,
      requirements: [
        ScenarioReadingRequirement(
          readingId: 'ranking_superiority',
          subject: ScenarioRequirementSubject.subject,
        ),
        ScenarioReadingRequirement(
          readingId: 'structural_level_gap',
          subject: ScenarioRequirementSubject.subject,
        ),
      ],
    ),
    FootballScenarioDefinition(
      id: 'credible_outsider',
      scope: FootballScenarioScope.team,
      availability: FootballScenarioAvailability.pendingReadings,
      requirements: [
        ScenarioReadingRequirement(
          readingId: 'ranking_inferiority',
          subject: ScenarioRequirementSubject.subject,
        ),
        ScenarioReadingRequirement(
          readingId: 'positive_streak',
          subject: ScenarioRequirementSubject.subject,
        ),
        ScenarioReadingRequirement(
          readingId: 'form_advantage',
          subject: ScenarioRequirementSubject.subject,
        ),
        ScenarioReadingRequirement(
          readingId: 'venue_strength',
          subject: ScenarioRequirementSubject.subject,
        ),
        ScenarioReadingRequirement(
          readingId: 'fragile_defense',
          subject: ScenarioRequirementSubject.opponent,
        ),
      ],
    ),
    FootballScenarioDefinition(
      id: 'fragile_defense',
      scope: FootballScenarioScope.team,
      availability: FootballScenarioAvailability.pendingReadings,
      requirements: [
        ScenarioReadingRequirement(
          readingId: 'fragile_defense',
          subject: ScenarioRequirementSubject.subject,
        ),
        ScenarioReadingRequirement(
          readingId: 'high_xg_conceded',
          subject: ScenarioRequirementSubject.subject,
        ),
        ScenarioReadingRequirement(
          readingId: 'high_shots_on_target_conceded',
          subject: ScenarioRequirementSubject.subject,
        ),
      ],
    ),
    FootballScenarioDefinition(
      id: 'prolific_attack',
      scope: FootballScenarioScope.team,
      availability: FootballScenarioAvailability.pendingReadings,
      requirements: [
        ScenarioReadingRequirement(
          readingId: 'prolific_attack',
          subject: ScenarioRequirementSubject.subject,
        ),
        ScenarioReadingRequirement(
          readingId: 'high_xg_creation',
          subject: ScenarioRequirementSubject.subject,
        ),
        ScenarioReadingRequirement(
          readingId: 'high_shots_on_target',
          subject: ScenarioRequirementSubject.subject,
        ),
      ],
    ),
    FootballScenarioDefinition(
      id: 'positive_series',
      scope: FootballScenarioScope.team,
      availability: FootballScenarioAvailability.pendingReadings,
      requirements: [
        ScenarioReadingRequirement(
          readingId: 'positive_streak',
          subject: ScenarioRequirementSubject.subject,
        ),
        ScenarioReadingRequirement(
          readingId: 'improving_form',
          subject: ScenarioRequirementSubject.subject,
        ),
        ScenarioReadingRequirement(
          readingId: 'high_xg_creation',
          subject: ScenarioRequirementSubject.subject,
        ),
      ],
    ),
    FootballScenarioDefinition(
      id: 'negative_series',
      scope: FootballScenarioScope.team,
      availability: FootballScenarioAvailability.pendingReadings,
      requirements: [
        ScenarioReadingRequirement(
          readingId: 'negative_streak',
          subject: ScenarioRequirementSubject.subject,
        ),
        ScenarioReadingRequirement(
          readingId: 'declining_form',
          subject: ScenarioRequirementSubject.subject,
        ),
        ScenarioReadingRequirement(
          readingId: 'low_xg_creation',
          subject: ScenarioRequirementSubject.subject,
        ),
      ],
    ),
  ];

  static FootballScenarioDefinition? byId(String id) {
    for (final definition in values) {
      if (definition.id == id) return definition;
    }
    return null;
  }
}

/// Resolves scenario contracts from the immutable readings produced by the
/// global match analysis. User preferences deliberately do not enter here.
class FootballScenarioDetector {
  const FootballScenarioDetector({
    this.definitions = FootballScenarioCatalog.values,
  });

  final List<FootballScenarioDefinition> definitions;

  List<FootballScenarioMatch> detect({
    required FootballAnalysis analysis,
    required String homeTeamId,
    required String awayTeamId,
  }) {
    final detected = <FootballScenarioMatch>[];
    for (final definition in definitions) {
      if (!definition.isAvailable) continue;

      switch (definition.scope) {
        case FootballScenarioScope.team:
          for (final subject in [
            (id: homeTeamId, side: ReadingSubjectSide.home),
            (id: awayTeamId, side: ReadingSubjectSide.away),
          ]) {
            final readings = _resolveRequirements(
              definition,
              analysis,
              homeTeamId: homeTeamId,
              awayTeamId: awayTeamId,
              subjectTeamId: subject.id,
            );
            if (readings != null) {
              detected.add(
                FootballScenarioMatch(
                  scenarioId: definition.id,
                  subjectTeamId: subject.id,
                  subjectSide: subject.side,
                  supportingReadings: readings,
                ),
              );
            }
          }
        case FootballScenarioScope.match:
          final readings = _resolveRequirements(
            definition,
            analysis,
            homeTeamId: homeTeamId,
            awayTeamId: awayTeamId,
            subjectTeamId: analysis.fixtureId,
          );
          if (readings != null) {
            detected.add(
              FootballScenarioMatch(
                scenarioId: definition.id,
                subjectTeamId: analysis.fixtureId,
                subjectSide: ReadingSubjectSide.match,
                supportingReadings: readings,
              ),
            );
          }
      }
    }
    return List.unmodifiable(detected);
  }

  List<FootballReading>? _resolveRequirements(
    FootballScenarioDefinition definition,
    FootballAnalysis analysis, {
    required String homeTeamId,
    required String awayTeamId,
    required String subjectTeamId,
  }) {
    final opponentTeamId = subjectTeamId == homeTeamId
        ? awayTeamId
        : homeTeamId;
    final resolved = <FootballReading>[];

    for (final requirement in definition.requirements) {
      final matches = _readingsForRequirement(
        requirement,
        analysis,
        homeTeamId: homeTeamId,
        awayTeamId: awayTeamId,
        subjectTeamId: subjectTeamId,
        opponentTeamId: opponentTeamId,
      );
      if (matches == null) return null;
      resolved.addAll(matches);
    }

    return List.unmodifiable(_uniqueReadings(resolved));
  }

  List<FootballReading>? _readingsForRequirement(
    ScenarioReadingRequirement requirement,
    FootballAnalysis analysis, {
    required String homeTeamId,
    required String awayTeamId,
    required String subjectTeamId,
    required String opponentTeamId,
  }) {
    List<FootballReading> forTeam(String teamId) => analysis.readings
        .where(
          (reading) =>
              reading.isDetected &&
              !reading.isContradiction &&
              reading.id == requirement.readingId &&
              reading.subjectTeamId == teamId,
        )
        .toList(growable: false);

    switch (requirement.subject) {
      case ScenarioRequirementSubject.subject:
        return _nonEmpty(forTeam(subjectTeamId));
      case ScenarioRequirementSubject.opponent:
        return _nonEmpty(forTeam(opponentTeamId));
      case ScenarioRequirementSubject.home:
        return _nonEmpty(forTeam(homeTeamId));
      case ScenarioRequirementSubject.away:
        return _nonEmpty(forTeam(awayTeamId));
      case ScenarioRequirementSubject.match:
        final matches = analysis.readings
            .where(
              (reading) =>
                  reading.isDetected &&
                  !reading.isContradiction &&
                  reading.id == requirement.readingId &&
                  reading.subjectSide == ReadingSubjectSide.match &&
                  reading.subjectTeamId == analysis.fixtureId,
            )
            .toList(growable: false);
        return _nonEmpty(matches);
      case ScenarioRequirementSubject.bothTeams:
        final home = forTeam(homeTeamId);
        final away = forTeam(awayTeamId);
        if (home.isEmpty || away.isEmpty) return null;
        return [...home, ...away];
      case ScenarioRequirementSubject.atLeastOneTeam:
        return _nonEmpty([...forTeam(homeTeamId), ...forTeam(awayTeamId)]);
    }
  }

  List<FootballReading>? _nonEmpty(List<FootballReading> readings) {
    return readings.isEmpty ? null : readings;
  }

  List<FootballReading> _uniqueReadings(List<FootballReading> readings) {
    final seen = <String>{};
    return [
      for (final reading in readings)
        if (seen.add(
          '${reading.id}:${reading.subjectTeamId}:${reading.subjectSide.name}',
        ))
          reading,
    ];
  }
}
