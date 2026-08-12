import 'football_reading.dart';
import 'football_reading_rules.dart';
import 'match_board_item.dart';

class FootballAnalyzer {
  const FootballAnalyzer();

  FootballAnalysis analyze(MatchBoardItem match, {DateTime? asOf}) {
    final snapshotTime =
        asOf ?? match.analysis.asOf ?? match.fixture.kickoff ?? DateTime.now();
    final readings = <FootballReading>[
      ..._hierarchyReadings(match, snapshotTime),
      ..._formReadings(match, snapshotTime),
      ..._homeAwayReadings(match, snapshotTime),
      ..._attackReadings(match, snapshotTime),
      ..._defenseReadings(match, snapshotTime),
      ..._rhythmReadings(match, snapshotTime),
      ..._expectedGoalsReadings(match, snapshotTime),
    ];

    final contradictions = _contradictions(match, snapshotTime, readings);
    final allReadings = [...readings, ...contradictions];

    if (allReadings.where((reading) => reading.isDetected).isEmpty) {
      allReadings.add(
        FootballReading(
          id: 'insufficient_data',
          subjectTeamId: match.id,
          subjectSide: ReadingSubjectSide.match,
          status: ReadingStatus.detected,
          strength: ReadingStrength.strong,
          evidence: const [
            ReadingEvidence(
              label: 'Aucun échantillon exploitable ne soutient une lecture.',
              kind: ReadingEvidenceKind.sample,
              sourcePath: 'MatchAnalysisData',
            ),
          ],
          warnings: const [],
          asOf: snapshotTime,
          sampleSize: 0,
          isContradiction: true,
        ),
      );
    }

    return FootballAnalysis(
      fixtureId: match.id,
      asOf: snapshotTime,
      readings: List.unmodifiable(allReadings),
    );
  }

  List<FootballReading> _hierarchyReadings(
    MatchBoardItem match,
    DateTime asOf,
  ) {
    final home = match.analysis.homeStanding;
    final away = match.analysis.awayStanding;
    if (home?.rank == null || away?.rank == null) {
      return const [];
    }

    final rankGap = (home!.rank! - away!.rank!).abs();
    final pointsGap = home.points == null || away.points == null
        ? 0
        : (home.points! - away.points!).abs();
    final sampleSize = [home.played ?? 0, away.played ?? 0].reduce(_min);
    final superiorSide = home.rank! < away.rank!
        ? ReadingSubjectSide.home
        : ReadingSubjectSide.away;
    final superiorTeam = superiorSide == ReadingSubjectSide.home
        ? match.homeTeam
        : match.awayTeam;
    final readings = <FootballReading>[];

    if (rankGap <= 2 && pointsGap <= 4) {
      readings.add(
        _reading(
          id: 'balanced_hierarchy',
          teamId: match.id,
          side: ReadingSubjectSide.match,
          strength: ReadingStrength.moderate,
          asOf: asOf,
          sampleSize: sampleSize,
          evidence: [
            ReadingEvidence(
              label:
                  'Hiérarchie proche : ${match.homeTeam.name} #${home.rank}, ${match.awayTeam.name} #${away.rank}.',
              kind: ReadingEvidenceKind.standing,
              sourcePath: 'standings[].rank',
              value: rankGap,
            ),
          ],
        ),
      );
    }

    if (rankGap >= 3 || pointsGap >= 5) {
      readings.add(
        _reading(
          id: 'ranking_superiority',
          teamId: superiorTeam.id,
          side: superiorSide,
          strength: ReadingStrengthResolver.fromGap(
            (rankGap + pointsGap / 2).toDouble(),
            5,
            10,
          ),
          asOf: asOf,
          sampleSize: sampleSize,
          evidence: [
            ReadingEvidence(
              label:
                  '${superiorTeam.name} possède un avantage de classement ($rankGap rangs, $pointsGap pts).',
              kind: ReadingEvidenceKind.standing,
              sourcePath: 'standings[].rank + standings[].points',
              value: {'rankGap': rankGap, 'pointsGap': pointsGap},
            ),
          ],
        ),
      );
    }

    if (rankGap >= 5 || pointsGap >= 8) {
      readings.add(
        _reading(
          id: 'structural_level_gap',
          teamId: superiorTeam.id,
          side: superiorSide,
          strength: ReadingStrengthResolver.fromGap(
            (rankGap + pointsGap / 2).toDouble(),
            8,
            14,
          ),
          asOf: asOf,
          sampleSize: sampleSize,
          evidence: [
            ReadingEvidence(
              label:
                  'Écart structurel confirmé entre ${match.homeTeam.name} et ${match.awayTeam.name}.',
              kind: ReadingEvidenceKind.standing,
              sourcePath: 'standings[].rank + standings[].points',
              value: {'rankGap': rankGap, 'pointsGap': pointsGap},
            ),
          ],
        ),
      );
    }

    return readings;
  }

  List<FootballReading> _formReadings(MatchBoardItem match, DateTime asOf) {
    return [
      ..._formFor(match.homeTeam, ReadingSubjectSide.home, match, asOf),
      ..._formFor(match.awayTeam, ReadingSubjectSide.away, match, asOf),
    ];
  }

  List<FootballReading> _formFor(
    TeamInfo team,
    ReadingSubjectSide side,
    MatchBoardItem match,
    DateTime asOf,
  ) {
    final form =
        _standingForSide(match, side)?.form ??
        _statisticsForSide(match, side)?.form;
    if (form == null || form.length < 3) {
      return const [];
    }

    final normalized = form.toUpperCase().replaceAll(RegExp('[^WDL]'), '');
    final sampleSize = normalized.length.clamp(0, 5);
    if (sampleSize < 3) {
      return const [];
    }

    final recent = normalized.substring(0, sampleSize);
    final score = _formScore(recent);
    final readings = <FootballReading>[];
    if (sampleSize >= 5 && score >= 10) {
      readings.add(
        _reading(
          id: 'positive_streak',
          teamId: team.id,
          side: side,
          strength: score >= 13
              ? ReadingStrength.strong
              : ReadingStrength.moderate,
          asOf: asOf,
          sampleSize: sampleSize,
          evidence: [
            ReadingEvidence(
              label: '${team.name} reste sur une dynamique positive ($recent).',
              kind: ReadingEvidenceKind.form,
              sourcePath: 'standings[].form',
              value: recent,
            ),
          ],
        ),
      );
    }
    if (sampleSize >= 5 && score <= 4) {
      readings.add(
        _reading(
          id: 'negative_streak',
          teamId: team.id,
          side: side,
          strength: score <= 2
              ? ReadingStrength.strong
              : ReadingStrength.moderate,
          asOf: asOf,
          sampleSize: sampleSize,
          evidence: [
            ReadingEvidence(
              label: '${team.name} traverse une dynamique négative ($recent).',
              kind: ReadingEvidenceKind.form,
              sourcePath: 'standings[].form',
              value: recent,
            ),
          ],
        ),
      );
    }

    if (sampleSize >= 5) {
      final firstTwo = _formScore(recent.substring(3, 5));
      final lastThree = _formScore(recent.substring(0, 3));
      if (lastThree >= firstTwo + 4) {
        readings.add(
          _reading(
            id: 'improving_form',
            teamId: team.id,
            side: side,
            strength: ReadingStrength.moderate,
            asOf: asOf,
            sampleSize: sampleSize,
            evidence: [
              ReadingEvidence(
                label:
                    '${team.name} montre une amélioration récente ($recent).',
                kind: ReadingEvidenceKind.form,
                sourcePath: 'standings[].form',
                value: recent,
              ),
            ],
          ),
        );
      } else if (lastThree + 4 <= firstTwo) {
        readings.add(
          _reading(
            id: 'declining_form',
            teamId: team.id,
            side: side,
            strength: ReadingStrength.moderate,
            asOf: asOf,
            sampleSize: sampleSize,
            evidence: [
              ReadingEvidence(
                label:
                    '${team.name} se dégrade dans la série récente ($recent).',
                kind: ReadingEvidenceKind.form,
                sourcePath: 'standings[].form',
                value: recent,
              ),
            ],
          ),
        );
      }
    }

    return readings;
  }

  List<FootballReading> _homeAwayReadings(MatchBoardItem match, DateTime asOf) {
    final home = match.analysis.homeStatistics;
    final away = match.analysis.awayStatistics;
    final readings = <FootballReading>[];

    final homePlayed = home?.playedHome ?? home?.playedTotal;
    final homeWins = home?.winsHome ?? home?.winsTotal;
    final awayPlayed = away?.playedAway ?? away?.playedTotal;
    final awayLosses = away?.lossesAway ?? away?.lossesTotal;

    if (homePlayed != null && homePlayed >= 5 && homeWins != null) {
      final rate = homeWins / homePlayed;
      if (rate >= FootballReadingRules.homeAway.thresholds['strongRate']!) {
        readings.add(
          _reading(
            id: 'strong_home_team',
            teamId: match.homeTeam.id,
            side: ReadingSubjectSide.home,
            strength: rate >= .72
                ? ReadingStrength.strong
                : ReadingStrength.moderate,
            asOf: asOf,
            sampleSize: homePlayed,
            evidence: [
              ReadingEvidence(
                label:
                    '${match.homeTeam.name} gagne ${_percent(rate)} de ses matchs à domicile.',
                kind: ReadingEvidenceKind.homeAway,
                sourcePath: 'teams/statistics.fixtures.wins.home',
                value: rate,
              ),
            ],
          ),
        );
      }
    }

    if (awayPlayed != null && awayPlayed >= 5 && awayLosses != null) {
      final rate = awayLosses / awayPlayed;
      if (rate >= FootballReadingRules.homeAway.thresholds['weakLossRate']!) {
        readings.add(
          _reading(
            id: 'weak_away_team',
            teamId: match.awayTeam.id,
            side: ReadingSubjectSide.away,
            strength: rate >= .58
                ? ReadingStrength.strong
                : ReadingStrength.moderate,
            asOf: asOf,
            sampleSize: awayPlayed,
            evidence: [
              ReadingEvidence(
                label:
                    '${match.awayTeam.name} perd ${_percent(rate)} de ses déplacements.',
                kind: ReadingEvidenceKind.homeAway,
                sourcePath: 'teams/statistics.fixtures.loses.away',
                value: rate,
              ),
            ],
          ),
        );
      }
    }

    if (readings.any((reading) => reading.id == 'strong_home_team') &&
        readings.any((reading) => reading.id == 'weak_away_team')) {
      readings.add(
        _reading(
          id: 'home_away_mismatch',
          teamId: match.id,
          side: ReadingSubjectSide.match,
          strength: ReadingStrength.strong,
          asOf: asOf,
          sampleSize: _min(homePlayed ?? 0, awayPlayed ?? 0),
          evidence: const [
            ReadingEvidence(
              label: 'Le split domicile/extérieur renforce la lecture.',
              kind: ReadingEvidenceKind.homeAway,
              sourcePath: 'teams/statistics.fixtures.home/away',
            ),
          ],
        ),
      );
    }

    return readings;
  }

  List<FootballReading> _attackReadings(MatchBoardItem match, DateTime asOf) {
    return [
      ..._attackFor(match.homeTeam, ReadingSubjectSide.home, match, asOf),
      ..._attackFor(match.awayTeam, ReadingSubjectSide.away, match, asOf),
    ];
  }

  List<FootballReading> _attackFor(
    TeamInfo team,
    ReadingSubjectSide side,
    MatchBoardItem match,
    DateTime asOf,
  ) {
    final stats = _statisticsForSide(match, side);
    final average = stats?.goalsForAverageTotal;
    final played = stats?.playedTotal ?? 0;
    if (average == null || played < 8) {
      return const [];
    }

    if (average >= FootballReadingRules.attack.thresholds['prolific']!) {
      return [
        _reading(
          id: 'prolific_attack',
          teamId: team.id,
          side: side,
          strength: average >= 2.05
              ? ReadingStrength.strong
              : ReadingStrength.moderate,
          asOf: asOf,
          sampleSize: played,
          evidence: [
            ReadingEvidence(
              label:
                  '${team.name} marque ${average.toStringAsFixed(2)} but(s) par match.',
              kind: ReadingEvidenceKind.goals,
              sourcePath: 'teams/statistics.goals.for.average.total',
              value: average,
            ),
          ],
        ),
      ];
    }

    if (average <= FootballReadingRules.attack.thresholds['difficulty']!) {
      return [
        _reading(
          id: 'scoring_difficulty',
          teamId: team.id,
          side: side,
          strength: average <= .65
              ? ReadingStrength.strong
              : ReadingStrength.moderate,
          asOf: asOf,
          sampleSize: played,
          evidence: [
            ReadingEvidence(
              label:
                  '${team.name} produit peu au score (${average.toStringAsFixed(2)} but/match).',
              kind: ReadingEvidenceKind.goals,
              sourcePath: 'teams/statistics.goals.for.average.total',
              value: average,
            ),
          ],
        ),
      ];
    }

    return const [];
  }

  List<FootballReading> _defenseReadings(MatchBoardItem match, DateTime asOf) {
    return [
      ..._defenseFor(match.homeTeam, ReadingSubjectSide.home, match, asOf),
      ..._defenseFor(match.awayTeam, ReadingSubjectSide.away, match, asOf),
    ];
  }

  List<FootballReading> _defenseFor(
    TeamInfo team,
    ReadingSubjectSide side,
    MatchBoardItem match,
    DateTime asOf,
  ) {
    final stats = _statisticsForSide(match, side);
    final average = stats?.goalsAgainstAverageTotal;
    final played = stats?.playedTotal ?? 0;
    final readings = <FootballReading>[];
    if (average == null || played < 8) {
      return readings;
    }

    if (average <= FootballReadingRules.defense.thresholds['solid']!) {
      readings.add(
        _reading(
          id: 'solid_defense',
          teamId: team.id,
          side: side,
          strength: average <= .75
              ? ReadingStrength.strong
              : ReadingStrength.moderate,
          asOf: asOf,
          sampleSize: played,
          evidence: [
            ReadingEvidence(
              label:
                  '${team.name} encaisse seulement ${average.toStringAsFixed(2)} but/match.',
              kind: ReadingEvidenceKind.goals,
              sourcePath: 'teams/statistics.goals.against.average.total',
              value: average,
            ),
          ],
        ),
      );
    }

    if (average >= FootballReadingRules.defense.thresholds['fragile']!) {
      readings.add(
        _reading(
          id: 'fragile_defense',
          teamId: team.id,
          side: side,
          strength: average >= 1.95
              ? ReadingStrength.strong
              : ReadingStrength.moderate,
          asOf: asOf,
          sampleSize: played,
          evidence: [
            ReadingEvidence(
              label:
                  '${team.name} concède ${average.toStringAsFixed(2)} but(s) par match.',
              kind: ReadingEvidenceKind.goals,
              sourcePath: 'teams/statistics.goals.against.average.total',
              value: average,
            ),
          ],
        ),
      );
    }

    final cleanSheets = stats?.cleanSheetsTotal;
    if (cleanSheets != null && played > 0) {
      final rate = cleanSheets / played;
      if (rate >= FootballReadingRules.defense.thresholds['cleanSheetRate']!) {
        readings.add(
          _reading(
            id: 'frequent_clean_sheet',
            teamId: team.id,
            side: side,
            strength: rate >= .50
                ? ReadingStrength.strong
                : ReadingStrength.moderate,
            asOf: asOf,
            sampleSize: played,
            evidence: [
              ReadingEvidence(
                label:
                    '${team.name} garde sa cage inviolée ${_percent(rate)} du temps.',
                kind: ReadingEvidenceKind.goals,
                sourcePath: 'teams/statistics.clean_sheet.total',
                value: rate,
              ),
            ],
          ),
        );
      }
    }

    return readings;
  }

  List<FootballReading> _rhythmReadings(MatchBoardItem match, DateTime asOf) {
    final home = match.analysis.homeStatistics;
    final away = match.analysis.awayStatistics;
    final homeFor = home?.goalsForAverageTotal;
    final awayFor = away?.goalsForAverageTotal;
    final homeAgainst = home?.goalsAgainstAverageTotal;
    final awayAgainst = away?.goalsAgainstAverageTotal;
    if (homeFor == null ||
        awayFor == null ||
        homeAgainst == null ||
        awayAgainst == null) {
      return const [];
    }

    final sampleSize = _min(home?.playedTotal ?? 0, away?.playedTotal ?? 0);
    if (sampleSize < 8) {
      return const [];
    }

    final climate = (homeFor + awayFor + homeAgainst + awayAgainst) / 2;
    if (climate >= FootballReadingRules.rhythm.thresholds['open']!) {
      return [
        _reading(
          id: 'open_match_profile',
          teamId: match.id,
          side: ReadingSubjectSide.match,
          strength: climate >= 3.20
              ? ReadingStrength.strong
              : ReadingStrength.moderate,
          asOf: asOf,
          sampleSize: sampleSize,
          evidence: [
            ReadingEvidence(
              label:
                  'Le climat buts agrégé atteint ${climate.toStringAsFixed(2)}.',
              kind: ReadingEvidenceKind.goals,
              sourcePath: 'teams/statistics.goals.*.average.total',
              value: climate,
            ),
          ],
        ),
        _reading(
          id: 'frequent_over_25',
          teamId: match.id,
          side: ReadingSubjectSide.match,
          strength: ReadingStrength.moderate,
          asOf: asOf,
          sampleSize: sampleSize,
          evidence: [
            ReadingEvidence(
              label:
                  'Le profil global soutient un scénario au-dessus de 2,5 buts.',
              kind: ReadingEvidenceKind.goals,
              sourcePath: 'teams/statistics.goals.*.average.total',
              value: climate,
            ),
          ],
        ),
      ];
    }

    if (climate <= FootballReadingRules.rhythm.thresholds['closed']!) {
      return [
        _reading(
          id: 'closed_match_profile',
          teamId: match.id,
          side: ReadingSubjectSide.match,
          strength: climate <= 1.80
              ? ReadingStrength.strong
              : ReadingStrength.moderate,
          asOf: asOf,
          sampleSize: sampleSize,
          evidence: [
            ReadingEvidence(
              label:
                  'Le climat buts agrégé reste bas (${climate.toStringAsFixed(2)}).',
              kind: ReadingEvidenceKind.goals,
              sourcePath: 'teams/statistics.goals.*.average.total',
              value: climate,
            ),
          ],
        ),
        _reading(
          id: 'frequent_under_25',
          teamId: match.id,
          side: ReadingSubjectSide.match,
          strength: ReadingStrength.moderate,
          asOf: asOf,
          sampleSize: sampleSize,
          evidence: [
            ReadingEvidence(
              label: 'Le profil global soutient un scénario sous 2,5 buts.',
              kind: ReadingEvidenceKind.goals,
              sourcePath: 'teams/statistics.goals.*.average.total',
              value: climate,
            ),
          ],
        ),
      ];
    }

    return const [];
  }

  List<FootballReading> _expectedGoalsReadings(
    MatchBoardItem match,
    DateTime asOf,
  ) {
    return [
      ..._expectedGoalsFor(
        match.homeTeam,
        ReadingSubjectSide.home,
        match,
        asOf,
      ),
      ..._expectedGoalsFor(
        match.awayTeam,
        ReadingSubjectSide.away,
        match,
        asOf,
      ),
    ];
  }

  List<FootballReading> _expectedGoalsFor(
    TeamInfo team,
    ReadingSubjectSide side,
    MatchBoardItem match,
    DateTime asOf,
  ) {
    final xg = side == ReadingSubjectSide.home
        ? match.analysis.homeExpectedGoals
        : match.analysis.awayExpectedGoals;
    if (xg == null ||
        xg.sampleSize < FootballReadingRules.expectedGoals.minimumSampleSize) {
      return const [];
    }

    final kickoff = match.fixture.kickoff;
    if (kickoff != null && xg.asOf.isAfter(kickoff)) {
      return [
        FootballReading(
          id: 'insufficient_data',
          subjectTeamId: team.id,
          subjectSide: side,
          status: ReadingStatus.detected,
          strength: ReadingStrength.moderate,
          evidence: const [
            ReadingEvidence(
              label:
                  'Les xG disponibles sont postérieurs au snapshot pré-match.',
              kind: ReadingEvidenceKind.expectedGoals,
              sourcePath: 'fixtures/statistics[].expected_goals',
              isPostMatchOnly: true,
            ),
          ],
          warnings: const [
            ReadingWarning(
              id: 'post_match_xg_rejected',
              label: 'xG non utilisés pour une lecture pré-match.',
              sourcePath: 'fixtures/statistics[].expected_goals',
            ),
          ],
          asOf: asOf,
          sampleSize: xg.sampleSize,
          isContradiction: true,
        ),
      ];
    }

    final readings = <FootballReading>[];
    final created = xg.rollingXgFor5;
    final conceded = xg.rollingXgAgainst5;
    if (created != null) {
      if (created >=
          FootballReadingRules.expectedGoals.thresholds['highCreation']!) {
        readings.add(
          _xgReading(
            id: 'high_xg_creation',
            team: team,
            side: side,
            value: created,
            asOf: asOf,
            sampleSize: xg.sampleSize,
            label:
                '${team.name} produit ${created.toStringAsFixed(2)} xG en moyenne récente.',
          ),
        );
      } else if (created <=
          FootballReadingRules.expectedGoals.thresholds['lowCreation']!) {
        readings.add(
          _xgReading(
            id: 'low_xg_creation',
            team: team,
            side: side,
            value: created,
            asOf: asOf,
            sampleSize: xg.sampleSize,
            label:
                '${team.name} crée peu d’occasions nettes (${created.toStringAsFixed(2)} xG).',
          ),
        );
      }
    }

    if (conceded != null &&
        conceded >=
            FootballReadingRules.expectedGoals.thresholds['highConceded']!) {
      readings.add(
        _xgReading(
          id: 'high_xg_conceded',
          team: team,
          side: side,
          value: conceded,
          asOf: asOf,
          sampleSize: xg.sampleSize,
          label:
              '${team.name} concède ${conceded.toStringAsFixed(2)} xG en moyenne récente.',
        ),
      );
    }

    final goalsMinusXg = xg.goalsMinusXgFor5;
    if (goalsMinusXg != null) {
      final threshold =
          FootballReadingRules.expectedGoals.thresholds['divergence']!;
      if (goalsMinusXg <= -threshold) {
        readings.add(
          _xgReading(
            id: 'offensive_underperformance',
            team: team,
            side: side,
            value: goalsMinusXg,
            asOf: asOf,
            sampleSize: xg.sampleSize,
            label:
                '${team.name} marque moins que sa production xG récente ne le suggère.',
          ),
        );
      } else if (goalsMinusXg >= threshold) {
        readings.add(
          _xgReading(
            id: 'offensive_overperformance',
            team: team,
            side: side,
            value: goalsMinusXg,
            asOf: asOf,
            sampleSize: xg.sampleSize,
            label:
                '${team.name} marque davantage que sa production xG récente.',
          ),
        );
      }
    }

    final concededMinusXg = xg.goalsConcededMinusXgAgainst5;
    if (concededMinusXg != null) {
      final threshold =
          FootballReadingRules.expectedGoals.thresholds['divergence']!;
      if (concededMinusXg <= -threshold) {
        readings.add(
          _xgReading(
            id: 'defensive_overperformance',
            team: team,
            side: side,
            value: concededMinusXg,
            asOf: asOf,
            sampleSize: xg.sampleSize,
            label:
                '${team.name} encaisse moins que les xG concédés ne le suggèrent.',
          ),
        );
      } else if (concededMinusXg >= threshold) {
        readings.add(
          _xgReading(
            id: 'defensive_underperformance',
            team: team,
            side: side,
            value: concededMinusXg,
            asOf: asOf,
            sampleSize: xg.sampleSize,
            label:
                '${team.name} encaisse plus que les xG concédés ne le suggèrent.',
          ),
        );
      }
    }

    return readings;
  }

  List<FootballReading> _contradictions(
    MatchBoardItem match,
    DateTime asOf,
    List<FootballReading> readings,
  ) {
    final result = <FootballReading>[];
    for (final team in [match.homeTeam, match.awayTeam]) {
      final teamReadings = readings
          .where((reading) => reading.subjectTeamId == team.id)
          .map((reading) => reading.id)
          .toSet();

      if (teamReadings.contains('positive_streak') &&
          (teamReadings.contains('offensive_overperformance') ||
              teamReadings.contains('defensive_overperformance'))) {
        result.add(
          _contradiction(
            id: 'misleading_result',
            team: team,
            side: team.id == match.homeTeam.id
                ? ReadingSubjectSide.home
                : ReadingSubjectSide.away,
            asOf: asOf,
            label:
                '${team.name} obtient des résultats positifs, mais les xG invitent à les nuancer.',
          ),
        );
      }

      if (teamReadings.contains('positive_streak') &&
          teamReadings.contains('fragile_defense')) {
        result.add(
          _contradiction(
            id: 'conflicting_signals',
            team: team,
            side: team.id == match.homeTeam.id
                ? ReadingSubjectSide.home
                : ReadingSubjectSide.away,
            asOf: asOf,
            label:
                '${team.name} gagne récemment, mais sa défense reste fragile.',
          ),
        );
      }
    }

    return result;
  }

  FootballReading _reading({
    required String id,
    required String teamId,
    required ReadingSubjectSide side,
    required ReadingStrength strength,
    required DateTime asOf,
    required int sampleSize,
    required List<ReadingEvidence> evidence,
  }) {
    return FootballReading(
      id: id,
      subjectTeamId: teamId,
      subjectSide: side,
      status: ReadingStatus.detected,
      strength: strength,
      evidence: evidence,
      warnings: const [],
      asOf: asOf,
      sampleSize: sampleSize,
    );
  }

  FootballReading _xgReading({
    required String id,
    required TeamInfo team,
    required ReadingSubjectSide side,
    required double value,
    required DateTime asOf,
    required int sampleSize,
    required String label,
  }) {
    return _reading(
      id: id,
      teamId: team.id,
      side: side,
      strength: value.abs() >= 2
          ? ReadingStrength.strong
          : ReadingStrength.moderate,
      asOf: asOf,
      sampleSize: sampleSize,
      evidence: [
        ReadingEvidence(
          label: label,
          kind: ReadingEvidenceKind.expectedGoals,
          sourcePath: 'fixtures/statistics[].statistics[].type=expected_goals',
          value: value,
          isPostMatchOnly: false,
        ),
      ],
    );
  }

  FootballReading _contradiction({
    required String id,
    required TeamInfo team,
    required ReadingSubjectSide side,
    required DateTime asOf,
    required String label,
  }) {
    return FootballReading(
      id: id,
      subjectTeamId: team.id,
      subjectSide: side,
      status: ReadingStatus.detected,
      strength: ReadingStrength.moderate,
      evidence: [
        ReadingEvidence(
          label: label,
          kind: ReadingEvidenceKind.sample,
          sourcePath: 'FootballAnalysis.readings',
        ),
      ],
      warnings: const [],
      asOf: asOf,
      sampleSize: 1,
      isContradiction: true,
    );
  }

  TeamStandingSnapshot? _standingForSide(
    MatchBoardItem match,
    ReadingSubjectSide side,
  ) {
    return side == ReadingSubjectSide.home
        ? match.analysis.homeStanding
        : match.analysis.awayStanding;
  }

  TeamStatisticsSnapshot? _statisticsForSide(
    MatchBoardItem match,
    ReadingSubjectSide side,
  ) {
    return side == ReadingSubjectSide.home
        ? match.analysis.homeStatistics
        : match.analysis.awayStatistics;
  }

  int _formScore(String form) {
    return form.split('').fold(0, (score, result) {
      return score +
          switch (result) {
            'W' => 3,
            'D' => 1,
            _ => 0,
          };
    });
  }

  int _min(int a, int b) => a < b ? a : b;

  String _percent(double value) => '${(value * 100).round()}%';
}
