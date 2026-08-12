import 'package:flutter/material.dart';

import '../auth/auth_entry_page.dart';
import '../../core/auth/supabase_auth_controller.dart';
import '../../core/di/service_locator.dart';
import '../../features/matches/presentation/matches_home_page.dart';
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
    super.key,
  });

  final SavedDecisionProfileStore profileStore;
  final SavedTicketStrategyStore ticketStrategyStore;

  @override
  State<CopilotFlowPage> createState() => _CopilotFlowPageState();
}

class _CopilotFlowPageState extends State<CopilotFlowPage> {
  SupabaseAuthController? _authController;
  DecisionProfile? _profile;
  List<TicketStrategy> _ticketStrategies = const [];
  bool _isEditingProfile = false;
  bool _isCheckingSavedProfile = true;
  bool _hasCompletedAuthEntry = false;
  String? _lastSyncedUserId;

  @override
  void initState() {
    super.initState();
    if (getIt.isRegistered<SupabaseAuthController>()) {
      _authController = getIt<SupabaseAuthController>()
        ..addListener(_handleAuthChange);
      _lastSyncedUserId = _authController?.user?.id;
    }
    _checkSavedProfile();
  }

  @override
  void dispose() {
    _authController?.removeListener(_handleAuthChange);
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
    if (isResolvingOAuthRedirect) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isSignedIn = _authController?.isSignedIn ?? false;
    if (!_hasCompletedAuthEntry && !isSignedIn) {
      return AuthEntryPage(
        controller: _authController,
        onContinueLocal: () {
          setState(() {
            _hasCompletedAuthEntry = true;
          });
        },
      );
    }

    if (profile == null) {
      return OnboardingPage(
        onCancel: _cancelOnboardingWithoutSaving,
        onCompleted: (completion) {
          _saveCompletion(completion);
          setState(() {
            _profile = completion.profile;
            _ticketStrategies = completion.ticketStrategies;
          });
        },
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
      key: ValueKey<String>('matches-home:${_lastSyncedUserId ?? 'guest'}'),
      profile: profile,
      ticketStrategies: _ticketStrategies,
      onEditProfile: () {
        setState(() {
          _isEditingProfile = true;
        });
      },
    );
  }

  Future<void> _checkSavedProfile() async {
    final savedProfile = await widget.profileStore.load();
    final savedStrategies = await widget.ticketStrategyStore.load();
    if (!mounted) {
      return;
    }

    setState(() {
      _ticketStrategies = savedStrategies;
      _isCheckingSavedProfile = false;
    });

    if (savedProfile == null) {
      return;
    }

    setState(() {
      _profile = savedProfile;
    });
  }

  void _handleAuthChange() {
    final userId = _authController?.user?.id;
    if (userId == _lastSyncedUserId) {
      return;
    }

    _lastSyncedUserId = userId;
    if (userId == null) {
      setState(() {
        _hasCompletedAuthEntry = true;
        _isEditingProfile = false;
      });
      return;
    }

    _reloadPersistedStateAfterSignIn();
  }

  Future<void> _reloadPersistedStateAfterSignIn() async {
    final savedProfile = await widget.profileStore.load();
    final savedStrategies = await widget.ticketStrategyStore.load();
    if (!mounted) {
      return;
    }

    setState(() {
      _hasCompletedAuthEntry = true;
      if (savedProfile != null) {
        _profile = savedProfile;
      }
      _ticketStrategies = savedStrategies;
      _isEditingProfile = false;
    });
  }

  Future<void> _saveCompletion(OnboardingCompletion completion) async {
    await widget.profileStore.save(completion.profile);
    await widget.ticketStrategyStore.save(completion.ticketStrategies);
  }

  void _cancelOnboardingWithoutSaving() {
    setState(() {
      _profile = const DecisionProfile(onboardingVersion: '2.0', answers: []);
      _ticketStrategies = const [];
      _isEditingProfile = false;
    });
  }
}
