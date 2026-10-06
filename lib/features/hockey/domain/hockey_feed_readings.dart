import '../../../core/domain/lector_head_to_head_policy.dart';
import '../../../core/sports/domain/sport.dart';
import '../../../core/sports/domain/sport_fixture.dart';
import '../../../core/sports/domain/sport_match_history.dart';
import '../../../core/sports/domain/sport_competition_context.dart';
import '../../../core/sports/domain/sport_snapshot.dart';
import '../../../core/sports/domain/sport_module.dart';
import '../../../core/sports/domain/sport_reading_preferences.dart';
import 'hockey_analysis.dart';
import 'hockey_reading_engine.dart';
import 'hockey_rules.dart';
import 'hockey_standing_tiers.dart';

/// First regular-season publication adapter. No football profile or model.
/// Unknown leagues/seasons, mixed phase histories and post-kickoff snapshots
/// produce explainable abstentions, never historical prematch predictions.
class HockeyFeedReadings {
  const HockeyFeedReadings({this.engine = const HockeyReadingEngine()});
  final HockeyReadingEngine engine;

  static const readingIds = {
    'standing_advantage',
    'structural_level_gap',
    'positive_streak',
    'negative_streak',
    'improving_form',
    'form_gap',
    'strong_home_team',
    'weak_home_team',
    'strong_away_team',
    'weak_away_team',
    'home_away_advantage',
    'away_home_advantage',
    'recent_form_advantage',
    'winning_streak',
    'head_to_head_dominance',
  };

  List<SportReadingAssessment> evaluate(
    SportFixture fixture,
    SportSnapshot<SportFixture> snapshot,
  ) {
    List<SportReadingAssessment> unavailable(String reason) => [
      for (final team in [fixture.away, fixture.home])
        for (final id in readingIds)
          SportReadingAssessment(
            id: id,
            subject: team.id,
            match: fixture.id,
            status: SportReadingStatus.insufficientData,
            explanation: reason,
            sampleSize: 0,
            asOf: snapshot.capturedAt,
          ),
    ];
    if (fixture.sport != SportId.hockey || snapshot.sport != SportId.hockey) {
      throw ArgumentError('Hockey readings cannot consume another sport.');
    }
    final at = snapshot.capturedAt.add(const Duration(microseconds: 1));
    if (fixture.status != SportFixtureStatus.scheduled ||
        fixture.startsAt == null ||
        !fixture.startsAt!.isAfter(at)) {
      return unavailable(
        'Aucune évaluation d’avant-match conservée pour cette rencontre.',
      );
    }
    final rules = pointsRulesFor(fixture);
    final competition = snapshot.competitions
        .where((c) => c.id == fixture.competition && c.season == fixture.season)
        .firstOrNull;
    if (rules == null || competition == null) {
      return unavailable(
        'Règles non disponibles pour cette compétition et cette saison.',
      );
    }
    if (!_insideRegularWindow(fixture, fixture.startsAt!)) {
      return unavailable(
        'Cette rencontre est hors de la période régulière prise en charge.',
      );
    }
    final common =
        competition.tables
            .where(
              (t) =>
                  _regular(t.stage) &&
                  t.rows.any((r) => r.team.id == fixture.home.id) &&
                  t.rows.any((r) => r.team.id == fixture.away.id),
            )
            .toList()
          ..sort((a, b) => a.rows.length.compareTo(b.rows.length));
    // Prefer the most specific genuine table containing BOTH teams, matching
    // the local standings view. Across divisions use a real common conference.
    // No synthetic inter-conference ranking and no addition of duplicate views.
    final table = common.firstOrNull;
    final tiers = table == null
        ? null
        : HockeyStandingTiers.classify(table, competition: competition);
    HockeyTeamContext team(
      SportParticipant participant,
      List<SportFormResult> form,
    ) {
      final row = table?.rows
          .where((r) => r.team.id == participant.id)
          .firstOrNull;
      final consistent =
          row != null &&
          competition.tables
              .where((t) => _regular(t.stage))
              .expand((t) => t.rows)
              .where((r) => r.team.id == participant.id)
              .every((r) => r.played == row.played && r.points == row.points);
      final ownRows = competition.tables
          .where((t) => _regular(t.stage))
          .expand((t) => t.rows)
          .where((r) => r.team.id == participant.id)
          .toList();
      final ownRow = ownRows.firstOrNull;
      final history = <SportEntityId, SportFormResult>{};
      var coherentHistory = true;
      // A partial season can contain holes. Only append older games when the
      // season history reconciles with the official number of games played.
      // Otherwise the fixture's known latest results remain the safe prefix.
      final completeSeason =
          ownRow != null &&
          ownRow.formHistory.length == ownRow.played &&
          ownRow.formHistory.map((g) => g.matchId).toSet().length ==
              ownRow.played;
      for (final result in [
        ...form,
        if (completeSeason) ...ownRow.formHistory,
      ]) {
        final previous = history[result.matchId];
        if (previous != null &&
            (previous.startsAt != result.startsAt ||
                previous.home != result.home ||
                previous.scored != result.scored ||
                previous.conceded != result.conceded ||
                previous.providerStatus != result.providerStatus)) {
          coherentHistory = false;
        }
        history.putIfAbsent(result.matchId, () => result);
      }
      final phaseSafe =
          coherentHistory &&
          (ownRow == null || history.length <= ownRow.played) &&
          competition.formPhaseVerified &&
          ownRows.every(
            (r) =>
                ownRow == null ||
                r.points == ownRow.points && r.played == ownRow.played,
          ) &&
          history.values.every(
            (r) =>
                _insideRegularWindow(fixture, r.startsAt) &&
                r.matchId.sport == SportId.hockey &&
                r.matchId.provider == fixture.id.provider &&
                r.matchId.kind == SportEntityKind.match &&
                resultFor(r) != null &&
                r.startsAt.isBefore(snapshot.capturedAt) &&
                r.matchId != fixture.id,
          );
      return HockeyTeamContext(
        team: participant.id,
        historyComplete:
            phaseSafe && ownRow != null && history.length == ownRow.played,
        standing:
            !consistent || !_insideRegularWindow(fixture, fixture.startsAt!)
            ? null
            : HockeyStanding(
                competition: competition.id,
                season: competition.season,
                comparisonGroup: '${table!.stage}:${table.group}',
                gamesPlayed: row.played,
                points: row.points,
                asOf: snapshot.capturedAt,
                tier: tiers?.tiers[participant.id.key],
                rank: row.rank,
                tierVersion: HockeyStandingTiers.version,
                structuralRanks: tiers?.structuralRanks[row.rank],
              ),
        recentGames: !phaseSafe
            ? const []
            : [
                for (final result in history.values)
                  if (result.startsAt.isBefore(snapshot.capturedAt) &&
                      result.matchId != fixture.id &&
                      resultFor(result) != null)
                    HockeyRecentGame(
                      match: result.matchId,
                      competition: fixture.competition,
                      season: fixture.season,
                      // The publication proves completion BY its capture time.
                      // It does not provide the exact final-whistle time.
                      completedAt: snapshot.capturedAt,
                      startedAt: result.startsAt,
                      home: result.home,
                      result: resultFor(result)!,
                    ),
              ],
      );
    }

    final assessments = engine.analyze(
      HockeyMatchContext(
        match: fixture.id,
        competition: fixture.competition,
        season: fixture.season,
        startsAt: fixture.startsAt!,
        asOf: at,
        pointsRules: rules,
        home: team(fixture.home, fixture.homeForm),
        away: team(fixture.away, fixture.awayForm),
      ),
    );
    return [
      for (final r in [...assessments, ..._headToHead(fixture, snapshot)])
        SportReadingAssessment(
          id: r.id,
          subject: r.subject,
          match: r.match,
          status: r.status,
          explanation: r.explanation,
          sampleSize: r.sampleSize,
          asOf: snapshot.capturedAt,
          evidence: {
            ...r.evidence,
            'competition': fixture.competition.key,
            'season': fixture.season,
            'phasePolicy': 'regular-window-2026-preview-v1',
          },
        ),
    ];
  }

  List<SportReadingAssessment> _headToHead(
    SportFixture fixture,
    SportSnapshot<SportFixture> snapshot,
  ) {
    final reference = fixture.startsAt!;
    final lower = LectorHeadToHeadPolicy.lowerBound(reference);
    final history = fixture.headToHead;
    final coherent =
        history != null && !history.collectedAt.isAfter(snapshot.capturedAt);
    final result = <SportReadingAssessment>[];
    for (final participant in [fixture.home, fixture.away]) {
      for (final kind in [LectorMeetingKind.league, LectorMeetingKind.cup]) {
        final seen = <SportEntityId>{};
        final meetings = coherent
            ? history.meetings.where((m) {
                final f = m.fixture, date = f.startsAt;
                final score = f.scoreFor(SportScoreScope.finalResult);
                final pair = {f.home.id, f.away.id};
                final resolved = LectorHeadToHeadPolicy.classifyHockey(
                  name: f.competitionName,
                  competitionId: f.competition.value,
                  playedAt: date,
                  phase: m.competitionPhase,
                  declaredKind: m.competitionKind,
                );
                return resolved == kind &&
                    pair.contains(fixture.home.id) &&
                    pair.contains(fixture.away.id) &&
                    f.id.sport == SportId.hockey &&
                    f.id.provider == fixture.id.provider &&
                    f.id != fixture.id &&
                    f.status == SportFixtureStatus.finished &&
                    date != null &&
                    !date.isBefore(lower) &&
                    date.isBefore(reference) &&
                    date.isBefore(snapshot.capturedAt) &&
                    score != null &&
                    score.home != score.away &&
                    seen.add(f.id);
              }).toList()
            : <SportHistoricalMatch>[];
        meetings.sort(
          (a, b) => b.fixture.startsAt!.compareTo(a.fixture.startsAt!),
        );
        final recent = meetings.take(3).toList();
        final wins = recent.where((m) {
          final f = m.fixture, score = f.scoreFor(SportScoreScope.finalResult)!;
          return (score.home > score.away) == (f.home.id == participant.id);
        }).length;
        final enough = recent.length == 3;
        result.add(
          SportReadingAssessment(
            id: 'head_to_head_dominance',
            subject: participant.id,
            match: fixture.id,
            asOf: snapshot.capturedAt,
            sampleSize: recent.length,
            status: !enough
                ? SportReadingStatus.insufficientData
                : wins == 3
                ? SportReadingStatus.detected
                : SportReadingStatus.notDetected,
            explanation:
                '${kind == LectorMeetingKind.league ? "Championnat" : "Coupes / phases finales"} : '
                '$wins victoires sur les ${recent.length} dernières confrontations admissibles sur trois ans. '
                '${enough ? "Trois victoires sur trois sont requises." : "Il faut trois confrontations comparables."}',
            evidence: {
              'competitionKind': kind.name,
              'windowYears': 3,
              'thresholdWins': 3,
              'meetingIds': recent.map((m) => m.fixture.id.key).toList(),
            },
          ),
        );
      }
    }
    return result;
  }

  List<SportReadingAssessment> selected(
    SportFixture fixture,
    SportSnapshot<SportFixture> snapshot,
    SportReadingPreferences preferences,
  ) => preferences.sport != SportId.hockey
      ? const []
      : evaluate(
          fixture,
          snapshot,
        ).where((r) => preferences.readingIds.contains(r.id)).toList();

  bool recommends(
    SportFixture fixture,
    SportSnapshot<SportFixture> snapshot,
    SportReadingPreferences preferences,
  ) =>
      preferences.isConfigured &&
      preferences.follows(fixture.competition) &&
      selected(
        fixture,
        snapshot,
        preferences,
      ).any((r) => r.status == SportReadingStatus.detected);

  bool _regular(String stage) => stage.toLowerCase().contains('regular season');
  HockeyPointsRules? pointsRulesFor(SportFixture f) {
    if (f.competition.provider != 'api-hockey' || f.season != '2026') {
      return null;
    }
    return switch (f.competition.value) {
      '57' || '58' || '35' => HockeyPointsRules.nhlRegularSeason,
      '10' || '18' || '16' || '47' => HockeyPointsRules.threePointRegularSeason,
      _ => null,
    };
  }

  /// Bounded first-season policy from the study. Outside these regular-season
  /// windows we abstain. NHL history remains blocked by formPhaseVerified.
  bool _insideRegularWindow(SportFixture f, DateTime date) {
    final (month, day, endMonth, endDay) = switch (f.competition.value) {
      '57' => (9, 29, 3, 1), // conservative bound before postseason
      '58' => (10, 2, 3, 1),
      '35' => (9, 5, 3, 20),
      '10' => (9, 15, 3, 5),
      '18' => (9, 15, 3, 2),
      '16' => (9, 1, 3, 1),
      '47' => (9, 19, 3, 16),
      _ => (12, 31, 1, 1),
    };
    return !date.isBefore(DateTime.utc(2026, month, day)) &&
        date.isBefore(DateTime.utc(2027, endMonth, endDay + 1));
  }

  HockeyResult? resultFor(SportFormResult r) {
    final won = r.scored > r.conceded;
    if (r.scored == r.conceded) return null;
    return switch (r.providerStatus) {
      'FT' => won ? HockeyResult.regulationWin : HockeyResult.regulationLoss,
      'AOT' => won ? HockeyResult.overtimeWin : HockeyResult.overtimeLoss,
      'AP' ||
      'APEN' => won ? HockeyResult.shootoutWin : HockeyResult.shootoutLoss,
      _ => null,
    };
  }
}
