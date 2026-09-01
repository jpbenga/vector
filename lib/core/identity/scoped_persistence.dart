import '../persistence/local_key_value_store.dart';
import 'identity_scope.dart';

class ScopedPersistence {
  const ScopedPersistence({LocalKeyValueStore? store})
    : _store = store ?? const PlatformLocalKeyValueStore();

  final LocalKeyValueStore _store;

  String keyFor(IdentityScope scope, String dataKey) {
    final normalizedDataKey = _normalizePart(dataKey);
    return switch (scope.kind) {
      IdentityScopeKind.device => 'lector:device:$normalizedDataKey',
      IdentityScopeKind.guest =>
        'lector:guest:${_normalizePart(scope.id)}:$normalizedDataKey',
      IdentityScopeKind.account =>
        'lector:account:${_normalizePart(scope.id)}:$normalizedDataKey',
      IdentityScopeKind.legacyUnowned =>
        'lector:legacy_unowned:$normalizedDataKey',
    };
  }

  Future<String?> read(IdentityScope scope, String dataKey) {
    return _store.read(keyFor(scope, dataKey));
  }

  Future<void> write(IdentityScope scope, String dataKey, String value) {
    return _store.write(keyFor(scope, dataKey), value);
  }

  Future<void> delete(IdentityScope scope, String dataKey) {
    return _store.delete(keyFor(scope, dataKey));
  }

  static String _normalizePart(String value) {
    final normalized = Uri.encodeComponent(value.trim());
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, 'value', 'Identity key part is empty.');
    }
    return normalized;
  }
}
