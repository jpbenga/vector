import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:copilot/features/admin/presentation/operations_page.dart';
import '../../fixtures/operations_preview.dart';

Future<void> boot(
  WidgetTester tester,
  OperationsFixtureRepository repository,
  Size size,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(home: OperationsPage(repository: repository)),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('desktop selects active batch and DAG exposes step evidence', (
    tester,
  ) async {
    final repository = OperationsFixtureRepository();
    await boot(tester, repository, const Size(1440, 1200));
    expect(find.byType(OperationsDag), findsOneWidget);
    expect(find.textContaining('25 % ·'), findsOneWidget);
    expect(find.text('Championnat Sud'), findsNWidgets(2));
    await tester.tap(
      find.descendant(
        of: find.byType(OperationsDag),
        matching: find.text('Collecte API'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('leagueFixtureRows'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('pause command persists and cancelled dialog sends nothing', (
    tester,
  ) async {
    final repository = OperationsFixtureRepository();
    await boot(tester, repository, const Size(1440, 1200));
    await tester.tap(find.text('Mettre en pause'));
    await tester.pumpAndSettle();
    expect(repository.calls, contains('ops_pause_cycle'));
    expect(find.text('Reprendre'), findsOneWidget);
    await tester.tap(find.text('Interrompre').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retour'));
    await tester.pumpAndSettle();
    expect(repository.calls, isNot(contains('ops_cancel_cycle')));
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('mobile schedule and weekly editor fit without overflow', (
    tester,
  ) async {
    final repository = OperationsFixtureRepository();
    await boot(tester, repository, const Size(390, 844));
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('Planification'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Planification'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Modifier').first);
    await tester.tap(find.text('Modifier').first);
    await tester.pumpAndSettle();
    expect(find.text('Modifier la planification'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('command errors remain visible after the next live refresh', (
    tester,
  ) async {
    final repository = OperationsFixtureRepository()..rejectCommands = true;
    await boot(tester, repository, const Size(1440, 1200));
    await tester.tap(find.text('Lancer un cycle'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.textContaining('Commande refusée'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
