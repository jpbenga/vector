import 'package:copilot/core/sports/domain/sport.dart';
import 'package:copilot/core/sports/domain/sport_competition_context.dart';
import 'package:copilot/core/sports/domain/sport_fixture.dart';
import 'package:copilot/core/sports/domain/sport_module.dart';
import 'package:copilot/core/sports/domain/sport_reading_preferences.dart';
import 'package:copilot/features/hockey/domain/hockey_feed_readings.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../fixtures/sports/hockey_readings_fixture.dart';

void main() {
  const adapter = HockeyFeedReadings();
  final fixture = hockeyReadingFixture();
  final snapshot = hockeyReadingSnapshot(fixture);
  SportReadingPreferences preferences({
    Iterable<String>? competitions,
    Iterable<String>? readings,
  }) => SportReadingPreferences(
    sport: SportId.hockey,
    competitionKeys: competitions ?? [fixture.competition.key],
    readingIds: readings ?? HockeyFeedReadings.readingIds,
  );
  SportReadingAssessment home(List<SportReadingAssessment> values, String id) =>
      values.firstWhere((r) => r.id == id && r.subject == fixture.home.id);

  test('venue series uses complete season history beyond the last five', () {
    final history = [
      for (var i = 0; i < 9; i++)
        SportFormResult(
          matchId: hockeyId(SportEntityKind.match, 'full-$i'),
          startsAt: readingCutoff.subtract(Duration(days: 9 - i)),
          opponent: 'Opponent',
          home: i.isEven,
          scored: i == 0 ? 1 : 3,
          conceded: i == 0 ? 3 : 1,
          outcome: i == 0 ? SportFormOutcome.loss : SportFormOutcome.win,
          providerStatus: 'FT',
        ),
    ];
    final f = hockeyReadingFixture(homeForm: history.skip(4).toList());
    final rows = commonTable().rows;
    final full = SportStandingTable(
      stage: 'Regular Season',
      group: 'Conference',
      rows: [
        SportStandingRow(
          team: f.home,
          rank: 1,
          played: 9,
          points: 16,
          wins: 8,
          losses: 1,
          form: history.skip(4),
          formHistory: history,
        ),
        ...rows.skip(1),
      ],
    );
    final values = adapter.evaluate(
      f,
      hockeyReadingSnapshot(f, tables: [full]),
    );
    final overall = home(values, 'winning_streak'),
        venue = home(values, 'strong_home_team');
    expect(overall.evidence['consecutiveWins'], 8);
    expect(overall.evidence['exact'], true);
    expect(venue.evidence['consecutiveResults'], 4);
    expect(venue.status, SportReadingStatus.detected);
    expect(
      home(values, 'strong_away_team').status,
      SportReadingStatus.notDetected,
    );
    final incomplete = SportStandingTable(
      stage: 'Regular Season',
      group: 'Conference',
      rows: [
        SportStandingRow(
          team: f.home,
          rank: 1,
          played: 12,
          points: 22,
          wins: 8,
          losses: 4,
          form: history.skip(4),
          formHistory: [history[1], ...history.skip(4)],
        ),
        ...rows.skip(1),
      ],
    );
    final truncated = adapter.evaluate(
      f,
      hockeyReadingSnapshot(f, tables: [incomplete]),
    );
    expect(home(truncated, 'winning_streak').evidence['consecutiveWins'], 5);
    expect(home(truncated, 'winning_streak').evidence['exact'], false);
  });

  test('publication evaluates the validated catalogue on both teams', () {
    final values = adapter.evaluate(fixture, snapshot);
    expect(values, hasLength(2 * HockeyFeedReadings.readingIds.length + 2));
    expect(
      values
          .where(
            (r) =>
                r.status == SportReadingStatus.detected &&
                r.id != 'negative_streak',
          )
          .map((r) => r.subject)
          .toSet(),
      {fixture.home.id},
    );
    expect(home(values, 'standing_advantage').evidence['tier'], 1);
    expect(home(values, 'recent_form_advantage').evidence['percentageGap'], 1);
    expect(
      values.every(
        (r) =>
            r.evidence['competition'] == fixture.competition.key &&
            r.asOf == readingCutoff,
      ),
      isTrue,
    );
  });

  test('For me needs opt-in competition AND active detected reading', () {
    for (final p in [
      preferences(competitions: []),
      preferences(readings: []),
      preferences(readings: ['unknown']),
      preferences(competitions: ['hockey:api-hockey:competition:18']),
    ]) {
      expect(adapter.recommends(fixture, snapshot, p), isFalse);
    }
    expect(adapter.recommends(fixture, snapshot, preferences()), isTrue);
    expect(
      adapter
          .selected(
            fixture,
            snapshot,
            preferences(readings: ['winning_streak']),
          )
          .map((r) => r.id)
          .toSet(),
      {'winning_streak'},
    );
    // Discovery may show active readings outside followed competitions.
    expect(
      adapter
          .selected(
            fixture,
            snapshot,
            preferences(competitions: ['hockey:api-hockey:competition:18']),
          )
          .where((r) => r.status == SportReadingStatus.detected),
      isNotEmpty,
    );
    expect(
      adapter.selected(
        fixture,
        snapshot,
        SportReadingPreferences(
          sport: SportId.football,
          readingIds: ['winning_streak'],
        ),
      ),
      isEmpty,
    );
  });

  test('three-point leagues interpret OT and shootout wins differently', () {
    final three = hockeyReadingFixture(league: '18');
    final values = adapter.evaluate(three, hockeyReadingSnapshot(three));
    expect(
      home(values, 'recent_form_advantage').evidence['percentageGap'],
      closeTo(13 / 15, 1e-10),
    );
    expect(home(values, 'winning_streak').status, SportReadingStatus.detected);
  });

  test('orders by game date, rather than shared snapshot completion date', () {
    final f = hockeyReadingFixture(
      homeForm: hockeyForm('Home', [
        'L',
        'L',
        'FT',
        'AOT',
        'AP',
      ]).reversed.toList(),
    );
    expect(
      home(
        adapter.evaluate(f, hockeyReadingSnapshot(f)),
        'winning_streak',
      ).status,
      SportReadingStatus.detected,
    );
    final broken = hockeyReadingFixture(
      homeForm: hockeyForm('Home', ['FT', 'FT', 'FT', 'FT', 'L']),
    );
    expect(
      home(
        adapter.evaluate(broken, hockeyReadingSnapshot(broken)),
        'winning_streak',
      ).status,
      SportReadingStatus.notDetected,
    );
  });

  test('never compares separate division ranks or adds duplicate views', () {
    final separate = hockeyReadingSnapshot(
      fixture,
      tables: [
        SportStandingTable(
          stage: 'Regular Season',
          group: 'East',
          rows: [standing('Home', 22)],
        ),
        SportStandingTable(
          stage: 'Regular Season',
          group: 'West',
          rows: [standing('Away', 8)],
        ),
      ],
    );
    expect(
      home(adapter.evaluate(fixture, separate), 'standing_advantage').status,
      SportReadingStatus.insufficientData,
    );
    final duplicate = hockeyReadingSnapshot(
      fixture,
      tables: [commonTable(), commonTable()],
    );
    expect(
      home(
        adapter.evaluate(fixture, duplicate),
        'standing_advantage',
      ).evidence['pointsGap'],
      14,
    );
    final conflict = hockeyReadingSnapshot(
      fixture,
      tables: [commonTable(), commonTable(homePoints: 20)],
    );
    expect(
      home(adapter.evaluate(fixture, conflict), 'standing_advantage').status,
      SportReadingStatus.insufficientData,
    );
  });

  test('unverified NHL histories do not trigger form or streak readings', () {
    final nhl = hockeyReadingFixture(league: '57');
    final values = adapter.evaluate(
      nhl,
      hockeyReadingSnapshot(nhl, phaseVerified: false),
    );
    expect(
      home(values, 'recent_form_advantage').status,
      SportReadingStatus.insufficientData,
    );
    expect(
      home(values, 'winning_streak').status,
      SportReadingStatus.insufficientData,
    );
  });

  test(
    'unknown results, preseason, foreign and future histories cannot make streaks',
    () {
      for (final form in [
        hockeyForm('Home', ['FT', 'FT', 'FT', 'FT', 'UNKNOWN']),
        [
          for (final r in fixture.homeForm)
            SportFormResult(
              matchId: r.matchId,
              startsAt: DateTime.utc(2026, 8, 1),
              opponent: r.opponent,
              home: r.home,
              scored: r.scored,
              conceded: r.conceded,
              outcome: r.outcome,
              providerStatus: r.providerStatus,
            ),
        ],
        [
          for (final r in fixture.homeForm)
            SportFormResult(
              matchId: r.matchId,
              startsAt: readingCutoff.add(const Duration(hours: 1)),
              opponent: r.opponent,
              home: r.home,
              scored: r.scored,
              conceded: r.conceded,
              outcome: r.outcome,
              providerStatus: r.providerStatus,
            ),
        ],
      ]) {
        final f = hockeyReadingFixture(homeForm: form);
        expect(
          home(
            adapter.evaluate(f, hockeyReadingSnapshot(f)),
            'winning_streak',
          ).status,
          SportReadingStatus.insufficientData,
        );
      }
    },
  );

  test(
    'does not fabricate prematch readings with live or post-kickoff data',
    () {
      for (final status in [
        SportFixtureStatus.live,
        SportFixtureStatus.finished,
      ]) {
        final f = hockeyReadingFixture(status: status);
        expect(
          adapter
              .evaluate(f, hockeyReadingSnapshot(f))
              .every((r) => r.status == SportReadingStatus.insufficientData),
          isTrue,
        );
      }
      expect(
        adapter
            .evaluate(
              fixture,
              hockeyReadingSnapshot(
                fixture,
                capturedAt: fixture.startsAt!.add(const Duration(minutes: 1)),
              ),
            )
            .every((r) => r.status == SportReadingStatus.insufficientData),
        isTrue,
      );
    },
  );

  test(
    'unsupported league or season abstains without a default NHL fallback',
    () {
      for (final f in [
        hockeyReadingFixture(league: '999'),
        hockeyReadingFixture(season: '2025'),
      ]) {
        expect(
          adapter
              .evaluate(f, hockeyReadingSnapshot(f))
              .every((r) => r.status == SportReadingStatus.insufficientData),
          isTrue,
        );
      }
    },
  );
}
