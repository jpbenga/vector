import 'package:copilot/core/sports/domain/sport.dart';
import 'package:copilot/core/sports/domain/sport_module.dart';
import 'package:copilot/features/hockey/domain/hockey_analysis.dart';
import 'package:copilot/features/hockey/domain/hockey_reading_engine.dart';
import 'package:copilot/features/hockey/domain/hockey_rules.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:copilot/features/hockey/domain/hockey_standing_tiers.dart';

SportEntityId id(
  SportEntityKind kind,
  String value, {
  SportId sport = SportId.hockey,
}) => SportEntityId(sport: sport, provider: 'test', kind: kind, value: value);
final competition = id(SportEntityKind.competition, 'league');
final match = id(SportEntityKind.match, 'upcoming');
final cutoff = DateTime.utc(2026, 10, 4);
const engine = HockeyReadingEngine();

HockeyRecentGame game(
  int index,
  HockeyResult result, {
  SportEntityId? league,
  String season = '2026',
  DateTime? completedAt,
  bool? home = true,
}) => HockeyRecentGame(
  match: id(SportEntityKind.match, '$index'),
  competition: league ?? competition,
  season: season,
  completedAt: completedAt ?? cutoff.subtract(Duration(days: index + 1)),
  result: result,
  home: home,
);
HockeyTeamContext team(
  String name,
  List<HockeyRecentGame> games, {
  int points = 16,
  int played = 10,
  int? tier,
  int? rank,
  String group = 'league-overall',
  DateTime? standingAt,
}) => HockeyTeamContext(
  team: id(SportEntityKind.team, name),
  recentGames: games,
  standing: HockeyStanding(
    competition: competition,
    season: '2026',
    comparisonGroup: group,
    gamesPlayed: played,
    tier: tier ?? (name == 'home' ? 1 : 5),
    rank: rank ?? (name == 'home' ? 1 : 12),
    tierVersion: HockeyStandingTiers.version,
    points: points,
    asOf: standingAt ?? cutoff,
  ),
);
HockeyMatchContext context(
  HockeyTeamContext home,
  HockeyTeamContext away, {
  HockeyPointsRules rules = HockeyPointsRules.nhlRegularSeason,
  SportEntityId? matchId,
}) => HockeyMatchContext(
  match: matchId ?? match,
  competition: competition,
  season: '2026',
  startsAt: cutoff.add(const Duration(hours: 20)),
  asOf: cutoff,
  pointsRules: rules,
  home: home,
  away: away,
);
List<HockeyRecentGame> results(List<HockeyResult> values) => [
  for (final (index, result) in values.indexed) game(index, result),
];
SportReadingAssessment homeReading(
  List<SportReadingAssessment> readings,
  String key,
) => readings.firstWhere((r) => r.subject.value == 'home' && r.id == key);

void main() {
  test(
    'venue momentum requires both current runs and counts final overtime losses',
    () {
      final homeGames = [
        game(0, HockeyResult.regulationWin),
        game(1, HockeyResult.regulationLoss, home: false),
        game(2, HockeyResult.overtimeWin),
        game(3, HockeyResult.shootoutWin),
      ];
      final awayGames = [
        game(0, HockeyResult.overtimeLoss, home: false),
        game(1, HockeyResult.regulationWin),
        game(2, HockeyResult.regulationLoss, home: false),
        game(3, HockeyResult.shootoutLoss, home: false),
      ];
      final values = engine.analyze(
        context(team('home', homeGames), team('away', awayGames)),
      );
      expect(
        homeReading(values, 'strong_home_team').status,
        SportReadingStatus.detected,
      );
      expect(
        homeReading(values, 'home_away_advantage').status,
        SportReadingStatus.detected,
      );
      expect(
        values
            .firstWhere(
              (r) => r.subject.value == 'away' && r.id == 'weak_away_team',
            )
            .status,
        SportReadingStatus.detected,
      );
      final broken = engine.analyze(
        context(
          team('home', homeGames),
          team('away', [
            game(0, HockeyResult.regulationWin, home: false),
            ...awayGames.skip(1),
          ]),
        ),
      );
      expect(
        homeReading(broken, 'home_away_advantage').status,
        SportReadingStatus.notDetected,
      );
      final missing = engine.analyze(
        context(team('home', homeGames), team('away', [])),
      );
      expect(
        homeReading(missing, 'home_away_advantage').status,
        SportReadingStatus.insufficientData,
      );
      final unknownVenue = engine.analyze(
        context(
          team('home', [
            game(0, HockeyResult.regulationWin, home: null),
            ...homeGames,
          ]),
          team('away', awayGames),
        ),
      );
      expect(
        homeReading(unknownVenue, 'strong_home_team').status,
        SportReadingStatus.insufficientData,
      );
    },
  );
  test(
    'reverse venue advantage and season aggregates cannot override momentum',
    () {
      final values = engine.analyze(
        context(
          team('home', results(List.filled(3, HockeyResult.regulationLoss))),
          team('away', [
            for (var i = 0; i < 3; i++)
              game(i, HockeyResult.regulationWin, home: false),
          ]),
        ),
      );
      expect(
        values
            .firstWhere(
              (r) => r.subject.value == 'away' && r.id == 'away_home_advantage',
            )
            .status,
        SportReadingStatus.detected,
      );
      expect(
        homeReading(values, 'home_away_advantage').status,
        SportReadingStatus.notDetected,
      );
      expect(
        homeReading(values, 'strong_home_team').status,
        SportReadingStatus.notDetected,
      );
    },
  );

  test('dynamics do not mistake overtime points for final wins', () {
    final readings = engine.analyze(
      context(
        team(
          'home',
          results([
            HockeyResult.overtimeLoss,
            HockeyResult.regulationWin,
            HockeyResult.regulationWin,
            HockeyResult.regulationWin,
            HockeyResult.regulationWin,
          ]),
        ),
        team(
          'away',
          results(List.filled(5, HockeyResult.regulationLoss)),
          points: 0,
        ),
      ),
    );
    expect(
      homeReading(readings, 'positive_streak').status,
      SportReadingStatus.detected,
    );
    expect(
      homeReading(readings, 'winning_streak').status,
      SportReadingStatus.notDetected,
    );
    expect(
      readings
          .singleWhere(
            (r) => r.subject.value == 'away' && r.id == 'negative_streak',
          )
          .status,
      SportReadingStatus.detected,
    );
  });
  test(
    'form gap needs nine raw points in both two and three point leagues',
    () {
      for (final (rules, homeResults, awayResults) in [
        (
          HockeyPointsRules.nhlRegularSeason,
          List.filled(5, HockeyResult.regulationWin),
          [
            HockeyResult.overtimeLoss,
            ...List.filled(4, HockeyResult.regulationLoss),
          ],
        ),
        (
          HockeyPointsRules.threePointRegularSeason,
          [
            HockeyResult.regulationWin,
            HockeyResult.regulationWin,
            HockeyResult.regulationWin,
            HockeyResult.overtimeWin,
            HockeyResult.overtimeWin,
          ],
          [
            HockeyResult.regulationWin,
            HockeyResult.overtimeLoss,
            ...List.filled(3, HockeyResult.regulationLoss),
          ],
        ),
      ]) {
        final reading = homeReading(
          engine.analyze(
            context(
              team('home', results(homeResults)),
              team('away', results(awayResults), points: 4),
              rules: rules,
            ),
          ),
          'form_gap',
        );
        expect(reading.status, SportReadingStatus.detected);
        expect(reading.evidence['pointsGap'], 9);
      }
      final shortGap = homeReading(
        engine.analyze(
          context(
            team('home', results(List.filled(5, HockeyResult.regulationWin))),
            team(
              'away',
              results([
                HockeyResult.regulationWin,
                ...List.filled(4, HockeyResult.regulationLoss),
              ]),
              points: 2,
            ),
          ),
        ),
        'form_gap',
      );
      expect(shortGap.status, SportReadingStatus.notDetected);
    },
  );
  test('improving form compares latest two to previous three', () {
    final r = homeReading(
      engine.analyze(
        context(
          team(
            'home',
            results([
              HockeyResult.regulationWin,
              HockeyResult.regulationWin,
              ...List.filled(3, HockeyResult.regulationLoss),
            ]),
          ),
          team(
            'away',
            results(List.filled(5, HockeyResult.regulationLoss)),
            points: 0,
          ),
        ),
      ),
      'improving_form',
    );
    expect(r.status, SportReadingStatus.detected);
    expect(r.evidence['trend'], 2);
  });
  test(
    'series uses full history and three venue wins despite an away loss',
    () {
      final long = engine.analyze(
        context(
          team(
            'home',
            results([
              ...List.filled(8, HockeyResult.shootoutWin),
              HockeyResult.overtimeLoss,
            ]),
          ),
          team('away', []),
        ),
      );
      expect(
        homeReading(long, 'winning_streak').evidence['consecutiveWins'],
        8,
      );
      expect(homeReading(long, 'winning_streak').evidence['exact'], true);
      final venue = engine.analyze(
        context(
          team('home', [
            game(0, HockeyResult.regulationWin),
            game(1, HockeyResult.regulationLoss, home: false),
            game(2, HockeyResult.shootoutWin),
            game(3, HockeyResult.regulationLoss, home: false),
            game(4, HockeyResult.overtimeWin),
          ]),
          team('away', []),
        ),
      );
      expect(
        homeReading(venue, 'winning_streak').status,
        SportReadingStatus.notDetected,
      );
      expect(
        homeReading(venue, 'strong_home_team').status,
        SportReadingStatus.detected,
      );
      expect(
        homeReading(venue, 'strong_away_team').status,
        SportReadingStatus.notDetected,
      );
    },
  );

  test(
    'standings points follow explicit competition rules, including overtime losses',
    () {
      const nhl = HockeyPointsRules.nhlRegularSeason;
      const three = HockeyPointsRules.threePointRegularSeason;
      expect(nhl.points(HockeyResult.regulationWin), 2);
      expect(nhl.points(HockeyResult.overtimeLoss), 1);
      expect(nhl.points(HockeyResult.shootoutLoss), 1);
      expect(three.points(HockeyResult.regulationWin), 3);
      expect(three.points(HockeyResult.overtimeWin), 2);
      expect(three.points(HockeyResult.regulationLoss), 0);
    },
  );

  test(
    'compares complete windows and combines both advantages on the same team',
    () {
      final home = team(
        'home',
        results([
          HockeyResult.regulationWin,
          HockeyResult.overtimeWin,
          HockeyResult.shootoutWin,
          HockeyResult.regulationWin,
          HockeyResult.overtimeLoss,
        ]),
      );
      final away = team(
        'away',
        results([
          HockeyResult.regulationWin,
          HockeyResult.regulationWin,
          HockeyResult.regulationLoss,
          HockeyResult.regulationLoss,
          HockeyResult.regulationLoss,
        ]),
        points: 10,
      );
      final readings = engine.analyze(context(home, away));
      expect(
        homeReading(
          readings,
          'recent_form_advantage',
        ).evidence['percentageGap'],
        closeTo(.5, 1e-10),
      );
      expect(
        homeReading(readings, 'winning_streak').status,
        SportReadingStatus.detected,
      );
      expect(engine.scenarioSubjects(readings, match: match), {home.team});
      // The same scores have a different meaning under a three-point system.
      final threeReadings = engine.analyze(
        context(home, away, rules: HockeyPointsRules.threePointRegularSeason),
      );
      expect(
        homeReading(
          threeReadings,
          'recent_form_advantage',
        ).evidence['percentageGap'],
        closeTo(1 / 3, 1e-10),
      );
    },
  );

  test(
    'ignores future, duplicate, other-season and other-competition matches',
    () {
      final recent = game(1, HockeyResult.regulationWin);
      final home = team('home', [
        recent,
        recent,
        game(
          2,
          HockeyResult.regulationWin,
          league: id(SportEntityKind.competition, 'other'),
        ),
        game(3, HockeyResult.regulationWin, season: '2025'),
        game(
          4,
          HockeyResult.regulationWin,
          completedAt: cutoff.add(const Duration(hours: 1)),
        ),
      ]);
      final away = team(
        'away',
        results(List.filled(5, HockeyResult.regulationLoss)),
      );
      final readings = engine.analyze(context(home, away));
      expect(
        homeReading(readings, 'recent_form_advantage').status,
        SportReadingStatus.insufficientData,
      );
      expect(homeReading(readings, 'recent_form_advantage').sampleSize, 1);
      expect(engine.scenarioSubjects(readings, match: match), isEmpty);
    },
  );

  test(
    'does not compare unrelated standing groups or post-cutoff standings',
    () {
      final games = results(List.filled(5, HockeyResult.regulationWin));
      for (final away in [
        team('away', games, group: 'other-conference'),
        team('away', games, standingAt: cutoff.add(const Duration(hours: 1))),
      ]) {
        final readings = engine.analyze(context(team('home', games), away));
        expect(
          homeReading(readings, 'standing_advantage').status,
          SportReadingStatus.insufficientData,
        );
      }
    },
  );

  test(
    'scenario cannot join readings from other matches, sides or evaluation dates',
    () {
      final subject = id(SportEntityKind.team, 'home');
      SportReadingAssessment reading(
        String readingId,
        SportEntityId gameId,
        SportEntityId teamId,
        DateTime at,
      ) => SportReadingAssessment(
        id: readingId,
        subject: teamId,
        match: gameId,
        status: SportReadingStatus.detected,
        explanation: '',
        sampleSize: 5,
        asOf: at,
      );
      final ranking = reading('standing_advantage', match, subject, cutoff);
      for (final form in [
        reading(
          'recent_form_advantage',
          id(SportEntityKind.match, 'other'),
          subject,
          cutoff,
        ),
        reading(
          'recent_form_advantage',
          match,
          id(SportEntityKind.team, 'away'),
          cutoff,
        ),
        reading(
          'recent_form_advantage',
          match,
          subject,
          cutoff.subtract(const Duration(days: 1)),
        ),
      ]) {
        expect(engine.scenarioSubjects([ranking, form], match: match), isEmpty);
      }
    },
  );

  test(
    'rejects football contamination instead of using football data for hockey',
    () {
      final games = results(List.filled(5, HockeyResult.regulationWin));
      expect(
        () => engine.analyze(
          context(
            team('home', games),
            team('away', games),
            matchId: id(
              SportEntityKind.match,
              'upcoming',
              sport: SportId.football,
            ),
          ),
        ),
        throwsArgumentError,
      );
    },
  );

  test(
    'standing advantage requires tiers, five games and comparable samples',
    () {
      final games = results(List.filled(5, HockeyResult.regulationWin));
      for (final (home, away, expected) in [
        (
          team('home', games, points: 10, played: 5),
          team('away', games, points: 4, played: 5),
          SportReadingStatus.detected,
        ),
        (
          team('home', games),
          team('away', games, points: 10, tier: 1, rank: 2),
          SportReadingStatus.notDetected,
        ),
        (
          team('home', games),
          team('away', games, points: 10, played: 8),
          SportReadingStatus.insufficientData,
        ),
        (
          team('home', games, points: 8, played: 4),
          team('away', games, points: 4, played: 5),
          SportReadingStatus.insufficientData,
        ),
        (
          team('home', games, points: 16),
          team('away', games, points: 16),
          SportReadingStatus.notDetected,
        ),
      ]) {
        expect(
          homeReading(
            engine.analyze(context(home, away)),
            'standing_advantage',
          ).status,
          expected,
        );
      }
    },
  );
}
