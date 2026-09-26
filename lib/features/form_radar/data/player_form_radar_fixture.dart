import '../../matches/domain/match_board_item.dart';
import '../domain/player_form_radar.dart';

/// Local-only data used to review the Radar interface before enriched server
/// snapshots exist. It is enabled only with `FORM_RADAR_FIXTURE=true` and is
/// never merged into the match feed or published to Supabase.
const bool formRadarFixtureEnabled = bool.fromEnvironment(
  'FORM_RADAR_FIXTURE',
  defaultValue: false,
);

final List<PlayerFormRadarProfile> _playerFormRadarFixtureProfiles = [
  _profile(
    playerId: 1,
    playerName: 'K. Mbappé',
    teamId: 541,
    teamName: 'Real Madrid',
    teamLogoUrl: 'https://media.api-sports.io/football/teams/541.png',
    photoUrl: 'https://media.api-sports.io/football/players/278.png',
    leagueId: 140,
    activity: [
      _match(1, 1, goals: 1),
      _match(2, 4),
      _match(3, 7, goals: 1),
      _match(4, 10, goals: 1),
      _match(5, 13, assists: 1),
      _match(6, 16, goals: 2),
      _match(7, 19, goals: 1),
    ],
  ),
  _profile(
    playerId: 2,
    playerName: 'M. Salah',
    teamId: 102,
    teamName: 'Liverpool',
    teamLogoUrl: 'https://media.api-sports.io/football/teams/40.png',
    photoUrl: 'https://media.api-sports.io/football/players/306.png',
    leagueId: 39,
    activity: [
      _match(11, 1, goals: 1),
      _match(12, 4, assists: 1),
      _match(13, 7),
      _match(14, 10, goals: 1),
      _match(15, 13, goals: 1),
      _match(16, 16),
      _match(17, 19, goals: 2),
    ],
  ),
  _profile(
    playerId: 3,
    playerName: 'V. Gyökeres',
    teamId: 103,
    teamName: 'Arsenal',
    teamLogoUrl: 'https://media.api-sports.io/football/teams/42.png',
    photoUrl: 'https://media.api-sports.io/football/players/19595.png',
    leagueId: 39,
    activity: [
      _match(21, 1),
      _match(22, 4, goals: 1),
      _match(23, 7),
      _match(24, 10, goals: 1),
      _match(25, 13, goals: 1),
      _match(26, 16, assists: 1),
      _match(27, 19, goals: 1),
    ],
  ),
  _profile(
    playerId: 4,
    playerName: 'J. Durán',
    teamId: 104,
    teamName: 'Al Nassr',
    teamLogoUrl: 'https://media.api-sports.io/football/teams/2344.png',
    photoUrl: 'https://media.api-sports.io/football/players/186245.png',
    leagueId: 307,
    activity: [
      _match(31, 1, appeared: false),
      _match(32, 4, substitute: true, minutes: 24),
      _match(33, 7, substitute: true, minutes: 18, goals: 1),
      _match(34, 10, substitute: true, minutes: 31, goals: 1),
      _match(35, 13, substitute: true, minutes: 21, assists: 1),
      _match(36, 16, substitute: true, minutes: 26, goals: 1),
      _match(37, 19, substitute: true, minutes: 29, goals: 1),
    ],
  ),
  _profile(
    playerId: 5,
    playerName: 'L. Yamal',
    teamId: 105,
    teamName: 'Barcelona',
    teamLogoUrl: 'https://media.api-sports.io/football/teams/529.png',
    photoUrl: 'https://media.api-sports.io/football/players/1100.png',
    leagueId: 140,
    activity: [
      _match(41, 1, assists: 1),
      _match(42, 4),
      _match(43, 7, goals: 1),
      _match(44, 10),
      _match(45, 13, assists: 1),
      _match(46, 16, goals: 1),
      _match(47, 19, assists: 1),
    ],
  ),
  _profile(
    playerId: 6,
    playerName: 'C. Pérez',
    teamId: 106,
    teamName: 'Girona',
    teamLogoUrl: 'https://media.api-sports.io/football/teams/547.png',
    photoUrl: 'https://media.api-sports.io/football/players/340.png',
    leagueId: 141,
    activity: [
      _match(51, 1),
      _match(52, 4, goals: 1),
      _match(53, 7, assists: 1),
      _match(54, 10),
      _match(55, 13, goals: 1),
      _match(56, 16),
      _match(57, 19, goals: 1),
    ],
  ),
];

/// A date-aware local fixture. Moving through the calendar deliberately
/// changes the displayed sample, while a future date keeps the last known
/// state. This exercises the same temporal contract as the server snapshots.
FormRadarFixtureSnapshot playerFormRadarFixtureForDate(DateTime selectedDate) {
  final day = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
  final lastKnownDay = DateTime(2026, 9, 25);
  if (day.isAfter(lastKnownDay)) {
    return FormRadarFixtureSnapshot(
      asOf: lastKnownDay.add(const Duration(hours: 22, minutes: 30)),
      profiles: _playerFormRadarFixtureProfiles,
    );
  }
  final profiles = day.day.isEven
      ? _playerFormRadarFixtureProfiles
      : _playerFormRadarFixtureProfiles
            .where((profile) => profile.playerId != 1)
            .toList(growable: false);
  return FormRadarFixtureSnapshot(
    asOf: day.add(const Duration(hours: 22, minutes: 30)),
    profiles: profiles,
  );
}

/// Makes the local Radar preview visible inside an existing match card without
/// mutating the match feed. The club identity always comes from that card;
/// only the player activity is illustrative.
List<PlayerFormRadarEntry> playerFormRadarFixtureEntriesForMatch(
  MatchBoardItem match,
) {
  if (!formRadarFixtureEnabled) return const [];
  final template =
      _playerFormRadarFixtureProfiles[(match.fixture.apiFootballFixtureId ??
              0) %
          _playerFormRadarFixtureProfiles.length];
  final team = match.homeTeam;
  final profile = PlayerFormRadarProfile(
    playerId: template.playerId,
    playerName: template.playerName,
    teamId: team.apiFootballTeamId ?? template.teamId,
    teamName: team.name,
    teamLogoUrl: team.logoUrl,
    photoUrl: template.photoUrl,
    leagueId: match.competition.apiFootballLeagueId ?? template.leagueId,
    activity: template.activity,
  );
  return PlayerFormRadarRanker.rank([profile]);
}

class FormRadarFixtureSnapshot {
  const FormRadarFixtureSnapshot({required this.asOf, required this.profiles});

  final DateTime asOf;
  final List<PlayerFormRadarProfile> profiles;
}

PlayerFormRadarProfile _profile({
  required int playerId,
  required String playerName,
  required int teamId,
  required String teamName,
  required int leagueId,
  required List<PlayerFormRadarMatchSnapshot> activity,
  String? photoUrl,
  String? teamLogoUrl,
}) => PlayerFormRadarProfile(
  playerId: playerId,
  playerName: playerName,
  teamId: teamId,
  teamName: teamName,
  leagueId: leagueId,
  photoUrl: photoUrl,
  teamLogoUrl: teamLogoUrl,
  activity: [
    for (final match in activity)
      PlayerFormRadarMatchSnapshot(
        fixtureId: match.fixtureId,
        playedAt: match.playedAt,
        appeared: match.appeared,
        starter: match.starter,
        substitute: match.substitute,
        minutes: match.minutes,
        goals: match.goals,
        assists: match.assists,
        competitionName: 'Championnat',
        round: 'Journée ${match.playedAt.day}',
        homeTeamName: teamName,
        homeTeamLogoUrl: teamLogoUrl,
        homeGoals: match.contributions > 0 ? match.contributions : 0,
        awayTeamName: 'Adversaire',
        awayGoals: match.contributions > 0 ? 0 : 1,
        actions: match.actions,
      ),
  ],
);

PlayerFormRadarMatchSnapshot _match(
  int fixtureId,
  int day, {
  bool appeared = true,
  bool substitute = false,
  int minutes = 90,
  int goals = 0,
  int assists = 0,
}) => PlayerFormRadarMatchSnapshot(
  fixtureId: fixtureId,
  playedAt: DateTime.utc(2026, 9, day),
  appeared: appeared,
  starter: appeared && !substitute,
  substitute: appeared && substitute,
  minutes: appeared ? minutes : 0,
  goals: goals,
  assists: assists,
  actions: [
    for (var index = 0; index < goals; index += 1)
      PlayerFormRadarActionSnapshot(
        minute: 25 + index * 19,
        kind: PlayerFormRadarActionKind.goal,
      ),
    for (var index = 0; index < assists; index += 1)
      PlayerFormRadarActionSnapshot(
        minute: 42 + index * 17,
        kind: PlayerFormRadarActionKind.assist,
      ),
  ],
);
