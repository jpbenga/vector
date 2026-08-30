import 'package:copilot/app/app.dart';
import 'package:copilot/app/view/copilot_flow_page.dart';
import 'package:copilot/core/config/app_config.dart';
import 'package:copilot/core/config/app_environment.dart';
import 'package:copilot/core/di/service_locator.dart';
import 'package:copilot/core/theme/app_theme.dart';
import 'package:copilot/features/matches/data/match_feed_repository.dart';
import 'package:copilot/features/onboarding/data/saved_decision_profile_store.dart';
import 'package:copilot/features/onboarding/domain/decision_profile.dart';
import 'package:copilot/features/tickets/data/saved_ticket_strategy_store.dart';
import 'package:copilot/features/tickets/domain/ticket_strategy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('starts with the auth entry flow before scores', (tester) async {
    await configureDependencies(
      const AppConfig(
        environment: AppEnvironment.development,
        supabaseUrl: null,
        supabaseAnonKey: null,
      ),
    );

    await tester.pumpWidget(const CopilotApp());
    await tester.pumpAndSettle();

    expect(find.text('Read the Game.'), findsOneWidget);
    expect(find.text('Continuer sans compte'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
    expect(find.text('Aperçu des matchs du jour'), findsOneWidget);
    expect(find.text('Onboarding'), findsNothing);
  });

  testWidgets('can continue locally from auth entry to scores', (tester) async {
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
        home: const CopilotFlowPage(
          repositoryOverride: DemoMatchFeedRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continuer sans compte'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 8));

    expect(find.text('Tous les matchs'), findsOneWidget);
    expect(find.text('Générateur'), findsOneWidget);
    expect(find.text('Live'), findsNothing);
    expect(find.text('A suivre aujourd’hui'), findsNothing);
    expect(find.text('Onboarding'), findsNothing);
  });

  testWidgets('keeps all matches separated from for me stories', (
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
        home: const CopilotFlowPage(
          repositoryOverride: DemoMatchFeedRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continuer sans compte'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 8));

    expect(find.text('Tous les matchs'), findsOneWidget);
    expect(find.text('A suivre aujourd’hui'), findsNothing);

    await tester.tap(find.text('Pour moi'));
    await tester.pumpAndSettle();

    expect(find.text('Ma sélection'), findsOneWidget);
    expect(find.text('A suivre aujourd’hui'), findsOneWidget);
  });

  testWidgets('opens the ticket generator from the main mode control', (
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
        home: const CopilotFlowPage(
          repositoryOverride: DemoMatchFeedRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continuer sans compte'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 8));
    await tester.tap(find.text('Générateur'));
    await tester.pumpAndSettle();

    expect(find.text('Générateur de tickets'), findsOneWidget);
    expect(find.text('Tous les matchs'), findsNothing);
    expect(find.text('Live'), findsNothing);
  });

  testWidgets(
    'uses scores directly when an existing local profile is present',
    (tester) async {
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
            repositoryOverride: const DemoMatchFeedRepository(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 8));

      expect(find.text('Continuer sans compte'), findsNothing);
      expect(find.text('Pour moi'), findsOneWidget);
    },
  );

  testWidgets('edits preferences from scores without reopening onboarding', (
    tester,
  ) async {
    await configureDependencies(
      const AppConfig(
        environment: AppEnvironment.development,
        supabaseUrl: null,
        supabaseAnonKey: null,
      ),
    );
    final profileStore = _CapturingProfileStore(
      const DecisionProfile(onboardingVersion: '2.0', answers: []),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: CopilotTheme.dark.copyWith(
          splashFactory: NoSplash.splashFactory,
        ),
        home: CopilotFlowPage(
          profileStore: profileStore,
          ticketStrategyStore: _EmptyTicketStrategyStore(),
          repositoryOverride: const DemoMatchFeedRepository(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 8));

    await tester.tap(find.byTooltip('Profil'));
    await tester.pumpAndSettle();

    expect(find.text('Paramètres Lector'), findsOneWidget);
    expect(find.text('Onboarding'), findsNothing);

    await tester.tap(find.text('Championnats').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Premier League').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer').last);
    await tester.pumpAndSettle();

    expect(profileStore.savedProfile?.optionIdsFor('competitions'), ['39']);
    expect(find.text('Onboarding'), findsNothing);
  });

  testWidgets('creates a ticket builder configuration from preferences', (
    tester,
  ) async {
    await configureDependencies(
      const AppConfig(
        environment: AppEnvironment.development,
        supabaseUrl: null,
        supabaseAnonKey: null,
      ),
    );
    final strategyStore = _CapturingTicketStrategyStore();

    await tester.pumpWidget(
      MaterialApp(
        theme: CopilotTheme.dark.copyWith(
          splashFactory: NoSplash.splashFactory,
        ),
        home: CopilotFlowPage(
          profileStore: _ProfileStoreWithExistingProfile(),
          ticketStrategyStore: strategyStore,
          repositoryOverride: const DemoMatchFeedRepository(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 8));

    await tester.tap(find.byTooltip('Profil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ticket builder').last);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('create-ticket-strategy-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-ticket-strategy-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer').last);
    await tester.pumpAndSettle();

    expect(strategyStore.savedStrategies, hasLength(1));
    expect(strategyStore.savedStrategies.single.name, 'Configuration 1');
    expect(find.text('Onboarding'), findsNothing);
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

class _CapturingProfileStore implements SavedDecisionProfileStore {
  _CapturingProfileStore(this._profile);

  DecisionProfile? _profile;
  DecisionProfile? savedProfile;

  @override
  Future<DecisionProfile?> load() async {
    return _profile;
  }

  @override
  Future<void> save(DecisionProfile profile) async {
    _profile = profile;
    savedProfile = profile;
  }
}

class _EmptyTicketStrategyStore implements SavedTicketStrategyStore {
  @override
  Future<List<TicketStrategy>> load() async => const [];

  @override
  Future<void> save(List<TicketStrategy> strategies) async {}
}

class _CapturingTicketStrategyStore implements SavedTicketStrategyStore {
  List<TicketStrategy> savedStrategies = const [];

  @override
  Future<List<TicketStrategy>> load() async => const [];

  @override
  Future<void> save(List<TicketStrategy> strategies) async {
    savedStrategies = strategies;
  }
}
