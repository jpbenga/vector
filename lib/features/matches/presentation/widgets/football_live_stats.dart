import 'package:flutter/material.dart';
import '../../../../core/widgets/lector_match_stats.dart';
import '../../domain/live_match_state.dart';
import '../../domain/match_board_item.dart';

/// Match facts only: no season averages or pre-match estimates in this panel.
class FootballLiveStats extends StatelessWidget {
  const FootballLiveStats({required this.match, this.state, super.key});
  final MatchBoardItem match;
  final LiveMatchState? state;
  @override
  Widget build(BuildContext context) {
    const labels = {
      'Ball Possession': 'Possession',
      'Total Shots': 'Tirs',
      'Shots on Goal': 'Tirs cadrés',
      'Corner Kicks': 'Corners',
      'Fouls': 'Fautes',
      'Yellow Cards': 'Cartons jaunes',
      'Red Cards': 'Cartons rouges',
      'Goalkeeper Saves': 'Arrêts',
      'expected_goals': 'Buts attendus (xG)',
    };
    Map<String, String> values(int? teamId) {
      if (teamId == null) return {};
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

    final home = values(match.homeTeam.apiFootballTeamId),
        away = values(match.awayTeam.apiFootballTeamId);
    final current = state?.overlay(match) ?? match;
    return LectorMatchStats(
      isLive: state?.isLive == true,
      firstTeam: match.homeTeam.name,
      secondTeam: match.awayTeam.name,
      scoreLabel: current.fixture.score == null
          ? null
          : '${current.fixture.score!.home} – ${current.fixture.score!.away}',
      capturedAt: state?.statisticsCapturedAt,
      rows: [
        for (final key in labels.keys)
          if (home.containsKey(key) || away.containsKey(key))
            LectorMatchStatistic(
              label: labels[key]!,
              first: home[key],
              second: away[key],
            ),
      ],
    );
  }
}
