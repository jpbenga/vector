import 'package:copilot/app/app.dart';
import 'package:copilot/app/view/copilot_flow_page.dart';
import 'package:copilot/core/config/app_config.dart';
import 'package:copilot/core/config/app_environment.dart';
import 'package:copilot/core/di/service_locator.dart';
import 'package:copilot/core/theme/app_theme.dart';
import 'package:copilot/features/onboarding/data/saved_decision_profile_store.dart';
import 'package:copilot/features/onboarding/domain/decision_profile.dart';
import 'package:copilot/features/tickets/data/saved_ticket_strategy_store.dart';
import 'package:copilot/features/tickets/domain/ticket_strategy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('starts with the auth entry flow before onboarding', (
    tester,
  ) async {
    await configureDependencies(
      const AppConfig(
        environment: AppEnvironment.development,
        supabaseUrl: null,
        supabaseAnonKey: null,
      ),
    );

    await tester.pumpWidget(const CopilotApp());
    await tester.pumpAndSettle();

    expect(find.text('LECTOR SPORT'), findsOneWidget);
    expect(find.text('Read the Game.'), findsOneWidget);
    expect(find.text('Commencer'), findsOneWidget);
    expect(find.text('Onboarding'), findsNothing);
  });

  testWidgets('can continue locally from auth entry to onboarding', (
    tester,
  ) async {
    await configureDependencies(
      const AppConfig(
        environment: AppEnvironment.development,
        supabaseUrl: null,
        supabaseAnonKey: null,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: CopilotTheme.dark.copyWith(
          splashFactory: NoSplash.splashFactory,
        ),
        home: const CopilotFlowPage(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Commencer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuer sans compte'));
    await tester.pumpAndSettle();

    expect(find.text('Onboarding'), findsOneWidget);
    expect(find.text('Followed competitions'), findsOneWidget);
  });

  testWidgets('requires auth entry before using an existing local profile', (
    tester,
  ) async {
    await configureDependencies(
      const AppConfig(
        environment: AppEnvironment.development,
        supabaseUrl: null,
        supabaseAnonKey: null,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: CopilotTheme.dark.copyWith(
          splashFactory: NoSplash.splashFactory,
        ),
        home: CopilotFlowPage(
          profileStore: _ProfileStoreWithExistingProfile(),
          ticketStrategyStore: _EmptyTicketStrategyStore(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('LECTOR SPORT'), findsOneWidget);
    expect(find.text('Commencer'), findsOneWidget);
    expect(find.text('Pour moi'), findsNothing);
  });
}

class _ProfileStoreWithExistingProfile implements SavedDecisionProfileStore {
  @override
  Future<DecisionProfile?> load() async {
    return const DecisionProfile(onboardingVersion: '2.0', answers: []);
  }

  @override
  Future<void> save(DecisionProfile profile) async {}
}

class _EmptyTicketStrategyStore implements SavedTicketStrategyStore {
  @override
  Future<List<TicketStrategy>> load() async => const [];

  @override
  Future<void> save(List<TicketStrategy> strategies) async {}
}
