import 'package:flutter/material.dart';

import '../access/temporary_access_link_cleaner.dart';
import '../access/temporary_access_link_repository.dart';
import '../auth/auth_entry_page.dart';
import '../../core/auth/supabase_auth_controller.dart';
import '../../core/di/service_locator.dart';
import '../../core/identity/identity_controller.dart';
import '../../core/identity/identity_scope.dart';
import '../../core/identity/scoped_operation_token.dart';
import '../../core/supabase/supabase_initializer.dart';
import '../../features/matches/presentation/matches_home_page.dart';
import '../../features/matches/data/match_feed_repository.dart';
import '../../features/onboarding/data/saved_decision_profile_store.dart';
import '../../features/onboarding/domain/decision_profile.dart';
import '../../features/onboarding/domain/onboarding_completion.dart';
import '../../features/onboarding/presentation/onboarding_page.dart';
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
  bool _isEditingProfile = false;
  bool _isCheckingSavedProfile = true;
  bool _hasCompletedAuthEntry = false;
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

    if (_identityController?.isReauthRequired == true) {
      return _ReauthRequiredPage(
        onReconnect: () {
          setState(() {
            _hasCompletedAuthEntry = false;
          });
        },
        onContinueWithoutAccount: _continueWithoutAccountFromReauth,
      );
    }

    final isSignedIn =
        _identityController?.isAccount ?? _authController?.isSignedIn ?? false;
    if (!_hasCompletedAuthEntry && !isSignedIn) {
      return AuthEntryPage(
        controller: _authController,
        identityController: _identityController,
        onContinueLocal: _continueWithoutAccount,
      );
    }

    if (_isEditingProfile) {
      return OnboardingPage(
        initialProfile: profile,
        initialTicketStrategies: _ticketStrategies,
        onCancel: () {
          setState(() {
            _isEditingProfile = false;
          });
        },
        onCompleted: (completion) {
          _saveCompletion(completion);
          setState(() {
            _profile = completion.profile;
            _ticketStrategies = completion.ticketStrategies;
            _isEditingProfile = false;
          });
        },
      );
    }

    return MatchesHomePage(
      key: ValueKey<String>('matches-home:${_activeScope.stableKey}'),
      identityScope: _activeScope,
      profile: profile ?? _defaultGuestProfile,
      ticketStrategies: _ticketStrategies,
      repositoryOverride: widget.repositoryOverride,
      onProfileChanged: _saveProfilePreferences,
      onTicketStrategiesChanged: _saveTicketStrategyPreferences,
      onEditProfile: () {
        setState(() {
          _isEditingProfile = true;
        });
      },
    );
  }

  Future<void> _loadStartupState() async {
    await _identityController?.start();
    final hasTemporaryAccess = await _redeemTemporaryAccessLinkIfPresent();
    await _hydrateCurrentScope(hasTemporaryAccess: hasTemporaryAccess);
  }

  Future<void> _hydrateCurrentScope({bool hasTemporaryAccess = false}) async {
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
      _isEditingProfile = false;
      _lastHydratedScopeKey = token.scope.stableKey;
      _hasCompletedAuthEntry =
          token.scope.isAccount || hasTemporaryAccess || savedProfile != null;
    });
  }

  Future<bool> _redeemTemporaryAccessLinkIfPresent() async {
    final token = Uri.base.queryParameters['tester_token'];
    if (token == null || token.isEmpty) {
      return false;
    }

    try {
      final client = getIt<SupabaseInitializer>().client;
      if (client == null) {
        return false;
      }
      final result = await TemporaryAccessLinkRepository(client).redeem(token);
      return result.isAllowed;
    } on Object {
      return false;
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
    final status = controller?.status;
    if (_isIdentityBusy || status == IdentityStatus.reauthRequired) {
      if (!mounted) {
        return;
      }
      setState(() {
        _profile = null;
        _ticketStrategies = const [];
        _isEditingProfile = false;
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

  Future<void> _saveCompletion(OnboardingCompletion completion) async {
    final token = _operationTokenOrNull();
    if (token == null) {
      return;
    }
    await widget.profileStore.save(
      scope: token.scope,
      profile: completion.profile,
    );
    await widget.ticketStrategyStore.save(
      scope: token.scope,
      strategies: completion.ticketStrategies,
    );
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

  Future<void> _continueWithoutAccount() async {
    final token = _operationTokenOrNull();
    if (token == null) {
      return;
    }
    setState(() {
      _hasCompletedAuthEntry = true;
      _profile ??= _defaultGuestProfile;
    });

    try {
      await widget.profileStore.save(
        scope: token.scope,
        profile: _profile ?? _defaultGuestProfile,
      );
    } on Object {
      // Local persistence is a convenience; access to scores must stay open.
    }
  }

  Future<void> _continueWithoutAccountFromReauth() async {
    await _identityController?.continueWithoutAccountFromReauth();
    if (!mounted) {
      return;
    }
    setState(() {
      _hasCompletedAuthEntry = true;
      _profile ??= _defaultGuestProfile;
    });
  }
}

class _ReauthRequiredPage extends StatelessWidget {
  const _ReauthRequiredPage({
    required this.onReconnect,
    required this.onContinueWithoutAccount,
  });

  final VoidCallback onReconnect;
  final VoidCallback onContinueWithoutAccount;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Session expirée',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Reconnectez-vous pour retrouver vos données de compte, ou continuez sans compte sur cet appareil.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: onReconnect,
                  child: const Text('Se reconnecter'),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: onContinueWithoutAccount,
                  child: const Text('Continuer sans compte'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
