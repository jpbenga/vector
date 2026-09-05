import 'package:copilot/app/view/copilot_flow_page.dart';
import 'package:copilot/core/config/app_config.dart';
import 'package:copilot/core/config/app_environment.dart';
import 'package:copilot/core/di/service_locator.dart';
import 'package:copilot/core/identity/identity_scope.dart';
import 'package:copilot/core/theme/app_theme.dart';
import 'package:copilot/features/matches/data/match_feed_repository.dart';
import 'package:copilot/features/matches/presentation/lector_space_page.dart';
import 'package:copilot/features/onboarding/data/saved_decision_profile_store.dart';
import 'package:copilot/features/onboarding/domain/decision_profile.dart';
import 'package:copilot/features/onboarding/domain/decision_profile_catalogs.dart';
import 'package:copilot/features/tickets/data/saved_ticket_strategy_store.dart';
import 'package:copilot/features/tickets/domain/ticket_strategy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('starts directly in guest scores', (tester) async {
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
    await tester.pump();
    await tester.pump(const Duration(seconds: 8));

    expect(find.text('Pour moi'), findsOneWidget);
    expect(find.byTooltip('Connexion'), findsOneWidget);
    expect(find.text('Read the Game.'), findsNothing);
    expect(find.text('Continuer sans compte'), findsNothing);
    expect(find.text('Onboarding'), findsNothing);
  });

  testWidgets('guest scores expose matches without an account', (tester) async {
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

    expect(find.text('À suivre aujourd’hui'), findsOneWidget);
    expect(find.text('Générateur'), findsOneWidget);
    expect(find.text('Live'), findsNothing);
    expect(find.text('À suivre aujourd’hui'), findsOneWidget);
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

    expect(find.text('À suivre aujourd’hui'), findsOneWidget);

    await tester.tap(find.text('Tous'));
    await tester.pumpAndSettle();

    expect(find.text('Tous les matchs'), findsOneWidget);
    expect(find.text('À suivre aujourd’hui'), findsNothing);
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

    await tester.tap(find.text('Générateur'));
    await tester.pumpAndSettle();

    expect(find.text('Mes tickets'), findsOneWidget);
    expect(find.text('Tous les matchs'), findsNothing);
    expect(find.text('Live'), findsNothing);
  });

  testWidgets(
    'opens profile preferences when an active strategy lacks reading preferences',
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
            ticketStrategyStore: _ActiveTicketStrategyStore(),
            repositoryOverride: const DemoMatchFeedRepository(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 8));

      await tester.tap(find.text('Générateur'));
      await tester.pumpAndSettle();

      expect(find.text('Préférences de lecture incomplètes'), findsOneWidget);
      expect(
        find.textContaining('Votre stratégie Configuration 1 est active.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Configurer mes préférences'));
      await tester.pumpAndSettle();

      expect(find.byType(LectorSpacePage), findsOneWidget);
      expect(find.text('Mes marchés'), findsOneWidget);
      expect(find.text('Onboarding'), findsNothing);
    },
  );

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

    await tester.tap(find.byTooltip('Paramètres'));
    await tester.pumpAndSettle();

    expect(find.text('Mon espace'), findsOneWidget);
    expect(find.text('Mes compétitions'), findsOneWidget);
    expect(find.text('Onboarding'), findsNothing);

    await tester.tap(find.text('Mes compétitions').last);
    await tester.pumpAndSettle();
    expect(
      find.text('Choisissez les championnats que vous souhaitez suivre.'),
      findsOneWidget,
    );
    expect(
      find.text('Vos compétitions suivies apparaissent en premier.'),
      findsOneWidget,
    );
    expect(
      find.text('Parcourir et ajouter d’autres compétitions.'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField).last, 'Premier League');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Premier League').last);
    await tester.pumpAndSettle();

    expect(profileStore.savedProfile?.optionIdsFor('competitions'), ['39']);

    await tester.tap(find.byTooltip('Retour'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mes scénarios').last);
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Choisissez les situations de match que Lector doit rechercher pour vous.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Ils alimentent vos opportunités dans Pour moi.'),
      findsOneWidget,
    );
    expect(
      find.text('Ces scénarios sont prioritaires pour Lector.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Dominations attendues').last);
    await tester.pumpAndSettle();

    expect(profileStore.savedProfile?.optionIdsFor('opportunity_profiles'), [
      'solid_favorite',
    ]);
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

    await tester.tap(find.byTooltip('Paramètres'));
    await tester.pumpAndSettle();
    expect(find.text('Mon espace'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -180));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mes stratégies').last);
    await tester.pumpAndSettle();
    expect(
      find.text('Vos différentes configurations de tickets.'),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('create-ticket-strategy-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-ticket-strategy-button')));
    await tester.pumpAndSettle();

    expect(strategyStore.savedStrategies, hasLength(1));
    expect(strategyStore.savedStrategies.single.name, 'Configuration 1');
    expect(find.text('Onboarding'), findsNothing);
  });
}

class _ProfileStoreWithExistingProfile implements SavedDecisionProfileStore {
  @override
  Future<DecisionProfile?> load({required IdentityScope scope}) async {
    return const DecisionProfile(onboardingVersion: '2.0', answers: []);
  }

  @override
  Future<void> save({
    required IdentityScope scope,
    required DecisionProfile profile,
  }) async {}
}

class _CapturingProfileStore implements SavedDecisionProfileStore {
  _CapturingProfileStore(this._profile);

  DecisionProfile? _profile;
  DecisionProfile? savedProfile;

  @override
  Future<DecisionProfile?> load({required IdentityScope scope}) async {
    return _profile;
  }

  @override
  Future<void> save({
    required IdentityScope scope,
    required DecisionProfile profile,
  }) async {
    _profile = profile;
    savedProfile = profile;
  }
}

class _EmptyTicketStrategyStore implements SavedTicketStrategyStore {
  @override
  Future<List<TicketStrategy>> load({required IdentityScope scope}) async =>
      const [];

  @override
  Future<void> save({
    required IdentityScope scope,
    required List<TicketStrategy> strategies,
  }) async {}
}

class _CapturingTicketStrategyStore implements SavedTicketStrategyStore {
  List<TicketStrategy> savedStrategies = const [];

  @override
  Future<List<TicketStrategy>> load({required IdentityScope scope}) async =>
      const [];

  @override
  Future<void> save({
    required IdentityScope scope,
    required List<TicketStrategy> strategies,
  }) async {
    savedStrategies = strategies;
  }
}

class _ActiveTicketStrategyStore implements SavedTicketStrategyStore {
  @override
  Future<List<TicketStrategy>> load({required IdentityScope scope}) async => [
    TicketStrategy(
      schemaVersion: TicketStrategy.currentSchemaVersion,
      id: 'configuration-1',
      userId: '',
      name: 'Configuration 1',
      isActive: true,
      pickTypes: const [PickType.normal],
      minimumIndividualOdds: 1.45,
      maximumIndividualOdds: 1.80,
      minimumSelections: 2,
      maximumSelections: 3,
      minimumTotalOdds: 2,
      maximumTotalOdds: 3,
      priority: 0,
      createdAt: DateTime.utc(2026, 9, 4),
      updatedAt: DateTime.utc(2026, 9, 4),
    ),
  ];

  @override
  Future<void> save({
    required IdentityScope scope,
    required List<TicketStrategy> strategies,
  }) async {}
}
