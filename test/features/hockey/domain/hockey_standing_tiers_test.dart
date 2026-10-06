import 'package:copilot/core/domain/structural_tiers/dynamic_tier_algorithm_v1.dart';
import 'package:copilot/core/domain/structural_tiers/tier_input.dart';
import 'package:copilot/core/domain/structural_tiers/competition_structural_metadata.dart';
import 'package:copilot/core/domain/structural_tiers/tier_models.dart';
import 'package:copilot/core/sports/domain/sport_competition_context.dart';
import 'package:copilot/core/sports/domain/sport_module.dart';
import 'package:copilot/features/hockey/domain/hockey_feed_readings.dart';
import 'package:copilot/features/hockey/domain/hockey_standing_tiers.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../fixtures/sports/hockey_readings_fixture.dart';

SportStandingTable table(List<int> points, {int played = 10}) =>
    SportStandingTable(
      stage: 'Regular Season',
      group: 'League',
      rows: [
        for (final (i, p) in points.indexed)
          SportStandingRow(
            team: hockeyTeam(
              i == 0
                  ? 'Home'
                  : i == points.length - 1
                  ? 'Away'
                  : 'Team $i',
            ),
            rank: i + 1,
            played: played,
            points: p,
            wins: 0,
            losses: 0,
          ),
      ],
    );

void main() {
  test(
    'standing advantage and confirmed structural gap are distinct readings',
    () {
      final fixture = hockeyReadingFixture();
      for (final (points, strong) in [
        ([18, 17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7], false),
        ([20, 19, 18, 6, 5, 4, 3, 2, 1, 0, 0, 0], true),
      ]) {
        final t = table(points);
        final readings = const HockeyFeedReadings().evaluate(
          fixture,
          hockeyReadingSnapshot(fixture, tables: [t]),
        );
        SportReadingAssessment r(String id) => readings.singleWhere(
          (r) => r.id == id && r.subject == fixture.home.id,
        );
        expect(r('standing_advantage').status, SportReadingStatus.detected);
        expect(
          r('structural_level_gap').status,
          strong ? SportReadingStatus.detected : SportReadingStatus.notDetected,
        );
      }
    },
  );

  test(
    'continuous points still classify leaders and bottom; readings consume those exact tiers',
    () {
      final t = table([18, 17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7]);
      final tiers = HockeyStandingTiers.classify(t).tiers;
      expect(tiers.values, [1, 1, 1, 3, 3, 3, 3, 3, 3, 3, 5, 5]);
      final fixture = hockeyReadingFixture();
      final readings = const HockeyFeedReadings().evaluate(
        fixture,
        hockeyReadingSnapshot(fixture, tables: [t]),
      );
      final advantage = readings.singleWhere(
        (r) => r.id == 'standing_advantage' && r.subject == fixture.home.id,
      );
      expect(advantage.status, SportReadingStatus.detected);
      expect(advantage.evidence['tier'], tiers[fixture.home.id.key]);
      expect(advantage.evidence['opponentTier'], tiers[fixture.away.id.key]);
      expect(advantage.evidence.containsKey('percentageGap'), isFalse);
    },
  );

  test(
    'hockey partition reuses football kernel with the same points and anchors',
    () {
      for (final points in [
        [20, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2],
        [18, 17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 0],
        [20, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 0],
        [20, 19, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1],
        [18, 17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7],
      ]) {
        final t = table(points);
        final football = const DynamicTierAlgorithmV1().buildSnapshot(
          DynamicTierInput(
            competitionId: 'example',
            season: 2026,
            analysisAsOf: readingCutoff,
            competitionFormat: CompetitionFormat.standardRoundRobin,
            standingsRows: [
              for (final (i, r) in t.rows.indexed)
                DynamicTierInputStanding(
                  teamId: i,
                  teamName: r.team.name,
                  officialRank: r.rank,
                  points: r.points,
                  played: r.played,
                ),
            ],
            podiumAnchor: const CompetitionStructuralAnchor(
              startRank: 1,
              endRank: 3,
              source: StructuralAnchorSource.tierDefinition,
            ),
            relegationAnchor: const CompetitionStructuralAnchor(
              startRank: 11,
              endRank: 12,
              source: StructuralAnchorSource.lectorOverride,
            ),
            anchorMetadataVersion: 'test',
            competitionFormatVersion: 'test',
            structuralMetadataVersion: 'test',
          ),
        );
        expect(
          HockeyStandingTiers.classify(t).tiers.values,
          football.teamAssignments.map((r) => r.assignedTier.ordinal),
        );
      }
    },
  );

  test('five games required, equal points do not create false divisions', () {
    expect(
      HockeyStandingTiers.classify(
        table([9, 8, 7, 6, 5, 4, 3, 2], played: 4),
      ).available,
      isFalse,
    );
    expect(
      HockeyStandingTiers.classify(
        table([9, 8, 7, 6, 5, 4, 3, 2], played: 5),
      ).available,
      isTrue,
    );
    expect(
      HockeyStandingTiers.classify(table(List.filled(8, 8))).available,
      isFalse,
    );
    final tied = HockeyStandingTiers.classify(
      table([12, 11, 10, 10, 8, 7, 6, 5]),
    );
    expect(tied.tiers.values.take(4), [1, 1, 1, 1]);
  });

  test(
    'small NHL/KHL divisions and points systems share scale-independent anchors',
    () {
      for (final n in [5, 6, 7, 8, 10, 11, 12, 14, 16, 17]) {
        final result = HockeyStandingTiers.classify(
          table(List.generate(n, (i) => n - i)),
        );
        expect(result.tiers.length, n);
        expect(result.tiers.values.first, 1);
        expect(result.tiers.values.last, 5);
      }
    },
  );
}
