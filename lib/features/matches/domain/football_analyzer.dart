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
    final matchCompetitionReadings = <FootballReading>[
      ..._hierarchyReadings(match, snapshotTime, reference),
      ..._formReadings(match, snapshotTime, reference),
      ..._formTrendReadings(match, snapshotTime),
      ..._homeAwayReadings(match, snapshotTime),
      ..._attackReadings(match, snapshotTime, reference),
      ..._defenseReadings(match, snapshotTime, reference),
      ..._rhythmReadings(match, snapshotTime),
      ..._halfTimeReadings(match, snapshotTime),
      ..._goalTimingReadings(match, snapshotTime),
      ..._performanceStatisticsReadings(match, snapshotTime),
      ..._expectedGoalsReadings(match, snapshotTime),
      ..._standoutGoalScorerReadings(match, snapshotTime),
      ..._playerPerformanceReadings(match, snapshotTime),
      ..._keyPlayerUnavailableReadings(match),
    ];
    final isTournament = match.competition.isContinentalTournament;
    final readings = <FootballReading>[
      ...matchCompetitionReadings.map(
        (reading) => isTournament
            ? reading.copyWith(
                competitionScope: ReadingCompetitionScope.tournament,
                sourceCompetitionId: match.competition.id,
                sourceCompetitionName: match.competition.name,
              )
            : reading,
      ),
      if (isTournament) ..._domesticContextReadings(match, snapshotTime),
      if (isTournament) ..._tournamentProgressionReadings(match, snapshotTime),
      if (isTournament) ..._tournamentPathReadings(match, snapshotTime),
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

  List<FootballReading> _halfTimeReadings(MatchBoardItem match, DateTime asOf) {
    final builder = const ChampionshipContextReferenceBuilder();
    final readings = <FootballReading>[];

    void addPhaseReadings({
      required ChampionshipStandingView view,
      required ChampionshipContextMetric metric,
      required String strongId,
      required String weakId,
      required String phaseLabel,
    }) {
      final table = match.analysis.standingsFor(view);
      final distribution = builder.distributionForValues(
        metric: metric,
        values: [
          for (final row in table)
            if (row.played != null && row.played! > 0 && row.points != null)
              ChampionshipContextValue(
                teamId: row.teamId,
                teamName: row.teamName,
                value: row.points! / row.played!,
              ),
        ],
      );
      if (distribution == null) return;

      for (final entry in [
        (team: match.homeTeam, side: ReadingSubjectSide.home),
        (team: match.awayTeam, side: ReadingSubjectSide.away),
      ]) {
        final apiTeamId = entry.team.apiFootballTeamId;
        if (apiTeamId == null) continue;
        final row = table.where((item) => item.teamId == apiTeamId).firstOrNull;
        final zone = distribution.zoneForTeam(apiTeamId);
        if (row == null || zone == null || row.played == null) continue;
        final isStrong = zone.side == ChampionshipContextZoneSide.high;
        readings.add(
          _reading(
            id: isStrong ? strongId : weakId,
            teamId: entry.team.id,
            side: entry.side,
            strength: ReadingStrength.moderate,
            asOf: asOf,
            sampleSize: row.played!,
            evidence: [
              ReadingEvidence(
                label:
                    '${entry.team.name} se situe dans la zone ${isStrong ? 'haute' : 'basse'} du classement $phaseLabel (#${row.rank ?? '—'}, ${row.points ?? 0} pts).',
                kind: ReadingEvidenceKind.standing,
                sourcePath: 'league_fixtures.score.$phaseLabel',
                value: {
                  'rank': row.rank,
                  'points': row.points,
                  'played': row.played,
                  'pointsPerGame': row.points! / row.played!,
                },
              ),
            ],
          ),
        );
      }
    }

    addPhaseReadings(
      view: ChampionshipStandingView.firstHalf,
      metric: ChampionshipContextMetric.firstHalfPointsPerGame,
      strongId: 'strong_first_half_team',
      weakId: 'weak_first_half_team',
      phaseLabel: 'de première mi-temps',
    );
    addPhaseReadings(
      view: ChampionshipStandingView.secondHalf,
      metric: ChampionshipContextMetric.secondHalfPointsPerGame,
      strongId: 'strong_second_half_team',
      weakId: 'weak_second_half_team',
      phaseLabel: 'de seconde mi-temps',
    );

    final firstHalf = match.analysis.standingsFor(
      ChampionshipStandingView.firstHalf,
    );
    void addFrequentResultReading({
      required ChampionshipContextMetric metric,
      required String id,
      required String label,
      required int? Function(TeamStandingSnapshot row) countFor,
    }) {
      final distribution = builder.distributionForValues(
        metric: metric,
        values: [
          for (final row in firstHalf)
            if (row.played != null && row.played! > 0 && countFor(row) != null)
              ChampionshipContextValue(
                teamId: row.teamId,
                teamName: row.teamName,
                value: countFor(row)! / row.played!,
              ),
        ],
      );
      if (distribution == null) return;
      for (final entry in [
        (team: match.homeTeam, side: ReadingSubjectSide.home),
        (team: match.awayTeam, side: ReadingSubjectSide.away),
      ]) {
        final apiTeamId = entry.team.apiFootballTeamId;
        if (apiTeamId == null) continue;
        final row = firstHalf
            .where((item) => item.teamId == apiTeamId)
            .firstOrNull;
        final zone = distribution.zoneForTeam(apiTeamId);
        final count = row == null ? null : countFor(row);
        if (row?.played == null || count == null || zone == null) continue;
        if (zone.side != ChampionshipContextZoneSide.high) continue;
        final rate = count / row!.played!;
        readings.add(
          _reading(
            id: id,
            teamId: entry.team.id,
            side: entry.side,
            strength: ReadingStrength.moderate,
            asOf: asOf,
            sampleSize: row.played!,
            evidence: [
              ReadingEvidence(
                label:
                    '${entry.team.name} $label dans ${_percent(rate)} de ses matchs ($count/${row.played}).',
                kind: ReadingEvidenceKind.form,
                sourcePath: 'league_fixtures.score.halftime',
                value: rate,
              ),
            ],
          ),
        );
      }
    }

    addFrequentResultReading(
      metric: ChampionshipContextMetric.halfTimeLeadRate,
      id: 'frequent_halftime_lead',
      label: 'mène à la pause',
      countFor: (row) => row.wins,
    );
    addFrequentResultReading(
      metric: ChampionshipContextMetric.halfTimeDrawRate,
      id: 'frequent_halftime_draw',
      label: 'est à égalité à la pause',
      countFor: (row) => row.draws,
    );

    void addOutcomeReading({
      required ChampionshipContextMetric metric,
      required double? Function(TeamGoalProfileSnapshot) valueFor,
      required int Function(TeamGoalProfileSnapshot) sampleFor,
      required String id,
      required String label,
    }) {
      final distribution = builder.distributionForValues(
        metric: metric,
        values: [
          for (final profile in match.analysis.leagueGoalProfiles)
            if (valueFor(profile) != null)
              ChampionshipContextValue(
                teamId: profile.teamId,
                teamName: profile.teamName,
                value: valueFor(profile)!,
              ),
        ],
      );
      if (distribution == null) return;
      for (final entry in [
        (
          team: match.homeTeam,
          side: ReadingSubjectSide.home,
          profile: match.analysis.homeGoalProfile,
        ),
        (
          team: match.awayTeam,
          side: ReadingSubjectSide.away,
          profile: match.analysis.awayGoalProfile,
        ),
      ]) {
        final profile = entry.profile;
        if (profile == null ||
            valueFor(profile) == null ||
            distribution.zoneForTeam(profile.teamId)?.side !=
                ChampionshipContextZoneSide.high) {
          continue;
        }
        readings.add(
          _reading(
            id: id,
            teamId: entry.team.id,
            side: entry.side,
            strength: ReadingStrength.moderate,
            asOf: asOf,
            sampleSize: sampleFor(profile),
            evidence: [
              ReadingEvidence(
                label:
                    '${entry.team.name} $label dans ${_percent(valueFor(profile)!)} des cas (${sampleFor(profile)} situations), relativement au championnat.',
                kind: ReadingEvidenceKind.form,
                sourcePath: 'league_fixtures.score.halftime/fulltime',
                value: valueFor(profile),
              ),
            ],
          ),
        );
      }
    }

    addOutcomeReading(
      metric: ChampionshipContextMetric.leadRetentionRate,
      valueFor: (profile) => profile.leadRetentionRate,
      sampleFor: (profile) => profile.halftimeLeads,
      id: 'strong_lead_retention',
      label: 'conserve son avance à la pause',
    );
    addOutcomeReading(
      metric: ChampionshipContextMetric.lostLeadRate,
      valueFor: (profile) => profile.lostLeadRate,
      sampleFor: (profile) => profile.halftimeLeads,
      id: 'weak_lead_retention',
      label: 'perd son avance à la pause',
    );
    addOutcomeReading(
      metric: ChampionshipContextMetric.recoveryRate,
      valueFor: (profile) => profile.recoveryRate,
      sampleFor: (profile) => profile.halftimeDeficits,
      id: 'second_half_recovery',
      label: 'remonte après avoir été menée à la pause',
    );

    return readings;
  }

  List<FootballReading> _goalTimingReadings(
    MatchBoardItem match,
    DateTime asOf,
  ) {
    final leagueStatistics = match.analysis.leagueTeamStatistics;
    final builder = const ChampionshipContextReferenceBuilder();
    final readings = <FootballReading>[];

    void addTimingReading({
      required String bucket,
      required ChampionshipContextMetric metric,
      required String id,
      required String label,
      required bool conceded,
    }) {
      int? countFor(TeamStatisticsSnapshot statistics) => (conceded
          ? statistics.goalsAgainstByMinute
          : statistics.goalsForByMinute)[bucket];
      final distribution = builder.distributionForValues(
        metric: metric,
        values: [
          for (final statistics in leagueStatistics)
            if (statistics.playedTotal != null &&
                statistics.playedTotal! > 0 &&
                countFor(statistics) != null)
              ChampionshipContextValue(
                teamId: statistics.teamId,
                teamName: statistics.teamName,
                value: countFor(statistics)! / statistics.playedTotal!,
              ),
        ],
      );
      if (distribution == null) return;

      for (final entry in [
        (
          team: match.homeTeam,
          side: ReadingSubjectSide.home,
          statistics: match.analysis.homeStatistics,
        ),
        (
          team: match.awayTeam,
          side: ReadingSubjectSide.away,
          statistics: match.analysis.awayStatistics,
        ),
      ]) {
        final apiTeamId = entry.team.apiFootballTeamId;
        final count = entry.statistics == null
            ? null
            : countFor(entry.statistics!);
        final played = entry.statistics?.playedTotal;
        final zone = apiTeamId == null
            ? null
            : distribution.zoneForTeam(apiTeamId);
        if (count == null || played == null || played <= 0 || zone == null) {
          continue;
        }
        if (zone.side != ChampionshipContextZoneSide.high) continue;
        final rate = count / played;
        readings.add(
          _reading(
            id: id,
            teamId: entry.team.id,
            side: entry.side,
            strength: ReadingStrength.moderate,
            asOf: asOf,
            sampleSize: played,
            evidence: [
              ReadingEvidence(
                label:
                    '${entry.team.name} $label entre $bucket ($count fois en $played matchs), dans une zone haute du championnat.',
                kind: ReadingEvidenceKind.goals,
                sourcePath:
                    'teams/statistics.goals.${conceded ? 'against' : 'for'}.minute.$bucket',
                value: rate,
              ),
            ],
          ),
        );
      }
    }

    addTimingReading(
      bucket: '0-15',
      metric: ChampionshipContextMetric.scoringRate0To15,
      id: 'early_scoring_0_15',
      label: 'marque fréquemment',
      conceded: false,
    );
    addTimingReading(
      bucket: '0-15',
      metric: ChampionshipContextMetric.concedingRate0To15,
      id: 'early_conceding_0_15',
      label: 'concède fréquemment',
      conceded: true,
    );
    addTimingReading(
      bucket: '31-45',
      metric: ChampionshipContextMetric.scoringRate31To45,
      id: 'pre_halftime_scoring_31_45',
      label: 'marque fréquemment',
      conceded: false,
    );
    addTimingReading(
      bucket: '31-45',
      metric: ChampionshipContextMetric.concedingRate31To45,
      id: 'pre_halftime_conceding_31_45',
      label: 'concède fréquemment',
      conceded: true,
    );
    addTimingReading(
      bucket: '76-90',
      metric: ChampionshipContextMetric.scoringRate76To90,
      id: 'late_scoring_76_90',
      label: 'marque fréquemment',
      conceded: false,
    );
    addTimingReading(
      bucket: '76-90',
      metric: ChampionshipContextMetric.concedingRate76To90,
      id: 'late_conceding_76_90',
      label: 'concède fréquemment',
      conceded: true,
    );
    return readings;
  }

  List<FootballReading> _performanceStatisticsReadings(
    MatchBoardItem match,
    DateTime asOf,
  ) {
    final leagueStatistics = match.analysis.leaguePerformanceStatistics;
    final kickoff = match.fixture.kickoff;
    final builder = const ChampionshipContextReferenceBuilder();
    final readings = <FootballReading>[];

    void addRelativeReading({
      required ChampionshipContextMetric metric,
      required double? Function(TeamPerformanceStatisticsSnapshot) valueFor,
      required String? highId,
      required String? lowId,
      required String highLabel,
      required String lowLabel,
      required ReadingEvidenceKind evidenceKind,
      required String sourcePath,
      int Function(TeamPerformanceStatisticsSnapshot)? sampleSizeFor,
      String Function(double)? formatValue,
    }) {
      final distribution = builder.distributionForValues(
        metric: metric,
        values: [
          for (final statistics in leagueStatistics)
            if (valueFor(statistics) != null)
              ChampionshipContextValue(
                teamId: statistics.teamId,
                teamName: statistics.teamName,
                value: valueFor(statistics)!,
              ),
        ],
      );
      if (distribution == null) return;

      for (final entry in [
        (
          team: match.homeTeam,
          side: ReadingSubjectSide.home,
          statistics: match.analysis.homePerformanceStatistics,
        ),
        (
          team: match.awayTeam,
          side: ReadingSubjectSide.away,
          statistics: match.analysis.awayPerformanceStatistics,
        ),
      ]) {
        final statistics = entry.statistics;
        final apiTeamId = entry.team.apiFootballTeamId;
        if (statistics == null || apiTeamId == null) continue;
        if (kickoff != null && statistics.asOf.isAfter(kickoff)) continue;
        final value = valueFor(statistics);
        final zone = distribution.zoneForTeam(apiTeamId);
        if (value == null || zone == null) continue;
        final id = zone.side == ChampionshipContextZoneSide.high
            ? highId
            : lowId;
        if (id == null) continue;
        final label = zone.side == ChampionshipContextZoneSide.high
            ? highLabel
            : lowLabel;
        readings.add(
          _reading(
            id: id,
            teamId: entry.team.id,
            side: entry.side,
            strength: ReadingStrength.moderate,
            asOf: statistics.asOf,
            sampleSize:
                sampleSizeFor?.call(statistics) ?? statistics.sampleSize,
            evidence: [
              ReadingEvidence(
                label:
                    '${entry.team.name} $label (${formatValue?.call(value) ?? '${value.toStringAsFixed(2)} par match'}), dans une zone ${zone.side == ChampionshipContextZoneSide.high ? 'haute' : 'basse'} du championnat.',
                kind: evidenceKind,
                sourcePath: sourcePath,
                value: value,
              ),
            ],
          ),
        );
      }
    }

    addRelativeReading(
      metric: ChampionshipContextMetric.shotsFor,
      valueFor: (value) => value.shotsFor,
      highId: 'high_shot_volume',
      lowId: 'low_shot_volume',
      highLabel: 'produit un volume de tirs élevé',
      lowLabel: 'produit peu de tirs',
      evidenceKind: ReadingEvidenceKind.shots,
      sourcePath: 'fixtures/statistics.Total Shots',
    );
    addRelativeReading(
      metric: ChampionshipContextMetric.shotsOnTargetFor,
      valueFor: (value) => value.shotsOnTargetFor,
      highId: 'high_shots_on_target',
      lowId: null,
      highLabel: 'cadre de nombreux tirs',
      lowLabel: '',
      evidenceKind: ReadingEvidenceKind.shots,
      sourcePath: 'fixtures/statistics.Shots on Goal',
    );
    addRelativeReading(
      metric: ChampionshipContextMetric.shotAccuracy,
      valueFor: (value) => value.shotAccuracy,
      highId: null,
      lowId: 'low_shot_accuracy',
      highLabel: '',
      lowLabel: 'cadre une faible part de ses tirs',
      evidenceKind: ReadingEvidenceKind.shots,
      sourcePath: 'fixtures/statistics.Shots on Goal / Total Shots',
    );
    addRelativeReading(
      metric: ChampionshipContextMetric.shotsAgainst,
      valueFor: (value) => value.shotsAgainst,
      highId: 'high_shots_conceded',
      lowId: null,
      highLabel: 'concède beaucoup de tirs',
      lowLabel: '',
      evidenceKind: ReadingEvidenceKind.shots,
      sourcePath: 'fixtures/statistics.opponent.Total Shots',
    );
    addRelativeReading(
      metric: ChampionshipContextMetric.shotsOnTargetAgainst,
      valueFor: (value) => value.shotsOnTargetAgainst,
      highId: 'high_shots_on_target_conceded',
      lowId: null,
      highLabel: 'concède beaucoup de tirs cadrés',
      lowLabel: '',
      evidenceKind: ReadingEvidenceKind.shots,
      sourcePath: 'fixtures/statistics.opponent.Shots on Goal',
    );
    addRelativeReading(
      metric: ChampionshipContextMetric.cornersFor,
      valueFor: (value) => value.cornersFor,
      highId: 'high_corner_creation',
      lowId: null,
      highLabel: 'obtient beaucoup de corners',
      lowLabel: '',
      evidenceKind: ReadingEvidenceKind.corners,
      sourcePath: 'fixtures/statistics.Corner Kicks',
    );
    addRelativeReading(
      metric: ChampionshipContextMetric.cornersAgainst,
      valueFor: (value) => value.cornersAgainst,
      highId: 'high_corners_conceded',
      lowId: null,
      highLabel: 'concède beaucoup de corners',
      lowLabel: '',
      evidenceKind: ReadingEvidenceKind.corners,
      sourcePath: 'fixtures/statistics.opponent.Corner Kicks',
    );
    addRelativeReading(
      metric: ChampionshipContextMetric.totalCorners,
      valueFor: (value) => value.totalCorners,
      highId: 'high_total_corners_profile',
      lowId: 'low_total_corners_profile',
      highLabel: 'dispute des matchs riches en corners',
      lowLabel: 'dispute des matchs pauvres en corners',
      evidenceKind: ReadingEvidenceKind.corners,
      sourcePath: 'fixtures/statistics.Corner Kicks total',
    );
    addRelativeReading(
      metric: ChampionshipContextMetric.cardsFor,
      valueFor: (value) => value.cardsFor,
      highId: 'high_card_rate',
      lowId: 'low_card_rate',
      highLabel: 'reçoit beaucoup de cartons',
      lowLabel: 'reçoit peu de cartons',
      evidenceKind: ReadingEvidenceKind.cards,
      sourcePath: 'fixtures/statistics.Yellow Cards + Red Cards',
    );
    addRelativeReading(
      metric: ChampionshipContextMetric.totalCards,
      valueFor: (value) => value.totalCards,
      highId: 'high_total_cards_profile',
      lowId: null,
      highLabel: 'dispute des matchs riches en cartons',
      lowLabel: '',
      evidenceKind: ReadingEvidenceKind.cards,
      sourcePath: 'fixtures/statistics.cards total',
    );
    addRelativeReading(
      metric: ChampionshipContextMetric.secondHalfCardsShare,
      valueFor: (value) => value.secondHalfCardsShare,
      highId: 'second_half_cards_profile',
      lowId: null,
      highLabel: 'reçoit surtout des cartons après la pause',
      lowLabel: '',
      evidenceKind: ReadingEvidenceKind.cards,
      sourcePath: 'fixtures/events.Card.time.elapsed',
      sampleSizeFor: (value) => value.observedCards ?? value.sampleSize,
      formatValue: _percent,
    );
    final homeHighCards = readings.any(
      (reading) =>
          reading.id == 'high_total_cards_profile' &&
          reading.subjectTeamId == match.homeTeam.id,
    );
    final awayHighCards = readings.any(
      (reading) =>
          reading.id == 'high_total_cards_profile' &&
          reading.subjectTeamId == match.awayTeam.id,
    );
    if (homeHighCards && awayHighCards) {
      final home = match.analysis.homePerformanceStatistics!;
      final away = match.analysis.awayPerformanceStatistics!;
      readings.add(
        _reading(
          id: 'high_total_cards_profile',
          teamId: match.id,
          side: ReadingSubjectSide.match,
          strength: ReadingStrength.moderate,
          asOf: home.asOf.isAfter(away.asOf) ? home.asOf : away.asOf,
          sampleSize: _min(home.sampleSize, away.sampleSize),
          evidence: [
            ReadingEvidence(
              label:
                  'Les matchs des deux équipes ont un total de cartons élevé relativement au championnat.',
              kind: ReadingEvidenceKind.cards,
              sourcePath: 'fixtures/statistics.cards total',
              value: {'home': home.totalCards, 'away': away.totalCards},
            ),
          ],
        ),
      );
    }
    return readings;
  }

  List<FootballReading> _domesticContextReadings(
    MatchBoardItem match,
    DateTime asOf,
  ) {
    return [
      ..._domesticReadingsForTeam(
        team: match.homeTeam,
        side: ReadingSubjectSide.home,
        context: match.analysis.homeDomesticContext,
        asOf: asOf,
      ),
      ..._domesticReadingsForTeam(
        team: match.awayTeam,
        side: ReadingSubjectSide.away,
        context: match.analysis.awayDomesticContext,
        asOf: asOf,
      ),
    ];
  }

  List<FootballReading> _domesticReadingsForTeam({
    required TeamInfo team,
    required ReadingSubjectSide side,
    required TeamCompetitionContext? context,
    required DateTime asOf,
  }) {
    if (context == null) return const [];
    final reference = const ChampionshipContextReferenceBuilder()
        .buildForStandings(
          competitionId: context.competition.id,
          season: context.competition.season,
          asOf: asOf,
          standings: context.leagueStandings,
        );
    final readings = <FootballReading>[];

    final form = _normalizedForm(
      context.standing?.form ?? context.statistics?.form,
    );
    final formZone = reference
        ?.distributionFor(ChampionshipContextMetric.form)
        ?.zoneForTeam(context.teamId);
    if (form != null && formZone != null) {
      final isHigh = formZone.side == ChampionshipContextZoneSide.high;
      readings.add(
        _scopedReading(
          context: context,
          reading: _reading(
            id: isHigh ? 'positive_streak' : 'negative_streak',
            teamId: team.id,
            side: side,
            strength: ReadingStrength.moderate,
            asOf: asOf,
            sampleSize: form.length,
            evidence: [
              ReadingEvidence(
                label: isHigh
                    ? '${team.name} se situe dans la zone de forme haute de ${context.competition.name} ($form).'
                    : '${team.name} se situe dans la zone de forme basse de ${context.competition.name} ($form).',
                kind: ReadingEvidenceKind.form,
                sourcePath: 'domestic.standings[].form',
                value: form,
              ),
            ],
          ),
        ),
      );
    }

    void addGoalReading({
      required ChampionshipContextMetric metric,
      required String highId,
      required String lowId,
      required String highVerb,
      required String lowVerb,
    }) {
      final distribution = reference?.distributionFor(metric);
      final value = distribution?.valueForTeam(context.teamId);
      final zone = distribution?.zoneForTeam(context.teamId);
      final played = context.standing?.played;
      if (value == null || zone == null || played == null || played <= 0) {
        return;
      }
      final isHigh = zone.side == ChampionshipContextZoneSide.high;
      readings.add(
        _scopedReading(
          context: context,
          reading: _reading(
            id: isHigh ? highId : lowId,
            teamId: team.id,
            side: side,
            strength: ReadingStrength.moderate,
            asOf: asOf,
            sampleSize: played,
            evidence: [
              ReadingEvidence(
                label:
                    '${team.name} ${isHigh ? highVerb : lowVerb} ${value.value.toStringAsFixed(2)} but(s) par match, dans une zone ${isHigh ? 'haute' : 'basse'} de ${context.competition.name}.',
                kind: ReadingEvidenceKind.goals,
                sourcePath: 'domestic.standings[].all.goals',
                value: value.value,
              ),
            ],
          ),
        ),
      );
    }

    addGoalReading(
      metric: ChampionshipContextMetric.goalsFor,
      highId: 'prolific_attack',
      lowId: 'scoring_difficulty',
      highVerb: 'marque',
      lowVerb: 'marque peu',
    );
    addGoalReading(
      metric: ChampionshipContextMetric.goalsAgainst,
      highId: 'fragile_defense',
      lowId: 'solid_defense',
      highVerb: 'encaisse',
      lowVerb: 'encaisse peu',
    );

    final stats = context.statistics;
    final venuePlayed = side == ReadingSubjectSide.home
        ? stats?.playedHome
        : stats?.playedAway;
    final venueWins = side == ReadingSubjectSide.home
        ? stats?.winsHome
        : stats?.winsAway;
    final venueLosses = side == ReadingSubjectSide.home
        ? stats?.lossesHome
        : stats?.lossesAway;
    if (venuePlayed != null &&
        venuePlayed > 0 &&
        venueWins != null &&
        venueLosses != null &&
        venueWins != venueLosses) {
      final isStrong = venueWins > venueLosses;
      final rate = (isStrong ? venueWins : venueLosses) / venuePlayed;
      final venueLabel = side == ReadingSubjectSide.home
          ? 'à domicile'
          : 'à l’extérieur';
      readings.add(
        _scopedReading(
          context: context,
          reading: _reading(
            id: isStrong
                ? side == ReadingSubjectSide.home
                      ? 'strong_home_team'
                      : 'strong_away_team'
                : side == ReadingSubjectSide.home
                ? 'weak_home_team'
                : 'weak_away_team',
            teamId: team.id,
            side: side,
            strength: ReadingStrength.moderate,
            asOf: asOf,
            sampleSize: venuePlayed,
            evidence: [
              ReadingEvidence(
                label:
                    '${team.name} ${isStrong ? 'gagne' : 'perd'} ${_percent(rate)} de ses matchs $venueLabel en ${context.competition.name}.',
                kind: ReadingEvidenceKind.homeAway,
                sourcePath: 'domestic.teams/statistics.fixtures',
                value: rate,
              ),
            ],
          ),
        ),
      );
    }

    return readings;
  }

  FootballReading _scopedReading({
    required TeamCompetitionContext context,
    required FootballReading reading,
  }) {
    return reading.copyWith(
      competitionScope: ReadingCompetitionScope.domestic,
      sourceCompetitionId: context.competition.id,
      sourceCompetitionName: context.competition.name,
    );
  }

  List<FootballReading> _tournamentProgressionReadings(
    MatchBoardItem match,
    DateTime asOf,
  ) {
    final readings = <FootballReading>[];
    for (final entry in [
      (
        team: match.homeTeam,
        side: ReadingSubjectSide.home,
        standing: match.analysis.homeStanding,
      ),
      (
        team: match.awayTeam,
        side: ReadingSubjectSide.away,
        standing: match.analysis.awayStanding,
      ),
    ]) {
      final description = entry.standing?.description?.trim();
      final played = entry.standing?.played;
      if (description == null || description.isEmpty || played == null) {
        continue;
      }
      readings.add(
        FootballReading(
          id: 'tournament_progression',
          subjectTeamId: entry.team.id,
          subjectSide: entry.side,
          status: ReadingStatus.detected,
          strength: ReadingStrength.moderate,
          evidence: [
            ReadingEvidence(
              label:
                  '${entry.team.name} occupe la place #${entry.standing?.rank ?? '—'} : $description.',
              kind: ReadingEvidenceKind.standing,
              sourcePath: 'tournament.standings[].description',
              value: {'rank': entry.standing?.rank, 'description': description},
            ),
          ],
          warnings: const [],
          asOf: asOf,
          sampleSize: played,
          competitionScope: ReadingCompetitionScope.tournament,
          sourceCompetitionId: match.competition.id,
          sourceCompetitionName: match.competition.name,
        ),
      );
    }
    return readings;
  }

  List<FootballReading> _tournamentPathReadings(
    MatchBoardItem match,
    DateTime asOf,
  ) {
    final paths = match.analysis.tournamentPaths;
    final distribution = const ChampionshipContextReferenceBuilder()
        .distributionForValues(
          metric: ChampionshipContextMetric.opponentStrength,
          values: [
            for (final path in paths)
              ChampionshipContextValue(
                teamId: path.teamId,
                teamName: path.teamName,
                value: path.averageOpponentPointsPerGame,
              ),
          ],
        );
    if (distribution == null) return const [];
    final readings = <FootballReading>[];
    for (final entry in [
      (team: match.homeTeam, side: ReadingSubjectSide.home),
      (team: match.awayTeam, side: ReadingSubjectSide.away),
    ]) {
      final teamId = entry.team.apiFootballTeamId;
      if (teamId == null) continue;
      final path = paths.where((path) => path.teamId == teamId).firstOrNull;
      final zone = distribution.zoneForTeam(teamId);
      if (path == null || zone == null) continue;
      final demanding = zone.side == ChampionshipContextZoneSide.high;
      readings.add(
        FootballReading(
          id: demanding
              ? 'demanding_tournament_path'
              : 'favorable_tournament_path',
          subjectTeamId: entry.team.id,
          subjectSide: entry.side,
          status: ReadingStatus.detected,
          strength: ReadingStrength.moderate,
          evidence: [
            ReadingEvidence(
              label:
                  'Le parcours déjà joué par ${entry.team.name} se situe dans une zone ${demanding ? 'd’adversité haute' : 'd’adversité basse'} du tournoi.',
              kind: ReadingEvidenceKind.standing,
              sourcePath:
                  'tournament.league_fixtures + standings.points_per_game',
              value: {
                'played': path.played,
                'averageOpponentPointsPerGame':
                    path.averageOpponentPointsPerGame,
              },
            ),
          ],
          warnings: const [],
          asOf: asOf,
          sampleSize: path.played,
          competitionScope: ReadingCompetitionScope.tournament,
          sourceCompetitionId: match.competition.id,
          sourceCompetitionName: match.competition.name,
        ),
      );
    }
    return readings;
  }

  String? _normalizedForm(String? form) {
    if (form == null) return null;
    final normalized = form.toUpperCase().replaceAll(RegExp('[^WDL]'), '');
    if (normalized.isEmpty) return null;
    return normalized.substring(
      0,
      normalized.length > 5 ? 5 : normalized.length,
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
    final inferiorSide = superiorSide == ReadingSubjectSide.home
        ? ReadingSubjectSide.away
        : ReadingSubjectSide.home;
    final inferiorTeam = superiorSide == ReadingSubjectSide.home
        ? match.awayTeam
        : match.homeTeam;
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
      readings.add(
        _reading(
          id: 'ranking_inferiority',
          teamId: inferiorTeam.id,
          side: inferiorSide,
          strength: ReadingStrength.moderate,
          asOf: asOf,
          sampleSize: sampleSize,
          evidence: [
            ReadingEvidence(
              label:
                  '${inferiorTeam.name} se trouve derrière ${superiorTeam.name} dans la distribution du championnat ($rankGap rangs, $pointsGap pts).',
              kind: ReadingEvidenceKind.standing,
              sourcePath: 'standings[].rank + standings[].points',
              value: {'rankGap': rankGap, 'pointsGap': pointsGap},
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

  List<FootballReading> _formTrendReadings(
    MatchBoardItem match,
    DateTime asOf,
  ) {
    double? trend(List<TeamRecentMatchSnapshot> matches) {
      if (matches.length < 4) return null;
      int points(TeamRecentMatchSnapshot match) =>
          switch (match.result.toUpperCase()) {
            'W' => 3,
            'D' => 1,
            _ => 0,
          };
      final newest = matches.take(2).map(points).reduce((a, b) => a + b);
      final oldest = matches.reversed
          .take(2)
          .map(points)
          .reduce((a, b) => a + b);
      return (newest - oldest) / 2;
    }

    final distribution = const ChampionshipContextReferenceBuilder()
        .distributionForValues(
          metric: ChampionshipContextMetric.formTrend,
          values: [
            for (final entry
                in match.analysis.leagueRecentLeagueMatches.entries)
              if (trend(entry.value) != null)
                ChampionshipContextValue(
                  teamId: entry.key,
                  teamName: 'Équipe ${entry.key}',
                  value: trend(entry.value)!,
                ),
          ],
        );
    if (distribution == null) return const [];
    final readings = <FootballReading>[];
    for (final entry in [
      (
        team: match.homeTeam,
        side: ReadingSubjectSide.home,
        matches: match.analysis.homeRecentLeagueMatches,
      ),
      (
        team: match.awayTeam,
        side: ReadingSubjectSide.away,
        matches: match.analysis.awayRecentLeagueMatches,
      ),
    ]) {
      final teamId = entry.team.apiFootballTeamId;
      final value = trend(entry.matches);
      final zone = teamId == null ? null : distribution.zoneForTeam(teamId);
      if (value == null || zone == null) continue;
      final improving = zone.side == ChampionshipContextZoneSide.high;
      readings.add(
        _reading(
          id: improving ? 'improving_form' : 'declining_form',
          teamId: entry.team.id,
          side: entry.side,
          strength: ReadingStrength.moderate,
          asOf: asOf,
          sampleSize: entry.matches.length,
          evidence: [
            ReadingEvidence(
              label:
                  '${entry.team.name} ${improving ? 'progresse' : 'recule'} entre ses deux matchs les plus anciens et ses deux plus récents (${value.toStringAsFixed(2)} point par match), relativement au championnat.',
              kind: ReadingEvidenceKind.form,
              sourcePath: 'recent_league_matches[].matches',
              value: value,
            ),
          ],
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

    for (final entry in [
      (
        team: match.homeTeam,
        side: ReadingSubjectSide.home,
        view: ChampionshipStandingView.home,
        label: 'domicile',
      ),
      (
        team: match.awayTeam,
        side: ReadingSubjectSide.away,
        view: ChampionshipStandingView.away,
        label: 'extérieur',
      ),
    ]) {
      final table = match.analysis.standingsFor(entry.view);
      final distribution = const ChampionshipContextReferenceBuilder()
          .distributionForValues(
            metric: ChampionshipContextMetric.pointsPerGame,
            values: [
              for (final row in table)
                if (row.played != null && row.played! > 0 && row.points != null)
                  ChampionshipContextValue(
                    teamId: row.teamId,
                    teamName: row.teamName,
                    value: row.points! / row.played!,
                  ),
            ],
          );
      final apiTeamId = entry.team.apiFootballTeamId;
      final row = table.where((value) => value.teamId == apiTeamId).firstOrNull;
      if (apiTeamId == null ||
          row?.played == null ||
          row!.points == null ||
          distribution?.zoneForTeam(apiTeamId)?.side !=
              ChampionshipContextZoneSide.high) {
        continue;
      }
      readings.add(
        _reading(
          id: 'venue_strength',
          teamId: entry.team.id,
          side: entry.side,
          strength: ReadingStrength.moderate,
          asOf: asOf,
          sampleSize: row.played!,
          evidence: [
            ReadingEvidence(
              label:
                  '${entry.team.name} appartient à la zone haute du classement ${entry.label} (${row.points} points en ${row.played} matchs).',
              kind: ReadingEvidenceKind.homeAway,
              sourcePath: 'standings[].${entry.label}.points',
              value: row.points! / row.played!,
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
  ) {
    final readings = _relativeGoalReadings(
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
    final distribution = const ChampionshipContextReferenceBuilder()
        .distributionForValues(
          metric: ChampionshipContextMetric.cleanSheetRate,
          values: [
            for (final stats in match.analysis.leagueTeamStatistics)
              if (stats.playedTotal != null &&
                  stats.playedTotal! > 0 &&
                  stats.cleanSheetsTotal != null)
                ChampionshipContextValue(
                  teamId: stats.teamId,
                  teamName: stats.teamName,
                  value: stats.cleanSheetsTotal! / stats.playedTotal!,
                ),
          ],
        );
    if (distribution == null) return readings;
    for (final entry in [
      (
        team: match.homeTeam,
        side: ReadingSubjectSide.home,
        stats: match.analysis.homeStatistics,
      ),
      (
        team: match.awayTeam,
        side: ReadingSubjectSide.away,
        stats: match.analysis.awayStatistics,
      ),
    ]) {
      final stats = entry.stats;
      final apiTeamId = entry.team.apiFootballTeamId;
      if (stats?.playedTotal == null ||
          stats!.playedTotal! <= 0 ||
          stats.cleanSheetsTotal == null ||
          apiTeamId == null ||
          distribution.zoneForTeam(apiTeamId)?.side !=
              ChampionshipContextZoneSide.high) {
        continue;
      }
      readings.add(
        _reading(
          id: 'frequent_clean_sheet',
          teamId: entry.team.id,
          side: entry.side,
          strength: ReadingStrength.moderate,
          asOf: asOf,
          sampleSize: stats.playedTotal!,
          evidence: [
            ReadingEvidence(
              label:
                  '${entry.team.name} garde sa cage inviolée dans ${stats.cleanSheetsTotal}/${stats.playedTotal} matchs, dans une zone haute du championnat.',
              kind: ReadingEvidenceKind.goals,
              sourcePath: 'teams/statistics.clean_sheet.total',
              value: stats.cleanSheetsTotal! / stats.playedTotal!,
            ),
          ],
        ),
      );
    }
    return readings;
  }

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
    final league = match.analysis.leagueGoalProfiles;
    final builder = const ChampionshipContextReferenceBuilder();
    final readings = <FootballReading>[];

    void addRate({
      required ChampionshipContextMetric metric,
      required double? Function(TeamGoalProfileSnapshot) valueFor,
      required String id,
      required String label,
    }) {
      final distribution = builder.distributionForValues(
        metric: metric,
        values: [
          for (final profile in league)
            if (valueFor(profile) != null)
              ChampionshipContextValue(
                teamId: profile.teamId,
                teamName: profile.teamName,
                value: valueFor(profile)!,
              ),
        ],
      );
      if (distribution == null) return;
      for (final entry in [
        (
          team: match.homeTeam,
          side: ReadingSubjectSide.home,
          profile: match.analysis.homeGoalProfile,
        ),
        (
          team: match.awayTeam,
          side: ReadingSubjectSide.away,
          profile: match.analysis.awayGoalProfile,
        ),
      ]) {
        final profile = entry.profile;
        if (profile == null ||
            valueFor(profile) == null ||
            distribution.zoneForTeam(profile.teamId)?.side !=
                ChampionshipContextZoneSide.high) {
          continue;
        }
        readings.add(
          _reading(
            id: id,
            teamId: entry.team.id,
            side: entry.side,
            strength: ReadingStrength.moderate,
            asOf: asOf,
            sampleSize: profile.played,
            evidence: [
              ReadingEvidence(
                label:
                    '${entry.team.name} $label dans ${_percent(valueFor(profile)!)} de ses matchs, dans une zone haute du championnat.',
                kind: ReadingEvidenceKind.goals,
                sourcePath: 'league_fixtures.score.fulltime',
                value: valueFor(profile),
              ),
            ],
          ),
        );
      }
    }

    addRate(
      metric: ChampionshipContextMetric.over25Rate,
      valueFor: (profile) => profile.over25Rate,
      id: 'frequent_over_25',
      label: 'dépasse 2,5 buts',
    );
    addRate(
      metric: ChampionshipContextMetric.under25Rate,
      valueFor: (profile) => profile.under25Rate,
      id: 'frequent_under_25',
      label: 'reste sous 2,5 buts',
    );
    addRate(
      metric: ChampionshipContextMetric.bttsRate,
      valueFor: (profile) => profile.bttsRate,
      id: 'frequent_btts',
      label: 'voit les deux équipes marquer',
    );

    final totalDistribution = builder.distributionForValues(
      metric: ChampionshipContextMetric.totalGoalsPerMatch,
      values: [
        for (final profile in league)
          if (profile.totalGoalsPerMatch != null)
            ChampionshipContextValue(
              teamId: profile.teamId,
              teamName: profile.teamName,
              value: profile.totalGoalsPerMatch!,
            ),
      ],
    );
    final home = match.analysis.homeGoalProfile;
    final away = match.analysis.awayGoalProfile;
    final homeZone = home == null
        ? null
        : totalDistribution?.zoneForTeam(home.teamId);
    final awayZone = away == null
        ? null
        : totalDistribution?.zoneForTeam(away.teamId);
    if (homeZone != null &&
        awayZone != null &&
        homeZone.side == awayZone.side) {
      final open = homeZone.side == ChampionshipContextZoneSide.high;
      readings.add(
        _reading(
          id: open ? 'open_match_profile' : 'closed_match_profile',
          teamId: match.id,
          side: ReadingSubjectSide.match,
          strength: ReadingStrength.moderate,
          asOf: asOf,
          sampleSize: _min(home!.played, away!.played),
          evidence: [
            ReadingEvidence(
              label:
                  'Les matchs de ${match.homeTeam.name} et ${match.awayTeam.name} présentent tous deux un total de buts ${open ? 'élevé' : 'faible'} relativement au championnat.',
              kind: ReadingEvidenceKind.goals,
              sourcePath: 'league_fixtures.score.fulltime',
              value: {
                'home': home.totalGoalsPerMatch,
                'away': away.totalGoalsPerMatch,
              },
            ),
          ],
        ),
      );
    }
    return readings;
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

  List<FootballReading> _playerPerformanceReadings(
    MatchBoardItem match,
    DateTime asOf,
  ) {
    final leaguePlayers = match.analysis.leaguePlayerStatistics
        .where((player) => (player.minutes ?? 0) > 0)
        .toList(growable: false);
    if (leaguePlayers.isEmpty) return const [];
    final minuteMedian = _median(
      leaguePlayers.map((player) => player.minutes!.toDouble()),
    );
    final exposed = leaguePlayers
        .where((player) => player.minutes! >= minuteMedian)
        .toList(growable: false);
    final builder = const ChampionshipContextReferenceBuilder();
    final readings = <FootballReading>[];

    void addPlayerReading({
      required ChampionshipContextMetric metric,
      required double? Function(PlayerSeasonStatisticsSnapshot) valueFor,
      required String id,
      required String label,
      required String sourcePath,
    }) {
      final distribution = builder.distributionForValues(
        metric: metric,
        values: [
          for (final player in exposed)
            if (valueFor(player) != null)
              ChampionshipContextValue(
                teamId: player.playerId,
                teamName: player.playerName,
                value: valueFor(player)!,
              ),
        ],
      );
      if (distribution == null) return;
      for (final entry in [
        (
          teamId: match.homeTeam.id,
          side: ReadingSubjectSide.home,
          players: match.analysis.homePlayerStatistics,
        ),
        (
          teamId: match.awayTeam.id,
          side: ReadingSubjectSide.away,
          players: match.analysis.awayPlayerStatistics,
        ),
      ]) {
        for (final player in entry.players) {
          final value = valueFor(player);
          final zone = distribution.zoneForTeam(player.playerId);
          if (value == null || zone?.side != ChampionshipContextZoneSide.high) {
            continue;
          }
          readings.add(
            FootballReading(
              id: id,
              subjectTeamId: entry.teamId,
              subjectSide: entry.side,
              subjectKind: ReadingSubjectKind.player,
              playerId: player.playerId,
              playerName: player.playerName,
              status: ReadingStatus.detected,
              strength: ReadingStrength.moderate,
              evidence: [
                ReadingEvidence(
                  label:
                      '${player.playerName} $label (${value.toStringAsFixed(2)} par 90 min), dans une zone haute du championnat.',
                  kind: ReadingEvidenceKind.player,
                  sourcePath: sourcePath,
                  value: value,
                ),
              ],
              warnings: const [],
              asOf: asOf,
              sampleSize: player.appearances ?? 0,
            ),
          );
        }
      }
    }

    addPlayerReading(
      metric: ChampionshipContextMetric.playerShotsPer90,
      valueFor: (player) => player.shotsPer90,
      id: 'high_volume_shooter',
      label: 'tire beaucoup',
      sourcePath: 'players.statistics.shots.total + games.minutes',
    );
    addPlayerReading(
      metric: ChampionshipContextMetric.playerShotsOnTargetPer90,
      valueFor: (player) => player.shotsOnTargetPer90,
      id: 'accurate_shooter',
      label: 'cadre fréquemment',
      sourcePath: 'players.statistics.shots.on + games.minutes',
    );
    addPlayerReading(
      metric: ChampionshipContextMetric.playerAssistsPer90,
      valueFor: (player) => player.assistsPer90,
      id: 'standout_creator',
      label: 'se distingue à la création',
      sourcePath: 'players.statistics.goals.assists + games.minutes',
    );
    addPlayerReading(
      metric: ChampionshipContextMetric.playerPenaltyAttemptsPer90,
      valueFor: (player) => (player.penaltyAttempts ?? 0) > 0
          ? player.penaltyAttemptsPer90
          : null,
      id: 'identified_penalty_taker',
      label: 'tire régulièrement les penalties',
      sourcePath: 'players.statistics.penalty.scored/missed + games.minutes',
    );
    return readings;
  }

  List<FootballReading> _keyPlayerUnavailableReadings(MatchBoardItem match) {
    final injuries = match.analysis.unavailablePlayers;
    final kickoff = match.fixture.kickoff;
    if (injuries.isEmpty || kickoff == null) return const [];
    final leaguePlayers = match.analysis.leaguePlayerStatistics
        .where((player) => (player.minutes ?? 0) > 0)
        .toList(growable: false);
    if (leaguePlayers.isEmpty) return const [];
    final minutesMedian = _median(
      leaguePlayers.map((player) => player.minutes!.toDouble()),
    );
    final distribution = const ChampionshipContextReferenceBuilder()
        .distributionForValues(
          metric: ChampionshipContextMetric.playerContributionsPer90,
          values: [
            for (final player in leaguePlayers)
              if (player.minutes! >= minutesMedian &&
                  player.contributionsPer90 != null)
                ChampionshipContextValue(
                  teamId: player.playerId,
                  teamName: player.playerName,
                  value: player.contributionsPer90!,
                ),
          ],
        );
    if (distribution == null) return const [];
    final readings = <FootballReading>[];
    for (final entry in [
      (
        team: match.homeTeam,
        side: ReadingSubjectSide.home,
        players: match.analysis.homePlayerStatistics,
      ),
      (
        team: match.awayTeam,
        side: ReadingSubjectSide.away,
        players: match.analysis.awayPlayerStatistics,
      ),
    ]) {
      final teamMinutes = entry.players
          .where((player) => (player.minutes ?? 0) > 0)
          .map((player) => player.minutes!.toDouble());
      if (teamMinutes.isEmpty) continue;
      final teamMedian = _median(teamMinutes);
      for (final injury in injuries.where(
        (value) =>
            value.teamId == entry.team.apiFootballTeamId &&
            !value.asOf.isAfter(kickoff),
      )) {
        final player = entry.players
            .where((value) => value.playerId == injury.playerId)
            .firstOrNull;
        if (player == null ||
            (player.minutes ?? 0) < teamMedian ||
            distribution.zoneForTeam(player.playerId)?.side !=
                ChampionshipContextZoneSide.high) {
          continue;
        }
        readings.add(
          FootballReading(
            id: 'key_player_unavailable',
            subjectTeamId: entry.team.id,
            subjectSide: entry.side,
            subjectKind: ReadingSubjectKind.player,
            playerId: player.playerId,
            playerName: player.playerName,
            status: ReadingStatus.detected,
            strength: ReadingStrength.moderate,
            evidence: [
              ReadingEvidence(
                label:
                    '${player.playerName} est signalé absent : ${injury.reason}.',
                kind: ReadingEvidenceKind.availability,
                sourcePath: 'injuries.player.type/reason',
                value: injury.reason,
              ),
              ReadingEvidence(
                label:
                    '${player.playerName} cumule ${player.minutes} minutes et ${player.contributionsPer90?.toStringAsFixed(2)} contribution(s) par 90 minutes, dans une zone haute du championnat.',
                kind: ReadingEvidenceKind.player,
                sourcePath: 'players.statistics.games.minutes/goals',
                value: player.contributionsPer90,
              ),
            ],
            warnings: const [],
            asOf: injury.asOf,
            sampleSize: player.appearances ?? 0,
          ),
        );
      }
    }
    return readings;
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

    final league = match.analysis.leagueExpectedGoals.where(
      (value) => kickoff == null || !value.asOf.isAfter(kickoff),
    );
    final builder = const ChampionshipContextReferenceBuilder();
    final readings = <FootballReading>[];

    void addRelative({
      required ChampionshipContextMetric metric,
      required double? Function(TeamExpectedGoalsSnapshot) valueFor,
      required String? highId,
      required String? lowId,
      required String label,
    }) {
      final distribution = builder.distributionForValues(
        metric: metric,
        values: [
          for (final candidate in league)
            if (valueFor(candidate) != null && candidate.sampleSize > 0)
              ChampionshipContextValue(
                teamId: candidate.teamId,
                teamName: candidate.teamName,
                value: valueFor(candidate)!,
              ),
        ],
      );
      final value = valueFor(xg);
      final zone = distribution?.zoneForTeam(xg.teamId);
      if (value == null || zone == null) return;
      final id = zone.side == ChampionshipContextZoneSide.high ? highId : lowId;
      if (id == null) return;
      readings.add(
        _reading(
          id: id,
          teamId: team.id,
          side: side,
          strength: ReadingStrength.moderate,
          asOf: xg.asOf,
          sampleSize: xg.sampleSize,
          evidence: [
            ReadingEvidence(
              label:
                  '${team.name} $label (${value.toStringAsFixed(2)} par match), dans une zone ${zone.side == ChampionshipContextZoneSide.high ? 'haute' : 'basse'} du championnat.',
              kind: ReadingEvidenceKind.expectedGoals,
              sourcePath: 'fixtures/statistics.Expected Goals',
              value: value,
            ),
          ],
        ),
      );
    }

    addRelative(
      metric: ChampionshipContextMetric.xgFor,
      valueFor: (value) => value.seasonXgForAverage ?? value.rollingXgFor5,
      highId: 'high_xg_creation',
      lowId: 'low_xg_creation',
      label: 'crée des xG',
    );
    addRelative(
      metric: ChampionshipContextMetric.xgAgainst,
      valueFor: (value) =>
          value.seasonXgAgainstAverage ?? value.rollingXgAgainst5,
      highId: 'high_xg_conceded',
      lowId: null,
      label: 'concède des xG',
    );
    addRelative(
      metric: ChampionshipContextMetric.goalsMinusXgFor,
      valueFor: (value) =>
          value.sampleSize > 0 && value.goalsMinusXgFor5 != null
          ? value.goalsMinusXgFor5! / value.sampleSize
          : null,
      highId: 'offensive_overperformance',
      lowId: 'offensive_underperformance',
      label: 'présente un écart buts marqués/xG',
    );
    addRelative(
      metric: ChampionshipContextMetric.goalsMinusXgAgainst,
      valueFor: (value) =>
          value.sampleSize > 0 && value.goalsConcededMinusXgAgainst5 != null
          ? value.goalsConcededMinusXgAgainst5! / value.sampleSize
          : null,
      highId: 'defensive_underperformance',
      lowId: 'defensive_overperformance',
      label: 'présente un écart buts encaissés/xG concédés',
    );
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
