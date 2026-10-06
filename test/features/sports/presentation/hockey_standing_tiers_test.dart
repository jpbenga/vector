import 'package:copilot/app/theme/app_theme.dart';
import 'package:copilot/core/sports/domain/sport.dart';
import 'package:copilot/core/sports/domain/sport_competition_context.dart';
import 'package:copilot/core/widgets/lector_standing_table.dart';
import 'package:copilot/features/hockey/presentation/hockey_context_panels.dart';
import 'package:copilot/features/hockey/domain/hockey_standing_tiers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../fixtures/sports/hockey_readings_fixture.dart';

void main() {
  for (final grouped in [false, true]) {
    testWidgets(
      'Lector bands and DOM/EXT preserve points in every scope; grouped=$grouped',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final rows = [
          for (var i = 0; i < 12; i++)
            SportStandingRow(
              team: hockeyTeam('Team $i'),
              rank: i + 1,
              played: 20,
              points: (18 - i) * 2,
              wins: 0,
              losses: 0,
            ),
        ];
        final table = SportStandingTable(
          stage: 'Regular Season',
          group: 'Group',
          rows: rows,
        );
        final venue = [
          for (final r in rows)
            SportVenueStandingRow(
              team: r.team,
              rank: r.rank,
              played: 10,
              points: r.points ~/ 2,
              wins: 0,
              losses: 0,
              goalsFor: 0,
              goalsAgainst: 0,
            ),
        ];
        final c = SportCompetitionContext(
          id: hockeyId(SportEntityKind.competition, '35'),
          name: 'KHL',
          season: '2026',
          country: 'Russia',
          formPhaseVerified: true,
          tables: [table],
          venueStandings: SportVenueStandings(
            collectedAt: readingCutoff,
            home: venue,
            away: venue,
            unavailableTeams: [],
            source: 'season-games',
            status: 'verified',
          ),
          standingContext: grouped
              ? SportStandingContext(
                  phase: 'regular',
                  collectedAt: readingCutoff,
                  maximumPoints: 2,
                  groups: [
                    const SportStandingGroupContext(
                      tableIndex: 0,
                      kind: SportStandingGroupKind.league,
                    ),
                  ],
                )
              : null,
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark,
            home: Scaffold(
              body: SingleChildScrollView(
                child: HockeyStandingsPanel(
                  competition: c,
                  homeTeamId: rows.first.team.id,
                  awayTeamId: rows.last.team.id,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (final (scope, text) in [
          'Général',
          'Domicile',
          'Extérieur',
        ].indexed) {
          await tester.ensureVisible(find.text(text).first);
          await tester.tap(find.text(text).first);
          await tester.pumpAndSettle();
          final rendered = tester.widget<LectorStandingDataTable>(
            find.byType(LectorStandingDataTable),
          );
          expect(rendered.groups.map((g) => g.label), ['T1', 'T3', 'T5']);
          final entries = rendered.groups.expand((g) => g.rows).toList();
          expect(entries.first.role, LectorStandingRole.home);
          expect(entries.last.role, LectorStandingRole.away);
          expect(
            entries.map((e) => e.values.last.text),
            rows.map((r) => '${scope == 0 ? r.points : r.points ~/ 2}'),
          );
          expect(find.byType(LectorStandingLegend), findsOneWidget);
          expect(find.text('Tiers Lector · provisoires'), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
        expect(
          HockeyStandingTiers.classify(
            table,
            competition: c,
          ).tiers[rows.first.team.id.key],
          1,
        );
      },
    );
  }
}
