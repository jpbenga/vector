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

class ApiFootballMatchAdapter {
  const ApiFootballMatchAdapter();

  static const _bookmakerPriority = [16, 8, 4, 3, 11, 6];

  List<MatchBoardItem> fromSnapshot(Map<String, Object?> snapshot) {
    final raw = _map(snapshot['raw']);
    final capturedAt = _dateTimeValue(snapshot['captured_at']);
    final fixtures = _list(raw['fixtures']);
    final oddsByFixtureId = _oddsByFixtureId(_list(raw['odds']));
    final standingsByLeagueId = _standingsByLeagueId(_list(raw['standings']));
    final standingsByLeagueTeamId = _standingsByLeagueTeamId(
      _list(raw['standings']),
    );
    final statisticsByLeagueTeamId = _statisticsByLeagueTeamId(
      _list(raw['team_statistics']),
    );
    final recentMatchesByLeagueTeamId = _recentLeagueMatchesByLeagueTeamId(
      _list(raw['recent_league_matches']),
    );
    final expectedGoalsByTeamId = _expectedGoalsByTeamId(
      _list(raw['expected_goals']),
      capturedAt,
    );
    final containsPredictions = _list(raw['predictions']).isNotEmpty;
    final items = <MatchBoardItem>[];

    for (final fixtureJson in fixtures) {
      final item = _mapFixture(
        fixtureJson,
        oddsByFixtureId,
        standingsByLeagueId,
        standingsByLeagueTeamId,
        statisticsByLeagueTeamId,
        recentMatchesByLeagueTeamId,
        expectedGoalsByTeamId,
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
    Map<String, TeamStandingSnapshot> standingsByLeagueTeamId,
    Map<String, TeamStatisticsSnapshot> statisticsByLeagueTeamId,
    Map<String, List<TeamRecentMatchSnapshot>> recentMatchesByLeagueTeamId,
    Map<int, TeamExpectedGoalsSnapshot> expectedGoalsByTeamId,
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
        homeExpectedGoals: homeTeamId == null
            ? null
            : expectedGoalsByTeamId[homeTeamId],
        awayExpectedGoals: awayTeamId == null
            ? null
            : expectedGoalsByTeamId[awayTeamId],
        containsPredictions: containsPredictions,
      ),
      compatibility: 0,
      signals: const [],
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

  Map<String, TeamStandingSnapshot> _standingsByLeagueTeamId(
    List<Object?> standingsRows,
  ) {
    final result = <String, TeamStandingSnapshot>{};

    for (final row in standingsRows) {
      final league = _map(_map(row)['league']);
      final leagueId = _intValue(league['id']);
      if (leagueId == null) {
        continue;
      }

      for (final groupJson in _list(league['standings'])) {
        for (final standingJson in _list(groupJson)) {
          final standing = _standingSnapshot(standingJson);
          if (standing != null) {
            result[_standingKey(leagueId, standing.teamId)] = standing;
          }
        }
      }
    }

    return result;
  }

  Map<int, List<TeamStandingSnapshot>> _standingsByLeagueId(
    List<Object?> standingsRows,
  ) {
    final result = <int, List<TeamStandingSnapshot>>{};

    for (final row in standingsRows) {
      final league = _map(_map(row)['league']);
      final leagueId = _intValue(league['id']);
      if (leagueId == null) {
        continue;
      }

      final leagueStandings = <TeamStandingSnapshot>[];
      for (final groupJson in _list(league['standings'])) {
        for (final standingJson in _list(groupJson)) {
          final standing = _standingSnapshot(standingJson);
          if (standing != null) {
            leagueStandings.add(standing);
          }
        }
      }

      leagueStandings.sort((a, b) {
        final aRank = a.rank ?? 999;
        final bRank = b.rank ?? 999;
        return aRank.compareTo(bRank);
      });
      result[leagueId] = List.unmodifiable(leagueStandings);
    }

    return result;
  }

  TeamStandingSnapshot? _standingSnapshot(Object? standingJson) {
    final standing = _map(standingJson);
    final team = _map(standing['team']);
    final teamId = _intValue(team['id']);
    final teamName = _stringValue(team['name']);
    if (teamId == null) {
      return null;
    }

    final all = _map(standing['all']);
    final goals = _map(all['goals']);

    return TeamStandingSnapshot(
      teamId: teamId,
      teamName: teamName ?? 'Équipe',
      group: _stringValue(standing['group']),
      rank: _intValue(standing['rank']),
      points: _intValue(standing['points']),
      played: _intValue(all['played']),
      wins: _intValue(all['win']),
      draws: _intValue(all['draw']),
      losses: _intValue(all['lose']),
      goalsFor: _intValue(goals['for']),
      goalsAgainst: _intValue(goals['against']),
      goalDiff: _intValue(standing['goalsDiff']),
      form: _stringValue(standing['form']),
    );
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
      );
    }

    return result;
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

    final goals = _map(root['goals']);
    return TeamRecentMatchSnapshot(
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

  Map<int, TeamExpectedGoalsSnapshot> _expectedGoalsByTeamId(
    List<Object?> rows,
    DateTime? capturedAt,
  ) {
    final result = <int, TeamExpectedGoalsSnapshot>{};
    final asOf = capturedAt ?? DateTime.now().toUtc();

    for (final row in rows) {
      final root = _map(row);
      final team = _map(root['team']);
      final teamId = _intValue(team['id']);
      final teamName = _stringValue(team['name']);
      if (teamId == null) {
        continue;
      }

      final rolling = _map(root['rolling']);
      final season = _map(root['season']);
      final latest = _map(root['latest']);
      result[teamId] = TeamExpectedGoalsSnapshot(
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
