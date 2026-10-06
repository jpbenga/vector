import 'package:copilot/app/theme/app_theme.dart';
import 'package:copilot/core/widgets/lector_radar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'history and recent cells keep original tap indices when scrolling',
    (tester) async {
      int? selected;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: LectorFormResultStrip(
              results: List.filled(13, 'W'),
              historyColumns: 5,
              tooltips: List.generate(13, (i) => 'Match $i'),
              onMatchTap: (i) => selected = i,
            ),
          ),
        ),
      );
      expect(
        find.byKey(const ValueKey('team-form-history-separator')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('team-form-result-8')));
      expect(selected, 8); // First of the five recent results.
      await tester.tap(find.byKey(const ValueKey('team-form-result-7')));
      expect(selected, 7); // Sixth-most-recent match, next to the divider.
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(150, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('team-form-result-0')));
      expect(selected, 0);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('without history mode only the latest five are shown', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LectorFormResultStrip(results: List.filled(10, 'W')),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('team-form-result-0')), findsNothing);
    expect(find.byKey(const ValueKey('team-form-result-5')), findsOneWidget);
    expect(find.byKey(const ValueKey('team-form-result-9')), findsOneWidget);
  });
  for (final width in [320.0, 390.0, 1100.0]) {
    testWidgets('shared team history row fits $width', (tester) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: LectorRadarEntryCard(
              child: LectorRadarTeamRow(
                rank: 1,
                name: 'Une équipe avec un nom très long',
                competitionName: 'Championnat',
                metric: '5/5',
                streakLabel: 'série 8',
                activity: LectorFormResultStrip(
                  results: List.filled(8, 'W'),
                  historyColumns: 5,
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('5/5 · série 8'), findsOneWidget);
    });
  }
}
