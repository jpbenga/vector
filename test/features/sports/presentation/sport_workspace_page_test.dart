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
  for (final width in [360.0, 1100.0]) {
    testWidgets('sport menu stays anchored and routes at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final registry = SportWorkspaceRegistry([
        for (final entry in SportWorkspaceRegistry.defaults.entries)
          SportWorkspaceRegistration(
            definition: entry.definition,
            icon: entry.icon,
            builder: (_) => Text('Content ${entry.definition.sport.label}'),
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
      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
      );
      await tester.pumpAndSettle();
      final trigger = find.byKey(const ValueKey('sport-selector'));
      final triggerRect = tester.getRect(trigger);
      await tester.tap(trigger);
      await tester.pumpAndSettle();
      final football = find.byKey(const ValueKey('sport-option:football'));
      final hockey = find.byKey(const ValueKey('sport-option:hockey'));
      expect(tester.getRect(football).top, greaterThan(triggerRect.bottom));
      expect(tester.getSize(football).width, 236);
      expect(tester.getSize(football).height, 52);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(
        find.descendant(
          of: football,
          matching: find.byIcon(Icons.check_rounded),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('En préparation'), findsNothing);
      expect(find.textContaining('À venir'), findsNothing);
      expect(find.text('Basket'), findsNothing);
      await tester.tap(hockey);
      await tester.pumpAndSettle();
      expect(find.text('Content Hockey'), findsOneWidget);
      expect(router.routeInformationProvider.value.uri.path, '/sports/hockey');
      await tester.tap(trigger);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: hockey, matching: find.byIcon(Icons.check_rounded)),
        findsOneWidget,
      );
      await tester.tap(football);
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/');
      expect(find.text('Content Football'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the sport menu scrolls when more disciplines become available', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final registry = SportWorkspaceRegistry([
      for (final entry in SportWorkspaceRegistry.defaults.entries)
        SportWorkspaceRegistration(
          definition: entry.definition,
          icon: entry.icon,
          builder: (_) => Text('Content ${entry.definition.sport.label}'),
        ),
      for (var i = 1; i <= 10; i++)
        SportWorkspaceRegistration(
          definition: SportModuleDefinition(
            sport: SportId('discipline-$i', 'Discipline $i'),
            stage: SportModuleStage.active,
            capabilities: const {},
          ),
          icon: Icons.sports,
          builder: (_) => Text('Content discipline $i'),
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
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sport-selector')));
    await tester.pumpAndSettle();
    final lastSport = find.byKey(const ValueKey('sport-option:discipline-10'));
    await tester.ensureVisible(lastSport);
    await tester.pumpAndSettle();
    await tester.tap(lastSport);
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      '/sports/discipline-10',
    );
    expect(tester.takeException(), isNull);
  });

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
      expect(find.text('Personnalisez votre Lector'), findsOneWidget);
      await tester.tap(find.text('Tous'));
      await tester.pumpAndSettle();
      expect(find.text('Aucune rencontre hockey chargée'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('hockey-rules')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('hockey-section-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Avantage au classement'));
      await tester.pumpAndSettle();
      expect(find.text('Exemple illustratif'), findsOneWidget);
      expect(
        find.textContaining('Le premier est T1, le dernier T5'),
        findsOneWidget,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('hockey-section-2')),
      );
      await tester.tap(find.byKey(const ValueKey('hockey-section-2')));
      await tester.pumpAndSettle();
      expect(find.text('Avantages convergents'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('sport-selector')));
      await tester.pumpAndSettle();
      expect(find.text('Football'), findsOneWidget);
      expect(find.text('Basket · À venir'), findsNothing);
      expect(find.text('Hockey · En préparation'), findsNothing);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
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
