import 'package:copilot/app/router/app_router.dart';
import 'package:copilot/app/theme/app_theme.dart';
import 'package:copilot/core/config/app_config.dart';
import 'package:copilot/core/config/app_environment.dart';
import 'package:copilot/features/hockey/presentation/hockey_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'hockey workspace explains draft readings without loading football',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final router = createAppRouter(
        const AppConfig(
          environment: AppEnvironment.development,
          supabaseUrl: null,
          supabaseAnonKey: null,
        ),
      );
      addTearDown(router.dispose);
      router.go('/sports/hockey');
      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
      );
      await tester.pumpAndSettle();
      expect(find.byType(HockeyWorkspace), findsOneWidget);
      expect(find.text('Aucune rencontre hockey chargée'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('hockey-section-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Avantage au classement'));
      await tester.pumpAndSettle();
      expect(find.text('Exemple illustratif'), findsOneWidget);
      expect(find.textContaining('16 points sur 20'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('hockey-section-2')),
      );
      await tester.tap(find.byKey(const ValueKey('hockey-section-2')));
      await tester.pumpAndSettle();
      expect(find.text('Avantages convergents'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('sport-selector')));
      await tester.pumpAndSettle();
      expect(find.text('Football'), findsOneWidget);
      expect(find.text('Basket · À venir'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
