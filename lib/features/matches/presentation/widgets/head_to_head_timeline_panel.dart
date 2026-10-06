import '../../../../core/domain/lector_head_to_head_policy.dart';
import 'package:flutter/material.dart';
import '../../../../core/widgets/lector_head_to_head_data.dart';
import '../../../../core/widgets/lector_head_to_head_timeline_panel.dart';
import '../../domain/match_board_item.dart';

/// Football policy adapter for the common factual confrontation view.
class HeadToHeadTimelinePanel extends StatelessWidget {
  const HeadToHeadTimelinePanel({required this.match, super.key});
  final MatchBoardItem match;
  @override
  Widget build(BuildContext context) => LectorHeadToHeadTimelinePanel(
    data: LectorHeadToHeadData(
      competitionId: match.fixture.competition.apiFootballLeagueId?.toString(),
      firstTeamId: match.fixture.homeTeam.apiFootballTeamId?.toString(),
      secondTeamId: match.fixture.awayTeam.apiFootballTeamId?.toString(),
      firstTeamName: match.fixture.homeTeam.name,
      secondTeamName: match.fixture.awayTeam.name,
      firstTeamLogoUrl: match.fixture.homeTeam.logoUrl,
      secondTeamLogoUrl: match.fixture.awayTeam.logoUrl,
      emptyDescription:
          'Ces équipes ne se sont pas encore rencontrées dans les trois dernières saisons officielles.',
      meetings: _eligible(match)
          .map(
            (m) => LectorHeadToHeadMeeting(
              fixtureId: m.fixtureId?.toString(),
              competitionKind: LectorHeadToHeadPolicy.classify(
                name: m.competitionName,
                type: m.competitionType,
                knownLeague:
                    m.competitionId == match.competition.apiFootballLeagueId,
              ),
              competitionId: m.competitionId.toString(),
              competitionName: m.competitionName,
              playedAt: m.playedAt,
              homeTeamId: m.homeTeamId.toString(),
              awayTeamId: m.awayTeamId.toString(),
              homeTeamName: m.homeTeamName,
              awayTeamName: m.awayTeamName,
              homeTeamLogoUrl: m.homeTeamLogoUrl,
              awayTeamLogoUrl: m.awayTeamLogoUrl,
              homeGoals: m.homeGoals,
              awayGoals: m.awayGoals,
              events: m.events
                  .where(_isKeyEvent)
                  .map(
                    (e) => LectorHeadToHeadEvent(
                      minute: e.minute,
                      teamId: e.teamId?.toString(),
                      label: _eventLabel(e),
                      clockLabel: "${e.minute}'",
                      playerName: e.playerName,
                      danger: e.type.toLowerCase() == 'card',
                      icon: e.type.toLowerCase() == 'card'
                          ? Icons.rectangle_rounded
                          : e.type.toLowerCase() == 'var'
                          ? Icons.videocam_rounded
                          : Icons.sports_soccer_rounded,
                    ),
                  )
                  .toList(),
              statistics: [
                for (final r in [
                  (
                    'Tirs',
                    m.homeStatistics?.totalShots,
                    m.awayStatistics?.totalShots,
                  ),
                  (
                    'Tirs cadrés',
                    m.homeStatistics?.shotsOnGoal,
                    m.awayStatistics?.shotsOnGoal,
                  ),
                  (
                    'xG',
                    m.homeStatistics?.expectedGoals,
                    m.awayStatistics?.expectedGoals,
                  ),
                ])
                  if (r.$2 != null || r.$3 != null)
                    LectorHeadToHeadStatistic(r.$1, r.$2, r.$3),
              ],
            ),
          )
          .toList(),
    ),
  );
  List<HeadToHeadFixtureSnapshot> _eligible(MatchBoardItem match) {
    final reference = match.fixture.kickoff;
    if (reference == null) return const [];
    final lowerBound = LectorHeadToHeadPolicy.lowerBound(reference);
    final recentMeetings =
        match.analysis.headToHeadMatches
            .where(
              (meeting) =>
                  !meeting.playedAt.isBefore(lowerBound) &&
                  meeting.playedAt.isBefore(reference) &&
                  !_isFriendlyCompetition(meeting.competitionName),
            )
            .toList(growable: false)
          ..sort((left, right) => right.playedAt.compareTo(left.playedAt));
    // Keep the six newest eligible meetings, then restore chronological order
    // for the left-to-right visual timeline.
    final championship = recentMeetings
        .where((m) => m.competitionId == match.competition.apiFootballLeagueId)
        .take(6);
    final cups = recentMeetings
        .where(
          (m) =>
              LectorHeadToHeadPolicy.classify(
                name: m.competitionName,
                type: m.competitionType,
              ) ==
              LectorMeetingKind.cup,
        )
        .take(6);
    final selected = {...recentMeetings.take(6), ...championship, ...cups};
    final meetings = selected.toList(growable: false)
      ..sort((left, right) => left.playedAt.compareTo(right.playedAt));
    return List.unmodifiable(meetings);
  }
}

bool _isFriendlyCompetition(String competitionName) {
  return LectorHeadToHeadPolicy.classify(name: competitionName) ==
      LectorMeetingKind.excluded;
}

bool _isKeyEvent(HeadToHeadMatchEventSnapshot event) {
  final type = event.type.toLowerCase();
  final detail = event.detail.toLowerCase();
  return type == 'goal' ||
      type == 'var' ||
      (type == 'card' &&
          (detail.contains('red') || detail.contains('yellow red')));
}

String _eventLabel(HeadToHeadMatchEventSnapshot event) {
  final type = event.type.toLowerCase();
  final detail = event.detail.toLowerCase();
  if (type == 'var') {
    if (detail.contains('cancel')) return 'But refusé par la VAR';
    if (detail.contains('penalty')) return 'Décision VAR · penalty';
    return 'Décision VAR';
  }
  if (type == 'card') {
    return detail.contains('yellow red')
        ? 'Second jaune · rouge'
        : 'Carton rouge';
  }
  if (detail.contains('missed penalty')) return 'Penalty manqué';
  if (detail.contains('penalty')) return 'Penalty';
  if (detail.contains('own goal')) return 'But contre son camp';
  return 'But';
}
