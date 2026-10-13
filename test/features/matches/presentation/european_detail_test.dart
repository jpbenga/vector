import 'dart:convert';
import 'dart:io';
import 'package:copilot/core/theme/app_theme.dart';
import 'package:copilot/features/matches/data/api_football_match_adapter.dart';
import 'package:copilot/features/matches/presentation/match_detail_page.dart';
import 'package:copilot/features/matches/domain/match_board_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  testWidgets(
    'European detail retains tabs and generator actions at mobile widths, with honest missing states',
    (tester) async {
      await initializeDateFormatting('fr');
      final snapshot =
          jsonDecode(
                File('assets/design_preview/champions.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      final match = const ApiFootballMatchAdapter()
          .fromSnapshot(snapshot)
          .single;
      var compare = 0, ask = 0;
      for (final width in [320.0, 375.0, 390.0, 430.0, 768.0]) {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          MaterialApp(
            theme: CopilotTheme.dark,
            home: MatchDetailPage(
              match: match,
              onAskEuropean: (c) {
                c ? compare++ : ask++;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Synthèse'), findsOneWidget);
        expect(find.text('Marchés'), findsNothing);
        expect(find.text('Ce qu’il faut retenir'), findsNothing);
        expect(
          find.text('Situation domestique et forme récente'),
          findsOneWidget,
        );
        expect(find.text('Forme récente en championnat'), findsNothing);
        expect(find.text('Parcours européen'), findsOneWidget);
        expect(find.textContaining('0V'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Comparer'));
        await tester.pump();
        await tester.tap(find.text('Demander à Lector'));
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Contexte'));
        await tester.pumpAndSettle();
        expect(
          find.text('Situation domestique et forme récente'),
          findsNothing,
        );
        expect(find.text('Parcours européen'), findsNothing);
        expect(find.text('Cotes disponibles'), findsNothing);
        expect(find.textContaining('éléments différenciants'), findsOneWidget);
        await tester.tap(find.text('Classement'));
        await tester.pumpAndSettle();
        expect(
          find.text('Situation domestique et forme récente'),
          findsNothing,
        );
        expect(find.text('Classement européen'), findsNothing);
        expect(
          find.byKey(ValueKey('cup-standing-groups-${match.id}')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }
      expect(compare, 5);
      expect(ask, 5);
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    },
  );
  testWidgets('Cup standings retain every official group and its local ranks', (
    tester,
  ) async {
    await initializeDateFormatting('fr');
    final snapshot =
        jsonDecode(
              File('assets/design_preview/champions.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    final original = const ApiFootballMatchAdapter()
        .fromSnapshot(snapshot)
        .single;
    final rows = [
      const TeamStandingSnapshot(
        teamId: 1,
        teamName: 'Alpha',
        group: 'Group A',
        rank: 1,
        played: 2,
        points: 6,
      ),
      const TeamStandingSnapshot(
        teamId: 2,
        teamName: 'Beta',
        group: 'Group A',
        rank: 2,
        played: 2,
        points: 3,
      ),
      const TeamStandingSnapshot(
        teamId: 3,
        teamName: 'Gamma',
        group: 'Group B',
        rank: 1,
        played: 2,
        points: 4,
      ),
      const TeamStandingSnapshot(
        teamId: 4,
        teamName: 'Delta',
        group: 'Group B',
        rank: 2,
        played: 2,
        points: 1,
      ),
    ];
    final match = original.copyWith(
      analysis: original.analysis.copyWith(
        asOf: original.fixture.kickoff!.subtract(const Duration(days: 1)),
        leagueStandings: rows.take(2).toList(),
        competitionStandings: rows,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: CopilotTheme.dark,
        home: MatchDetailPage(match: match),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Classement'));
    await tester.pumpAndSettle();
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Gamma'), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('cup-standing-groups-${match.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Group B').last);
    await tester.pumpAndSettle();
    expect(find.text('Gamma'), findsOneWidget);
    expect(find.text('Delta'), findsOneWidget);
    expect(find.text('Alpha'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Europa and Conference use the same separated cup tabs', (
    tester,
  ) async {
    await initializeDateFormatting('fr');
    for (final id in [3, 848]) {
      final snapshot =
          jsonDecode(
                File('assets/design_preview/champions.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      for (final f in snapshot['raw']['fixtures'] as List) {
        f['league']['id'] = id;
      }
      final match = const ApiFootballMatchAdapter()
          .fromSnapshot(snapshot)
          .single;
      await tester.pumpWidget(
        MaterialApp(
          theme: CopilotTheme.dark,
          home: MatchDetailPage(match: match),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Situation domestique et forme récente'),
        findsOneWidget,
      );
      expect(find.text('Ce qu’il faut retenir'), findsNothing);
      await tester.tap(find.text('Contexte'));
      await tester.pumpAndSettle();
      expect(find.text('Parcours européen'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}
