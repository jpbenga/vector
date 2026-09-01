import 'package:flutter/foundation.dart';

import '../auth/supabase_auth_controller.dart';
import 'device_identity_store.dart';
import 'guest_account_migration_service.dart';
import 'identity_scope.dart';
import 'scoped_operation_token.dart';

enum IdentityStatus {
  resolving,
  guest,
  authenticating,
  creatingAccount,
  migratingGuestToNewAccount,
  account,
  loggingOut,
  reauthRequired,
  authFailed,
}

class IdentityController extends ChangeNotifier {
  IdentityController({
    required SupabaseAuthController authController,
    DeviceIdentityStore deviceIdentityStore = const DeviceIdentityStore(),
    GuestAccountMigrationService migrationService =
        const GuestAccountMigrationService(),
  }) : _authController = authController,
       _deviceIdentityStore = deviceIdentityStore,
       _migrationService = migrationService;

  final SupabaseAuthController _authController;
  final DeviceIdentityStore _deviceIdentityStore;
  final GuestAccountMigrationService _migrationService;

  IdentityStatus _status = IdentityStatus.resolving;
  IdentityScope? _scope;
  IdentityScope? _lastAccountScope;
  bool _started = false;
  bool _isVoluntaryLogout = false;
  int _revision = 0;

  IdentityStatus get status => _status;
  IdentityScope? get scope => _scope;
  IdentityScope? get lastAccountScope => _lastAccountScope;
  int get revision => _revision;

  bool get isResolving => _status == IdentityStatus.resolving;
  bool get isGuest => _scope?.isGuest == true;
  bool get isAccount => _scope?.isAccount == true;
  bool get isReauthRequired => _status == IdentityStatus.reauthRequired;

  Future<void> start() async {
    if (_started) {
      return;
    }
    _started = true;
    _authController.addListener(_handleAuthChange);
    await _resolveInitialScope();
  }

  ScopedOperationToken operationToken() {
    final activeScope = _scope;
    if (activeScope == null) {
      throw StateError('No active identity scope.');
    }
    return ScopedOperationToken(scope: activeScope, revision: _revision);
  }

  bool isCurrent(ScopedOperationToken token) {
    return _scope == token.scope &&
        _revision == token.revision &&
        _status != IdentityStatus.loggingOut &&
        _status != IdentityStatus.resolving &&
        _status != IdentityStatus.reauthRequired;
  }

  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    _setStatus(IdentityStatus.authenticating);
    try {
      await _authController.signInWithPassword(
        email: email,
        password: password,
      );
      final user = _authController.user;
      if (user == null) {
        _setStatus(IdentityStatus.authFailed);
        return;
      }
      _activateAccount(user.id);
    } on Object {
      await _restoreGuestAfterAuthFailure();
      rethrow;
    }
  }

  Future<void> signUpWithPassword({
    required String email,
    required String password,
  }) async {
    final guestScope = _scope?.isGuest == true ? _scope : null;
    _setStatus(IdentityStatus.creatingAccount);
    try {
      await _authController.signUpWithPassword(
        email: email,
        password: password,
      );
      final user = _authController.user;
      if (user == null) {
        _setStatus(IdentityStatus.authFailed);
        return;
      }

      final accountScope = IdentityScope.account(user.id);
      if (guestScope != null) {
        _setStatus(IdentityStatus.migratingGuestToNewAccount);
        await _migrationService.migrateGuestToNewAccount(
          guestScope: guestScope,
          accountScope: accountScope,
        );
        await _deviceIdentityStore.markGuestConsumed(
          guestId: guestScope.id,
          accountUserId: user.id,
        );
      }
      _activateAccount(user.id);
    } on Object {
      await _restoreGuestAfterAuthFailure();
      rethrow;
    }
  }

  Future<void> signInWithGoogle() async {
    _setStatus(IdentityStatus.authenticating);
    try {
      await _authController.signInWithGoogle();
      final user = _authController.user;
      if (user != null) {
        _activateAccount(user.id);
      } else {
        await _restoreGuestAfterAuthFailure();
      }
    } on Object {
      await _restoreGuestAfterAuthFailure();
      rethrow;
    }
  }

  Future<void> signOut() async {
    _isVoluntaryLogout = true;
    _status = IdentityStatus.loggingOut;
    _scope = null;
    _revision++;
    notifyListeners();

    try {
      await _authController.signOut();
    } finally {
      final guestId = await _deviceIdentityStore.currentOrRotateConsumedGuestId();
      _isVoluntaryLogout = false;
      _activateGuest(guestId);
    }
  }

  Future<void> continueWithoutAccountFromReauth() async {
    _isVoluntaryLogout = true;
    try {
      if (_authController.isSignedIn) {
        await _authController.signOut();
      }
    } finally {
      final guestId = await _deviceIdentityStore.currentOrRotateConsumedGuestId();
      _isVoluntaryLogout = false;
      _activateGuest(guestId);
    }
  }

  Future<void> _resolveInitialScope() async {
    final user = _authController.user;
    if (user != null) {
      _activateAccount(user.id);
      return;
    }

    final guestId = await _deviceIdentityStore.currentOrRotateConsumedGuestId();
    _activateGuest(guestId);
  }

  void _handleAuthChange() {
    if (_isVoluntaryLogout) {
      return;
    }

    final user = _authController.user;
    if (user != null) {
      if (_scope != IdentityScope.account(user.id)) {
        _activateAccount(user.id);
      }
      return;
    }

    final currentScope = _scope;
    if (currentScope != null && currentScope.isAccount) {
      _lastAccountScope = currentScope;
      _scope = null;
      _status = IdentityStatus.reauthRequired;
      _revision++;
      notifyListeners();
    }
  }

  Future<void> _restoreGuestAfterAuthFailure() async {
    final guestId = await _deviceIdentityStore.currentOrRotateConsumedGuestId();
    _activateGuest(guestId);
  }

  void _activateGuest(String guestId) {
    _scope = IdentityScope.guest(guestId);
    _status = IdentityStatus.guest;
    _revision++;
    notifyListeners();
  }

  void _activateAccount(String userId) {
    _scope = IdentityScope.account(userId);
    _lastAccountScope = _scope;
    _status = IdentityStatus.account;
    _revision++;
    notifyListeners();
  }

  void _setStatus(IdentityStatus status) {
    if (_status == status) {
      return;
    }
    _status = status;
    _revision++;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_started) {
      _authController.removeListener(_handleAuthChange);
    }
    super.dispose();
  }
}
