import 'package:flutter/material.dart';

import '../access/temporary_access_link_cleaner.dart';
import '../access/temporary_access_link_repository.dart';
import '../../core/auth/supabase_auth_controller.dart';
import '../../core/debug/runtime_personalization_diagnostic.dart';
import '../../core/di/service_locator.dart';
import '../../core/identity/identity_controller.dart';
import '../../core/identity/identity_scope.dart';
import '../../core/identity/scoped_operation_token.dart';
import '../../core/supabase/supabase_initializer.dart';
import '../../features/matches/presentation/matches_home_page.dart';
import '../../features/matches/data/match_feed_repository.dart';
import '../../features/onboarding/data/saved_decision_profile_store.dart';
import '../../features/onboarding/domain/decision_profile.dart';
import '../../features/tickets/data/saved_ticket_strategy_store.dart';
import '../../features/tickets/domain/ticket_strategy.dart';

class CopilotFlowPage extends StatefulWidget {
  const CopilotFlowPage({
    this.profileStore = const SavedDecisionProfileStore(),
    this.ticketStrategyStore = const SavedTicketStrategyStore(),
    this.repositoryOverride,
    super.key,
  });

  final SavedDecisionProfileStore profileStore;
  final SavedTicketStrategyStore ticketStrategyStore;
  final MatchFeedRepository? repositoryOverride;

  @override
  State<CopilotFlowPage> createState() => _CopilotFlowPageState();
}

class _CopilotFlowPageState extends State<CopilotFlowPage> {
  static const _defaultGuestProfile = DecisionProfile(
    onboardingVersion: '2.0',
    answers: [],
  );

  SupabaseAuthController? _authController;
  IdentityController? _identityController;
  DecisionProfile? _profile;
  List<TicketStrategy> _ticketStrategies = const [];
  bool _isCheckingSavedProfile = true;
  String? _lastHydratedScopeKey;

  @override
  void initState() {
    super.initState();
    if (getIt.isRegistered<SupabaseAuthController>()) {
      _authController = getIt<SupabaseAuthController>();
    }
    if (getIt.isRegistered<IdentityController>()) {
      _identityController = getIt<IdentityController>()
        ..addListener(_handleIdentityChange);
    }
    _loadStartupState();
  }

  @override
  void dispose() {
    _identityController?.removeListener(_handleIdentityChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;

    if (_isCheckingSavedProfile) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isResolvingOAuthRedirect =
        _authController?.isResolvingOAuthRedirect ?? false;
    if (isResolvingOAuthRedirect || _isIdentityBusy) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return MatchesHomePage(
      key: ValueKey<String>('matches-home:${_activeScope.stableKey}'),
      identityScope: _activeScope,
      profile: profile ?? _defaultGuestProfile,
      ticketStrategies: _ticketStrategies,
      repositoryOverride: widget.repositoryOverride,
      onProfileChanged: _saveProfilePreferences,
      onTicketStrategiesChanged: _saveTicketStrategyPreferences,
      // Configuration now lives in Mon espace. The old onboarding screen is
      // retained only as a historical component, never as an active route.
      onEditProfile: () {},
    );
  }

  Future<void> _loadStartupState() async {
    await _identityController?.start();
    await _redeemTemporaryAccessLinkIfPresent();
    await _hydrateCurrentScope();
  }

  Future<void> _hydrateCurrentScope() async {
    final token = _operationTokenOrNull();
    if (token == null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _profile = null;
        _ticketStrategies = const [];
        _isCheckingSavedProfile = false;
      });
      return;
    }

    final savedProfile = await widget.profileStore.load(scope: token.scope);
    final savedStrategies = await widget.ticketStrategyStore.load(
      scope: token.scope,
    );
    if (!mounted) {
      return;
    }
    if (!_isTokenCurrent(token)) {
      return;
    }

    setState(() {
      _profile = savedProfile;
      _ticketStrategies = savedStrategies;
      _isCheckingSavedProfile = false;
      _lastHydratedScopeKey = token.scope.stableKey;
    });
    RuntimePersonalizationDiagnostic.instance.recordLifecycle(
      'compiled profile created',
      fields: {
        'scope': token.scope.stableKey,
        'profilePresent': savedProfile != null,
      },
    );
  }

  Future<void> _redeemTemporaryAccessLinkIfPresent() async {
    final token = Uri.base.queryParameters['tester_token'];
    if (token == null || token.isEmpty) {
      return;
    }

    try {
      final client = getIt<SupabaseInitializer>().client;
      if (client == null) {
        return;
      }
      await TemporaryAccessLinkRepository(client).redeem(token);
    } on Object {
      return;
    } finally {
      cleanTemporaryAccessLinkUrl();
    }
  }

  bool get _isIdentityBusy {
    final status = _identityController?.status;
    return status == IdentityStatus.resolving ||
        status == IdentityStatus.authenticating ||
        status == IdentityStatus.creatingAccount ||
        status == IdentityStatus.migratingGuestToNewAccount ||
        status == IdentityStatus.loggingOut;
  }

  IdentityScope get _activeScope {
    return _identityController?.scope ?? const IdentityScope.guest('local');
  }

  ScopedOperationToken? _operationTokenOrNull() {
    try {
      return _identityController?.operationToken() ??
          ScopedOperationToken(scope: _activeScope, revision: 0);
    } on StateError {
      return null;
    }
  }

  bool _isTokenCurrent(ScopedOperationToken token) {
    final controller = _identityController;
    if (controller == null) {
      return true;
    }
    return controller.isCurrent(token);
  }

  void _handleIdentityChange() {
    final controller = _identityController;
    final scope = controller?.scope;
    if (_isIdentityBusy) {
      if (!mounted) {
        return;
      }
      setState(() {
        _profile = null;
        _ticketStrategies = const [];
        _isCheckingSavedProfile = _isIdentityBusy;
      });
      return;
    }

    if (scope == null || scope.stableKey == _lastHydratedScopeKey) {
      return;
    }

    setState(() {
      _profile = null;
      _ticketStrategies = const [];
      _isCheckingSavedProfile = true;
    });
    _hydrateCurrentScope();
  }

  Future<void> _saveProfilePreferences(DecisionProfile profile) async {
    final token = _operationTokenOrNull();
    if (token == null) {
      return;
    }
    setState(() {
      _profile = profile;
    });

    await widget.profileStore.save(scope: token.scope, profile: profile);
  }

  Future<void> _saveTicketStrategyPreferences(
    List<TicketStrategy> strategies,
  ) async {
    final token = _operationTokenOrNull();
    if (token == null) {
      return;
    }
    setState(() {
      _ticketStrategies = strategies;
    });

    await widget.ticketStrategyStore.save(
      scope: token.scope,
      strategies: strategies,
    );
  }
}
