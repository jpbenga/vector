import '../../../core/sports/domain/sport.dart';
import '../../../core/sports/domain/sport_module.dart';
import 'hockey_analysis.dart';
import 'hockey_module.dart';
import 'hockey_rules.dart';

/// Provider-independent draft engine. No football models or rules are imported.
class HockeyReadingEngine implements SportReadingEngine<HockeyMatchContext> {
  const HockeyReadingEngine({this.policy = const HockeyReadingPolicy()});
  final HockeyReadingPolicy policy;
  @override
  SportId get sport => SportId.hockey;
  @override
  String get rulesVersion => policy.version;

  @override
  List<SportReadingAssessment> analyze(HockeyMatchContext context) {
    _validate(context);
    final homeForm = _recent(context, context.home);
    final awayForm = _recent(context, context.away);
    return List.unmodifiable([
      ..._forTeam(context, context.home, context.away, homeForm, awayForm),
      ..._forTeam(context, context.away, context.home, awayForm, homeForm),
    ]);
  }

  Iterable<SportReadingAssessment> _forTeam(
    HockeyMatchContext context,
    HockeyTeamContext team,
    HockeyTeamContext opponent,
    List<HockeyRecentGame> form,
    List<HockeyRecentGame> opponentForm,
  ) sync* {
    final maxPoints = context.pointsRules.maximumPointsPerGame;
    SportReadingAssessment assessment(
      String id,
      SportReadingStatus status,
      String explanation,
      int sample, [
      Map<String, Object> evidence = const {},
    ]) => SportReadingAssessment(
      id: id,
      subject: team.team,
      match: context.match,
      status: status,
      explanation: explanation,
      sampleSize: sample,
      asOf: context.asOf,
      evidence: {'policyVersion': policy.version, ...evidence},
    );
    SportReadingStatus detected(bool value) =>
        value ? SportReadingStatus.detected : SportReadingStatus.notDetected;

    final standing = team.standing;
    final otherStanding = opponent.standing;
    final comparable =
        _usableStanding(context, standing) &&
        _usableStanding(context, otherStanding) &&
        standing!.comparisonGroup == otherStanding!.comparisonGroup;
    if (!comparable) {
      yield assessment(
        'standing_advantage',
        SportReadingStatus.insufficientData,
        'Classements absents, incomplets ou non comparables.',
        0,
      );
    } else {
      final gap =
          standing.points / (standing.gamesPlayed * maxPoints) -
          otherStanding.points / (otherStanding.gamesPlayed * maxPoints);
      yield assessment(
        'standing_advantage',
        detected(_meets(gap, policy.standingPercentageGap)),
        'Écart de ${(gap * 100).toStringAsFixed(1)} points de pourcentage '
            'des points disponibles.',
        standing.gamesPlayed,
        {'percentageGap': gap, 'comparisonGroup': standing.comparisonGroup},
      );
    }

    if (form.length < policy.formWindow ||
        opponentForm.length < policy.formWindow) {
      yield assessment(
        'recent_form_advantage',
        SportReadingStatus.insufficientData,
        'Il faut ${policy.formWindow} matchs terminés par équipe '
            'dans cette compétition et cette saison.',
        form.length,
      );
    } else {
      final gap =
          _percentage(form, context.pointsRules) -
          _percentage(opponentForm, context.pointsRules);
      yield assessment(
        'recent_form_advantage',
        detected(_meets(gap, policy.formPercentageGap)),
        'Écart de ${(gap * 100).toStringAsFixed(1)} points de pourcentage '
            'sur les ${policy.formWindow} derniers matchs.',
        form.length,
        {'percentageGap': gap},
      );
    }

    final available = form.length >= policy.consecutiveWins;
    yield assessment(
      'winning_streak',
      available
          ? detected(
              form.take(policy.consecutiveWins).every((g) => g.result.isWin),
            )
          : SportReadingStatus.insufficientData,
      available
          ? 'Les ${policy.consecutiveWins} derniers résultats sont évalués '
                'avec prolongations et tirs au but inclus.'
          : 'Historique insuffisant pour mesurer la série.',
      form.length,
    );
  }

  List<HockeyRecentGame> _recent(
    HockeyMatchContext context,
    HockeyTeamContext team,
  ) {
    final seen = <SportEntityId>{};
    final games =
        team.recentGames
            .where(
              (game) =>
                  game.competition == context.competition &&
                  game.season == context.season &&
                  game.match.sport == SportId.hockey &&
                  game.match.kind == SportEntityKind.match &&
                  game.completedAt.isBefore(context.asOf) &&
                  game.completedAt.isBefore(context.startsAt) &&
                  game.match != context.match,
            )
            .toList()
          ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
    return games
        .where((game) => seen.add(game.match))
        .take(policy.formWindow)
        .toList(growable: false);
  }

  bool _usableStanding(HockeyMatchContext context, HockeyStanding? value) =>
      value != null &&
      value.competition == context.competition &&
      value.season == context.season &&
      value.comparisonGroup.trim().isNotEmpty &&
      !value.asOf.isAfter(context.asOf) &&
      value.gamesPlayed >= policy.minimumStandingGames &&
      value.points >= 0 &&
      value.points <=
          value.gamesPlayed * context.pointsRules.maximumPointsPerGame;

  double _percentage(List<HockeyRecentGame> games, HockeyPointsRules rules) =>
      games.fold(0, (sum, game) => sum + rules.points(game.result)) /
      (games.length * rules.maximumPointsPerGame);

  bool _meets(double value, double threshold) => value + 1e-10 >= threshold;

  void _validate(HockeyMatchContext context) {
    final ids = [
      context.match,
      context.competition,
      context.home.team,
      context.away.team,
    ];
    if (ids.any(
          (id) =>
              id.sport != SportId.hockey ||
              id.provider != context.match.provider,
        ) ||
        context.match.kind != SportEntityKind.match ||
        context.competition.kind != SportEntityKind.competition ||
        context.home.team.kind != SportEntityKind.team ||
        context.away.team.kind != SportEntityKind.team ||
        context.home.team == context.away.team ||
        context.asOf.isAfter(context.startsAt) ||
        context.season.trim().isEmpty ||
        policy.consecutiveWins < 1 ||
        policy.formWindow < policy.consecutiveWins ||
        policy.minimumStandingGames < 1 ||
        policy.standingPercentageGap <= 0 ||
        policy.standingPercentageGap > 1 ||
        policy.formPercentageGap <= 0 ||
        policy.formPercentageGap > 1 ||
        context.pointsRules.maximumPointsPerGame <= 0) {
      throw ArgumentError('Invalid prematch hockey context or policy.');
    }
  }

  /// All required readings must converge on the SAME team and evaluation date.
  Set<SportEntityId> scenarioSubjects(
    Iterable<SportReadingAssessment> readings, {
    required SportEntityId match,
    String scenarioId = 'converging_advantages',
  }) {
    final definition = HockeyModule.definition.scenarios.firstWhere(
      (definition) => definition.id == scenarioId,
    );
    final bySubject = <SportEntityId, Map<DateTime, Set<String>>>{};
    for (final reading in readings) {
      if (reading.match != match ||
          reading.subject.sport != SportId.hockey ||
          reading.status != SportReadingStatus.detected) {
        continue;
      }
      (bySubject
              .putIfAbsent(reading.subject, () => {})
              .putIfAbsent(reading.asOf, () => {}))
          .add(reading.id);
    }
    return Set.unmodifiable(
      bySubject.entries
          .where(
            (entry) => entry.value.values.any(
              (ids) => ids.containsAll(definition.requiredReadingIds),
            ),
          )
          .map((entry) => entry.key),
    );
  }
}
