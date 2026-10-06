import 'package:copilot/core/widgets/lector_match_stats.dart';
import 'package:copilot/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final light in [false, true]) {
    testWidgets(
      'archived hockey stats fit mobile in ${light ? 'light' : 'dark'} theme',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: light ? CopilotTheme.light : CopilotTheme.dark,
            home: Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: LectorMatchStats(
                    firstTeam: 'Novosibirsk',
                    secondTeam: 'Nizhnekamsk',
                    sceneAsset: 'assets/backgrounds/hockey-rink-stats.png',
                    isFinal: true,
                    finalStatistics: true,
                    scoreLabel: '2 – 3',
                    capturedAt: DateTime.now().subtract(
                      const Duration(days: 4),
                    ),
                    rows: const [
                      LectorMatchStatistic(
                        label: 'Tirs',
                        first: '24',
                        second: '15',
                      ),
                      LectorMatchStatistic(
                        label: 'Tirs cadrés',
                        first: '14',
                        second: '8',
                      ),
                      LectorMatchStatistic(
                        label: 'Mises en jeu',
                        first: '52%',
                        second: '48%',
                      ),
                      LectorMatchStatistic(
                        label: 'Pénalités (min)',
                        first: '0',
                      ),
                    ],
                    events: const [
                      LectorMatchEvent(
                        clock: 'P2 · 14′',
                        label: 'But · Nizhnekamsk',
                        order: 34,
                      ),
                      LectorMatchEvent(
                        clock: 'P1 · 4′',
                        label: 'But · Novosibirsk',
                        order: 4,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('Statistiques finales'), findsOneWidget);
        expect(
          find.text('Statistiques en attente d’actualisation'),
          findsNothing,
        );
        expect(find.text('—'), findsOneWidget);
        expect(find.byType(Image), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('But · Novosibirsk'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(
          tester.getTopLeft(find.text('But · Novosibirsk')).dy,
          greaterThan(tester.getTopLeft(find.text('But · Nizhnekamsk')).dy),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'a last live block is not presented as confirmed final statistics',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: LectorMatchStats(
                firstTeam: 'A',
                secondTeam: 'B',
                isFinal: true,
                capturedAt: DateTime.now().subtract(const Duration(days: 4)),
                rows: const [
                  LectorMatchStatistic(label: 'Tirs', first: '0', second: '2'),
                ],
              ),
            ),
          ),
        ),
      );
      expect(
        find.textContaining(
          'statistiques finales ne sont pas encore confirmées',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Statistiques en attente d’actualisation'),
        findsNothing,
      );
    },
  );
  testWidgets('score-only match remains readable without invented statistics', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: LectorMatchStats(
              firstTeam: 'A',
              secondTeam: 'B',
              isFinal: true,
              scoreLabel: '2 – 3',
              rows: [],
            ),
          ),
        ),
      ),
    );
    expect(find.text('2 – 3'), findsOneWidget);
    expect(find.textContaining('n’a pas transmis'), findsOneWidget);
    expect(find.text('Lecture du résultat'), findsNothing);
    expect(find.text('Tirs'), findsNothing);
  });
}
