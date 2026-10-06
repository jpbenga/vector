import '../../../core/sports/domain/sport.dart';
import '../../../core/domain/lector_victory_series.dart';
import '../../../core/domain/lector_form_reading_policy.dart';
import '../../../core/sports/domain/sport_module.dart';
import 'hockey_analysis.dart';
import 'hockey_module.dart';
import 'hockey_rules.dart';
import 'hockey_standing_tiers.dart';

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

    final formWindow = LectorFormWindow(
      form.map((g) => context.pointsRules.points(g.result)).toList(),
      maximumPoints: context.pointsRules.maximumPointsPerGame,
    );
    final otherWindow = LectorFormWindow(
      opponentForm.map((g) => context.pointsRules.points(g.result)).toList(),
      maximumPoints: context.pointsRules.maximumPointsPerGame,
    );
    final standing = team.standing;
    final otherStanding = opponent.standing;
    final comparable =
        _usableStanding(context, standing) &&
        _usableStanding(context, otherStanding) &&
        standing!.comparisonGroup == otherStanding!.comparisonGroup &&
        (standing.gamesPlayed - otherStanding.gamesPlayed).abs() <= 1;
    if (!comparable) {
      yield assessment(
        'standing_advantage',
        SportReadingStatus.insufficientData,
        'Tiers absents, échantillon inférieur à 5 matchs ou classements non comparables (groupe ou matchs joués).',
        0,
      );
    } else {
      final advantage =
          standing.tier! < otherStanding.tier! &&
          standing.rank! < otherStanding.rank! &&
          standing.points > otherStanding.points &&
          standing.points / standing.gamesPlayed >
              otherStanding.points / otherStanding.gamesPlayed;
      yield assessment(
        'standing_advantage',
        detected(advantage),
        'T${standing.tier} face à T${otherStanding.tier} · ${standing.comparisonGroup} · '
            '${standing.points} points en ${standing.gamesPlayed} matchs contre '
            '${otherStanding.points} en ${otherStanding.gamesPlayed}. '
            '${advantage ? 'Avantage dans un tiers supérieur du même classement.' : 'Pas d’avantage de tier confirmé pour cette équipe.'}',
        standing.gamesPlayed,
        {
          'tier': standing.tier!,
          'opponentTier': otherStanding.tier!,
          'tierVersion': standing.tierVersion!,
          'pointsGap': standing.points - otherStanding.points,
          'comparisonGroup': standing.comparisonGroup,
        },
      );
    }

    final structuralAvailable = comparable && standing.structuralRanks != null;
    final structural =
        structuralAvailable &&
        standing.structuralRanks!.contains(otherStanding.rank) &&
        standing.tier! < otherStanding.tier! &&
        standing.points > otherStanding.points &&
        standing.points / standing.gamesPlayed >
            otherStanding.points / otherStanding.gamesPlayed;
    yield assessment(
      'structural_level_gap',
      structuralAvailable
          ? detected(structural)
          : SportReadingStatus.insufficientData,
      structural
          ? 'Écart de niveau structurel : T${standing.tier} face à T${otherStanding.tier}, séparation confirmée dans ${standing.comparisonGroup}.'
          : 'Pas de séparation structurelle confirmée dans un classement commun exploitable.',
      structuralAvailable ? standing.gamesPlayed : 0,
      structuralAvailable
          ? {
              'tier': standing.tier!,
              'opponentTier': otherStanding.tier!,
              'tierVersion': standing.tierVersion!,
              'comparisonGroup': standing.comparisonGroup,
              'boundaryMethod': 'strong-or-multiple-confirmed-boundaries',
            }
          : const {},
    );

    final windowFacts = {
      'points': formWindow.total,
      'possiblePoints': formWindow.possible,
      'window': 5,
    };
    for (final (id, active, explanation) in [
      (
        'positive_streak',
        formWindow.positive,
        'Des points à chacun des cinq derniers matchs et au moins ${formWindow.positiveMinimum}/${formWindow.possible} points.',
      ),
      (
        'negative_streak',
        formWindow.negative,
        'Au plus ${formWindow.negativeMaximum}/${formWindow.possible} points sur les cinq derniers matchs.',
      ),
      (
        'improving_form',
        formWindow.improving,
        'Moyenne des deux derniers matchs comparée aux trois précédents : évolution de ${formWindow.trend.toStringAsFixed(2)} point/match ; seuil ${formWindow.trendThreshold.toStringAsFixed(2)}.',
      ),
    ]) {
      yield assessment(
        id,
        formWindow.available
            ? detected(active)
            : SportReadingStatus.insufficientData,
        formWindow.available
            ? '$explanation Total observé : ${formWindow.total}/${formWindow.possible}.'
            : 'Il faut cinq résultats comparables pour cette lecture.',
        formWindow.points.length,
        {...windowFacts, 'trend': formWindow.trend},
      );
    }
    final completeForms = formWindow.available && otherWindow.available;
    final pointGap = formWindow.total - otherWindow.total;
    yield assessment(
      'form_gap',
      completeForms
          ? detected(pointGap >= policy.formGapPoints)
          : SportReadingStatus.insufficientData,
      completeForms
          ? '${formWindow.total}/${formWindow.possible} contre ${otherWindow.total}/${otherWindow.possible} sur cinq matchs : $pointGap points d’écart, ${policy.formGapPoints} requis.'
          : 'Il faut cinq résultats comparables pour chaque équipe.',
      formWindow.points.length,
      {
        'pointsGap': pointGap,
        'thresholdPoints': policy.formGapPoints,
        ...windowFacts,
      },
    );

    if (!completeForms) {
      yield assessment(
        'recent_form_advantage',
        SportReadingStatus.insufficientData,
        'Il faut ${policy.formWindow} matchs terminés par équipe '
            'dans cette compétition et cette saison.',
        formWindow.points.length,
      );
    } else {
      final gap =
          _percentage(form.take(5).toList(), context.pointsRules) -
          _percentage(opponentForm.take(5).toList(), context.pointsRules);
      yield assessment(
        'recent_form_advantage',
        detected(_meets(gap, policy.formPercentageGap)),
        '$pointGap points d’écart sur cinq matchs (${formWindow.total}/${formWindow.possible} contre ${otherWindow.total}/${otherWindow.possible}).',
        formWindow.points.length,
        {'percentageGap': gap, 'pointsGap': pointGap},
      );
    }

    for (final scope in [LectorSeriesScope.overall]) {
      final series = LectorVictorySeries.assess(
        form,
        won: (g) => g.result.isWin,
        home: (g) => g.home,
        scope: scope,
        historyComplete: team.historyComplete,
      );
      final relevant =
          scope == LectorSeriesScope.overall ||
          (scope == LectorSeriesScope.home
              ? team.team == context.home.team
              : team.team == context.away.team);
      yield assessment(
        scope.readingId,
        !relevant
            ? SportReadingStatus.notDetected
            : !series.sufficient
            ? SportReadingStatus.insufficientData
            : detected(series.detected),
        !relevant
            ? 'La série ${scope.label} ne concerne pas le lieu de cette équipe pour cette rencontre.'
            : !series.sufficient
            ? 'Historique insuffisant pour confirmer trois victoires consécutives ${scope.label}.'
            : 'Série ${scope.label} : ${series.label}, prolongation et tirs au but inclus. ${series.milestone}',
        series.sample,
        {
          'scope': scope.name,
          'consecutiveWins': series.count,
          'exact': series.exact,
          'threshold': 3,
          'relevantVenue': relevant,
        },
      );
    }
    for (final id
        in team.team == context.home.team
            ? ['strong_away_team', 'weak_away_team', 'away_home_advantage']
            : ['strong_home_team', 'weak_home_team', 'home_away_advantage']) {
      yield assessment(
        id,
        SportReadingStatus.notDetected,
        'Cette lecture ne concerne pas le lieu de cette équipe pour cette rencontre.',
        0,
      );
    }
    final isHome = team.team == context.home.team;
    final scope = isHome ? LectorSeriesScope.home : LectorSeriesScope.away;
    final oppositeScope = isHome
        ? LectorSeriesScope.away
        : LectorSeriesScope.home;
    LectorVictorySeriesAssessment run(
      List<HockeyRecentGame> games,
      LectorSeriesScope place,
      bool win,
      bool complete,
    ) => LectorResultSeries.assess(
      games,
      scope: place,
      historyComplete: complete,
      home: (g) => g.home,
      matches: (g) => g.result.isWin == win,
    );
    final wins = run(form, scope, true, team.historyComplete);
    final losses = run(form, scope, false, team.historyComplete);
    final opponentLosses = run(
      opponentForm,
      oppositeScope,
      false,
      opponent.historyComplete,
    );
    for (final (id, series, win) in [
      (isHome ? 'strong_home_team' : 'strong_away_team', wins, true),
      (isHome ? 'weak_home_team' : 'weak_away_team', losses, false),
    ]) {
      yield assessment(
        id,
        !series.sufficient
            ? SportReadingStatus.insufficientData
            : detected(series.detected),
        !series.sufficient
            ? 'Historique insuffisant pour confirmer trois résultats consécutifs ${scope.label}.'
            : '${series.exact ? "" : "Au moins "}${series.count} ${win ? "victoires" : "défaites"} consécutives ${scope.label}, prolongation et tirs au but inclus.',
        series.sample,
        {
          'scope': scope.name,
          'result': win ? 'win' : 'loss',
          'consecutiveResults': series.count,
          'exact': series.exact,
          'threshold': 3,
        },
      );
    }
    final advantage = wins.detected && opponentLosses.detected;
    // A proven failure of either condition rules the conjunction out even
    // if the other team's history is incomplete.
    final available =
        advantage ||
        (wins.sufficient && !wins.detected) ||
        (opponentLosses.sufficient && !opponentLosses.detected);
    yield assessment(
      isHome ? 'home_away_advantage' : 'away_home_advantage',
      available ? detected(advantage) : SportReadingStatus.insufficientData,
      '${wins.exact ? "" : "Au moins "}${wins.count} victoires ${scope.label} pour cette équipe ; '
      '${opponentLosses.exact ? "" : "au moins "}${opponentLosses.count} défaites ${oppositeScope.label} pour son adversaire. Trois résultats consécutifs requis de chaque côté.',
      wins.sample < opponentLosses.sample ? wins.sample : opponentLosses.sample,
      {
        'scope': scope.name,
        'consecutiveWins': wins.count,
        'opponentConsecutiveLosses': opponentLosses.count,
        'winsExact': wins.exact,
        'lossesExact': opponentLosses.exact,
        'threshold': 3,
      },
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
                  game.match.provider == context.match.provider &&
                  game.match.kind == SportEntityKind.match &&
                  (game.startedAt == null ||
                      !game.startedAt!.isAfter(game.completedAt)) &&
                  game.completedAt.isBefore(context.asOf) &&
                  game.completedAt.isBefore(context.startsAt) &&
                  game.match != context.match,
            )
            .toList()
          ..sort(
            (a, b) => (b.startedAt ?? b.completedAt).compareTo(
              a.startedAt ?? a.completedAt,
            ),
          );
    return games.where((game) => seen.add(game.match)).toList(growable: false);
  }

  bool _usableStanding(HockeyMatchContext context, HockeyStanding? value) =>
      value != null &&
      value.competition == context.competition &&
      value.season == context.season &&
      value.comparisonGroup.trim().isNotEmpty &&
      !value.asOf.isAfter(context.asOf) &&
      value.gamesPlayed >= policy.minimumStandingGames &&
      value.tierVersion == HockeyStandingTiers.version &&
      value.tier != null &&
      value.tier! >= 1 &&
      value.tier! <= 5 &&
      value.rank != null &&
      value.rank! >= 1 &&
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
        policy.consecutiveWins != LectorVictorySeries.threshold ||
        policy.formWindow != 5 ||
        policy.formGapPoints < 1 ||
        policy.formWindow < policy.consecutiveWins ||
        policy.minimumStandingGames < 1 ||
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
