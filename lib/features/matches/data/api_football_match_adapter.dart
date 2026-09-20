import '../domain/match_board_item.dart';
import '../domain/odds_normalization.dart';
import '../../onboarding/domain/decision_profile_catalogs.dart';

class _FixtureOdds {
  const _FixtureOdds({
    required this.primaryMarket,
    required this.availableMarkets,
  });

  final MarketOdds primaryMarket;
  final List<MatchMarket> availableMarkets;
}

class _StandingAccumulator {
  final Map<int, _StandingAccumulatorRow> _rows = {};

  Iterable<TeamStandingSnapshot> get rows => _rows.values.map(
    (row) => TeamStandingSnapshot(
      teamId: row.teamId,
      teamName: row.teamName,
      points: row.wins * 3 + row.draws,
      played: row.played,
      wins: row.wins,
      draws: row.draws,
      losses: row.losses,
      goalsFor: row.goalsFor,
      goalsAgainst: row.goalsAgainst,
      goalDiff: row.goalsFor - row.goalsAgainst,
    ),
  );

  void addMatch({
    required int homeId,
    required String homeName,
    required int awayId,
    required String awayName,
    required int homeGoals,
    required int awayGoals,
  }) {
    final home = _rows.putIfAbsent(
      homeId,
      () => _StandingAccumulatorRow(teamId: homeId, teamName: homeName),
    );
    final away = _rows.putIfAbsent(
      awayId,
      () => _StandingAccumulatorRow(teamId: awayId, teamName: awayName),
    );
    home.played += 1;
    away.played += 1;
    home.goalsFor += homeGoals;
    home.goalsAgainst += awayGoals;
    away.goalsFor += awayGoals;
    away.goalsAgainst += homeGoals;
    if (homeGoals > awayGoals) {
      home.wins += 1;
      away.losses += 1;
    } else if (homeGoals < awayGoals) {
      away.wins += 1;
      home.losses += 1;
    } else {
      home.draws += 1;
      away.draws += 1;
    }
  }
}

class _StandingAccumulatorRow {
  _StandingAccumulatorRow({required this.teamId, required this.teamName});

  final int teamId;
  final String teamName;
  int played = 0;
  int wins = 0;
  int draws = 0;
  int losses = 0;
  int goalsFor = 0;
  int goalsAgainst = 0;
}

class _GoalProfileAccumulator {
  _GoalProfileAccumulator(this.teamId, this.teamName);
  final int teamId;
  final String teamName;
  int played = 0;
  int over25 = 0;
  int btts = 0;
  int totalGoals = 0;
  int halftimeLeads = 0;
  int retainedLeads = 0;
  int halftimeDeficits = 0;
  int recoveredDeficits = 0;

  TeamGoalProfileSnapshot snapshot() => TeamGoalProfileSnapshot(
    teamId: teamId,
    teamName: teamName,
    played: played,
    over25: over25,
    btts: btts,
    totalGoals: totalGoals,
    halftimeLeads: halftimeLeads,
    retainedLeads: retainedLeads,
    halftimeDeficits: halftimeDeficits,
    recoveredDeficits: recoveredDeficits,
  );
}

class ApiFootballMatchAdapter {
  const ApiFootballMatchAdapter();

  static const _bookmakerPriority = [16, 8, 4, 3, 11, 6];

  List<MatchBoardItem> fromSnapshot(Map<String, Object?> snapshot) {
    final raw = _map(snapshot['raw']);
    final capturedAt = _dateTimeValue(snapshot['captured_at']);
    final fixtures = _list(raw['fixtures']);
    final leagueFixtures = _list(raw['league_fixtures']);
    final oddsByFixtureId = _oddsByFixtureId(_list(raw['odds']));
    final expectedGoalsRows = _list(raw['expected_goals']);
    final standingTablesByLeagueId = _standingTablesByLeagueId(
      _list(raw['standings']),
      _list(raw['league_fixtures']),
      expectedGoalsRows,
      capturedAt,
    );
    final standingsByLeagueId = {
      for (final entry in standingTablesByLeagueId.entries)
        entry.key: entry.value[ChampionshipStandingView.general] ?? const [],
    };
    final standingsByLeagueTeamId = _standingsByLeagueTeamId(
      standingsByLeagueId,
    );
    final statisticsByLeagueTeamId = _statisticsByLeagueTeamId(
      _list(raw['team_statistics']),
    );
    final recentMatchesByLeagueTeamId = _recentLeagueMatchesByLeagueTeamId(
      _list(raw['recent_league_matches']),
    );
    final headToHeadByFixtureId = _headToHeadByFixtureId(
      _list(raw['head_to_head']),
    );
    final expectedGoalsByLeagueTeamId = _expectedGoalsByLeagueTeamId(
      _list(raw['expected_goals']),
      capturedAt,
    );
    final playerStatisticsByLeagueTeamId = _playerStatisticsByLeagueTeamId(
      _list(raw['player_statistics']),
    );
    final injuriesByFixtureId = _injuriesByFixtureId(_list(raw['injuries']));
    final performanceStatisticsByLeagueTeamId =
        _performanceStatisticsByLeagueTeamId(
          _list(raw['performance_statistics']),
        );
    final goalProfilesByLeagueTeamId = _goalProfilesByLeagueTeamId(
      leagueFixtures,
      capturedAt,
    );
    final domesticCompetitionByTeamId = _domesticCompetitionByTeamId(
      _list(raw['domestic_team_contexts']),
    );
    final containsPredictions = _list(raw['predictions']).isNotEmpty;
    final items = <MatchBoardItem>[];

    for (final fixtureJson in fixtures) {
      final item = _mapFixture(
        fixtureJson,
        oddsByFixtureId,
        standingsByLeagueId,
        standingTablesByLeagueId,
        standingsByLeagueTeamId,
        statisticsByLeagueTeamId,
        recentMatchesByLeagueTeamId,
        headToHeadByFixtureId,
        expectedGoalsByLeagueTeamId,
        playerStatisticsByLeagueTeamId,
        injuriesByFixtureId,
        performanceStatisticsByLeagueTeamId,
        goalProfilesByLeagueTeamId,
        domesticCompetitionByTeamId,
        leagueFixtures,
        capturedAt,
        containsPredictions,
      );
      if (item != null) {
        items.add(item);
      }
    }

    return items;
  }

  MatchBoardItem? _mapFixture(
    Object? fixtureJson,
    Map<int, _FixtureOdds> oddsByFixtureId,
    Map<int, List<TeamStandingSnapshot>> standingsByLeagueId,
    Map<int, Map<ChampionshipStandingView, List<TeamStandingSnapshot>>>
    standingTablesByLeagueId,
    Map<String, TeamStandingSnapshot> standingsByLeagueTeamId,
    Map<String, TeamStatisticsSnapshot> statisticsByLeagueTeamId,
    Map<String, List<TeamRecentMatchSnapshot>> recentMatchesByLeagueTeamId,
    Map<int, List<HeadToHeadFixtureSnapshot>> headToHeadByFixtureId,
    Map<String, TeamExpectedGoalsSnapshot> expectedGoalsByLeagueTeamId,
    Map<String, List<PlayerSeasonStatisticsSnapshot>>
    playerStatisticsByLeagueTeamId,
    Map<int, List<PlayerUnavailableSnapshot>> injuriesByFixtureId,
    Map<String, TeamPerformanceStatisticsSnapshot>
    performanceStatisticsByLeagueTeamId,
    Map<String, TeamGoalProfileSnapshot> goalProfilesByLeagueTeamId,
    Map<int, CompetitionInfo> domesticCompetitionByTeamId,
    List<Object?> leagueFixtures,
    DateTime? capturedAt,
    bool containsPredictions,
  ) {
    final root = _map(fixtureJson);
    final fixture = _map(root['fixture']);
    final league = _map(root['league']);
    final teams = _map(root['teams']);
    final homeTeam = _map(teams['home']);
    final awayTeam = _map(teams['away']);

    final apiFixtureId = _intValue(fixture['id']);
    final leagueId = _intValue(league['id']);
    final leagueName = _stringValue(league['name']);
    final leagueCountry = _stringValue(league['country']);
    final homeTeamId = _intValue(homeTeam['id']);
    final awayTeamId = _intValue(awayTeam['id']);
    final fixtureId = apiFixtureId == null
        ? _slug(
            '${_stringValue(homeTeam['name'])}-${_stringValue(awayTeam['name'])}',
          )
        : 'api-fixture-$apiFixtureId';
    final kickoff = _dateTimeValue(fixture['date']);
    final odds = apiFixtureId == null ? null : oddsByFixtureId[apiFixtureId];

    return MatchBoardItem(
      fixture: NormalizedFixture(
        id: fixtureId,
        apiFootballFixtureId: apiFixtureId,
        competition: CompetitionInfo(
          id: _competitionId(
            apiFootballLeagueId: leagueId,
            fallbackName: leagueName,
          ),
          name: leagueName ?? 'Compétition inconnue',
          country: CountryInfo(
            code: _countryCode(leagueCountry, leagueName),
            name: _localizedCountryName(leagueCountry, leagueName),
            flagUrl: _countryFlagUrl(
              leagueCountry,
              _stringValue(league['flag']),
            ),
          ),
          season: _intValue(league['season']) ?? kickoff?.year ?? 0,
          apiFootballLeagueId: leagueId,
          logoUrl: _stringValue(league['logo']),
        ),
        homeTeam: TeamInfo(
          id: _teamId(homeTeamId, _stringValue(homeTeam['name'])),
          name: _stringValue(homeTeam['name']) ?? 'Domicile',
          apiFootballTeamId: homeTeamId,
          logoUrl: _stringValue(homeTeam['logo']),
        ),
        awayTeam: TeamInfo(
          id: _teamId(awayTeamId, _stringValue(awayTeam['name'])),
          name: _stringValue(awayTeam['name']) ?? 'Extérieur',
          apiFootballTeamId: awayTeamId,
          logoUrl: _stringValue(awayTeam['logo']),
        ),
        kickoffLabel: _kickoffLabel(kickoff, _stringValue(fixture['date'])),
        round: _stringValue(league['round']),
        kickoff: kickoff,
        status: _fixtureStatus(_map(fixture['status'])['short']),
        score: _score(root),
        venue: _venue(fixture),
      ),
      primaryMarket:
          odds?.primaryMarket ??
          const MarketOdds(
            id: 'market_unavailable',
            label: 'Marché indisponible',
            odds: 0,
          ),
      availableMarkets: odds?.availableMarkets ?? const [],
      analysis: MatchAnalysisData(
        asOf: capturedAt,
        homeStanding: _standingFor(
          standingsByLeagueTeamId,
          leagueId,
          homeTeamId,
        ),
        awayStanding: _standingFor(
          standingsByLeagueTeamId,
          leagueId,
          awayTeamId,
        ),
        leagueStandings: leagueId == null
            ? const []
            : standingsByLeagueId[leagueId] ?? const [],
        standingTables: leagueId == null
            ? const {}
            : standingTablesByLeagueId[leagueId] ?? const {},
        homeStatistics: _statisticsFor(
          statisticsByLeagueTeamId,
          leagueId,
          homeTeamId,
        ),
        awayStatistics: _statisticsFor(
          statisticsByLeagueTeamId,
          leagueId,
          awayTeamId,
        ),
        leagueTeamStatistics: leagueId == null
            ? const []
            : List.unmodifiable(
                statisticsByLeagueTeamId.entries
                    .where((entry) => entry.key.startsWith('$leagueId:'))
                    .map((entry) => entry.value),
              ),
        homePerformanceStatistics: leagueId == null || homeTeamId == null
            ? null
            : performanceStatisticsByLeagueTeamId[_standingKey(
                leagueId,
                homeTeamId,
              )],
        awayPerformanceStatistics: leagueId == null || awayTeamId == null
            ? null
            : performanceStatisticsByLeagueTeamId[_standingKey(
                leagueId,
                awayTeamId,
              )],
        leaguePerformanceStatistics: leagueId == null
            ? const []
            : List.unmodifiable(
                performanceStatisticsByLeagueTeamId.entries
                    .where((entry) => entry.key.startsWith('$leagueId:'))
                    .map((entry) => entry.value),
              ),
        homeGoalProfile: leagueId == null || homeTeamId == null
            ? null
            : goalProfilesByLeagueTeamId[_standingKey(leagueId, homeTeamId)],
        awayGoalProfile: leagueId == null || awayTeamId == null
            ? null
            : goalProfilesByLeagueTeamId[_standingKey(leagueId, awayTeamId)],
        leagueGoalProfiles: leagueId == null
            ? const []
            : List.unmodifiable(
                goalProfilesByLeagueTeamId.entries
                    .where((entry) => entry.key.startsWith('$leagueId:'))
                    .map((entry) => entry.value),
              ),
        homeRecentLeagueMatches: _recentMatchesFor(
          recentMatchesByLeagueTeamId,
          leagueId,
          homeTeamId,
        ),
        awayRecentLeagueMatches: _recentMatchesFor(
          recentMatchesByLeagueTeamId,
          leagueId,
          awayTeamId,
        ),
        leagueRecentLeagueMatches: leagueId == null
            ? const {}
            : Map.unmodifiable({
                for (final entry in recentMatchesByLeagueTeamId.entries)
                  if (entry.key.startsWith('$leagueId:'))
                    int.parse(entry.key.split(':').last): entry.value,
              }),
        headToHeadMatches: apiFixtureId == null
            ? const []
            : headToHeadByFixtureId[apiFixtureId] ?? const [],
        homeExpectedGoals: homeTeamId == null || leagueId == null
            ? null
            : expectedGoalsByLeagueTeamId[_standingKey(leagueId, homeTeamId)],
        awayExpectedGoals: awayTeamId == null || leagueId == null
            ? null
            : expectedGoalsByLeagueTeamId[_standingKey(leagueId, awayTeamId)],
        leagueExpectedGoals: leagueId == null
            ? const []
            : List.unmodifiable(
                expectedGoalsByLeagueTeamId.entries
                    .where((entry) => entry.key.startsWith('$leagueId:'))
                    .map((entry) => entry.value),
              ),
        homePlayerStatistics: homeTeamId == null || leagueId == null
            ? const []
            : playerStatisticsByLeagueTeamId[_standingKey(
                    leagueId,
                    homeTeamId,
                  )] ??
                  const [],
        awayPlayerStatistics: awayTeamId == null || leagueId == null
            ? const []
            : playerStatisticsByLeagueTeamId[_standingKey(
                    leagueId,
                    awayTeamId,
                  )] ??
                  const [],
        leaguePlayerStatistics: leagueId == null
            ? const []
            : List.unmodifiable(
                playerStatisticsByLeagueTeamId.entries
                    .where((entry) => entry.key.startsWith('$leagueId:'))
                    .expand((entry) => entry.value),
              ),
        unavailablePlayers: apiFixtureId == null
            ? const []
            : injuriesByFixtureId[apiFixtureId] ?? const [],
        homeDomesticContext: _domesticContextFor(
          teamId: homeTeamId,
          competitions: domesticCompetitionByTeamId,
          standingsByLeagueId: standingsByLeagueId,
          standingTablesByLeagueId: standingTablesByLeagueId,
          standingsByLeagueTeamId: standingsByLeagueTeamId,
          statisticsByLeagueTeamId: statisticsByLeagueTeamId,
          recentMatchesByLeagueTeamId: recentMatchesByLeagueTeamId,
          expectedGoalsByLeagueTeamId: expectedGoalsByLeagueTeamId,
          playerStatisticsByLeagueTeamId: playerStatisticsByLeagueTeamId,
        ),
        awayDomesticContext: _domesticContextFor(
          teamId: awayTeamId,
          competitions: domesticCompetitionByTeamId,
          standingsByLeagueId: standingsByLeagueId,
          standingTablesByLeagueId: standingTablesByLeagueId,
          standingsByLeagueTeamId: standingsByLeagueTeamId,
          statisticsByLeagueTeamId: statisticsByLeagueTeamId,
          recentMatchesByLeagueTeamId: recentMatchesByLeagueTeamId,
          expectedGoalsByLeagueTeamId: expectedGoalsByLeagueTeamId,
          playerStatisticsByLeagueTeamId: playerStatisticsByLeagueTeamId,
        ),
        tournamentPaths:
            leagueId == null ||
                kickoff == null ||
                !const {2, 3, 848}.contains(leagueId)
            ? const []
            : _tournamentPaths(
                leagueId: leagueId,
                kickoff: kickoff,
                fixtures: leagueFixtures,
                standings: standingsByLeagueId[leagueId] ?? const [],
              ),
        containsPredictions: containsPredictions,
      ),
      compatibility: 0,
      signals: const [],
    );
  }

  List<TournamentPathSnapshot> _tournamentPaths({
    required int leagueId,
    required DateTime kickoff,
    required List<Object?> fixtures,
    required List<TeamStandingSnapshot> standings,
  }) {
    final standingByTeam = {for (final row in standings) row.teamId: row};
    final opponentPpgByTeam = <int, List<double>>{};
    final teamNames = <int, String>{};
    for (final fixtureJson in fixtures) {
      final root = _map(fixtureJson);
      if (_intValue(_map(root['league'])['id']) != leagueId) continue;
      final fixture = _map(root['fixture']);
      final playedAt = _dateTimeValue(fixture['date']);
      final status = _stringValue(_map(fixture['status'])['short']);
      if (playedAt == null ||
          !playedAt.isBefore(kickoff) ||
          !const {'FT', 'AET', 'PEN'}.contains(status)) {
        continue;
      }
      final teams = _map(root['teams']);
      final home = _map(teams['home']);
      final away = _map(teams['away']);
      final homeId = _intValue(home['id']);
      final awayId = _intValue(away['id']);
      if (homeId == null || awayId == null) continue;
      teamNames[homeId] = _stringValue(home['name']) ?? 'Équipe';
      teamNames[awayId] = _stringValue(away['name']) ?? 'Équipe';
      final homeOpponent = standingByTeam[awayId];
      final awayOpponent = standingByTeam[homeId];
      final homeOpponentPlayed = homeOpponent?.played;
      final awayOpponentPlayed = awayOpponent?.played;
      if (homeOpponent?.points != null &&
          homeOpponentPlayed != null &&
          homeOpponentPlayed > 0) {
        opponentPpgByTeam
            .putIfAbsent(homeId, () => [])
            .add(homeOpponent!.points! / homeOpponentPlayed);
      }
      if (awayOpponent?.points != null &&
          awayOpponentPlayed != null &&
          awayOpponentPlayed > 0) {
        opponentPpgByTeam
            .putIfAbsent(awayId, () => [])
            .add(awayOpponent!.points! / awayOpponentPlayed);
      }
    }
    return [
      for (final entry in opponentPpgByTeam.entries)
        if (entry.value.isNotEmpty)
          TournamentPathSnapshot(
            teamId: entry.key,
            teamName:
                teamNames[entry.key] ??
                standingByTeam[entry.key]?.teamName ??
                'Équipe',
            played: entry.value.length,
            averageOpponentPointsPerGame:
                entry.value.reduce((a, b) => a + b) / entry.value.length,
          ),
    ];
  }

  Map<int, CompetitionInfo> _domesticCompetitionByTeamId(List<Object?> rows) {
    final result = <int, CompetitionInfo>{};
    for (final row in rows) {
      final root = _map(row);
      final teamId =
          _intValue(_map(root['team'])['id']) ?? _intValue(root['team_id']);
      final league = _map(root['league']);
      final leagueId = _intValue(league['id']);
      if (teamId == null || leagueId == null) continue;
      final name = _stringValue(league['name']) ?? 'Championnat national';
      final country = _stringValue(league['country']);
      result[teamId] = CompetitionInfo(
        id: _competitionId(apiFootballLeagueId: leagueId, fallbackName: name),
        name: name,
        country: CountryInfo(
          code: _countryCode(country, name),
          name: _localizedCountryName(country, name),
          flagUrl: _countryFlagUrl(country, _stringValue(league['flag'])),
        ),
        season: _intValue(league['season']) ?? 0,
        apiFootballLeagueId: leagueId,
        logoUrl: _stringValue(league['logo']),
      );
    }
    return result;
  }

  TeamCompetitionContext? _domesticContextFor({
    required int? teamId,
    required Map<int, CompetitionInfo> competitions,
    required Map<int, List<TeamStandingSnapshot>> standingsByLeagueId,
    required Map<int, Map<ChampionshipStandingView, List<TeamStandingSnapshot>>>
    standingTablesByLeagueId,
    required Map<String, TeamStandingSnapshot> standingsByLeagueTeamId,
    required Map<String, TeamStatisticsSnapshot> statisticsByLeagueTeamId,
    required Map<String, List<TeamRecentMatchSnapshot>>
    recentMatchesByLeagueTeamId,
    required Map<String, TeamExpectedGoalsSnapshot> expectedGoalsByLeagueTeamId,
    required Map<String, List<PlayerSeasonStatisticsSnapshot>>
    playerStatisticsByLeagueTeamId,
  }) {
    if (teamId == null) return null;
    final competition = competitions[teamId];
    final leagueId = competition?.apiFootballLeagueId;
    if (competition == null || leagueId == null) return null;
    final key = _standingKey(leagueId, teamId);
    return TeamCompetitionContext(
      competition: competition,
      teamId: teamId,
      standing: standingsByLeagueTeamId[key],
      leagueStandings: standingsByLeagueId[leagueId] ?? const [],
      standingTables: standingTablesByLeagueId[leagueId] ?? const {},
      statistics: statisticsByLeagueTeamId[key],
      recentMatches: recentMatchesByLeagueTeamId[key] ?? const [],
      expectedGoals: expectedGoalsByLeagueTeamId[key],
      playerStatistics: playerStatisticsByLeagueTeamId[key] ?? const [],
    );
  }

  TeamStandingSnapshot? _standingFor(
    Map<String, TeamStandingSnapshot> standings,
    int? leagueId,
    int? teamId,
  ) {
    if (leagueId == null || teamId == null) {
      return null;
    }

    return standings[_standingKey(leagueId, teamId)];
  }

  TeamStatisticsSnapshot? _statisticsFor(
    Map<String, TeamStatisticsSnapshot> statistics,
    int? leagueId,
    int? teamId,
  ) {
    if (leagueId == null || teamId == null) {
      return null;
    }

    return statistics[_standingKey(leagueId, teamId)];
  }

  List<TeamRecentMatchSnapshot> _recentMatchesFor(
    Map<String, List<TeamRecentMatchSnapshot>> matches,
    int? leagueId,
    int? teamId,
  ) {
    if (leagueId == null || teamId == null) {
      return const [];
    }

    return matches[_standingKey(leagueId, teamId)] ?? const [];
  }

  Map<int, List<PlayerUnavailableSnapshot>> _injuriesByFixtureId(
    List<Object?> rows,
  ) {
    final grouped = <int, List<PlayerUnavailableSnapshot>>{};
    final seen = <String>{};
    for (final row in rows) {
      final root = _map(row);
      final fixtureId = _intValue(_map(root['fixture'])['id']);
      final teamId = _intValue(_map(root['team'])['id']);
      final player = _map(root['player']);
      final playerId = _intValue(player['id']);
      final name = _stringValue(player['name']);
      final type = _stringValue(player['type']);
      final asOf = _dateTimeValue(root['asOf']);
      if (fixtureId == null ||
          teamId == null ||
          playerId == null ||
          name == null ||
          asOf == null ||
          type != 'Missing Fixture' ||
          !seen.add('$fixtureId:$playerId')) {
        continue;
      }
      grouped
          .putIfAbsent(fixtureId, () => [])
          .add(
            PlayerUnavailableSnapshot(
              playerId: playerId,
              playerName: name,
              teamId: teamId,
              asOf: asOf,
              reason: _stringValue(player['reason']) ?? 'Absence signalée',
            ),
          );
    }
    return {
      for (final entry in grouped.entries)
        entry.key: List.unmodifiable(entry.value),
    };
  }

  Map<String, List<PlayerSeasonStatisticsSnapshot>>
  _playerStatisticsByLeagueTeamId(List<Object?> rows) {
    final grouped = <String, List<PlayerSeasonStatisticsSnapshot>>{};
    for (final row in rows) {
      final root = _map(row);
      final player = _map(root['player']);
      final playerId = _intValue(player['id']);
      final playerName = _stringValue(player['name']);
      if (playerId == null || playerName == null || playerName.isEmpty) {
        continue;
      }
      for (final statisticJson in _list(root['statistics'])) {
        final statistic = _map(statisticJson);
        final leagueId = _intValue(_map(statistic['league'])['id']);
        final team = _map(statistic['team']);
        final teamId = _intValue(team['id']);
        final teamName = _stringValue(team['name']);
        if (leagueId == null || teamId == null || teamName == null) continue;
        final games = _map(statistic['games']);
        final goals = _map(statistic['goals']);
        final shots = _map(statistic['shots']);
        final penalty = _map(statistic['penalty']);
        grouped
            .putIfAbsent(_standingKey(leagueId, teamId), () => [])
            .add(
              PlayerSeasonStatisticsSnapshot(
                playerId: playerId,
                playerName: playerName,
                teamId: teamId,
                teamName: teamName,
                appearances: _intValue(games['appearences']),
                lineups: _intValue(games['lineups']),
                minutes: _intValue(games['minutes']),
                goals: _intValue(goals['total']),
                assists: _intValue(goals['assists']),
                shots: _intValue(shots['total']),
                shotsOnTarget: _intValue(shots['on']),
                penaltyGoals: _intValue(penalty['scored']),
                penaltyMissed: _intValue(penalty['missed']),
              ),
            );
      }
    }
    return {
      for (final entry in grouped.entries)
        entry.key: List.unmodifiable(entry.value),
    };
  }

  Map<String, TeamPerformanceStatisticsSnapshot>
  _performanceStatisticsByLeagueTeamId(List<Object?> rows) {
    final result = <String, TeamPerformanceStatisticsSnapshot>{};
    for (final row in rows) {
      final root = _map(row);
      final leagueId = _intValue(_map(root['league'])['id']);
      final team = _map(root['team']);
      final teamId = _intValue(team['id']);
      final asOf = _dateTimeValue(root['asOf']);
      final sampleSize = _intValue(root['sampleSize']);
      if (leagueId == null ||
          teamId == null ||
          asOf == null ||
          sampleSize == null ||
          sampleSize <= 0) {
        continue;
      }
      final averages = _map(root['averages']);
      final cardTiming = _map(root['cardTiming']);
      result[_standingKey(
        leagueId,
        teamId,
      )] = TeamPerformanceStatisticsSnapshot(
        teamId: teamId,
        teamName: _stringValue(team['name']) ?? 'Équipe',
        asOf: asOf,
        sampleSize: sampleSize,
        shotsFor: _doubleValue(averages['shotsFor']),
        shotsAgainst: _doubleValue(averages['shotsAgainst']),
        shotsOnTargetFor: _doubleValue(averages['shotsOnTargetFor']),
        shotsOnTargetAgainst: _doubleValue(averages['shotsOnTargetAgainst']),
        cornersFor: _doubleValue(averages['cornersFor']),
        cornersAgainst: _doubleValue(averages['cornersAgainst']),
        cardsFor: _doubleValue(averages['cardsFor']),
        cardsAgainst: _doubleValue(averages['cardsAgainst']),
        totalCorners: _doubleValue(averages['totalCorners']),
        totalCards: _doubleValue(averages['totalCards']),
        secondHalfCardsShare: _doubleValue(cardTiming['secondHalfShare']),
        observedCards: _intValue(cardTiming['observedCards']),
      );
    }
    return result;
  }

  Map<String, TeamGoalProfileSnapshot> _goalProfilesByLeagueTeamId(
    List<Object?> fixtures,
    DateTime? capturedAt,
  ) {
    final rows = <String, _GoalProfileAccumulator>{};
    final seen = <int>{};
    for (final raw in fixtures) {
      final root = _map(raw);
      final fixture = _map(root['fixture']);
      final id = _intValue(fixture['id']);
      if (id != null && !seen.add(id)) continue;
      if (_stringValue(_map(fixture['status'])['short']) != 'FT') continue;
      final date = _dateTimeValue(fixture['date']);
      if (date != null && capturedAt != null && !date.isBefore(capturedAt)) {
        continue;
      }
      final leagueId = _intValue(_map(root['league'])['id']);
      final teams = _map(root['teams']);
      final home = _map(teams['home']);
      final away = _map(teams['away']);
      final homeId = _intValue(home['id']);
      final awayId = _intValue(away['id']);
      final fulltime = _map(_map(root['score'])['fulltime']);
      final halftime = _map(_map(root['score'])['halftime']);
      final goals = _map(root['goals']);
      final homeGoals = _intValue(fulltime['home']) ?? _intValue(goals['home']);
      final awayGoals = _intValue(fulltime['away']) ?? _intValue(goals['away']);
      if (leagueId == null ||
          homeId == null ||
          awayId == null ||
          homeGoals == null ||
          awayGoals == null) {
        continue;
      }
      final total = homeGoals + awayGoals;
      final halfHome = _intValue(halftime['home']);
      final halfAway = _intValue(halftime['away']);
      for (final team in [home, away]) {
        final teamId = _intValue(team['id'])!;
        final key = _standingKey(leagueId, teamId);
        final row = rows.putIfAbsent(
          key,
          () => _GoalProfileAccumulator(
            teamId,
            _stringValue(team['name']) ?? 'Équipe',
          ),
        );
        row.played += 1;
        if (total >= 3) row.over25 += 1;
        if (homeGoals > 0 && awayGoals > 0) row.btts += 1;
        row.totalGoals += total;
        if (halfHome != null && halfAway != null) {
          final isHome = teamId == homeId;
          final halfFor = isHome ? halfHome : halfAway;
          final halfAgainst = isHome ? halfAway : halfHome;
          final fullFor = isHome ? homeGoals : awayGoals;
          final fullAgainst = isHome ? awayGoals : homeGoals;
          if (halfFor > halfAgainst) {
            row.halftimeLeads += 1;
            if (fullFor > fullAgainst) row.retainedLeads += 1;
          } else if (halfFor < halfAgainst) {
            row.halftimeDeficits += 1;
            if (fullFor >= fullAgainst) row.recoveredDeficits += 1;
          }
        }
      }
    }
    return {
      for (final entry in rows.entries) entry.key: entry.value.snapshot(),
    };
  }

  Map<String, TeamStandingSnapshot> _standingsByLeagueTeamId(
    Map<int, List<TeamStandingSnapshot>> standingsByLeagueId,
  ) {
    final result = <String, TeamStandingSnapshot>{};

    for (final entry in standingsByLeagueId.entries) {
      for (final standing in entry.value) {
        result[_standingKey(entry.key, standing.teamId)] = standing;
      }
    }

    return result;
  }

  Map<int, Map<ChampionshipStandingView, List<TeamStandingSnapshot>>>
  _standingTablesByLeagueId(
    List<Object?> standingsRows,
    List<Object?> leagueFixtures,
    List<Object?> expectedGoalsRows,
    DateTime? capturedAt,
  ) {
    final result =
        <int, Map<ChampionshipStandingView, List<TeamStandingSnapshot>>>{};

    for (final row in standingsRows) {
      final league = _map(_map(row)['league']);
      final leagueId = _intValue(league['id']);
      if (leagueId == null) {
        continue;
      }

      final general = <TeamStandingSnapshot>[];
      final home = <TeamStandingSnapshot>[];
      final away = <TeamStandingSnapshot>[];
      final form = <TeamStandingSnapshot>[];
      for (final groupJson in _list(league['standings'])) {
        for (final standingJson in _list(groupJson)) {
          final generalStanding = _standingSnapshot(standingJson, 'all');
          final homeStanding = _standingSnapshot(standingJson, 'home');
          final awayStanding = _standingSnapshot(standingJson, 'away');
          final formStanding = _formStandingSnapshot(standingJson);
          if (generalStanding != null) general.add(generalStanding);
          if (homeStanding != null) home.add(homeStanding);
          if (awayStanding != null) away.add(awayStanding);
          if (formStanding != null) form.add(formStanding);
        }
      }

      general.sort((a, b) => (a.rank ?? 999).compareTo(b.rank ?? 999));
      final rankedGeneral = List<TeamStandingSnapshot>.unmodifiable(general);
      result[leagueId] = {
        ChampionshipStandingView.general: rankedGeneral,
        ChampionshipStandingView.home: _rankByPoints(home),
        ChampionshipStandingView.away: _rankByPoints(away),
        ChampionshipStandingView.form: _rankByPoints(form),
        ChampionshipStandingView.attack: _rankByAttack(rankedGeneral),
        ChampionshipStandingView.defense: _rankByDefense(rankedGeneral),
      };
    }

    final expectedGoalsByLeague = _expectedGoalsStandingsByLeagueId(
      expectedGoalsRows,
    );
    for (final entry in expectedGoalsByLeague.entries) {
      final tables = result.putIfAbsent(entry.key, () => {});
      tables[ChampionshipStandingView.expectedGoals] = entry.value;
    }

    final historical = _historicalStandingTables(
      leagueFixtures,
      capturedAt: capturedAt,
    );
    for (final entry in historical.entries) {
      final tables = result.putIfAbsent(entry.key, () => {});
      tables.addAll(entry.value);
    }

    return result;
  }

  TeamStandingSnapshot? _standingSnapshot(
    Object? standingJson,
    String segment,
  ) {
    final standing = _map(standingJson);
    final team = _map(standing['team']);
    final teamId = _intValue(team['id']);
    final teamName = _stringValue(team['name']);
    if (teamId == null) {
      return null;
    }

    final split = _map(standing[segment]);
    if (split.isEmpty) {
      return null;
    }
    final goals = _map(split['goals']);
    final wins = _intValue(split['win']);
    final draws = _intValue(split['draw']);

    return TeamStandingSnapshot(
      teamId: teamId,
      teamName: teamName ?? 'Équipe',
      group: _stringValue(standing['group']),
      description: segment == 'all'
          ? _stringValue(standing['description'])
          : null,
      rank: segment == 'all' ? _intValue(standing['rank']) : null,
      points: segment == 'all'
          ? _intValue(standing['points'])
          : wins == null || draws == null
          ? null
          : wins * 3 + draws,
      played: _intValue(split['played']),
      wins: wins,
      draws: draws,
      losses: _intValue(split['lose']),
      goalsFor: _intValue(goals['for']),
      goalsAgainst: _intValue(goals['against']),
      goalDiff: _intValue(standing['goalsDiff']),
      form: _stringValue(standing['form']),
    );
  }

  TeamStandingSnapshot? _formStandingSnapshot(Object? standingJson) {
    final standing = _map(standingJson);
    final team = _map(standing['team']);
    final teamId = _intValue(team['id']);
    if (teamId == null) return null;
    final results = (_stringValue(standing['form']) ?? '')
        .toUpperCase()
        .split('')
        .where((result) => const {'W', 'D', 'L'}.contains(result))
        .toList(growable: false);
    if (results.isEmpty) {
      return null;
    }
    final wins = results.where((result) => result == 'W').length;
    final draws = results.where((result) => result == 'D').length;
    final losses = results.where((result) => result == 'L').length;
    return TeamStandingSnapshot(
      teamId: teamId,
      teamName: _stringValue(team['name']) ?? 'Équipe',
      group: _stringValue(standing['group']),
      points: wins * 3 + draws,
      played: results.length,
      wins: wins,
      draws: draws,
      losses: losses,
      form: results.join(),
    );
  }

  List<TeamStandingSnapshot> _rankByPoints(
    Iterable<TeamStandingSnapshot> source,
  ) {
    final rows = [...source]
      ..sort((a, b) {
        final points = (b.points ?? -1).compareTo(a.points ?? -1);
        if (points != 0) return points;
        final difference = (b.goalDiff ?? -999).compareTo(a.goalDiff ?? -999);
        if (difference != 0) return difference;
        final goals = (b.goalsFor ?? -1).compareTo(a.goalsFor ?? -1);
        if (goals != 0) return goals;
        return a.teamName.compareTo(b.teamName);
      });
    return List.unmodifiable([
      for (final entry in rows.indexed) entry.$2.copyWith(rank: entry.$1 + 1),
    ]);
  }

  List<TeamStandingSnapshot> _rankByAttack(
    Iterable<TeamStandingSnapshot> source,
  ) {
    final rows = [...source]
      ..sort((a, b) {
        final goals = (b.goalsFor ?? -1).compareTo(a.goalsFor ?? -1);
        return goals != 0 ? goals : a.teamName.compareTo(b.teamName);
      });
    return List.unmodifiable([
      for (final entry in rows.indexed) entry.$2.copyWith(rank: entry.$1 + 1),
    ]);
  }

  List<TeamStandingSnapshot> _rankByDefense(
    Iterable<TeamStandingSnapshot> source,
  ) {
    final rows = [...source]
      ..sort((a, b) {
        final goals = (a.goalsAgainst ?? 999).compareTo(b.goalsAgainst ?? 999);
        return goals != 0 ? goals : a.teamName.compareTo(b.teamName);
      });
    return List.unmodifiable([
      for (final entry in rows.indexed) entry.$2.copyWith(rank: entry.$1 + 1),
    ]);
  }

  Map<int, List<TeamStandingSnapshot>> _expectedGoalsStandingsByLeagueId(
    List<Object?> rows,
  ) {
    final grouped = <int, List<TeamStandingSnapshot>>{};
    for (final row in rows) {
      final root = _map(row);
      final leagueId = _intValue(_map(root['league'])['id']);
      final team = _map(root['team']);
      final teamId = _intValue(team['id']);
      final value =
          _doubleValue(_map(root['season'])['xgForAverage']) ??
          _doubleValue(_map(root['rolling'])['xgFor5']);
      if (leagueId == null || teamId == null || value == null) {
        continue;
      }
      grouped
          .putIfAbsent(leagueId, () => [])
          .add(
            TeamStandingSnapshot(
              teamId: teamId,
              teamName: _stringValue(team['name']) ?? 'Équipe',
              played: _intValue(root['sampleSize']),
              metricValue: value,
              metricLabel: 'xG offensif',
            ),
          );
    }
    return {
      for (final entry in grouped.entries)
        entry.key: List.unmodifiable([
          for (final indexed
              in (entry.value..sort(
                    (a, b) =>
                        (b.metricValue ?? -1).compareTo(a.metricValue ?? -1),
                  ))
                  .indexed)
            indexed.$2.copyWith(rank: indexed.$1 + 1),
        ]),
    };
  }

  Map<int, Map<ChampionshipStandingView, List<TeamStandingSnapshot>>>
  _historicalStandingTables(
    List<Object?> fixtureRows, {
    required DateTime? capturedAt,
  }) {
    final rows = [...fixtureRows]
      ..sort((a, b) {
        final aDate = _dateTimeValue(_map(_map(a)['fixture'])['date']);
        final bDate = _dateTimeValue(_map(_map(b)['fixture'])['date']);
        return (aDate ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
          bDate ?? DateTime.fromMillisecondsSinceEpoch(0),
        );
      });
    final accumulators =
        <int, Map<ChampionshipStandingView, _StandingAccumulator>>{};
    final pairMeetings = <String, int>{};
    final seenFixtures = <int>{};

    _StandingAccumulator accumulator(
      int leagueId,
      ChampionshipStandingView view,
    ) {
      return accumulators
          .putIfAbsent(leagueId, () => {})
          .putIfAbsent(view, _StandingAccumulator.new);
    }

    for (final fixtureJson in rows) {
      final root = _map(fixtureJson);
      final fixture = _map(root['fixture']);
      final fixtureId = _intValue(fixture['id']);
      if (fixtureId != null && !seenFixtures.add(fixtureId)) continue;
      final date = _dateTimeValue(fixture['date']);
      if (date != null && capturedAt != null && !date.isBefore(capturedAt)) {
        continue;
      }
      final status = _stringValue(_map(fixture['status'])['short']);
      if (!const {'FT', 'AET', 'PEN'}.contains(status)) continue;

      final leagueId = _intValue(_map(root['league'])['id']);
      final teams = _map(root['teams']);
      final home = _map(teams['home']);
      final away = _map(teams['away']);
      final homeId = _intValue(home['id']);
      final awayId = _intValue(away['id']);
      if (leagueId == null || homeId == null || awayId == null) continue;
      final homeName = _stringValue(home['name']) ?? 'Équipe';
      final awayName = _stringValue(away['name']) ?? 'Équipe';
      final score = _map(root['score']);
      final fulltime = _map(score['fulltime']);
      final goals = _map(root['goals']);
      final homeGoals = _intValue(fulltime['home']) ?? _intValue(goals['home']);
      final awayGoals = _intValue(fulltime['away']) ?? _intValue(goals['away']);
      if (homeGoals == null || awayGoals == null) continue;

      final lowTeamId = homeId < awayId ? homeId : awayId;
      final highTeamId = homeId < awayId ? awayId : homeId;
      final pairKey = '$leagueId:$lowTeamId:$highTeamId';
      final meetingIndex = pairMeetings[pairKey] ?? 0;
      pairMeetings[pairKey] = meetingIndex + 1;
      if (meetingIndex < 2) {
        accumulator(
          leagueId,
          meetingIndex == 0
              ? ChampionshipStandingView.firstLeg
              : ChampionshipStandingView.secondLeg,
        ).addMatch(
          homeId: homeId,
          homeName: homeName,
          awayId: awayId,
          awayName: awayName,
          homeGoals: homeGoals,
          awayGoals: awayGoals,
        );
      }

      final halftime = _map(score['halftime']);
      final halftimeHome = _intValue(halftime['home']);
      final halftimeAway = _intValue(halftime['away']);
      if (halftimeHome == null || halftimeAway == null) continue;
      accumulator(leagueId, ChampionshipStandingView.firstHalf).addMatch(
        homeId: homeId,
        homeName: homeName,
        awayId: awayId,
        awayName: awayName,
        homeGoals: halftimeHome,
        awayGoals: halftimeAway,
      );
      accumulator(leagueId, ChampionshipStandingView.secondHalf).addMatch(
        homeId: homeId,
        homeName: homeName,
        awayId: awayId,
        awayName: awayName,
        homeGoals: homeGoals - halftimeHome,
        awayGoals: awayGoals - halftimeAway,
      );
    }

    return {
      for (final leagueEntry in accumulators.entries)
        leagueEntry.key: {
          for (final viewEntry in leagueEntry.value.entries)
            if (viewEntry.value.rows.isNotEmpty)
              viewEntry.key: _rankByPoints(viewEntry.value.rows),
        },
    };
  }

  Map<String, TeamStatisticsSnapshot> _statisticsByLeagueTeamId(
    List<Object?> statisticsRows,
  ) {
    final result = <String, TeamStatisticsSnapshot>{};

    for (final row in statisticsRows) {
      final root = _map(row);
      final leagueId = _intValue(_map(root['league'])['id']);
      final team = _map(root['team']);
      final teamId = _intValue(team['id']);
      final teamName = _stringValue(team['name']);
      if (leagueId == null || teamId == null) {
        continue;
      }

      final fixtures = _map(root['fixtures']);
      final wins = _map(fixtures['wins']);
      final draws = _map(fixtures['draws']);
      final losses = _map(fixtures['loses']);
      final goals = _map(root['goals']);
      final goalsFor = _map(goals['for']);
      final goalsAgainst = _map(goals['against']);
      final cleanSheets = _map(root['clean_sheet']);
      final failedToScore = _map(root['failed_to_score']);

      result[_standingKey(leagueId, teamId)] = TeamStatisticsSnapshot(
        teamId: teamId,
        teamName: teamName ?? 'Équipe',
        form: _stringValue(root['form']),
        playedTotal: _intValue(_map(fixtures['played'])['total']),
        playedHome: _intValue(_map(fixtures['played'])['home']),
        playedAway: _intValue(_map(fixtures['played'])['away']),
        winsTotal: _intValue(wins['total']),
        winsHome: _intValue(wins['home']),
        winsAway: _intValue(wins['away']),
        drawsTotal: _intValue(draws['total']),
        drawsHome: _intValue(draws['home']),
        drawsAway: _intValue(draws['away']),
        lossesTotal: _intValue(losses['total']),
        lossesHome: _intValue(losses['home']),
        lossesAway: _intValue(losses['away']),
        goalsForTotal: _intValue(_map(goalsFor['total'])['total']),
        goalsForHome: _intValue(_map(goalsFor['total'])['home']),
        goalsForAway: _intValue(_map(goalsFor['total'])['away']),
        goalsAgainstTotal: _intValue(_map(goalsAgainst['total'])['total']),
        goalsAgainstHome: _intValue(_map(goalsAgainst['total'])['home']),
        goalsAgainstAway: _intValue(_map(goalsAgainst['total'])['away']),
        goalsForAverageTotal: _doubleValue(_map(goalsFor['average'])['total']),
        goalsForAverageHome: _doubleValue(_map(goalsFor['average'])['home']),
        goalsForAverageAway: _doubleValue(_map(goalsFor['average'])['away']),
        goalsAgainstAverageTotal: _doubleValue(
          _map(goalsAgainst['average'])['total'],
        ),
        goalsAgainstAverageHome: _doubleValue(
          _map(goalsAgainst['average'])['home'],
        ),
        goalsAgainstAverageAway: _doubleValue(
          _map(goalsAgainst['average'])['away'],
        ),
        cleanSheetsTotal: _intValue(_map(cleanSheets)['total']),
        cleanSheetsHome: _intValue(_map(cleanSheets)['home']),
        cleanSheetsAway: _intValue(_map(cleanSheets)['away']),
        failedToScoreTotal: _intValue(_map(failedToScore)['total']),
        failedToScoreHome: _intValue(_map(failedToScore)['home']),
        failedToScoreAway: _intValue(_map(failedToScore)['away']),
        goalsForByMinute: _minuteGoalCounts(goalsFor['minute']),
        goalsAgainstByMinute: _minuteGoalCounts(goalsAgainst['minute']),
      );
    }

    return result;
  }

  Map<String, int> _minuteGoalCounts(Object? value) {
    final result = <String, int>{};
    for (final entry in _map(value).entries) {
      final total = _intValue(_map(entry.value)['total']);
      if (total != null) result[entry.key] = total;
    }
    return Map.unmodifiable(result);
  }

  Map<String, List<TeamRecentMatchSnapshot>> _recentLeagueMatchesByLeagueTeamId(
    List<Object?> recentRows,
  ) {
    final result = <String, List<TeamRecentMatchSnapshot>>{};

    for (final row in recentRows) {
      final root = _map(row);
      final leagueId =
          _intValue(_map(root['league'])['id']) ?? _intValue(root['leagueId']);
      final team = _map(root['team']);
      final teamId = _intValue(team['id']) ?? _intValue(root['teamId']);
      if (leagueId == null || teamId == null) {
        continue;
      }

      final matches = _list(root['matches'])
          .map(_recentMatchSnapshot)
          .whereType<TeamRecentMatchSnapshot>()
          .take(5)
          .toList(growable: false);
      result[_standingKey(leagueId, teamId)] = List.unmodifiable(matches);
    }

    return result;
  }

  Map<int, List<HeadToHeadFixtureSnapshot>> _headToHeadByFixtureId(
    List<Object?> rows,
  ) {
    final result = <int, List<HeadToHeadFixtureSnapshot>>{};
    for (final row in rows) {
      final root = _map(row);
      final fixtureId =
          _intValue(_map(root['fixture'])['id']) ??
          _intValue(root['fixtureId']);
      if (fixtureId == null) continue;

      final meetings =
          _list(root['matches'])
              .map(_headToHeadFixtureSnapshot)
              .whereType<HeadToHeadFixtureSnapshot>()
              .toList(growable: false)
            ..sort((left, right) => right.playedAt.compareTo(left.playedAt));
      result[fixtureId] = List.unmodifiable(meetings);
    }
    return result;
  }

  HeadToHeadFixtureSnapshot? _headToHeadFixtureSnapshot(Object? value) {
    final root = _map(value);
    final fixture = _map(root['fixture']);
    final league = _map(root['league']);
    final teams = _map(root['teams']);
    final home = _map(teams['home']);
    final away = _map(teams['away']);
    final goals = _map(root['goals']);
    final playedAt = _dateTimeValue(fixture['date']);
    final competitionId = _intValue(league['id']);
    final competitionName = _stringValue(league['name']);
    final homeTeamId = _intValue(home['id']);
    final homeTeamName = _stringValue(home['name']);
    final awayTeamId = _intValue(away['id']);
    final awayTeamName = _stringValue(away['name']);
    final homeGoals = _intValue(goals['home']);
    final awayGoals = _intValue(goals['away']);
    if (playedAt == null ||
        competitionId == null ||
        competitionName == null ||
        homeTeamId == null ||
        homeTeamName == null ||
        awayTeamId == null ||
        awayTeamName == null ||
        homeGoals == null ||
        awayGoals == null) {
      return null;
    }
    return HeadToHeadFixtureSnapshot(
      competitionId: competitionId,
      competitionName: competitionName,
      playedAt: playedAt,
      homeTeamId: homeTeamId,
      homeTeamName: homeTeamName,
      awayTeamId: awayTeamId,
      awayTeamName: awayTeamName,
      homeGoals: homeGoals,
      awayGoals: awayGoals,
    );
  }

  TeamRecentMatchSnapshot? _recentMatchSnapshot(Object? matchJson) {
    final root = _map(matchJson);
    final opponent = _map(root['opponent']);
    final opponentName =
        _stringValue(opponent['name']) ?? _stringValue(root['opponentName']);
    final venue = _recentMatchVenue(root['venue']);
    final result = _recentMatchResult(root);
    if (opponentName == null || venue == null || result == null) {
      return null;
    }

    final fixture = _map(root['fixture']);
    final goals = _map(root['goals']);
    return TeamRecentMatchSnapshot(
      playedAt: _dateTimeValue(fixture['date'] ?? root['date']),
      opponentTeamId:
          _intValue(opponent['id']) ?? _intValue(root['opponentId']),
      opponentName: opponentName,
      opponentLogoUrl:
          _stringValue(opponent['logo']) ?? _stringValue(root['opponentLogo']),
      venue: venue,
      result: result,
      goalsFor: _intValue(goals['for']) ?? _intValue(root['goalsFor']),
      goalsAgainst:
          _intValue(goals['against']) ?? _intValue(root['goalsAgainst']),
    );
  }

  RecentMatchVenue? _recentMatchVenue(Object? value) {
    return switch (_stringValue(value)?.trim().toLowerCase()) {
      'home' || 'domicile' || 'd' => RecentMatchVenue.home,
      'away' || 'extérieur' || 'exterieur' || 'e' => RecentMatchVenue.away,
      _ => null,
    };
  }

  String? _recentMatchResult(Map<String, Object?> root) {
    final explicit = _stringValue(root['result']);
    if (explicit != null) {
      return explicit;
    }

    final goals = _map(root['goals']);
    final goalsFor = _intValue(goals['for']) ?? _intValue(root['goalsFor']);
    final goalsAgainst =
        _intValue(goals['against']) ?? _intValue(root['goalsAgainst']);
    if (goalsFor == null || goalsAgainst == null) {
      return null;
    }
    if (goalsFor > goalsAgainst) {
      return 'W';
    }
    if (goalsFor == goalsAgainst) {
      return 'D';
    }
    return 'L';
  }

  Map<String, TeamExpectedGoalsSnapshot> _expectedGoalsByLeagueTeamId(
    List<Object?> rows,
    DateTime? capturedAt,
  ) {
    final result = <String, TeamExpectedGoalsSnapshot>{};
    final asOf = capturedAt ?? DateTime.now().toUtc();

    for (final row in rows) {
      final root = _map(row);
      final team = _map(root['team']);
      final teamId = _intValue(team['id']);
      final teamName = _stringValue(team['name']);
      final leagueId = _intValue(_map(root['league'])['id']);
      if (teamId == null || leagueId == null) {
        continue;
      }

      final rolling = _map(root['rolling']);
      final season = _map(root['season']);
      final latest = _map(root['latest']);
      result[_standingKey(leagueId, teamId)] = TeamExpectedGoalsSnapshot(
        teamId: teamId,
        teamName: teamName ?? 'Équipe',
        asOf: _dateTimeValue(root['asOf']) ?? asOf,
        sampleSize: _intValue(root['sampleSize']) ?? 0,
        rollingXgFor5: _doubleValue(rolling['xgFor5']),
        rollingXgAgainst5: _doubleValue(rolling['xgAgainst5']),
        seasonXgForAverage: _doubleValue(season['xgForAverage']),
        seasonXgAgainstAverage: _doubleValue(season['xgAgainstAverage']),
        goalsFor5: _intValue(rolling['goalsFor5']),
        goalsAgainst5: _intValue(rolling['goalsAgainst5']),
        latestMatchXgFor: _doubleValue(latest['xgFor']),
        latestMatchXgAgainst: _doubleValue(latest['xgAgainst']),
      );
    }

    return result;
  }

  String _standingKey(int leagueId, int teamId) => '$leagueId:$teamId';

  Map<int, _FixtureOdds> _oddsByFixtureId(List<Object?> oddsRows) {
    final result = <int, _FixtureOdds>{};

    for (final row in oddsRows) {
      final root = _map(row);
      final fixtureId = _intValue(_map(root['fixture'])['id']);
      if (fixtureId == null) {
        continue;
      }

      final odds = _fixtureOdds(_list(root['bookmakers']));
      if (odds != null) {
        result[fixtureId] = odds;
      }
    }

    return result;
  }

  _FixtureOdds? _fixtureOdds(List<Object?> bookmakers) {
    final sortedBookmakers = [...bookmakers]
      ..sort((a, b) {
        final aRank = _bookmakerRank(_intValue(_map(a)['id']));
        final bRank = _bookmakerRank(_intValue(_map(b)['id']));

        return aRank.compareTo(bRank);
      });

    final availableMarkets = _availableMarkets(sortedBookmakers);
    final primaryMarket = _firstSupportedMarket(availableMarkets);

    if (availableMarkets.isEmpty && primaryMarket == null) {
      return null;
    }

    return _FixtureOdds(
      primaryMarket:
          primaryMarket ??
          _marketSummaryOdds(availableMarkets.first) ??
          const MarketOdds(
            id: 'market_unavailable',
            label: 'Marché indisponible',
            odds: 0,
          ),
      availableMarkets: availableMarkets,
    );
  }

  List<MatchMarket> _availableMarkets(List<Object?> sortedBookmakers) {
    final markets = <String, MatchMarket>{};

    for (final bookmakerJson in sortedBookmakers) {
      final bookmaker = _map(bookmakerJson);
      final bookmakerId = _intValue(bookmaker['id']);
      final bookmakerName = _bookmakerName(bookmakerId, bookmaker);

      for (final betJson in _list(bookmaker['bets'])) {
        final bet = _map(betJson);
        final betId = _intValue(bet['id']);
        if (betId == null) {
          continue;
        }

        final marketMapping =
            OddsNormalizationCatalog.marketForApiFootballBetId(betId);
        if (marketMapping == null) {
          continue;
        }

        final marketId = marketMapping.internalId.name;
        if (markets.containsKey(marketId)) {
          continue;
        }

        final selections = <MarketOdds>[];

        for (final valueJson in _list(bet['values'])) {
          final value = _map(valueJson);
          final rawValue = _stringValue(value['value']);
          final selection = OddsNormalizationCatalog.normalizeSelection(
            apiFootballBetId: betId,
            rawValue: rawValue ?? '',
          );
          final odds = _doubleValue(value['odd']);
          if (rawValue == null || odds == null || selection == null) {
            continue;
          }

          selections.add(
            MarketOdds(
              id: selection.stableId,
              label: _marketSelectionLabel(marketMapping, rawValue),
              odds: odds,
              apiFootballBetId: betId,
              apiFootballValue: rawValue,
              playerName: selection.playerName,
              bookmakerId: bookmakerId,
              bookmakerName: bookmakerName,
            ),
          );
        }

        final orderedSelections = _orderedSelections(marketMapping, selections);
        if (orderedSelections.isEmpty ||
            !_hasRequiredSelections(marketMapping, orderedSelections)) {
          continue;
        }

        markets[marketId] = MatchMarket(
          id: marketId,
          label: marketMapping.displayName,
          selections: orderedSelections,
          apiFootballBetId: betId,
          bookmakerId: bookmakerId,
          bookmakerName: bookmakerName,
        );
      }
    }

    final values = markets.values.toList()
      ..sort((a, b) => _marketRank(a.id).compareTo(_marketRank(b.id)));

    return values;
  }

  MarketOdds? _firstSupportedMarket(List<MatchMarket> markets) {
    for (final market in markets) {
      if (market.id == InternalMarketId.matchResult.name) {
        continue;
      }

      final firstSelection = market.selections.firstOrNull;
      if (firstSelection == null) {
        continue;
      }

      return MarketOdds(
        id: market.id,
        label: _marketSummaryLabel(market),
        odds: firstSelection.odds,
        apiFootballBetId: market.apiFootballBetId,
        apiFootballValue: firstSelection.apiFootballValue,
        bookmakerId: market.bookmakerId,
        bookmakerName: market.bookmakerName,
      );
    }

    return null;
  }

  MarketOdds? _marketSummaryOdds(MatchMarket market) {
    final firstSelection = market.selections.firstOrNull;
    if (firstSelection == null) {
      return null;
    }

    return MarketOdds(
      id: market.id,
      label: _marketSummaryLabel(market),
      odds: firstSelection.odds,
      apiFootballBetId: market.apiFootballBetId,
      apiFootballValue: firstSelection.apiFootballValue,
      bookmakerId: market.bookmakerId,
      bookmakerName: market.bookmakerName,
    );
  }

  String _marketSummaryLabel(MatchMarket market) {
    if (market.bookmakerName == null || market.bookmakerName!.isEmpty) {
      return market.label;
    }

    return '${market.label} · ${market.bookmakerName}';
  }

  List<MarketOdds> _orderedSelections(
    MarketMapping market,
    List<MarketOdds> selections,
  ) {
    final ordered = [...selections]
      ..sort((a, b) {
        final aRank = _selectionRank(market, a.apiFootballValue);
        final bRank = _selectionRank(market, b.apiFootballValue);

        if (aRank != bRank) {
          return aRank.compareTo(bRank);
        }

        return a.label.compareTo(b.label);
      });

    return ordered;
  }

  bool _hasRequiredSelections(
    MarketMapping market,
    List<MarketOdds> selections,
  ) {
    if (market.internalId == InternalMarketId.matchResult) {
      final values = selections
          .map((selection) => selection.apiFootballValue?.toLowerCase())
          .toSet();

      return values.contains('home') &&
          values.contains('draw') &&
          values.contains('away');
    }

    return true;
  }

  int _marketRank(String marketId) {
    const order = [
      'matchResult',
      'doubleChance',
      'goalsTotal',
      'bothTeamsScore',
      'teamTotalHome',
      'teamTotalAway',
      'cornersTotal',
      'cardsTotal',
      'playerAnytimeScorer',
    ];
    final index = order.indexOf(marketId);

    return index == -1 ? order.length : index;
  }

  int _selectionRank(MarketMapping market, String? value) {
    final normalized = value?.toLowerCase();

    if (market.internalId == InternalMarketId.matchResult) {
      return switch (normalized) {
        'home' => 0,
        'draw' => 1,
        'away' => 2,
        _ => 99,
      };
    }

    if (market.internalId == InternalMarketId.doubleChance) {
      return switch (normalized) {
        'home/draw' => 0,
        'home/away' => 1,
        'draw/away' => 2,
        _ => 99,
      };
    }

    if (market.internalId == InternalMarketId.bothTeamsScore) {
      return switch (normalized) {
        'yes' => 0,
        'no' => 1,
        _ => 99,
      };
    }

    return 0;
  }

  String _marketSelectionLabel(MarketMapping market, String value) {
    if (market.internalId == InternalMarketId.doubleChance) {
      return switch (value) {
        'Home/Draw' => '1X',
        'Home/Away' => '12',
        'Draw/Away' => 'X2',
        _ => value,
      };
    }

    if (market.internalId == InternalMarketId.matchResult) {
      return _threeWaySelectionLabel(value);
    }

    return value;
  }

  String? _bookmakerName(int? bookmakerId, Map<String, Object?> bookmaker) {
    final bookmakerMapping = bookmakerId == null
        ? null
        : OddsNormalizationCatalog.bookmakerForApiFootballId(bookmakerId);

    return bookmakerMapping?.displayName ?? _stringValue(bookmaker['name']);
  }

  int _bookmakerRank(int? bookmakerId) {
    if (bookmakerId == null) {
      return _bookmakerPriority.length;
    }

    final index = _bookmakerPriority.indexOf(bookmakerId);
    if (index == -1) {
      return _bookmakerPriority.length;
    }

    return index;
  }

  FixtureScore? _score(Map<String, Object?> root) {
    final goals = _map(root['goals']);
    final home = _intValue(goals['home']);
    final away = _intValue(goals['away']);

    if (home == null || away == null) {
      return null;
    }

    return FixtureScore(home: home, away: away);
  }

  FixtureVenue? _venue(Map<String, Object?> fixture) {
    final venue = _map(fixture['venue']);
    final name = _stringValue(venue['name']);
    final city = _stringValue(venue['city']);

    if ((name == null || name.isEmpty) && (city == null || city.isEmpty)) {
      return null;
    }

    return FixtureVenue(name: name, city: city);
  }

  String _competitionId({
    required int? apiFootballLeagueId,
    required String? fallbackName,
  }) {
    final catalogDefinition = apiFootballLeagueId == null
        ? null
        : CompetitionCatalog.byApiFootballLeagueId(apiFootballLeagueId);

    return catalogDefinition?.id ?? _slug(fallbackName ?? 'competition');
  }

  String _teamId(int? apiFootballTeamId, String? fallbackName) {
    if (apiFootballTeamId != null) {
      return 'api-team-$apiFootballTeamId';
    }

    return _slug(fallbackName ?? 'team');
  }

  FixtureStatus _fixtureStatus(Object? status) {
    return switch (_stringValue(status)) {
      '1H' ||
      'HT' ||
      '2H' ||
      'ET' ||
      'BT' ||
      'P' ||
      'LIVE' ||
      'INT' => FixtureStatus.live,
      'FT' || 'AET' || 'PEN' => FixtureStatus.finished,
      'PST' => FixtureStatus.postponed,
      'CANC' || 'ABD' || 'AWD' || 'WO' => FixtureStatus.cancelled,
      _ => FixtureStatus.scheduled,
    };
  }

  String _countryCode(String? countryName, String? leagueName) {
    if (_isEuropeanCompetition(countryName, leagueName)) {
      return 'EU';
    }

    return switch (countryName) {
      'England' => 'GB-ENG',
      'France' => 'FR',
      'Portugal' => 'PT',
      'Italy' => 'IT',
      'Netherlands' => 'NL',
      _ => _slug(countryName ?? 'unknown').toUpperCase(),
    };
  }

  String _localizedCountryName(String? countryName, String? leagueName) {
    if (_isEuropeanCompetition(countryName, leagueName)) {
      return 'Europe';
    }

    return switch (countryName) {
      'England' => 'Angleterre',
      'Italy' => 'Italie',
      'Netherlands' => 'Pays-Bas',
      final name? when name.isNotEmpty => name,
      _ => 'International',
    };
  }

  String? _countryFlagUrl(String? countryName, String? flagUrl) {
    if (countryName == 'World') {
      return null;
    }

    return flagUrl;
  }

  bool _isEuropeanCompetition(String? countryName, String? leagueName) {
    if (countryName != 'World') {
      return false;
    }

    final normalizedLeagueName = (leagueName ?? '').toLowerCase();

    return normalizedLeagueName.contains('uefa') ||
        normalizedLeagueName.contains('champions league') ||
        normalizedLeagueName.contains('europa league') ||
        normalizedLeagueName.contains('conference league');
  }

  String _kickoffLabel(DateTime? kickoff, String? rawDate) {
    final rawTime = RegExp(r'T(\d{2}:\d{2})').firstMatch(rawDate ?? '');
    if (rawTime != null) {
      return rawTime.group(1)!;
    }

    final value = kickoff;
    if (value == null) {
      return rawDate ?? '--:--';
    }

    return '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }

  String _threeWaySelectionLabel(String value) {
    return switch (value.toLowerCase()) {
      'home' => 'Domicile',
      'draw' => 'Nul',
      'away' => 'Extérieur',
      _ => value,
    };
  }

  String _slug(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  Map<String, Object?> _map(Object? value) {
    if (value case final Map<String, Object?> map) {
      return map;
    }

    if (value case final Map<dynamic, dynamic> map) {
      return {
        for (final entry in map.entries)
          if (entry.key != null) entry.key.toString(): entry.value,
      };
    }

    return const {};
  }

  List<Object?> _list(Object? value) {
    if (value case final List<Object?> list) {
      return list;
    }

    if (value case final List<dynamic> list) {
      return list;
    }

    return const [];
  }

  int? _intValue(Object? value) {
    return switch (value) {
      final int number => number,
      final num number => number.toInt(),
      final String text => int.tryParse(text),
      _ => null,
    };
  }

  double? _doubleValue(Object? value) {
    return switch (value) {
      final double number => number,
      final num number => number.toDouble(),
      final String text => double.tryParse(text),
      _ => null,
    };
  }

  DateTime? _dateTimeValue(Object? value) {
    final text = _stringValue(value);
    if (text == null || text.isEmpty) {
      return null;
    }

    return DateTime.tryParse(text);
  }

  String? _stringValue(Object? value) {
    return switch (value) {
      final String text => text,
      final Object object => object.toString(),
      _ => null,
    };
  }
}
