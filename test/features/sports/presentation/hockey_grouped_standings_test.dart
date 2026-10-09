import 'dart:convert';
import 'dart:io';
import 'package:copilot/app/theme/app_theme.dart';
import 'package:copilot/core/sports/data/published_sport_feed_repository.dart';
import 'package:copilot/core/sports/domain/sport.dart';
import 'package:copilot/core/widgets/lector_standing_context.dart';
import 'package:copilot/core/widgets/lector_standing_table.dart';
import 'package:copilot/features/hockey/domain/hockey_standing_view.dart';
import 'package:copilot/features/hockey/presentation/hockey_context_panels.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> payload() =>
    jsonDecode(
          File(
            'test/fixtures/sports/hockey_grouped_standings_compact.json',
          ).readAsStringSync(),
        )
        as Map<String, dynamic>;
final snapshot = SportPublicationCodec.decode(payload(), SportId.hockey);
final nhl = snapshot.competitions.firstWhere((c) => c.id.value == '57');
final fixture = snapshot.items.single;
void main() {
  test(
    'smallest official group, weighted league mean and venue-local ranks use actual NHL data',
    () {
      final home = HockeyStandingView.localGroup(nhl, fixture.home.id)!;
      final away = HockeyStandingView.localGroup(nhl, fixture.away.id)!;
      expect(nhl.tables[home].group, 'Metropolitan Division');
      expect(nhl.tables[away].group, 'Atlantic Division');
      final unique = {
        for (final t in nhl.tables)
          for (final r in t.rows) r.team.id: r,
      };
      final played = unique.values.fold<int>(0, (n, r) => n + r.played);
      final points = unique.values.fold<int>(0, (n, r) => n + r.points);
      expect(HockeyStandingView.leagueMean(nhl, 0), points / played);
      for (var scope = 1; scope < 3; scope++) {
        final rows = HockeyStandingView.rows(nhl, home, scope);
        expect(rows.length, 8);
        expect(rows.first.rank, 1);
        expect(
          rows.every(
            (r) => nhl.tables[home].rows.any((o) => o.team.id == r.team.id),
          ),
          isTrue,
        );
        expect(
          rows.map((r) => r.points),
          orderedEquals(
            rows.map((r) => r.points).toList()..sort((a, b) => b.compareTo(a)),
          ),
        );
      }
    },
  );
  test(
    'public context refuses fabricated ratios, wrong hierarchy and unverified comparisons',
    () {
      void rejects(void Function(Map<String, dynamic>) modify) {
        final raw = payload();
        final c = (raw['competitions'] as List).first as Map<String, dynamic>;
        modify(c);
        expect(
          () => SportPublicationCodec.decode(raw, SportId.hockey),
          throwsFormatException,
        );
      }

      rejects((c) => c['standingContext']['maximumPoints'] = 4);
      rejects((c) => c['standingContext']['groups'][2]['all']['points'] = 9999);
      rejects((c) => c['standingContext']['groups'][2]['parentTableIndex'] = 3);
      rejects((c) => c['standingContext']['groups'][2]['home']['played']++);
      rejects((c) => c['venueStandings']['status'] = 'partial');
      rejects((c) => c['standingContext']['groups'].removeLast());
      final ahl = snapshot.competitions.firstWhere((c) => c.id.value == '58');
      expect(ahl.venueStandings!.status, 'partial');
      expect(ahl.standingContext!.groups.every((g) => g.all == null), isTrue);
    },
  );
  for (final width in [320.0, 390.0, 1100.0]) {
    testWidgets(
      'three-screen journey preserves team roles, table membership and scopes at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark,
            home: Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: HockeyStandingsPanel(
                    competition: nhl,
                    homeTeamId: fixture.home.id,
                    awayTeamId: fixture.away.id,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(LectorStandingHierarchyComparison), findsOneWidget);
        expect(find.byType(LectorStandingDataTable), findsOneWidget);
        expect(
          tester
              .widget<LectorStandingDataTable>(
                find.byType(LectorStandingDataTable),
              )
              .groups
              .single
              .rows
              .length,
          16,
        );
        expect(
          tester
              .widgetList<LectorStandingGroupPerformance>(
                find.byType(LectorStandingGroupPerformance),
              )
              .map((w) => w.name),
          ['Atlantic Division', 'Metropolitan Division'],
        );
        final divisions = find.byKey(const ValueKey('hockey-standing-level-1'));
        await tester.ensureVisible(divisions);
        await tester.tap(divisions);
        await tester.pumpAndSettle();
        expect(find.text('POSITION DANS LEUR DIVISION'), findsOneWidget);
        expect(find.byType(LectorStandingDataTable), findsNWidgets(2));
        final groupIndices = [
          HockeyStandingView.localGroup(nhl, fixture.away.id)!,
          HockeyStandingView.localGroup(nhl, fixture.home.id)!,
        ];
        for (final scope in [0, 1, 2, 0]) {
          final chip = find.byKey(ValueKey('hockey-standing-scope-$scope'));
          await tester.ensureVisible(chip);
          await tester.tap(chip);
          await tester.pumpAndSettle();
          for (final index in groupIndices) {
            final card = find.byKey(ValueKey('standing-ranking-$index'));
            final actual = tester.widget<LectorStandingDataTable>(
              find.descendant(
                of: card,
                matching: find.byType(LectorStandingDataTable),
              ),
            );
            final expected = HockeyStandingView.rows(nhl, index, scope);
            expect(
              actual.groups.single.rows.map((r) => r.identity),
              expected.map((r) => r.team.id.key),
            );
            expect(
              actual.groups.single.rows.map((r) => r.rank),
              expected.map((r) => '${r.rank}'),
            );
            expect(
              actual.groups.single.rows.map((r) => r.values.last.text),
              expected.map((r) => '${r.points}'),
            );
            expect(actual.compact, isTrue);
            expect(actual.columns.map((c) => c.label), ['J', 'Pts']);
            expect(
              actual.groups.single.rows.every((r) => r.secondaryText == null),
              isTrue,
            );
            final rowFinder = find.descendant(
              of: card,
              matching: find.byKey(
                ValueKey('standing-row-${expected.first.team.id.key}'),
              ),
            );
            expect(tester.getSize(rowFinder).height, lessThanOrEqualTo(32));
          }
          final left = tester.getRect(
            find.byKey(ValueKey('standing-ranking-${groupIndices[0]}')),
          );
          final right = tester.getRect(
            find.byKey(ValueKey('standing-ranking-${groupIndices[1]}')),
          );
          expect(left.top, right.top);
          expect(left.right, lessThan(right.left));
          final comparison = tester.widget<LectorStandingPaceComparison>(
            find.byType(LectorStandingPaceComparison),
          );
          expect(comparison.mean, HockeyStandingView.leagueMean(nhl, scope));
          for (final team in comparison.teams) {
            final index = groupIndices.firstWhere(
              (i) => nhl.tables[i].rows.any((r) => r.team.name == team.name),
            );
            final expected = HockeyStandingView.rows(
              nhl,
              index,
              scope,
            ).firstWhere((r) => r.team.name == team.name);
            expect(team.points, expected.points);
            expect(team.played, expected.played);
          }
          expect(tester.takeException(), isNull);
        }
        final cards = tester
            .widgetList<LectorStandingPositionCard>(
              find.byType(LectorStandingPositionCard),
            )
            .toList();
        expect(cards.map((w) => w.team.role), [
          LectorStandingRole.away,
          LectorStandingRole.home,
        ]);
        expect(cards.map((w) => w.team.group), [
          'Atlantic Division',
          'Metropolitan Division',
        ]);
        expect(find.textContaining('Moyenne NHL'), findsOneWidget);
        await tester.ensureVisible(
          find.byKey(const ValueKey('explore-standing-groups')),
        );
        await tester.tap(find.byKey(const ValueKey('explore-standing-groups')));
        await tester.pumpAndSettle();
        expect(find.text('Voir un classement'), findsOneWidget);
        expect(find.text('CONFÉRENCES'), findsOneWidget);
        final index = HockeyStandingView.localGroup(nhl, fixture.home.id)!;
        await tester.ensureVisible(
          find.byKey(ValueKey('standing-picker-$index')),
        );
        await tester.tap(find.byKey(ValueKey('standing-picker-$index')));
        await tester.pumpAndSettle();
        expect(find.text('Voir un classement'), findsNothing);
        final table = tester.widget<LectorStandingDataTable>(
          find.byType(LectorStandingDataTable),
        );
        expect(table.groups.single.rows.length, 8);
        expect(
          table.groups.single.rows
              .singleWhere((r) => r.name == fixture.home.name)
              .role,
          LectorStandingRole.home,
        );
        expect(
          table.groups.single.rows.any((r) => r.name == fixture.away.name),
          isFalse,
        );
        for (var scope = 1; scope < 3; scope++) {
          final chip = find.byKey(ValueKey('hockey-standing-scope-$scope'));
          await tester.ensureVisible(chip);
          await tester.tap(chip);
          await tester.pumpAndSettle();
          final current = tester.widget<LectorStandingDataTable>(
            find.byType(LectorStandingDataTable),
          );
          expect(current.groups.single.rows.length, 8);
          expect(
            current.groups.single.rows
                .singleWhere((r) => r.name == fixture.home.name)
                .role,
            LectorStandingRole.home,
          );
          expect(current.groups.single.rows.first.rank, '1');
        }
        await tester.ensureVisible(find.textContaining(fixture.away.name).last);
        await tester.tap(find.textContaining(fixture.away.name).last);
        await tester.pumpAndSettle();
        final other = tester.widget<LectorStandingDataTable>(
          find.byType(LectorStandingDataTable),
        );
        expect(
          other.groups.single.rows
              .singleWhere((r) => r.name == fixture.away.name)
              .role,
          LectorStandingRole.away,
        );
        await tester.ensureVisible(find.text('Retour à la vue du match'));
        await tester.tap(find.text('Retour à la vue du match'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(divisions);
        await tester.tap(divisions);
        await tester.pumpAndSettle();
        expect(find.text('POSITION DANS LEUR DIVISION'), findsOneWidget);
        final awayCard = find.byKey(
          ValueKey('standing-ranking-${groupIndices.first}'),
        );
        final openAway = find.descendant(
          of: awayCard,
          matching: find.text('Voir le classement complet ›'),
        );
        await tester.ensureVisible(openAway);
        await tester.tap(openAway);
        await tester.pumpAndSettle();
        expect(find.byType(LectorStandingDataTable), findsOneWidget);
        expect(find.byType(LectorStandingFeaturedTeam), findsOneWidget);
        expect(
          tester.getTopLeft(find.text('CLASSEMENT')).dy,
          greaterThanOrEqualTo(0),
        );
        expect(
          tester
              .widget<LectorStandingFeaturedTeam>(
                find.byType(LectorStandingFeaturedTeam),
              )
              .team
              .role,
          LectorStandingRole.away,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'same division uses one complete ranking and marks both opponents in every scope',
    (tester) async {
      final index = HockeyStandingView.localGroup(nhl, fixture.home.id)!;
      final members = nhl.tables[index].rows;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: SingleChildScrollView(
              child: HockeyStandingsPanel(
                competition: nhl,
                homeTeamId: members.first.team.id,
                awayTeamId: members.last.team.id,
              ),
            ),
          ),
        ),
      );
      for (final scope in [0, 1, 2]) {
        await tester.pumpAndSettle();
        final chip = find.byKey(ValueKey('hockey-standing-scope-$scope'));
        await tester.ensureVisible(chip);
        await tester.tap(chip);
        await tester.pumpAndSettle();
        expect(find.byType(LectorStandingDataTable), findsOneWidget);
        expect(find.byType(LectorStandingPositionComparison), findsNothing);
        final table = tester.widget<LectorStandingDataTable>(
          find.byType(LectorStandingDataTable),
        );
        expect(table.compact, isFalse);
        expect(table.columns.map((c) => c.label), ['J', 'V', 'D', 'OT', 'Pts']);
        expect(table.groups.single.rows.length, members.length);
        expect(
          table.groups.single.rows
              .where((r) => r.role == LectorStandingRole.home)
              .single
              .identity,
          members.first.team.id.key,
        );
        expect(
          table.groups.single.rows
              .where((r) => r.role == LectorStandingRole.away)
              .single
              .identity,
          members.last.team.id.key,
        );
        expect(tester.takeException(), isNull);
      }
    },
  );
  testWidgets(
    'partial and zero cross-group data never become an invented success rate',
    (tester) async {
      for (final c in snapshot.competitions.where((c) => c.id.value != '57')) {
        final teams = c.tables.first.rows;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: SingleChildScrollView(
                child: HockeyStandingsPanel(
                  key: ValueKey(c.id.key),
                  competition: c,
                  homeTeamId: teams.first.team.id,
                  awayTeamId: teams.last.team.id,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (c.id.value == '58') {
          expect(find.textContaining('Comparaison indisponible'), findsWidgets);
        }
        if (c.id.value == '47') {
          expect(
            find.textContaining('Aucun match face aux autres'),
            findsOneWidget,
          );
        }
        expect(find.text('0 %'), findsNothing);
        for (final scope in [1, 2]) {
          final chip = find.byKey(ValueKey('hockey-standing-scope-$scope'));
          await tester.ensureVisible(chip);
          await tester.tap(chip);
          await tester.pumpAndSettle();
          expect(find.text('0 %'), findsNothing);
          expect(tester.takeException(), isNull);
        }
      }
    },
  );
}
