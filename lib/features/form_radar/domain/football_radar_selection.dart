import '../../matches/domain/match_board_item.dart';
import 'player_form_radar.dart';
import 'team_form_radar.dart';
import 'radar_audience_filter.dart';
import 'radar_scope.dart';

const radarTopLimit = 50;
const nationalTeamRadarLeagues = <int>{
  1,
  4,
  5,
  6,
  7,
  8,
  9,
  10,
  22,
  32,
  38,
  536,
};

/// Canonical selection used by both the Radar UI and the Generator context.
class FootballRadarSelection {
  FootballRadarSelection({
    required Iterable<PlayerFormRadarProfile> players,
    required Iterable<TeamFormRadarProfile> teams,
    required this.audience,
    required this.nationalTeams,
    this.mode = 'players',
    this.capturedAt,
    this.sourceIds = const [],
    Map<int, String> competitionNames = const {},
  }) {
    final scopedPlayers = PlayerFormRadarRanker.rank(players)
        .where(
          (e) =>
              nationalTeamRadarLeagues.contains(e.profile.leagueId) ==
              nationalTeams,
        )
        .toList();
    final scopedTeams = TeamFormRadarRanker.rank(teams)
        .where(
          (e) =>
              nationalTeamRadarLeagues.contains(e.profile.leagueId) ==
              nationalTeams,
        )
        .toList();
    final filteredPlayers = scopedPlayers
        .where(
          (e) => audience.includes(
            leagueId: e.profile.leagueId,
            teamName: e.profile.teamName,
            competitionName:
                competitionNames[e.profile.leagueId] ??
                e.profile.activity.reversed
                    .map((m) => m.competitionName)
                    .whereType<String>()
                    .firstOrNull ??
                '',
          ),
        )
        .toList();
    final filteredTeams = scopedTeams
        .where(
          (e) => audience.includes(
            leagueId: e.profile.leagueId,
            teamName: e.profile.teamName,
            competitionName: e.profile.leagueName,
          ),
        )
        .toList();
    hiddenPlayers = scopedPlayers.length - filteredPlayers.length;
    hiddenTeams = scopedTeams.length - filteredTeams.length;
    this.players = List.unmodifiable(filteredPlayers.take(radarTopLimit));
    this.teams = List.unmodifiable(filteredTeams.take(radarTopLimit));
  }
  final RadarAudienceFilter audience;
  final bool nationalTeams;
  final String mode;
  final DateTime? capturedAt;
  final List<String> sourceIds;
  late final List<PlayerFormRadarEntry> players;
  late final List<TeamFormRadarEntry> teams;
  late final int hiddenPlayers, hiddenTeams;
  List<MatchBoardItem> matches(
    Iterable<MatchBoardItem> matches, {
    required bool teamMode,
  }) {
    final ids = teamMode
        ? teams.map((e) => e.profile.teamId).toSet()
        : players.map((e) => e.profile.teamId).toSet();
    return matches
        .where(audience.includesMatch)
        .where(
          (m) =>
              ids.contains(m.homeTeam.apiFootballTeamId) ||
              ids.contains(m.awayTeam.apiFootballTeamId),
        )
        .toList();
  }

  RadarScope get scope => RadarScope(
    mode: mode,
    category: nationalTeams ? 'national' : 'club',
    capturedAt: capturedAt,
    sourceIds: sourceIds,
    includeWomen: audience.includeWomen,
    includeYouth: audience.includeYouth,
    teams: [
      for (var i = 0; i < teams.length; i++)
        RadarMember(
          id: '${teams[i].profile.teamId}',
          teamId: '${teams[i].profile.teamId}',
          rank: i + 1,
          matchIds: teams[i].profile.activity.reversed
              .take(5)
              .map((m) => '${m.fixtureId}')
              .toList()
              .reversed
              .toList(),
        ),
    ],
    players: [
      for (var i = 0; i < players.length; i++)
        RadarMember(
          id: '${players[i].profile.playerId}',
          teamId: '${players[i].profile.teamId}',
          rank: i + 1,
          matchIds: players[i].recentActivity
              .map((m) => '${m.fixtureId}')
              .toList(),
        ),
    ],
  );
}

List<PlayerFormRadarProfile> footballRadarPlayerProfiles(
  List<MatchBoardItem> matches,
) {
  final values = <String, PlayerFormRadarProfile>{};
  for (final match in matches) {
    for (final profile in match.analysis.playerFormRadarProfiles) {
      values.putIfAbsent(
        '${profile.leagueId}:${profile.teamId}:${profile.playerId}',
        () => profile,
      );
    }
  }
  return values.values.toList(growable: false);
}

List<TeamFormRadarProfile> footballRadarTeamProfiles(
  List<MatchBoardItem> matches,
) {
  final values = <String, TeamFormRadarProfile>{};
  for (final match in matches) {
    final leagueId = match.competition.apiFootballLeagueId;
    if (leagueId == null) continue;
    final knownTeams = <int, TeamInfo>{
      if (match.homeTeam.apiFootballTeamId != null)
        match.homeTeam.apiFootballTeamId!: match.homeTeam,
      if (match.awayTeam.apiFootballTeamId != null)
        match.awayTeam.apiFootballTeamId!: match.awayTeam,
    };
    final standingNames = <int, String>{
      for (final standing in match.analysis.leagueStandings)
        standing.teamId: standing.teamName,
    };
    for (final entry in match.analysis.leagueRecentLeagueMatches.entries) {
      final teamId = entry.key;
      final activity = entry.value;
      if (activity.isEmpty) continue;
      final ordered = [...activity]
        ..sort((left, right) {
          final leftDate =
              left.playedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final rightDate =
              right.playedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return leftDate.compareTo(rightDate);
        });
      final knownTeam = knownTeams[teamId];
      final name =
          knownTeam?.name ??
          standingNames[teamId] ??
          ordered
              .map((item) => item.teamName)
              .whereType<String>()
              .firstOrNull ??
          'Équipe';
      final logoUrl =
          knownTeam?.logoUrl ??
          ordered
              .map((item) => item.teamLogoUrl)
              .whereType<String>()
              .firstOrNull ??
          'https://media.api-sports.io/football/teams/$teamId.png';
      values.putIfAbsent(
        '$leagueId:$teamId',
        () => TeamFormRadarProfile(
          teamId: teamId,
          teamName: name,
          logoUrl: logoUrl,
          leagueId: leagueId,
          leagueName: match.competition.name,
          activity: ordered,
        ),
      );
    }
  }
  return values.values.toList(growable: false);
}
