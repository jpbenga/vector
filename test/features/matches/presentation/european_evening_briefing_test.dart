import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:copilot/core/theme/app_theme.dart';
import 'package:copilot/features/matches/data/match_feed_repository.dart';
import 'package:copilot/features/matches/domain/match_board_item.dart';
import 'package:copilot/features/matches/presentation/widgets/european_evening_briefing.dart';
import 'package:copilot/features/matches/presentation/widgets/match_feed_card.dart';

MatchBoardItem archived(String name) => SnapshotMatchFeedRepository(
  snapshot:
      jsonDecode(File('assets/design_preview/$name.json').readAsStringSync())
          as Map<String, dynamic>,
).allMatches().single;
void main() {
  testWidgets(
    'briefing is absent without European cup fixtures and leaves other content available',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: CopilotTheme.dark,
          home: Scaffold(
            body: Column(
              children: [
                EuropeanEveningBriefing(
                  matches: [archived('league')],
                  date: DateTime(2026, 10, 11),
                  showReadings: false,
                  onOpenMatch: (_) {},
                ),
                const Text('Autres rencontres'),
              ],
            ),
          ),
        ),
      );
      expect(
        find.byKey(const ValueKey('european-evening-briefing-2')),
        findsNothing,
      );
      expect(find.text('Autres rencontres'), findsOneWidget);
    },
  );
  testWidgets(
    'opens only published Champions fixtures, uses actual count, and retains return path',
    (tester) async {
      final match = archived('champions');
      String? opened;
      await tester.pumpWidget(
        MaterialApp(
          theme: CopilotTheme.dark,
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  EuropeanEveningBriefing(
                    matches: [match, archived('league')],
                    date: DateTime(2026, 10, 13),
                    showReadings: false,
                    onOpenMatch: (m) => opened = m.id,
                  ),
                  const Text('Autres rencontres'),
                ],
              ),
            ),
          ),
        ),
      );
      expect(find.text('1 match · 13/10'), findsOneWidget);
      expect(find.text('Dynamique'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('open-european-evening-2')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widgetList<MatchFeedCard>(find.byType(MatchFeedCard))
            .map((c) => c.match.id),
        [match.id],
      );
      await tester.tap(find.text('Villarreal'));
      expect(opened, match.id);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Autres rencontres'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
