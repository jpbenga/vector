import 'package:copilot/app/router/app_router.dart';
import 'package:copilot/app/sports/sport_workspace_registry.dart';
import 'package:copilot/core/sports/domain/sport.dart';
import 'package:copilot/core/sports/domain/sport_module.dart';
import 'package:copilot/core/sports/domain/sport_feed_repository.dart';
import 'package:copilot/app/theme/app_theme.dart';
import 'package:copilot/core/config/app_config.dart';
import 'package:copilot/core/config/app_environment.dart';
import 'package:copilot/features/hockey/presentation/hockey_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('fr'));
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
  testWidgets(
    'a new module routes without hockey fallback and unknown sports stay navigable',
    (tester) async {
      const volleyball = SportId('volleyball', 'Volley');
      final registry = SportWorkspaceRegistry([
        ...SportWorkspaceRegistry.defaults.entries,
        SportWorkspaceRegistration(
          definition: const SportModuleDefinition(
            sport: volleyball,
            stage: SportModuleStage.preparation,
            capabilities: {},
          ),
          icon: Icons.sports_volleyball,
          builder: (_) => const Center(child: Text('Workspace Volley')),
        ),
      ]);
      final router = createAppRouter(
        const AppConfig(
          environment: AppEnvironment.development,
          supabaseUrl: null,
          supabaseAnonKey: null,
        ),
        sports: registry,
      );
      addTearDown(router.dispose);
      router.go('/sports/volleyball');
      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
      );
      await tester.pumpAndSettle();
      expect(find.text('Workspace Volley'), findsOneWidget);
      expect(find.byType(HockeyWorkspace), findsNothing);
      expect(
        (await registry.loadFeed(
          'hockey',
          DateTime(2026, 10, 4),
        )).unavailableReason,
        SportFeedUnavailableReason.notConnected,
      );
      router.go('/sports/basketball');
      await tester.pumpAndSettle();
      expect(find.text('Basket · À venir'), findsOneWidget);
      expect(find.byType(HockeyWorkspace), findsNothing);
      router.go('/sports/unregistered');
      await tester.pumpAndSettle();
      expect(find.text('Sport indisponible'), findsOneWidget);
      expect(find.text('Revenir au football'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
