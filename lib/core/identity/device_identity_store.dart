import 'identity_scope.dart';
import 'scoped_persistence.dart';

class DeviceIdentityStore {
  const DeviceIdentityStore({this.persistence = const ScopedPersistence()});

  static const _guestIdKey = 'guest_id';
  static const _consumedGuestPrefix = 'consumed_guest';

  final ScopedPersistence persistence;

  Future<String> currentOrCreateGuestId() async {
    final existing = await persistence.read(
      const IdentityScope.device(),
      _guestIdKey,
    );
    if (existing != null && existing.trim().isNotEmpty) {
      return existing;
    }

    final guestId = _newGuestId();
    await persistence.write(const IdentityScope.device(), _guestIdKey, guestId);
    return guestId;
  }

  Future<String> rotateGuestId() async {
    final guestId = _newGuestId();
    await persistence.write(const IdentityScope.device(), _guestIdKey, guestId);
    return guestId;
  }

  Future<void> markGuestConsumed({
    required String guestId,
    required String accountUserId,
  }) async {
    await persistence.write(
      const IdentityScope.device(),
      _consumedGuestKey(guestId),
      accountUserId,
    );
  }

  Future<bool> isGuestConsumed(String guestId) async {
    final value = await persistence.read(
      const IdentityScope.device(),
      _consumedGuestKey(guestId),
    );
    return value != null && value.isNotEmpty;
  }

  Future<String> currentOrRotateConsumedGuestId() async {
    final guestId = await currentOrCreateGuestId();
    if (await isGuestConsumed(guestId)) {
      return rotateGuestId();
    }
    return guestId;
  }

  String _consumedGuestKey(String guestId) {
    return '$_consumedGuestPrefix:$guestId';
  }

  String _newGuestId() {
    return 'guest-${DateTime.now().microsecondsSinceEpoch}';
  }
}
