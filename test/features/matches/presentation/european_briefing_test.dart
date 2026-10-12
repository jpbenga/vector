import 'dart:convert';
import 'dart:io';
import 'package:copilot/core/theme/app_theme.dart';
import 'package:copilot/features/matches/data/api_football_match_adapter.dart';
import 'package:copilot/features/matches/domain/match_board_item.dart';
import 'package:copilot/features/matches/presentation/widgets/european_evening_briefing.dart';
import 'package:copilot/features/matches/presentation/widgets/match_feed_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

MatchBoardItem fixture(int league, String name) {
  final snapshot =
      jsonDecode(
            File('assets/design_preview/champions.json').readAsStringSync(),
          )
          as Map<String, dynamic>;
  for (final f in snapshot['raw']['fixtures'] as List) {
    f['league']['id'] = league;
    f['league']['name'] = name;
  }
  return const ApiFootballMatchAdapter().fromSnapshot(snapshot).single;
}

void main() {
  final champions = fixture(2, 'Champions League');
  final europa = fixture(3, 'Europa League');
  final conference = fixture(848, 'Conference League');
  Widget screen(
    List<MatchBoardItem> matches, {
    DateTime? date,
    double scale = 1,
  }) => MaterialApp(
    theme: CopilotTheme.dark,
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(scale)),
      child: Scaffold(
        body: EuropeanEveningBriefing(
          matches: matches,
          date: date ?? DateTime(2026, 10, 15),
          showReadings: true,
          onOpenMatch: (_) {},
        ),
      ),
    ),
  );
  testWidgets(
    'Briefings swipe in CL, EL, Conference order and reset on date change',
    (tester) async {
      for (final width in [320.0, 390.0, 430.0, 768.0]) {
        tester.view.physicalSize = Size(width, 1100);
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(screen([conference, europa, champions]));
        await tester.pumpAndSettle();
        final pager = find.byType(PageView);
        expect(tester.widget<PageView>(pager).controller!.page, 0);
        expect(find.text('Briefing 1 / 3'), findsOneWidget);
        final card = tester.getRect(
          find.byKey(const ValueKey('european-evening-briefing-2')),
        );
        final button = tester.getRect(
          find.byKey(const ValueKey('open-european-evening-2')),
        );
        expect(card.bottom - button.bottom, lessThanOrEqualTo(14));
        expect(find.text('Vigilances'), findsNothing);
        expect(find.text('Équilibre'), findsNothing);
        await tester.drag(pager, Offset(-width, 0));
        await tester.pumpAndSettle();
        expect(tester.widget<PageView>(pager).controller!.page, 1);
        expect(find.text('Briefing 2 / 3'), findsOneWidget);
        await tester.tap(find.byTooltip('Briefing suivant'));
        await tester.pumpAndSettle();
        expect(tester.widget<PageView>(pager).controller!.page, 2);
        await tester.tap(
          find.byKey(const ValueKey('open-european-evening-848')),
        );
        await tester.pumpAndSettle();
        expect(
          find.widgetWithText(AppBar, 'Conference League'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.pumpWidget(
          screen([europa, conference], date: DateTime(2026, 10, 22)),
        );
        await tester.pumpAndSettle();
        expect(
          tester.widget<PageView>(find.byType(PageView)).controller!.page,
          0,
        );
        expect(find.text('Briefing 1 / 2'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    },
  );
  testWidgets(
    'Single competition and large text remain usable without synthetic badges',
    (tester) async {
      tester.view.physicalSize = const Size(320, 1200);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(screen([europa]));
      await tester.pumpAndSettle();
      expect(find.byType(PageView), findsNothing);
      expect(
        find.text(
          publishedMatchCardReadings(europa).isEmpty
              ? 'Aucune lecture de votre profil pour ces rencontres.'
              : '1 rencontre avec des lectures Lector.',
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(screen([europa, conference], scale: 2));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    },
  );
}
