import 'analysis_maturity.dart';
import 'football_reading.dart';
import 'match_board_item.dart';
import 'match_context_key_builder.dart';
import 'match_context_key_models.dart';
import 'structural_tiers/tier_models.dart';

class FootballAnalyzer {
  const FootballAnalyzer();

  FootballAnalysis analyze(MatchBoardItem match, {DateTime? asOf}) {
    final snapshotTime =
        asOf ?? match.analysis.asOf ?? match.fixture.kickoff ?? DateTime.now();
    final maturity = AnalysisMaturityResolver.forMatch(match);
    final reference = const ChampionshipContextReferenceBuilder().build(match);
    final readings = <FootballReading>[
      ..._hierarchyReadings(match, snapshotTime, reference),
      ..._formReadings(match, snapshotTime, reference),
      ..._homeAwayReadings(match, snapshotTime),
      ..._attackReadings(match, snapshotTime, reference),
      ..._defenseReadings(match, snapshotTime, reference),
      ..._rhythmReadings(match, snapshotTime),
      ..._expectedGoalsReadings(match, snapshotTime),
      ..._standoutGoalScorerReadings(match, snapshotTime),
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
          strength: ReadingStrength.weak,
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

    final maturityAdjusted = maturity.isEarly
        ? allReadings.map(_makeEarlyReading).toList(growable: false)
        : allReadings;
    return FootballAnalysis(
      fixtureId: match.id,
      asOf: snapshotTime,
      readings: List.unmodifiable(maturityAdjusted),
      maturity: maturity,
    );
  }

  List<FootballReading> _hierarchyReadings(
    MatchBoardItem match,
    DateTime asOf,
    ChampionshipContextReference? reference,
  ) {
    final home = match.analysis.homeStanding;
    final away = match.analysis.awayStanding;
    if (home?.rank == null ||
        away?.rank == null ||
        home?.points == null ||
        away?.points == null ||
        home?.played == null ||
        away?.played == null) {
      return const [];
    }

    final rankGap = (home!.rank! - away!.rank!).abs();
    final pointsGap = (home.points! - away.points!).abs();
    final sampleSize = [home.played!, away.played!].reduce(_min);
    final distribution = reference?.distributionFor(
      ChampionshipContextMetric.pointsPerGame,
    );
    final homeId = match.homeTeam.apiFootballTeamId;
    final awayId = match.awayTeam.apiFootballTeamId;
    final homeZone = homeId == null ? null : distribution?.zoneForTeam(homeId);
    final awayZone = awayId == null ? null : distribution?.zoneForTeam(awayId);
    final superiorSide = home.rank! < away.rank!
        ? ReadingSubjectSide.home
        : ReadingSubjectSide.away;
    final superiorTeam = superiorSide == ReadingSubjectSide.home
        ? match.homeTeam
        : match.awayTeam;
    final readings = <FootballReading>[];

    final structuralRelation = match.analysis.structuralRelation;
    if (structuralRelation?.balancedHierarchy.exists ?? false) {
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
                  'Hiérarchie équilibrée sans frontière structurelle confirmée : ${match.homeTeam.name} #${home.rank}, ${match.awayTeam.name} #${away.rank}.',
              kind: ReadingEvidenceKind.standing,
              sourcePath: 'MatchStructuralRelation',
              value: {
                'rankGap': rankGap,
                'pointsGap': pointsGap,
                'typicalGap': structuralRelation?.typicalGap,
              },
            ),
          ],
        ),
      );
    }

    final pointsPerGameGap =
        (home.points! / home.played! - away.points! / away.played!).abs();
    if ((homeZone != null || awayZone != null) && homeZone != awayZone) {
      readings.add(
        _reading(
          id: 'ranking_superiority',
          teamId: superiorTeam.id,
          side: superiorSide,
          strength: ReadingStrength.moderate,
          asOf: asOf,
          sampleSize: sampleSize,
          evidence: [
            ReadingEvidence(
              label:
                  '${superiorTeam.name} possède un écart mesurable au classement ($rankGap rangs, $pointsGap pts).',
              kind: ReadingEvidenceKind.standing,
              sourcePath: 'standings[].rank + standings[].points',
              value: {
                'rankGap': rankGap,
                'pointsGap': pointsGap,
                'pointsPerGameGap': pointsPerGameGap,
                'homePlayed': home.played,
                'awayPlayed': away.played,
              },
            ),
          ],
        ),
      );
    }

    final structuralGap = structuralRelation == null
        ? null
        : superiorSide == ReadingSubjectSide.home
        ? structuralRelation.homeStructuralLevelGap
        : structuralRelation.awayStructuralLevelGap;
    if (structuralGap?.exists ?? false) {
      readings.add(
        _reading(
          id: 'structural_level_gap',
          teamId: superiorTeam.id,
          side: superiorSide,
          strength: structuralGap?.strength == StructuralLevelGapStrength.strong
              ? ReadingStrength.strong
              : ReadingStrength.moderate,
          asOf: asOf,
          sampleSize: sampleSize,
          evidence: [
            ReadingEvidence(
              label:
                  'Écart structurel confirmé par ${structuralRelation!.structuralBoundaryGap} frontière(s) entre ${match.homeTeam.name} et ${match.awayTeam.name}.',
              kind: ReadingEvidenceKind.standing,
              sourcePath:
                  'MatchStructuralRelation.confirmedBoundariesBetweenTeams',
              value: {
                'rankGap': rankGap,
                'pointsGap': pointsGap,
                'structuralBoundaryGap':
                    structuralRelation.structuralBoundaryGap,
                'ordinalTierGap': structuralRelation.ordinalTierGap,
              },
            ),
          ],
        ),
      );
    }

    return readings;
  }

  List<FootballReading> _formReadings(
    MatchBoardItem match,
    DateTime asOf,
    ChampionshipContextReference? reference,
  ) {
    final distribution = reference?.distributionFor(
      ChampionshipContextMetric.form,
    );
    final homeId = match.homeTeam.apiFootballTeamId;
    final awayId = match.awayTeam.apiFootballTeamId;
    if (distribution == null || homeId == null || awayId == null) {
      return const [];
    }

    final readings = <FootballReading>[];
    final homeZone = distribution.zoneForTeam(homeId);
    final awayZone = distribution.zoneForTeam(awayId);
    final homeForm = _recentFormForSide(match, ReadingSubjectSide.home);
    final awayForm = _recentFormForSide(match, ReadingSubjectSide.away);

    void addDirectional(
      TeamInfo team,
      ReadingSubjectSide side,
      ChampionshipContextZone? zone,
      String? form,
    ) {
      if (zone == null || form == null) {
        return;
      }
      final isHigh = zone.side == ChampionshipContextZoneSide.high;
      readings.add(
        _reading(
          id: isHigh ? 'positive_streak' : 'negative_streak',
          teamId: team.id,
          side: side,
          strength: ReadingStrength.moderate,
          asOf: asOf,
          sampleSize: form.length,
          evidence: [
            ReadingEvidence(
              label: isHigh
                  ? '${team.name} appartient à une zone de forme haute dans ce championnat ($form).'
                  : '${team.name} appartient à une zone de forme basse dans ce championnat ($form).',
              kind: ReadingEvidenceKind.form,
              sourcePath: 'standings[].form',
              value: form,
            ),
          ],
        ),
      );
    }

    addDirectional(match.homeTeam, ReadingSubjectSide.home, homeZone, homeForm);
    addDirectional(match.awayTeam, ReadingSubjectSide.away, awayZone, awayForm);

    if (homeZone?.side == ChampionshipContextZoneSide.high &&
        awayZone?.side == ChampionshipContextZoneSide.low &&
        homeForm != null &&
        awayForm != null) {
      readings.add(
        _formAdvantageReading(
          team: match.homeTeam,
          side: ReadingSubjectSide.home,
          homeForm: homeForm,
          awayForm: awayForm,
          asOf: asOf,
        ),
      );
    } else if (awayZone?.side == ChampionshipContextZoneSide.high &&
        homeZone?.side == ChampionshipContextZoneSide.low &&
        homeForm != null &&
        awayForm != null) {
      readings.add(
        _formAdvantageReading(
          team: match.awayTeam,
          side: ReadingSubjectSide.away,
          homeForm: homeForm,
          awayForm: awayForm,
          asOf: asOf,
        ),
      );
    }
    return readings;
  }

  FootballReading _formAdvantageReading({
    required TeamInfo team,
    required ReadingSubjectSide side,
    required String homeForm,
    required String awayForm,
    required DateTime asOf,
  }) {
    return _reading(
      id: 'form_advantage',
      teamId: team.id,
      side: side,
      strength: ReadingStrength.moderate,
      asOf: asOf,
      sampleSize: _min(homeForm.length, awayForm.length),
      evidence: [
        ReadingEvidence(
          label:
              '${team.name} oppose une zone de forme haute à une zone basse adverse ($homeForm vs $awayForm).',
          kind: ReadingEvidenceKind.form,
          sourcePath: 'standings[].form',
          value: {'homeForm': homeForm, 'awayForm': awayForm},
        ),
      ],
    );
  }

  List<FootballReading> _homeAwayReadings(MatchBoardItem match, DateTime asOf) {
    final home = match.analysis.homeStatistics;
    final away = match.analysis.awayStatistics;
    final readings = <FootballReading>[];

    final homePlayed = home?.playedHome ?? home?.playedTotal;
    final homeWins = home?.winsHome ?? home?.winsTotal;
    final homeLosses = home?.lossesHome ?? home?.lossesTotal;
    final awayPlayed = away?.playedAway ?? away?.playedTotal;
    final awayWins = away?.winsAway ?? away?.winsTotal;
    final awayLosses = away?.lossesAway ?? away?.lossesTotal;

    if (homePlayed != null &&
        homePlayed > 0 &&
        homeWins != null &&
        homeLosses != null &&
        homeWins > homeLosses) {
      final rate = homeWins / homePlayed;
      readings.add(
        _reading(
          id: 'strong_home_team',
          teamId: match.homeTeam.id,
          side: ReadingSubjectSide.home,
          strength: ReadingStrength.moderate,
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

    if (homePlayed != null &&
        homePlayed > 0 &&
        homeWins != null &&
        homeLosses != null &&
        homeLosses > homeWins) {
      final rate = homeLosses / homePlayed;
      readings.add(
        _reading(
          id: 'weak_home_team',
          teamId: match.homeTeam.id,
          side: ReadingSubjectSide.home,
          strength: ReadingStrength.moderate,
          asOf: asOf,
          sampleSize: homePlayed,
          evidence: [
            ReadingEvidence(
              label:
                  '${match.homeTeam.name} perd ${_percent(rate)} de ses matchs à domicile.',
              kind: ReadingEvidenceKind.homeAway,
              sourcePath: 'teams/statistics.fixtures.loses.home',
              value: rate,
            ),
          ],
        ),
      );
    }

    if (awayPlayed != null &&
        awayPlayed > 0 &&
        awayWins != null &&
        awayLosses != null &&
        awayWins > awayLosses) {
      final rate = awayWins / awayPlayed;
      readings.add(
        _reading(
          id: 'strong_away_team',
          teamId: match.awayTeam.id,
          side: ReadingSubjectSide.away,
          strength: ReadingStrength.moderate,
          asOf: asOf,
          sampleSize: awayPlayed,
          evidence: [
            ReadingEvidence(
              label:
                  '${match.awayTeam.name} gagne ${_percent(rate)} de ses déplacements.',
              kind: ReadingEvidenceKind.homeAway,
              sourcePath: 'teams/statistics.fixtures.wins.away',
              value: rate,
            ),
          ],
        ),
      );
    }

    if (awayPlayed != null &&
        awayPlayed > 0 &&
        awayWins != null &&
        awayLosses != null &&
        awayLosses > awayWins) {
      final rate = awayLosses / awayPlayed;
      readings.add(
        _reading(
          id: 'weak_away_team',
          teamId: match.awayTeam.id,
          side: ReadingSubjectSide.away,
          strength: ReadingStrength.moderate,
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

    if (readings.any((reading) => reading.id == 'strong_home_team') &&
        readings.any((reading) => reading.id == 'weak_away_team')) {
      readings.add(
        _reading(
          id: 'home_away_mismatch',
          teamId: match.id,
          side: ReadingSubjectSide.match,
          strength: ReadingStrength.moderate,
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

    if (readings.any((reading) => reading.id == 'strong_away_team') &&
        readings.any((reading) => reading.id == 'weak_home_team')) {
      readings.add(
        _reading(
          id: 'home_away_mismatch',
          teamId: match.id,
          side: ReadingSubjectSide.match,
          strength: ReadingStrength.moderate,
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

  List<FootballReading> _attackReadings(
    MatchBoardItem match,
    DateTime asOf,
    ChampionshipContextReference? reference,
  ) => _relativeGoalReadings(
    match: match,
    asOf: asOf,
    reference: reference,
    metric: ChampionshipContextMetric.goalsFor,
    highId: 'prolific_attack',
    lowId: 'scoring_difficulty',
    highLabel: 'marque',
    lowLabel: 'marque peu',
    sourcePath: 'standings[].all.goals.for',
  );

  List<FootballReading> _defenseReadings(
    MatchBoardItem match,
    DateTime asOf,
    ChampionshipContextReference? reference,
  ) => _relativeGoalReadings(
    match: match,
    asOf: asOf,
    reference: reference,
    metric: ChampionshipContextMetric.goalsAgainst,
    highId: 'fragile_defense',
    lowId: 'solid_defense',
    highLabel: 'encaisse',
    lowLabel: 'encaisse peu',
    sourcePath: 'standings[].all.goals.against',
  );

  List<FootballReading> _relativeGoalReadings({
    required MatchBoardItem match,
    required DateTime asOf,
    required ChampionshipContextReference? reference,
    required ChampionshipContextMetric metric,
    required String highId,
    required String lowId,
    required String highLabel,
    required String lowLabel,
    required String sourcePath,
  }) {
    final distribution = reference?.distributionFor(metric);
    final homeId = match.homeTeam.apiFootballTeamId;
    final awayId = match.awayTeam.apiFootballTeamId;
    if (distribution == null || homeId == null || awayId == null) {
      return const [];
    }
    final readings = <FootballReading>[];
    for (final entry in [
      (team: match.homeTeam, side: ReadingSubjectSide.home, id: homeId),
      (team: match.awayTeam, side: ReadingSubjectSide.away, id: awayId),
    ]) {
      final value = distribution.valueForTeam(entry.id);
      final zone = distribution.zoneForTeam(entry.id);
      final standing = _standingForSide(match, entry.side);
      if (value == null || zone == null || standing?.played == null) {
        continue;
      }
      final isHigh = zone.side == ChampionshipContextZoneSide.high;
      final verb = isHigh ? highLabel : lowLabel;
      readings.add(
        _reading(
          id: isHigh ? highId : lowId,
          teamId: entry.team.id,
          side: entry.side,
          strength: ReadingStrength.moderate,
          asOf: asOf,
          sampleSize: standing!.played!,
          evidence: [
            ReadingEvidence(
              label:
                  '${entry.team.name} $verb ${value.value.toStringAsFixed(2)} but(s) par match, dans une zone ${isHigh ? 'haute' : 'basse'} du championnat.',
              kind: ReadingEvidenceKind.goals,
              sourcePath: sourcePath,
              value: value.value,
            ),
          ],
        ),
      );
    }
    return readings;
  }

  List<FootballReading> _rhythmReadings(MatchBoardItem match, DateTime asOf) {
    // No match-level championship reference exists yet. Do not turn raw team
    // averages into an "open" or "closed" qualification with a fixed cutoff.
    return const [];
  }

  /// Identifies a unique, sufficiently exposed scoring-rate leader inside its
  /// own team. There is no universal goals or minutes threshold: exposure is
  /// compared to the team's observed minutes distribution, and the scoring
  /// distinction is relative to the other players of that same team.
  List<FootballReading> _standoutGoalScorerReadings(
    MatchBoardItem match,
    DateTime asOf,
  ) {
    return [
      ..._standoutGoalScorerForTeam(
        teamId: match.homeTeam.id,
        side: ReadingSubjectSide.home,
        players: match.analysis.homePlayerStatistics,
        asOf: asOf,
      ),
      ..._standoutGoalScorerForTeam(
        teamId: match.awayTeam.id,
        side: ReadingSubjectSide.away,
        players: match.analysis.awayPlayerStatistics,
        asOf: asOf,
      ),
    ];
  }

  List<FootballReading> _standoutGoalScorerForTeam({
    required String teamId,
    required ReadingSubjectSide side,
    required List<PlayerSeasonStatisticsSnapshot> players,
    required DateTime asOf,
  }) {
    final exposed = players
        .where((player) => (player.minutes ?? 0) > 0)
        .where((player) => player.goalsPer90 != null)
        .toList(growable: false);
    if (exposed.length < 2) return const [];

    final minuteMedian = _median(
      exposed.map((player) => player.minutes!.toDouble()),
    );
    final candidates = exposed
        .where((player) => player.minutes! >= minuteMedian)
        .where((player) => (player.goals ?? 0) > 0)
        .toList(growable: false);
    if (candidates.isEmpty) return const [];

    final highestRate = candidates
        .map((player) => player.goalsPer90!)
        .reduce((a, b) => a > b ? a : b);
    final leaders = candidates
        .where((player) => player.goalsPer90! == highestRate)
        .toList(growable: false);
    if (leaders.length != 1) return const [];
    final leader = leaders.single;
    final otherRates = exposed
        .where((player) => player.playerId != leader.playerId)
        .map((player) => player.goalsPer90!)
        .toList(growable: false);
    if (otherRates.isEmpty || highestRate <= _upperQuartile(otherRates)) {
      return const [];
    }

    final appearances = leader.appearances;
    final evidence = <ReadingEvidence>[
      ReadingEvidence(
        label:
            '${leader.playerName} se distingue dans ${leader.teamName} : ${leader.goals} but${leader.goals == 1 ? '' : 's'} en ${leader.minutes} min (${highestRate.toStringAsFixed(2)} but/90).',
        kind: ReadingEvidenceKind.player,
        sourcePath: 'players.statistics.games.minutes + goals.total',
        value: {
          'playerId': leader.playerId,
          'teamId': leader.teamId,
          'goals': leader.goals,
          'minutes': leader.minutes,
          'appearances': appearances,
          'lineups': leader.lineups,
          'goalsPer90': highestRate,
        },
      ),
    ];
    return [
      FootballReading(
        id: 'standout_goal_scorer',
        subjectTeamId: teamId,
        subjectSide: side,
        subjectKind: ReadingSubjectKind.player,
        playerId: leader.playerId,
        playerName: leader.playerName,
        status: ReadingStatus.detected,
        strength: ReadingStrength.moderate,
        evidence: evidence,
        warnings: const [],
        asOf: asOf,
        sampleSize: appearances ?? 0,
      ),
    ];
  }

  double _median(Iterable<double> values) {
    final sorted = values.toList()..sort();
    final middle = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[middle]
        : (sorted[middle - 1] + sorted[middle]) / 2;
  }

  double _upperQuartile(Iterable<double> values) {
    final sorted = values.toList()..sort();
    final start = sorted.length ~/ 2;
    return _median(sorted.sublist(start));
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
    if (xg == null) {
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

    // xG is retained as pre-match data, but there is no championship-level
    // xG reference in the current snapshot. A fixed xG cutoff would recreate
    // a fixed qualification problem, so the analyzer deliberately abstains here.
    return const [];
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

  String? _recentFormForSide(MatchBoardItem match, ReadingSubjectSide side) {
    final form =
        _standingForSide(match, side)?.form ??
        _statisticsForSide(match, side)?.form;
    if (form == null) {
      return null;
    }
    final normalized = form.toUpperCase().replaceAll(RegExp('[^WDL]'), '');
    if (normalized.isEmpty) {
      return null;
    }
    return normalized.substring(
      0,
      normalized.length > 5 ? 5 : normalized.length,
    );
  }

  FootballReading _makeEarlyReading(FootballReading reading) {
    return reading.copyWith(
      strength: ReadingStrength.weak,
      warnings: [
        ...reading.warnings,
        const ReadingWarning(
          id: 'early_championship_analysis',
          label:
              'Championnat en phase précoce : lecture visible mais non exploitable automatiquement.',
          sourcePath:
              'MatchAnalysisData.homeStanding.played/awayStanding.played',
        ),
      ],
    );
  }

  int _min(int a, int b) => a < b ? a : b;

  String _percent(double value) => '${(value * 100).round()}%';
}
