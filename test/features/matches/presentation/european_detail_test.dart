import 'dart:convert';
import 'dart:io';
import 'package:copilot/core/theme/app_theme.dart';
import 'package:copilot/features/matches/data/api_football_match_adapter.dart';
import 'package:copilot/features/matches/presentation/match_detail_page.dart';
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
        expect(find.textContaining('0V'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Comparer'));
        await tester.pump();
        await tester.tap(find.text('Demander à Lector'));
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Contexte'));
        await tester.pumpAndSettle();
        expect(find.text('Situation domestique'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }
      expect(compare, 5);
      expect(ask, 5);
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    },
  );
}
