import 'dart:convert';
import 'dart:io';

import 'package:copilot/features/matches/data/api_football_match_adapter.dart';
import 'package:copilot/features/matches/data/match_feed_repository.dart';
import 'package:copilot/features/matches/domain/match_board_item.dart';
import 'package:copilot/features/onboarding/domain/decision_profile.dart';
import 'package:copilot/features/onboarding/domain/onboarding_answer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ApiFootballMatchAdapter', () {
    test('maps fixture and odds snapshots to normalized match board items', () {
      final snapshot = _loadSnapshot();

      final matches = const ApiFootballMatchAdapter().fromSnapshot(snapshot);

      expect(matches, hasLength(2));

      final arsenal = matches.first;
      expect(arsenal.id, 'api-fixture-868160');
      expect(arsenal.fixture.apiFootballFixtureId, 868160);
      expect(arsenal.competition.id, '39');
      expect(arsenal.competition.country.name, 'Angleterre');
      expect(arsenal.homeTeam.apiFootballTeamId, 42);
      expect(arsenal.homeTeam.name, 'Arsenal');
      expect(arsenal.awayTeam.name, 'Everton');
      expect(arsenal.fixture.kickoffLabel, '16:00');
      expect(arsenal.fixture.round, isNull);
      expect(arsenal.fixture.status, FixtureStatus.scheduled);
      expect(arsenal.primaryMarket.label, 'Double chance · Bet365');
      expect(arsenal.primaryMarket.odds, 1.42);
      expect(arsenal.primaryMarket.bookmakerId, 8);
      expect(arsenal.availableMarkets, hasLength(1));
      expect(arsenal.defaultMarket?.id, 'doubleChance');
      expect(arsenal.defaultMarket?.selections.single.label, '1X');
      expect(arsenal.compatibility, 0);
      expect(arsenal.signals, isEmpty);
    });

    test('shows international friendlies only when a market is available', () {
      final noOdds = _internationalFriendlySnapshot();
      final withOdds = _internationalFriendlySnapshot(
        odds: [
          {
            'fixture': {'id': 10},
            'bookmakers': [
              {
                'id': 16,
                'name': 'Unibet',
                'bets': [
                  {
                    'id': 1,
                    'name': 'Match Winner',
                    'values': [
                      {'value': 'Home', 'odd': '1.90'},
                      {'value': 'Draw', 'odd': '3.20'},
                      {'value': 'Away', 'odd': '4.10'},
                    ],
                  },
                ],
              },
            ],
          },
        ],
      );

      expect(const ApiFootballMatchAdapter().fromSnapshot(noOdds), isEmpty);
      final matches = const ApiFootballMatchAdapter().fromSnapshot(withOdds);
      expect(matches, hasLength(1));
      expect(matches.single.competition.apiFootballLeagueId, 10);
      expect(matches.single.hasMatchResultMarket, isTrue);
    });

    test('keeps the provider round on the normalized fixture', () {
      final snapshot = {
        'raw': {
          'fixtures': [
            {
              'fixture': {
                'id': 27,
                'date': '2026-11-22T12:00:00+09:00',
                'status': {'short': 'NS'},
              },
              'league': {
                'id': 292,
                'name': 'K League 1',
                'country': 'South Korea',
                'season': 2026,
                'round': 'Regular Season - 27',
              },
              'teams': {
                'home': {'id': 10, 'name': 'Bucheon FC 1995'},
                'away': {'id': 11, 'name': 'Daejeon Citizen'},
              },
            },
          ],
          'odds': <Object?>[],
        },
      };

      final match = const ApiFootballMatchAdapter()
          .fromSnapshot(snapshot)
          .single;

      expect(match.fixture.round, 'Regular Season - 27');
    });

    test(
      'maps compact player Form Radar activity with match context and events',
      () {
        final snapshot = {
          'raw': {
            'fixtures': [
              {
                'fixture': {
                  'id': 91,
                  'date': '2026-09-25T20:45:00+02:00',
                  'status': {'short': 'NS'},
                },
                'league': {
                  'id': 39,
                  'name': 'Premier League',
                  'country': 'England',
                  'season': 2026,
                },
                'teams': {
                  'home': {'id': 42, 'name': 'Arsenal'},
                  'away': {'id': 43, 'name': 'Everton'},
                },
              },
            ],
            'odds': <Object?>[],
            'player_form_radar': [
              {
                'league': {'id': 39},
                'team': {
                  'id': 42,
                  'name': 'Arsenal',
                  'logo': 'https://example.test/arsenal.png',
                },
                'player': {
                  'id': 9,
                  'name': 'Joueur Radar',
                  'photo': 'https://example.test/player.png',
                },
                'activity': [
                  {
                    'fixture_id': 81,
                    'played_at': '2026-09-10T20:00:00+02:00',
                    'appeared': true,
                    'starter': false,
                    'substitute': true,
                    'minutes': 26,
                    'goals': 1,
                    'assists': 0,
                    'competition_name': 'Premier League',
                    'round': 'Regular Season - 5',
                    'home_team_name': 'Arsenal',
                    'home_goals': 2,
                    'away_team_name': 'Everton',
                    'away_goals': 1,
                    'actions': [
                      {'minute': 61, 'kind': 'goal'},
                    ],
                  },
                ],
              },
            ],
          },
        };

        final profile = const ApiFootballMatchAdapter()
            .fromSnapshot(snapshot)
            .single
            .analysis
            .playerFormRadarProfiles
            .single;

        expect(profile.playerName, 'Joueur Radar');
        expect(profile.activity.single.substitute, isTrue);
        expect(profile.activity.single.minutes, 26);
        expect(profile.activity.single.contributions, 1);
        expect(profile.activity.single.competitionName, 'Premier League');
        expect(profile.activity.single.homeTeamName, 'Arsenal');
        expect(profile.activity.single.homeGoals, 2);
        expect(profile.activity.single.actions.single.minute, 61);
        expect(profile.activity.single.actions.single.kind.name, 'goal');
        expect(profile.teamLogoUrl, 'https://example.test/arsenal.png');
      },
    );

    test('snapshot repository does not recommend matches without a thesis', () {
      final repository = const MatchFeedRepositoryFactory().create(
        MatchDataSourceMode.snapshot,
        snapshot: _loadSnapshot(),
      );
      const profile = DecisionProfile(
        onboardingVersion: 'test',
        answers: [
          OnboardingAnswer(
            questionId: 'competitions',
            orderedOptionIds: ['fr_ligue_1'],
          ),
          OnboardingAnswer(
            questionId: 'match_volume_preference',
            orderedOptionIds: [],
            scaleValue: 5,
          ),
        ],
      );

      final matches = repository.personalizedFor(profile);

      expect(matches, isEmpty);
    });

    test(
      'keeps competitions outside the official catalog as normalized slugs',
      () {
        final snapshot = {
          'raw': {
            'fixtures': [
              {
                'fixture': {
                  'id': 1,
                  'date': '2026-07-30T20:00:00+02:00',
                  'status': {'short': 'NS'},
                },
                'league': {
                  'id': 9999,
                  'name': 'UEFA Youth League',
                  'country': 'World',
                  'season': 2026,
                },
                'teams': {
                  'home': {'id': 10, 'name': 'Home'},
                  'away': {'id': 11, 'name': 'Away'},
                },
              },
            ],
            'odds': <Object?>[],
          },
        };

        final matches = const ApiFootballMatchAdapter().fromSnapshot(snapshot);

        expect(matches.single.competition.id, 'uefa_youth_league');
        expect(matches.single.competition.country.code, 'EU');
        expect(matches.single.competition.country.name, 'Europe');
        expect(matches.single.competition.country.flagUrl, isNull);
      },
    );

    test('prioritizes Unibet odds when supported bookmakers are available', () {
      final snapshot = {
        'raw': {
          'fixtures': [
            {
              'fixture': {
                'id': 1,
                'date': '2026-07-30T20:00:00+02:00',
                'status': {'short': 'NS'},
              },
              'league': {
                'id': 848,
                'name': 'UEFA Europa Conference League',
                'country': 'World',
                'season': 2026,
              },
              'teams': {
                'home': {'id': 10, 'name': 'Home'},
                'away': {'id': 11, 'name': 'Away'},
              },
            },
          ],
          'odds': [
            {
              'fixture': {'id': 1},
              'bookmakers': [
                {
                  'id': 8,
                  'name': 'Bet365',
                  'bets': [
                    {
                      'id': 12,
                      'name': 'Double Chance',
                      'values': [
                        {'value': 'Home/Draw', 'odd': '1.40'},
                      ],
                    },
                  ],
                },
                {
                  'id': 16,
                  'name': 'Unibet',
                  'bets': [
                    {
                      'id': 12,
                      'name': 'Double Chance',
                      'values': [
                        {'value': 'Home/Draw', 'odd': '1.44'},
                      ],
                    },
                  ],
                },
              ],
            },
          ],
        },
      };

      final matches = const ApiFootballMatchAdapter().fromSnapshot(snapshot);

      expect(matches.single.primaryMarket.bookmakerId, 16);
      expect(matches.single.primaryMarket.bookmakerName, 'Unibet');
      expect(matches.single.primaryMarket.label, 'Double chance · Unibet');
      expect(matches.single.primaryMarket.odds, 1.44);
      expect(matches.single.availableMarkets.single.id, 'doubleChance');
      expect(matches.single.availableMarkets.single.bookmakerId, 16);
      expect(
        matches.single.availableMarkets.single.selections.single.label,
        '1X',
      );
    });

    test('maps match winner odds as the default available market', () {
      final snapshot = {
        'raw': {
          'fixtures': [
            {
              'fixture': {
                'id': 1,
                'date': '2026-07-30T20:00:00+02:00',
                'status': {'short': 'NS'},
              },
              'league': {
                'id': 848,
                'name': 'UEFA Europa Conference League',
                'country': 'World',
                'season': 2026,
              },
              'teams': {
                'home': {'id': 10, 'name': 'Home'},
                'away': {'id': 11, 'name': 'Away'},
              },
            },
          ],
          'odds': [
            {
              'fixture': {'id': 1},
              'bookmakers': [
                {
                  'id': 8,
                  'name': 'Bet365',
                  'bets': [
                    {
                      'id': 1,
                      'name': 'Match Winner',
                      'values': [
                        {'value': 'Home', 'odd': '1.90'},
                        {'value': 'Draw', 'odd': '3.20'},
                        {'value': 'Away', 'odd': '4.10'},
                      ],
                    },
                  ],
                },
                {
                  'id': 16,
                  'name': 'Unibet',
                  'bets': [
                    {
                      'id': 1,
                      'name': 'Match Winner',
                      'values': [
                        {'value': 'Home', 'odd': '1.95'},
                        {'value': 'Draw', 'odd': '3.30'},
                        {'value': 'Away', 'odd': '4.20'},
                      ],
                    },
                  ],
                },
              ],
            },
          ],
        },
      };

      final match = const ApiFootballMatchAdapter()
          .fromSnapshot(snapshot)
          .single;

      expect(match.availableMarkets, hasLength(1));
      expect(match.hasMatchResultMarket, isTrue);
      expect(match.defaultMarket?.id, 'matchResult');
      expect(match.defaultMarket?.bookmakerId, 16);
      expect(match.defaultMarket?.bookmakerName, 'Unibet');
      expect(match.defaultMarket?.selections[0].label, 'Domicile');
      expect(match.defaultMarket?.selections[0].odds, 1.95);
      expect(match.defaultMarket?.selections[1].label, 'Nul');
      expect(match.defaultMarket?.selections[1].odds, 3.30);
      expect(match.defaultMarket?.selections[2].label, 'Extérieur');
      expect(match.defaultMarket?.selections[2].odds, 4.20);
      expect(match.primaryMarket.label, '1 N 2 · Unibet');
    });

    test('maps venue and standings snapshots into match analysis data', () {
      final snapshot = {
        'raw': {
          'fixtures': [
            {
              'fixture': {
                'id': 1,
                'date': '2026-07-30T20:00:00+02:00',
                'status': {'short': 'NS'},
                'venue': {'name': 'Stade Test', 'city': 'Paris'},
              },
              'league': {
                'id': 61,
                'name': 'Ligue 1',
                'country': 'France',
                'season': 2026,
              },
              'teams': {
                'home': {'id': 10, 'name': 'Home'},
                'away': {'id': 11, 'name': 'Away'},
              },
            },
          ],
          'odds': <Object?>[],
          'standings': [
            {
              'league': {
                'id': 61,
                'standings': [
                  [
                    {
                      'rank': 2,
                      'team': {'id': 10, 'name': 'Home'},
                      'points': 21,
                      'goalsDiff': 8,
                      'group': 'Ligue 1',
                      'description':
                          'Promotion - Champions League (Qualification)',
                      'form': 'WWDLW',
                      'all': {
                        'played': 10,
                        'win': 6,
                        'draw': 3,
                        'lose': 1,
                        'goals': {'for': 18, 'against': 10},
                      },
                    },
                    {
                      'rank': 8,
                      'team': {'id': 11, 'name': 'Away'},
                      'points': 14,
                      'goalsDiff': -2,
                      'group': 'Ligue 1',
                      'description': null,
                      'form': 'LDWDL',
                      'all': {
                        'played': 10,
                        'win': 4,
                        'draw': 2,
                        'lose': 4,
                        'goals': {'for': 12, 'against': 14},
                      },
                    },
                    {
                      'rank': 4,
                      'team': {'id': 12, 'name': 'Table Context'},
                      'points': 19,
                      'goalsDiff': 4,
                      'group': 'Ligue 1',
                      'description': 'Relegation Playoffs',
                      'form': 'WDDWL',
                      'all': {
                        'played': 10,
                        'win': 5,
                        'draw': 4,
                        'lose': 1,
                        'goals': {'for': 15, 'against': 11},
                      },
                    },
                  ],
                ],
              },
            },
          ],
          'team_statistics': [
            {
              'league': {'id': 61},
              'team': {'id': 10, 'name': 'Home'},
              'form': 'WWDWW',
              'fixtures': {
                'played': {'home': 5, 'away': 5, 'total': 10},
                'wins': {'home': 4, 'away': 2, 'total': 6},
                'draws': {'home': 1, 'away': 2, 'total': 3},
                'loses': {'home': 0, 'away': 1, 'total': 1},
              },
              'goals': {
                'for': {
                  'total': {'total': 18},
                  'average': {'total': '1.8'},
                },
                'against': {
                  'total': {'total': 10},
                  'average': {'total': '1.0'},
                },
              },
              'clean_sheet': {'total': 4},
              'failed_to_score': {'total': 1},
            },
            {
              'league': {'id': 61},
              'team': {'id': 11, 'name': 'Away'},
              'form': 'LDWDL',
              'fixtures': {
                'played': {'home': 5, 'away': 5, 'total': 10},
                'wins': {'home': 2, 'away': 2, 'total': 4},
                'draws': {'home': 1, 'away': 1, 'total': 2},
                'loses': {'home': 2, 'away': 2, 'total': 4},
              },
              'goals': {
                'for': {
                  'total': {'total': 12},
                  'average': {'total': '1.2'},
                },
                'against': {
                  'total': {'total': 14},
                  'average': {'total': '1.4'},
                },
              },
              'clean_sheet': {'total': 2},
              'failed_to_score': {'total': 3},
            },
          ],
          'recent_league_matches': [
            {
              'league': {'id': 61},
              'team': {'id': 10, 'name': 'Home'},
              'matches': [
                {
                  'opponent': {'id': 30, 'name': 'Recent Opponent'},
                  'venue': 'home',
                  'goals': {'for': 2, 'against': 1},
                },
              ],
            },
            {
              'league': {'id': 61},
              'team': {'id': 11, 'name': 'Away'},
              'matches': [
                {
                  'opponentName': 'Away Opponent',
                  'venue': 'away',
                  'result': 'D',
                  'goalsFor': 0,
                  'goalsAgainst': 0,
                },
              ],
            },
          ],
          'head_to_head': [
            {
              'fixture': {'id': 1},
              'matches': [
                {
                  'fixture': {'date': '2026-01-12T19:00:00Z'},
                  'league': {'id': 61, 'name': 'Ligue 1'},
                  'teams': {
                    'home': {'id': 10, 'name': 'Home'},
                    'away': {'id': 11, 'name': 'Away'},
                  },
                  'goals': {'home': 2, 'away': 1},
                },
                {
                  'fixture': {'date': '2025-12-04T19:00:00Z'},
                  'league': {'id': 66, 'name': 'Coupe de France'},
                  'teams': {
                    'home': {'id': 11, 'name': 'Away'},
                    'away': {'id': 10, 'name': 'Home'},
                  },
                  'goals': {'home': 0, 'away': 1},
                },
              ],
            },
          ],
        },
      };

      final match = const ApiFootballMatchAdapter()
          .fromSnapshot(snapshot)
          .single;

      expect(match.fixture.venue?.name, 'Stade Test');
      expect(match.fixture.venue?.city, 'Paris');
      expect(match.analysis.hasStandings, isTrue);
      expect(match.analysis.homeStanding?.rank, 2);
      expect(match.analysis.homeStanding?.points, 21);
      expect(match.analysis.homeStanding?.played, 10);
      expect(match.analysis.homeStanding?.wins, 6);
      expect(match.analysis.homeStanding?.draws, 3);
      expect(match.analysis.homeStanding?.losses, 1);
      expect(match.analysis.homeStanding?.goalsFor, 18);
      expect(match.analysis.homeStanding?.goalsAgainst, 10);
      expect(
        match.analysis.homeStanding?.description,
        'Promotion - Champions League (Qualification)',
      );
      expect(match.analysis.homeStanding?.form, 'WWDLW');
      expect(match.analysis.awayStanding?.rank, 8);
      expect(match.analysis.awayStanding?.goalDiff, -2);
      expect(match.analysis.awayStanding?.description, isNull);
      expect(match.analysis.leagueStandings, hasLength(3));
      expect(match.analysis.leagueStandings.map((standing) => standing.rank), [
        2,
        4,
        8,
      ]);
      expect(match.analysis.leagueStandings[1].teamName, 'Table Context');
      expect(
        match.analysis.leagueStandings[1].description,
        'Relegation Playoffs',
      );
      expect(match.analysis.hasStatistics, isTrue);
      expect(match.analysis.homeStatistics?.form, 'WWDWW');
      expect(match.analysis.homeStatistics?.playedTotal, 10);
      expect(match.analysis.homeStatistics?.goalsForAverageTotal, 1.8);
      expect(match.analysis.homeStatistics?.goalsAgainstAverageTotal, 1.0);
      expect(match.analysis.homeStatistics?.cleanSheetsTotal, 4);
      expect(match.analysis.awayStatistics?.failedToScoreTotal, 3);
      expect(match.analysis.homeRecentLeagueMatches, hasLength(1));
      expect(
        match.analysis.homeRecentLeagueMatches.single.opponentName,
        'Recent Opponent',
      );
      expect(
        match.analysis.homeRecentLeagueMatches.single.venue,
        RecentMatchVenue.home,
      );
      expect(match.analysis.homeRecentLeagueMatches.single.result, 'W');
      expect(
        match.analysis.awayRecentLeagueMatches.single.opponentName,
        'Away Opponent',
      );
      expect(match.analysis.awayRecentLeagueMatches.single.result, 'D');
      expect(match.analysis.hasHeadToHead, isTrue);
      expect(match.analysis.headToHeadMatches, hasLength(2));
      expect(match.analysis.headToHeadMatches.first.competitionName, 'Ligue 1');
      expect(match.analysis.headToHeadMatches.first.homeGoals, 2);
    });

    test('maps snapshot asOf, home-away splits and expected-goals context', () {
      final snapshot = {
        'captured_at': '2026-07-30T08:00:00Z',
        'raw': {
          'fixtures': [
            {
              'fixture': {
                'id': 1,
                'date': '2026-07-30T20:00:00+02:00',
                'status': {'short': 'NS'},
              },
              'league': {
                'id': 39,
                'name': 'Premier League',
                'country': 'England',
                'season': 2026,
              },
              'teams': {
                'home': {'id': 10, 'name': 'Home'},
                'away': {'id': 11, 'name': 'Away'},
              },
            },
          ],
          'odds': <Object?>[],
          'team_statistics': [
            {
              'league': {'id': 39},
              'team': {'id': 10, 'name': 'Home'},
              'fixtures': {
                'played': {'total': 10, 'home': 5, 'away': 5},
                'wins': {'total': 7, 'home': 4, 'away': 3},
                'draws': {'total': 2, 'home': 1, 'away': 1},
                'loses': {'total': 1, 'home': 0, 'away': 1},
              },
              'goals': {
                'for': {
                  'total': {'total': 20, 'home': 12, 'away': 8},
                  'average': {'total': '2.00', 'home': '2.40', 'away': '1.60'},
                  'minute': {
                    '0-15': {'total': 4, 'percentage': '20.00%'},
                    '76-90': {'total': 6, 'percentage': '30.00%'},
                  },
                },
                'against': {
                  'total': {'total': 8, 'home': 3, 'away': 5},
                  'average': {'total': '0.80', 'home': '0.60', 'away': '1.00'},
                  'minute': {
                    '0-15': {'total': 1, 'percentage': '12.50%'},
                  },
                },
              },
              'clean_sheet': {'total': 5, 'home': 3, 'away': 2},
              'failed_to_score': {'total': 1, 'home': 0, 'away': 1},
            },
          ],
          'expected_goals': [
            {
              'league': {'id': 39},
              'team': {'id': 10, 'name': 'Home'},
              'asOf': '2026-07-30T08:00:00Z',
              'sampleSize': 5,
              'rolling': {
                'xgFor5': 1.82,
                'xgAgainst5': 0.88,
                'goalsFor5': 6,
                'goalsAgainst5': 5,
              },
              'season': {'xgForAverage': 1.66, 'xgAgainstAverage': 1.02},
            },
          ],
        },
      };

      final match = const ApiFootballMatchAdapter()
          .fromSnapshot(snapshot)
          .single;

      expect(match.analysis.asOf, DateTime.utc(2026, 7, 30, 8));
      expect(match.analysis.homeStatistics?.winsHome, 4);
      expect(match.analysis.homeStatistics?.goalsForAverageHome, 2.40);
      expect(match.analysis.homeStatistics?.cleanSheetsAway, 2);
      expect(match.analysis.homeStatistics?.goalsForByMinute['0-15'], 4);
      expect(match.analysis.homeStatistics?.goalsAgainstByMinute['0-15'], 1);
      expect(match.analysis.leagueTeamStatistics, hasLength(1));
      expect(match.analysis.homeExpectedGoals?.rollingXgFor5, 1.82);
      expect(match.analysis.homeExpectedGoals?.rollingXgAgainst5, 0.88);
      expect(
        match.analysis.homeExpectedGoals?.goalsMinusXgFor5,
        closeTo(-3.10, 0.001),
      );
      expect(
        match
            .analysis
            .standingTables[ChampionshipStandingView.expectedGoals]
            ?.single
            .metricValue,
        1.66,
      );
    });

    test(
      'builds dynamic standing views from split and historical fixtures',
      () {
        final snapshot = {
          'captured_at': '2026-09-01T00:00:00Z',
          'raw': {
            'fixtures': [
              {
                'fixture': {
                  'id': 300,
                  'date': '2026-09-10T20:00:00Z',
                  'status': {'short': 'NS'},
                },
                'league': {'id': 61, 'name': 'Ligue 1', 'country': 'France'},
                'teams': {
                  'home': {'id': 10, 'name': 'Home'},
                  'away': {'id': 11, 'name': 'Away'},
                },
              },
            ],
            'odds': <Object?>[],
            'standings': [
              {
                'league': {
                  'id': 61,
                  'standings': [
                    [
                      {
                        'rank': 1,
                        'team': {'id': 10, 'name': 'Home'},
                        'points': 9,
                        'goalsDiff': 5,
                        'all': {
                          'played': 4,
                          'win': 3,
                          'draw': 0,
                          'lose': 1,
                          'goals': {'for': 8, 'against': 3},
                        },
                        'home': {
                          'played': 2,
                          'win': 2,
                          'draw': 0,
                          'lose': 0,
                          'goals': {'for': 5, 'against': 1},
                        },
                        'away': {
                          'played': 2,
                          'win': 1,
                          'draw': 0,
                          'lose': 1,
                          'goals': {'for': 3, 'against': 2},
                        },
                        'form': 'WWLW',
                      },
                      {
                        'rank': 2,
                        'team': {'id': 11, 'name': 'Away'},
                        'points': 7,
                        'goalsDiff': 1,
                        'all': {
                          'played': 4,
                          'win': 2,
                          'draw': 1,
                          'lose': 1,
                          'goals': {'for': 6, 'against': 5},
                        },
                        'home': {
                          'played': 2,
                          'win': 1,
                          'draw': 1,
                          'lose': 0,
                          'goals': {'for': 3, 'against': 1},
                        },
                        'away': {
                          'played': 2,
                          'win': 1,
                          'draw': 0,
                          'lose': 1,
                          'goals': {'for': 3, 'against': 4},
                        },
                        'form': 'WDDL',
                      },
                    ],
                  ],
                },
              },
            ],
            'league_fixtures': [
              {
                'fixture': {
                  'id': 100,
                  'date': '2026-08-01T18:00:00Z',
                  'status': {'short': 'FT'},
                },
                'league': {'id': 61},
                'teams': {
                  'home': {'id': 10, 'name': 'Home'},
                  'away': {'id': 11, 'name': 'Away'},
                },
                'goals': {'home': 1, 'away': 0},
                'score': {
                  'halftime': {'home': 1, 'away': 0},
                  'fulltime': {'home': 1, 'away': 0},
                },
              },
              {
                'fixture': {
                  'id': 101,
                  'date': '2026-08-20T18:00:00Z',
                  'status': {'short': 'FT'},
                },
                'league': {'id': 61},
                'teams': {
                  'home': {'id': 11, 'name': 'Away'},
                  'away': {'id': 10, 'name': 'Home'},
                },
                'goals': {'home': 2, 'away': 2},
                'score': {
                  'halftime': {'home': 0, 'away': 1},
                  'fulltime': {'home': 2, 'away': 2},
                },
              },
            ],
          },
        };

        final match = const ApiFootballMatchAdapter()
            .fromSnapshot(snapshot)
            .single;
        final tables = match.analysis.standingTables;

        expect(tables[ChampionshipStandingView.home]!.first.teamId, 10);
        expect(tables[ChampionshipStandingView.away]!.first.teamId, 10);
        expect(tables[ChampionshipStandingView.form]!.first.teamId, 10);
        expect(tables[ChampionshipStandingView.firstLeg], hasLength(2));
        expect(tables[ChampionshipStandingView.secondLeg], hasLength(2));
        expect(tables[ChampionshipStandingView.firstHalf], hasLength(2));
        expect(tables[ChampionshipStandingView.secondHalf], hasLength(2));
        expect(match.analysis.homeGoalProfile?.played, 2);
        expect(match.analysis.homeGoalProfile?.over25, 1);
        expect(match.analysis.homeGoalProfile?.btts, 1);
        expect(match.analysis.leagueGoalProfiles, hasLength(2));
      },
    );

    test('maps domestic contexts without replacing the UEFA table', () {
      Map<String, Object?> standing({
        required int id,
        required String name,
        required int rank,
        required int played,
      }) => {
        'rank': rank,
        'team': {'id': id, 'name': name},
        'points': rank == 1 ? 15 : 4,
        'form': rank == 1 ? 'WWWWW' : 'LLLDD',
        'all': {
          'played': played,
          'win': rank == 1 ? 5 : 1,
          'draw': 1,
          'lose': rank == 1 ? 0 : 4,
          'goals': {'for': rank == 1 ? 15 : 4, 'against': rank == 1 ? 3 : 12},
        },
      };

      final domesticTable = [
        standing(id: 10, name: 'Home', rank: 1, played: 6),
        for (var id = 100; id < 109; id += 1)
          standing(id: id, name: 'D$id', rank: id - 98, played: 6),
      ];
      final snapshot = <String, Object?>{
        'captured_at': '2026-09-15T08:00:00Z',
        'raw': {
          'fixtures': [
            {
              'fixture': {
                'id': 900,
                'date': '2026-09-16T20:00:00Z',
                'status': {'short': 'NS'},
              },
              'league': {
                'id': 2,
                'name': 'UEFA Champions League',
                'country': 'World',
                'season': 2026,
              },
              'teams': {
                'home': {'id': 10, 'name': 'Home'},
                'away': {'id': 11, 'name': 'Away'},
              },
            },
          ],
          'standings': [
            {
              'league': {
                'id': 2,
                'name': 'UEFA Champions League',
                'country': 'World',
                'season': 2026,
                'standings': [
                  [
                    standing(id: 10, name: 'Home', rank: 3, played: 2),
                    standing(id: 11, name: 'Away', rank: 18, played: 2),
                  ],
                ],
              },
            },
            {
              'league': {
                'id': 39,
                'name': 'Premier League',
                'country': 'England',
                'season': 2026,
                'standings': [domesticTable],
              },
            },
          ],
          'domestic_team_contexts': [
            {
              'team': {'id': 10, 'name': 'Home'},
              'league': {
                'id': 39,
                'name': 'Premier League',
                'country': 'England',
                'season': 2026,
              },
            },
          ],
          'league_fixtures': [
            {
              'fixture': {
                'id': 899,
                'date': '2026-09-01T20:00:00Z',
                'status': {'short': 'FT'},
              },
              'league': {'id': 2, 'season': 2026},
              'teams': {
                'home': {'id': 10, 'name': 'Home'},
                'away': {'id': 11, 'name': 'Away'},
              },
              'goals': {'home': 1, 'away': 0},
            },
          ],
          'odds': <Object?>[],
        },
      };

      final match = const ApiFootballMatchAdapter()
          .fromSnapshot(snapshot)
          .single;

      expect(match.analysis.homeStanding?.rank, 3);
      expect(match.analysis.homeDomesticContext?.standing?.rank, 1);
      expect(
        match.analysis.homeDomesticContext?.competition.name,
        'Premier League',
      );
      expect(match.analysis.awayDomesticContext, isNull);
      expect(match.analysis.tournamentPaths, hasLength(2));
      expect(
        match.analysis.tournamentPaths
            .singleWhere((path) => path.teamId == 10)
            .played,
        1,
      );
    });
  });
}

Map<String, Object?> _internationalFriendlySnapshot({
  List<Object?> odds = const [],
}) => {
  'raw': {
    'fixtures': [
      {
        'fixture': {
          'id': 10,
          'date': '2026-10-10T20:45:00+02:00',
          'status': {'short': 'NS'},
        },
        'league': {
          'id': 10,
          'name': 'Friendlies',
          'country': 'World',
          'season': 2026,
        },
        'teams': {
          'home': {'id': 1, 'name': 'France'},
          'away': {'id': 2, 'name': 'Brésil'},
        },
      },
    ],
    'odds': odds,
  },
};

Map<String, Object?> _loadSnapshot() {
  final file = File('assets/snapshots/api_football_match_feed_v1.json');
  final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

  return Map<String, Object?>.from(json);
}
