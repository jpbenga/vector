import 'package:copilot/core/sports/domain/sport.dart';
import 'package:copilot/core/sports/domain/sport_module.dart';
import 'package:copilot/features/hockey/domain/hockey_analysis.dart';
import 'package:copilot/features/hockey/domain/hockey_reading_engine.dart';
import 'package:copilot/features/hockey/domain/hockey_rules.dart';
import 'package:flutter_test/flutter_test.dart';

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
}) => HockeyRecentGame(
  match: id(SportEntityKind.match, '$index'),
  competition: league ?? competition,
  season: season,
  completedAt: completedAt ?? cutoff.subtract(Duration(days: index + 1)),
  result: result,
);
HockeyTeamContext team(
  String name,
  List<HockeyRecentGame> games, {
  int points = 16,
  String group = 'league-overall',
  DateTime? standingAt,
}) => HockeyTeamContext(
  team: id(SportEntityKind.team, name),
  recentGames: games,
  standing: HockeyStanding(
    competition: competition,
    season: '2026',
    comparisonGroup: group,
    gamesPlayed: 10,
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
    'policy thresholds are configurable and exact boundaries are included',
    () {
      final home = team(
        'home',
        results(List.filled(5, HockeyResult.regulationWin)),
        points: 13,
      );
      final away = team(
        'away',
        results(List.filled(5, HockeyResult.regulationLoss)),
        points: 10,
      );
      expect(
        homeReading(
          engine.analyze(context(home, away)),
          'standing_advantage',
        ).status,
        SportReadingStatus.detected,
      );
      const strict = HockeyReadingEngine(
        policy: HockeyReadingPolicy(standingPercentageGap: .16),
      );
      expect(
        homeReading(
          strict.analyze(context(home, away)),
          'standing_advantage',
        ).status,
        SportReadingStatus.notDetected,
      );
    },
  );
}
