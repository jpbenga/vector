import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:copilot/features/admin/domain/operations_models.dart';
import 'package:copilot/features/admin/presentation/operations_history.dart';
import 'package:copilot/features/admin/presentation/operations_issue_card.dart';

const technical =
    'sync-match-results failed with 500: Missing api_football_sync_run_id for quota reservation';
OpsOverview fixture(int length) => OpsOverview({
  'cycles': <Map<String, dynamic>>[],
  'audit': <Map<String, dynamic>>[],
  'competitions': [
    for (var i = 0; i < length; i++) {'league_id': i, 'name': 'Compétition $i'},
  ],
  'legacy': [
    for (var i = 0; i < length; i++)
      {
        'id': 'run-$i',
        'league_ids': [i],
        'status': i == 12 ? 'failed' : 'succeeded',
        'started_at': '2026-10-01T09:00:00Z',
        if (i == 12) 'error_message': technical,
      },
  ],
});
Future<void> showHistory(
  WidgetTester tester, {
  Size size = const Size(1300, 1000),
  int length = 23,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: OperationsHistory(data: fixture(length), onCycle: (_) {}),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'history separates successful and failed runs with independent pagination',
    (tester) async {
      await showHistory(tester);
      expect(find.text('En erreur (1)'), findsOneWidget);
      expect(find.text('Réussis (22)'), findsOneWidget);
      expect(find.text('Compétition 0'), findsOneWidget);
      expect(find.text('Compétition 10'), findsNothing);
      expect(find.textContaining('ancien système'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('succeeded-next')));
      await tester.pumpAndSettle();
      expect(find.text('Compétition 10'), findsOneWidget);
      expect(find.text('Compétition 0'), findsNothing);
      expect(
        find.text('Lien entre la collecte et les résultats manquant'),
        findsOneWidget,
      );
      expect(find.text(technical), findsNothing);
      expect(find.text('Compétition 12'), findsOneWidget);
      await tester.ensureVisible(find.text('Détail technique'));
      await tester.tap(find.text('Détail technique'));
      await tester.pumpAndSettle();
      expect(find.text(technical), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('mobile pagination and search fit the viewport', (tester) async {
    await showHistory(tester, size: const Size(390, 844));
    await tester.enterText(find.byType(TextField), 'Compétition 22');
    await tester.pumpAndSettle();
    expect(find.text('Compétition 22'), findsNWidgets(2));
    expect(find.text('1–1 sur 1 · Page 1/1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    '401 explains session failure and offers reconnection without exposing raw details',
    (tester) async {
      var reconnected = false;
      const message =
          'FunctionException(status: 401, details: {error: Invalid user token.})';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OperationsIssueCard(
              message: message,
              adminRequest: true,
              onReconnect: () => reconnected = true,
            ),
          ),
        ),
      );
      expect(find.text('Session de connexion refusée'), findsOneWidget);
      expect(find.text(message), findsNothing);
      await tester.tap(find.text('Se reconnecter'));
      expect(reconnected, isTrue);
    },
  );
}
