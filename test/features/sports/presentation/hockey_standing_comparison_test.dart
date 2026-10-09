import 'package:copilot/app/theme/app_theme.dart';
import 'package:copilot/core/sports/domain/sport_competition_context.dart';
import 'package:copilot/core/widgets/lector_standing_context.dart';
import 'package:copilot/core/widgets/lector_standing_table.dart';
import 'package:copilot/features/hockey/domain/hockey_match_standing_context.dart';
import 'package:copilot/features/hockey/domain/hockey_standing_view.dart';
import 'package:copilot/features/hockey/presentation/hockey_context_panels.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'hockey_grouped_standings_test.dart' show nhl, fixture;

SportCompetitionContext copyCompetition({
  List<SportStandingTable>? tables,
  SportVenueStandings? venue,
}) => SportCompetitionContext(
  id: nhl.id,
  name: nhl.name,
  season: nhl.season,
  country: nhl.country,
  formPhaseVerified: nhl.formPhaseVerified,
  tables: tables ?? nhl.tables,
  standingContext: nhl.standingContext,
  venueStandings: venue ?? nhl.venueStandings,
);

void main() {
  test(
    'three relationships choose real complete division/conference tables',
    () {
      final sameConference = HockeyMatchStandingContext(nhl, [
        fixture.away.id,
        fixture.home.id,
      ]);
      expect(sameConference.relation, HockeyStandingRelation.sameConference);
      expect(sameConference.primaryGroups.length, 1);
      expect(nhl.tables[sameConference.primaryGroups.single].rows.length, 16);
      expect(sameConference.divisions.length, 2);
      final members = nhl.tables[sameConference.divisions.first].rows;
      final sameDivision = HockeyMatchStandingContext(nhl, [
        members.first.team.id,
        members.last.team.id,
      ]);
      expect(sameDivision.relation, HockeyStandingRelation.sameDivision);
      expect(nhl.tables[sameDivision.primaryGroups.single].rows.length, 8);
      final western = nhl.tables
          .firstWhere((t) => t.group == 'Western Conference')
          .rows
          .first
          .team
          .id;
      final cross = HockeyMatchStandingContext(nhl, [fixture.home.id, western]);
      expect(cross.relation, HockeyStandingRelation.differentConferences);
      expect(cross.primaryGroups.length, 2);
      expect(cross.primaryGroups.map((i) => nhl.tables[i].rows.length), [
        16,
        16,
      ]);
      expect(cross.description, contains('Conférences différentes'));
      expect(cross.pointsPerGameGap(0), isNotNull);
    },
  );

  test('unequal games can reverse the impression given by local ranks', () {
    final tables = [
      for (final table in nhl.tables)
        SportStandingTable(
          stage: table.stage,
          group: table.group,
          rows: [
            for (final r in table.rows)
              SportStandingRow(
                team: r.team,
                rank: r.team.id == fixture.home.id
                    ? 2
                    : r.team.id == fixture.away.id
                    ? 5
                    : r.rank,
                played: r.team.id == fixture.home.id
                    ? 3
                    : r.team.id == fixture.away.id
                    ? 4
                    : r.played,
                points: r.team.id == fixture.home.id
                    ? 3
                    : r.team.id == fixture.away.id
                    ? 6
                    : r.points,
                wins: r.wins,
                losses: r.losses,
                goalsFor: r.goalsFor,
                goalsAgainst: r.goalsAgainst,
              ),
          ],
        ),
    ];
    final c = HockeyMatchStandingContext(copyCompetition(tables: tables), [
      fixture.home.id,
      fixture.away.id,
    ]);
    expect(c.pointsPerGameGap(0), -.5);
    expect(
      c.interpretation(0),
      contains(
        '${fixture.away.name} présente un meilleur rendement comptable : +0,50',
      ),
    );
    expect(c.interpretation(0), contains('rang local est pourtant inférieur'));
    expect(
      c.interpretation(0),
      contains('échantillon inférieur à cinq matchs'),
    );
    final zero = [
      for (final t in tables)
        SportStandingTable(
          stage: t.stage,
          group: t.group,
          rows: [
            for (final r in t.rows)
              SportStandingRow(
                team: r.team,
                rank: r.rank,
                played: 0,
                points: 0,
                wins: 0,
                losses: 0,
              ),
          ],
        ),
    ];
    final empty = HockeyMatchStandingContext(
      copyCompetition(tables: zero),
      c.teams,
    );
    expect(empty.pointsPerGameGap(0), isNull);
    expect(empty.interpretation(0), contains('Pas encore'));
  });

  test('missing venue member never produces a silently incomplete ranking', () {
    final group = HockeyStandingView.localGroup(nhl, fixture.home.id)!;
    final missing = nhl.tables[group].rows.last.team.id;
    final old = nhl.venueStandings!;
    final c = copyCompetition(
      venue: SportVenueStandings(
        collectedAt: old.collectedAt,
        home: old.home.where((r) => r.team.id != missing),
        away: old.away,
        unavailableTeams: [missing.value],
        source: old.source,
        status: 'partial',
        phase: old.phase,
      ),
    );
    expect(HockeyStandingView.rows(c, group, 0).length, 8);
    expect(HockeyStandingView.rows(c, group, 1), isEmpty);
    expect(HockeyStandingView.leagueMean(c, 1), isNull);
    expect(HockeyStandingView.rows(c, group, 2).length, 8);
  });

  test(
    'Washington and Rangers share all eight Metropolitan and sixteen Eastern members',
    () {
      final washington = nhl.tables
          .expand((t) => t.rows)
          .firstWhere((r) => r.team.id.value == '703')
          .team
          .id;
      final rangers = nhl.tables
          .expand((t) => t.rows)
          .firstWhere((r) => r.team.id.value == '692')
          .team
          .id;
      final c = HockeyMatchStandingContext(nhl, [washington, rangers]);
      expect(c.relation, HockeyStandingRelation.sameDivision);
      expect(nhl.tables[c.primaryGroups.single].group, 'Metropolitan Division');
      expect(nhl.tables[c.primaryGroups.single].rows.length, 8);
      expect(nhl.tables[c.conferences.single].group, 'Eastern Conference');
      expect(nhl.tables[c.conferences.single].rows.length, 16);
    },
  );

  testWidgets(
    'cross-conference mobile view retains all 32 teams and all scopes',
    (tester) async {
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final western = nhl.tables
          .firstWhere((t) => t.group == 'Western Conference')
          .rows
          .first
          .team
          .id;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: SingleChildScrollView(
              child: HockeyStandingsPanel(
                competition: nhl,
                homeTeamId: fixture.home.id,
                awayTeamId: western,
              ),
            ),
          ),
        ),
      );
      for (final scope in [0, 1, 2]) {
        await tester.pumpAndSettle();
        final button = find.byKey(ValueKey('hockey-standing-scope-$scope'));
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
        final tables = tester
            .widgetList<LectorStandingDataTable>(
              find.byType(LectorStandingDataTable),
            )
            .toList();
        expect(tables.length, 2);
        expect(tables.map((t) => t.groups.expand((g) => g.rows).length), [
          16,
          16,
        ]);
        expect(
          tables
              .expand((t) => t.groups)
              .expand((g) => g.rows)
              .map((r) => r.identity)
              .toSet()
              .length,
          32,
        );
        expect(find.byType(LectorStandingHierarchyComparison), findsOneWidget);
        expect(find.textContaining('Diff. buts :'), findsNWidgets(2));
        expect(tester.takeException(), isNull);
      }
      final picker = find.byKey(const ValueKey('all-standing-groups'));
      await tester.ensureVisible(picker);
      await tester.tap(picker);
      await tester.pumpAndSettle();
      // Six full NHL groups, plus the match view, remain reachable.
      for (final group in nhl.standingContext!.groups) {
        expect(
          find.byKey(ValueKey('standing-picker-${group.tableIndex}')),
          findsOneWidget,
        );
      }
    },
  );
}
