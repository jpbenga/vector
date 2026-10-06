import 'package:copilot/core/domain/lector_head_to_head_policy.dart';
import 'package:copilot/core/sports/domain/sport.dart';
import 'package:copilot/core/sports/domain/sport_fixture.dart';
import 'package:copilot/core/sports/domain/sport_match_history.dart';
import 'package:copilot/core/sports/domain/sport_module.dart';
import 'package:copilot/features/hockey/domain/hockey_feed_readings.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../fixtures/sports/hockey_readings_fixture.dart';

SportHistoricalMatch meeting(
  String key,
  DateTime at, {
  bool won = true,
  String league = '35',
  String name = 'KHL Saison régulière',
  LectorMeetingKind kind = LectorMeetingKind.unknown,
  bool reversed = false,
}) => SportHistoricalMatch(
  competitionKind: kind,
  eventsCollected: false,
  events: const [],
  fixture: SportFixture(
    id: hockeyId(SportEntityKind.match, key),
    competition: hockeyId(SportEntityKind.competition, league),
    competitionName: name,
    season: '${at.year}',
    home: hockeyTeam(reversed ? 'Away' : 'Home'),
    away: hockeyTeam(reversed ? 'Home' : 'Away'),
    startsAt: at,
    status: SportFixtureStatus.finished,
    providerStatus: 'AOT',
    scores: {
      SportScoreScope.finalResult: SportScore(
        home: won != reversed ? 3 : 1,
        away: won != reversed ? 1 : 3,
      ),
    },
  ),
);
List<SportReadingAssessment> readings(List<SportHistoricalMatch> games) {
  final fixture = hockeyReadingFixture(
    headToHead: SportMatchHistory(collectedAt: readingCutoff, meetings: games),
  );
  return const HockeyFeedReadings()
      .evaluate(fixture, hockeyReadingSnapshot(fixture))
      .where(
        (r) => r.id == 'head_to_head_dominance' && r.subject == fixture.home.id,
      )
      .toList();
}

void main() {
  test(
    'three-year official scopes stay separate with final result and swapped venues',
    () {
      final games = [
        meeting('one', DateTime.utc(2026, 9, 25)),
        meeting('two', DateTime.utc(2025, 12, 1), reversed: true),
        meeting('three', DateTime.utc(2024, 11, 1)),
        meeting(
          'friendly',
          DateTime.utc(2026, 10, 1),
          won: false,
          league: '999',
          name: 'Club Friendlies',
        ),
        meeting(
          'cup',
          DateTime.utc(2026, 9, 26),
          won: false,
          league: '42',
          name: 'Champions Hockey League',
        ),
        meeting('old', DateTime.utc(2023, 10, 4), won: false),
        meeting('future', DateTime.utc(2026, 10, 7), won: false),
      ];
      final values = readings(games);
      expect(
        values
            .firstWhere((r) => r.evidence['competitionKind'] == 'league')
            .status,
        SportReadingStatus.detected,
      );
      expect(
        values.firstWhere((r) => r.evidence['competitionKind'] == 'cup').status,
        SportReadingStatus.insufficientData,
      );
      expect(
        values.first.evidence['meetingIds'],
        contains('hockey:api-hockey:match:two'),
      );
    },
  );
  test(
    'latest official loss breaks domination; cups and unknowns cannot fill league sample',
    () {
      final values = readings([
        meeting('one', DateTime.utc(2026, 9, 25), won: false),
        meeting('two', DateTime.utc(2025, 12, 1)),
        meeting('three', DateTime.utc(2024, 11, 1)),
      ]);
      expect(
        values
            .firstWhere((r) => r.evidence['competitionKind'] == 'league')
            .status,
        SportReadingStatus.notDetected,
      );
      final sparse = readings([
        meeting('one', DateTime.utc(2026, 9, 25)),
        meeting(
          'two',
          DateTime.utc(2025, 12, 1),
          league: '99',
          name: 'Unknown competition',
        ),
        meeting(
          'three',
          DateTime.utc(2024, 11, 1),
          league: '42',
          name: 'National Cup',
        ),
      ]);
      expect(
        sparse.every((r) => r.status == SportReadingStatus.insufficientData),
        true,
      );
    },
  );
  test(
    'unlabelled NHL preseason cannot manufacture three consecutive official wins',
    () {
      final values = readings([
        meeting(
          'preseason',
          DateTime.utc(2026, 9, 22),
          league: '57',
          name: 'NHL',
          kind: LectorMeetingKind.league,
        ),
        meeting(
          'official1',
          DateTime.utc(2025, 11, 25),
          league: '57',
          name: 'NHL',
        ),
        meeting(
          'official2',
          DateTime.utc(2026, 1, 13),
          league: '57',
          name: 'NHL',
        ),
      ]);
      expect(
        values
            .firstWhere((r) => r.evidence['competitionKind'] == 'league')
            .status,
        SportReadingStatus.insufficientData,
      );
      final complete = readings([
        meeting(
          'preseason',
          DateTime.utc(2026, 9, 22),
          league: '57',
          name: 'NHL',
          won: false,
        ),
        meeting(
          'official0',
          DateTime.utc(2025, 3, 17),
          league: '57',
          name: 'NHL',
        ),
        meeting(
          'official1',
          DateTime.utc(2025, 11, 25),
          league: '57',
          name: 'NHL',
        ),
        meeting(
          'official2',
          DateTime.utc(2026, 1, 13),
          league: '57',
          name: 'NHL',
        ),
      ]);
      expect(
        complete
            .firstWhere((r) => r.evidence['competitionKind'] == 'league')
            .status,
        SportReadingStatus.detected,
      );
    },
  );
  test(
    'calendar window uses UTC reference and excludes preseason regardless of casing',
    () {
      expect(
        LectorHeadToHeadPolicy.lowerBound(
          DateTime.parse('2026-10-05T20:00:00Z'),
        ),
        DateTime.utc(2023, 10, 5, 20),
      );
      expect(
        LectorHeadToHeadPolicy.classify(
          name: 'NHL Pre-Season',
          knownLeague: true,
        ),
        LectorMeetingKind.excluded,
      );
      expect(
        LectorHeadToHeadPolicy.classify(
          name: 'League',
          phase: 'Playoffs',
          knownLeague: true,
        ),
        LectorMeetingKind.cup,
      );
    },
  );
}
