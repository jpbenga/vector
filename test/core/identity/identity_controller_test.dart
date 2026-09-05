import 'package:copilot/core/auth/supabase_auth_controller.dart';
import 'package:copilot/core/config/app_config.dart';
import 'package:copilot/core/config/app_environment.dart';
import 'package:copilot/core/identity/device_identity_store.dart';
import 'package:copilot/core/identity/identity_controller.dart';
import 'package:copilot/core/identity/identity_scope.dart';
import 'package:copilot/core/supabase/supabase_initializer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('an expired account session moves directly to guest mode', () async {
    final authController = _FakeAuthController(user: _accountUser);
    final controller = IdentityController(
      authController: authController,
      deviceIdentityStore: const _FakeDeviceIdentityStore('guest-after-expiry'),
    );
    addTearDown(controller.dispose);

    await controller.start();
    expect(controller.scope, const IdentityScope.account('account-1'));
    expect(controller.status, IdentityStatus.account);

    authController.expireSession();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(controller.scope, const IdentityScope.guest('guest-after-expiry'));
    expect(controller.status, IdentityStatus.guest);
    expect(
      controller.lastAccountScope,
      const IdentityScope.account('account-1'),
    );
  });
}

const _config = AppConfig(
  environment: AppEnvironment.development,
  supabaseUrl: null,
  supabaseAnonKey: null,
);

final _accountUser = User(
  id: 'account-1',
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  email: 'account@example.com',
  createdAt: '2026-09-04T00:00:00.000Z',
);

class _FakeAuthController extends SupabaseAuthController {
  _FakeAuthController({User? user})
    : currentUser = user,
      super(SupabaseInitializer(_config), _config);

  User? currentUser;

  @override
  User? get user => currentUser;

  @override
  bool get isSignedIn => currentUser != null;

  void expireSession() {
    currentUser = null;
    notifyListeners();
  }
}

class _FakeDeviceIdentityStore extends DeviceIdentityStore {
  const _FakeDeviceIdentityStore(this.guestId);

  final String guestId;

  @override
  Future<String> currentOrRotateConsumedGuestId() async => guestId;
}
