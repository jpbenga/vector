import 'package:flutter/material.dart';
import '../../../../core/widgets/lector_match_stats.dart';
import '../../domain/live_match_state.dart';
import '../../domain/match_board_item.dart';

/// Match facts only: season averages and pre-match readings never enter Stats.
class FootballLiveStats extends StatelessWidget {
  const FootballLiveStats({required this.match, this.state, super.key});
  final MatchBoardItem match;
  final LiveMatchState? state;
  @override
  Widget build(BuildContext context) {
    final facts = FootballMatchFacts(match, state);
    final current = state?.overlay(match) ?? match;
    final score = current.fixture.score;
    final extraTime = const {'ET', 'BT', 'AET'}.contains(state?.status);
    final last = extraTime ? 120.0 : 90.0;
    final end = [
      last,
      (state?.elapsed ?? 0).toDouble(),
      ...facts.events.map((e) => e.position ?? 0),
    ].reduce((a, b) => a > b ? a : b);
    return LectorMatchStats(
      isLive: current.fixture.status == FixtureStatus.live,
      isFinal: current.fixture.status == FixtureStatus.finished,
      finalStatistics: state?.statisticsIsFinal == true,
      firstTeam: match.homeTeam.name,
      secondTeam: match.awayTeam.name,
      scoreLabel: score == null ? null : '${score.home} – ${score.away}',
      clockLabel: state?.elapsed == null
          ? null
          : '${state!.elapsed}${(state!.extra ?? 0) > 0 ? '+${state!.extra}' : ''}′',
      currentPosition: state?.elapsed?.toDouble(),
      capturedAt: state?.statisticsCapturedAt,
      rows: facts.rows,
      primaryLabels: const [
        'Possession',
        'Tirs',
        'Tirs cadrés',
        'Corners',
        'Fautes',
        'Hors-jeu',
        'Buts attendus (xG)',
      ],
      summary: facts.summary,
      events: facts.events,
      eventsCapturedAt: state?.eventsCapturedAt,
      periods: [
        const LectorMatchPeriod('1re période', 0, 45),
        const LectorMatchPeriod('2e période', 45, 90),
        if (!extraTime && end > 90) LectorMatchPeriod('Après 90′', 90, end),
        if (extraTime) ...[
          const LectorMatchPeriod('Prol. 1', 90, 105),
          LectorMatchPeriod('Prol. 2', 105, end),
        ],
      ],
    );
  }
}

/// Deterministic interpretation of received facts, testable without network/UI.
class FootballMatchFacts {
  FootballMatchFacts(this.match, this.state);
  final MatchBoardItem match;
  final LiveMatchState? state;
  static const labels = {
    'Ball Possession': 'Possession',
    'Total Shots': 'Tirs',
    'Shots on Goal': 'Tirs cadrés',
    'Corner Kicks': 'Corners',
    'Fouls': 'Fautes',
    'Offsides': 'Hors-jeu',
    'expected_goals': 'Buts attendus (xG)',
    'Shots off Goal': 'Tirs non cadrés',
    'Blocked Shots': 'Tirs contrés',
    'Shots insidebox': 'Tirs dans la surface',
    'Shots outsidebox': 'Tirs hors surface',
    'Total passes': 'Passes',
    'Passes accurate': 'Passes réussies',
    'Passes %': 'Précision des passes',
    'Yellow Cards': 'Cartons jaunes',
    'Red Cards': 'Cartons rouges',
    'Goalkeeper Saves': 'Arrêts',
  };
  Map<String, String> _values(int? teamId) {
    if (teamId == null ||
        state?.fixtureId != match.fixture.apiFootballFixtureId) {
      return {};
    }
    final result = <String, String>{};
    for (final block in state?.statistics ?? const <Map<String, dynamic>>[]) {
      if ((block['team'] as Map?)?['id'] != teamId) continue;
      for (final raw in block['statistics'] as List? ?? const []) {
        if (raw is! Map || !labels.containsKey(raw['type'])) continue;
        final value = raw['value'];
        if (value is num && value.isFinite && value >= 0 ||
            value is String && RegExp(r'^\d+(\.\d+)?%?$').hasMatch(value)) {
          result[raw['type'] as String] = '$value';
        }
      }
    }
    return result;
  }

  late final home = _values(match.homeTeam.apiFootballTeamId);
  late final away = _values(match.awayTeam.apiFootballTeamId);
  List<LectorMatchStatistic> get rows => [
    for (final key in labels.keys)
      if (home.containsKey(key) || away.containsKey(key))
        LectorMatchStatistic(
          label: labels[key]!,
          first: home[key],
          second: away[key],
        ),
  ];
  int? _advantage(String key) {
    final a = double.tryParse(home[key]?.replaceAll('%', '') ?? '');
    final b = double.tryParse(away[key]?.replaceAll('%', '') ?? '');
    return a == null || b == null ? null : a.compareTo(b);
  }

  String? get summary {
    final current = state?.overlay(match) ?? match;
    final finished = current.fixture.status == FixtureStatus.finished;
    if (finished && state?.statisticsIsFinal != true) {
      return null;
    }
    final shots = _advantage('Total Shots'),
        possession = _advantage('Ball Possession'),
        onGoal = _advantage('Shots on Goal');
    final parts = <String>[];
    String team(int direction) =>
        direction > 0 ? match.homeTeam.name : match.awayTeam.name;
    if (shots != null && shots != 0) {
      parts.add(
        '${team(shots)} ${possession == shots ? 'a davantage le ballon et ' : ''}produit davantage de tirs (${home['Total Shots']}–${away['Total Shots']})${onGoal == shots ? ', dont plus de tirs cadrés (${home['Shots on Goal']}–${away['Shots on Goal']})' : ''}.',
      );
    } else if (possession != null && possession != 0) {
      parts.add(
        '${team(possession)} a davantage le ballon (${home['Ball Possession']}–${away['Ball Possession']}).',
      );
    } else if (onGoal != null && onGoal != 0) {
      parts.add(
        '${team(onGoal)} a davantage de tirs cadrés (${home['Shots on Goal']}–${away['Shots on Goal']}).',
      );
    }
    if (parts.isEmpty) return null;
    final score = current.fixture.score;
    if (score != null) {
      if (score.home == score.away) {
        parts.add('Le score est à égalité (${score.home}–${score.away}).');
        if (state?.halftimeHomeGoals != null &&
            state?.halftimeAwayGoals != null &&
            state!.halftimeHomeGoals != state!.halftimeAwayGoals &&
            (finished || state!.status == '2H' || (state!.elapsed ?? 0) > 45)) {
          parts.add(
            '${state!.halftimeHomeGoals! > state!.halftimeAwayGoals! ? match.awayTeam.name : match.homeTeam.name} est revenu à égalité depuis la mi-temps.',
          );
        }
      } else {
        final first = score.home > score.away;
        parts.add(
          '${first ? match.homeTeam.name : match.awayTeam.name} ${finished ? 'a remporté le match' : 'mène'} ${first ? score.home : score.away}–${first ? score.away : score.home}.',
        );
      }
    }
    return parts.join(' ');
  }

  List<LectorMatchEvent> get events {
    if (state?.fixtureId != match.fixture.apiFootballFixtureId) return [];
    final rawEvents = [...state?.events ?? const <Map<String, dynamic>>[]];
    int? minute(Map<String, dynamic> raw) =>
        ((raw['time'] as Map?)?['elapsed'] as num?)?.toInt();
    int extra(Map<String, dynamic> raw) =>
        ((raw['time'] as Map?)?['extra'] as num?)?.toInt() ?? 0;
    int order(Map<String, dynamic> raw) =>
        minute(raw) == null ? 1000000 : minute(raw)! * 1000 + extra(raw);
    rawEvents.sort((a, b) => order(a).compareTo(order(b)));
    final goals = rawEvents
        .where(
          (e) =>
              e['type'] == 'Goal' &&
              e['detail'] != 'Missed Penalty' &&
              e['comments'] != 'Penalty Shootout',
        )
        .toList();
    final score = state?.overlay(match).fixture.score;
    // Display the evolving score only when every goal is present, attributable
    // and the count reconciles with the authoritative current score.
    final complete =
        score != null &&
        goals.every(
          (e) =>
              minute(e) != null &&
              minute(e)! >= 0 &&
              extra(e) >= 0 &&
              e['detail'] != 'Own Goal' &&
              (!state!.isLive ||
                  state!.elapsed == null ||
                  minute(e)! <= state!.elapsed!),
        ) &&
        goals
                .where(
                  (e) =>
                      (e['team'] as Map?)?['id'] ==
                      match.homeTeam.apiFootballTeamId,
                )
                .length ==
            score.home &&
        goals
                .where(
                  (e) =>
                      (e['team'] as Map?)?['id'] ==
                      match.awayTeam.apiFootballTeamId,
                )
                .length ==
            score.away &&
        goals.length == score.home + score.away;
    var homeScore = 0, awayScore = 0;
    final result = <LectorMatchEvent>[];
    for (final raw in rawEvents) {
      final id = (raw['team'] as Map?)?['id'];
      if (id == null ||
          id != match.homeTeam.apiFootballTeamId &&
              id != match.awayTeam.apiFootballTeamId) {
        continue;
      }
      final type = raw['type'], detail = raw['detail'];
      final label = switch (type) {
        'Goal' =>
          detail == 'Missed Penalty'
              ? 'Penalty manqué'
              : detail == 'Own Goal'
              ? 'But contre son camp'
              : detail == 'Penalty'
              ? 'But sur penalty'
              : 'But',
        'Card' =>
          detail == 'Red Card'
              ? 'Carton rouge'
              : detail == 'Second Yellow card'
              ? 'Second carton jaune'
              : 'Carton jaune',
        'subst' => 'Remplacement',
        'Var' => 'Décision VAR',
        _ => null,
      };
      if (label == null) continue;
      final first = id == match.homeTeam.apiFootballTeamId;
      final elapsed = minute(raw), added = extra(raw);
      if (elapsed != null && elapsed < 0 || added < 0) continue;
      if (state!.isLive &&
          elapsed != null &&
          state!.elapsed != null &&
          elapsed > state!.elapsed!) {
        continue;
      }
      if (complete && goals.contains(raw)) {
        if (first) {
          homeScore++;
        } else {
          awayScore++;
        }
      }
      final player = (raw['player'] as Map?)?['name'] as String?;
      final assist = (raw['assist'] as Map?)?['name'] as String?;
      result.add(
        LectorMatchEvent(
          clock: elapsed == null
              ? '—'
              : '$elapsed${added > 0 ? '+$added' : ''}′',
          order: elapsed == null ? null : order(raw),
          // Added time is attached to its actual half boundary; it must not move
          // a 45+3 event into the second half of the match.
          position: elapsed?.toDouble(),
          scoreLabel:
              complete &&
                  elapsed != null &&
                  raw['comments'] != 'Penalty Shootout'
              ? '$homeScore – $awayScore'
              : null,
          label:
              '$label · ${first ? match.homeTeam.name : match.awayTeam.name}',
          firstTeam: first,
          kind: switch (type) {
            'Goal' => LectorMatchEventKind.goal,
            'Card' =>
              const {'Red Card', 'Second Yellow card'}.contains(detail)
                  ? LectorMatchEventKind.dismissal
                  : LectorMatchEventKind.warning,
            'subst' => LectorMatchEventKind.substitution,
            'Var' => LectorMatchEventKind.review,
            _ => LectorMatchEventKind.other,
          },
          icon: switch (type) {
            'Goal' => Icons.sports_soccer_rounded,
            'Card' => Icons.style_rounded,
            'subst' => Icons.swap_horiz_rounded,
            _ => Icons.fact_check_outlined,
          },
          detail: [
            ?player,
            if (assist != null)
              '${type == 'subst' ? 'Entrée' : 'Passe'} : $assist',
            if (type == 'Var' && detail is String) detail,
          ].join(' · '),
        ),
      );
    }
    return result;
  }
}
