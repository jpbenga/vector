import '../../../core/sports/domain/sport_snapshot.dart';
import '../../../core/sports/domain/sport_fixture.dart';
import '../../form_radar/domain/radar_scope.dart';
import 'hockey_player_radar.dart';
import 'hockey_team_radar.dart';

class HockeyRadarSelection {
  HockeyRadarSelection(
    this.snapshot, {
    required DateTime day,
    this.competitionId,
    this.mode = 'players',
  }) {
    final end = DateTime(day.year, day.month, day.day + 1);
    final before = end.isBefore(snapshot.capturedAt)
        ? end
        : snapshot.capturedAt;
    teams = HockeyTeamRadarRanker.rank(
      snapshot.competitions.where(
        (c) => competitionId == null || c.id.value == competitionId,
      ),
    ).take(50).toList();
    players = HockeyPlayerRadarRanker.rank(
      snapshot.players.where(
        (p) => competitionId == null || p.competition.value == competitionId,
      ),
      before: before,
    ).take(50).toList();
  }
  final SportSnapshot<SportFixture> snapshot;
  final String? competitionId;
  final String mode;
  late final List<HockeyTeamRadarEntry> teams;
  late final List<HockeyPlayerRadarEntry> players;
  RadarScope get scope => RadarScope(
    mode: mode,
    category: 'club',
    capturedAt: snapshot.capturedAt,
    sourceIds: const [],
    competitionId: competitionId,
    teams: [
      for (var i = 0; i < teams.length; i++)
        RadarMember(
          id: teams[i].row.team.id.value,
          teamId: teams[i].row.team.id.value,
          rank: i + 1,
          matchIds: teams[i].row.formHistory.reversed
              .take(5)
              .map((m) => m.matchId.value)
              .toList()
              .reversed
              .toList(),
        ),
    ],
    players: [
      for (var i = 0; i < players.length; i++)
        RadarMember(
          id: players[i].profile.id.value,
          teamId: players[i].profile.team.id.value,
          rank: i + 1,
          matchIds: players[i].recentActivity
              .map((m) => m.result.matchId.value)
              .toList(),
        ),
    ],
  );
}
