import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/identity/identity_scope.dart';
import '../../../core/identity/scoped_data_keys.dart';
import '../../../core/identity/scoped_persistence.dart';
import '../../../core/supabase/supabase_initializer.dart';
import '../domain/decision_profile.dart';
import 'supabase_decision_profile_repository.dart';

class SavedDecisionProfileStore {
  const SavedDecisionProfileStore({this.persistence});

  static const legacyStorageKey = 'vector.saved_decision_profile.v1';
  static const legacyCookieKey = 'vector_saved_decision_profile_v1';

  final ScopedPersistence? persistence;

  Future<DecisionProfile?> load({required IdentityScope scope}) async {
    _ensureUserOwned(scope);
    if (scope.isGuest) {
      return _loadLocal(scope);
    }

    try {
      final remoteRepository = SupabaseDecisionProfileRepository(
        client: _accountClient(),
        scope: scope,
      );
      final remoteProfile = await remoteRepository.load();
      if (remoteProfile == null) {
        await _scopedPersistence.delete(scope, ScopedDataKeys.decisionProfile);
        return null;
      }

      await _saveLocal(scope, remoteProfile);
      return remoteProfile;
    } on Object catch (error) {
      debugPrint('Remote decision profile load failed: $error');
      return _loadLocal(scope);
    }
  }

  Future<void> save({
    required IdentityScope scope,
    required DecisionProfile profile,
  }) async {
    _ensureUserOwned(scope);
    if (scope.isGuest) {
      await _saveLocal(scope, profile);
      return;
    }

    try {
      await SupabaseDecisionProfileRepository(
        client: _accountClient(),
        scope: scope,
      ).save(profile);
      await _saveLocal(scope, profile);
    } on Object catch (error) {
      debugPrint('Remote decision profile save failed: $error');
      rethrow;
    }
  }

  ScopedPersistence get _scopedPersistence =>
      persistence ?? const ScopedPersistence();

  Future<DecisionProfile?> _loadLocal(IdentityScope scope) async {
    final raw = await _scopedPersistence.read(
      scope,
      ScopedDataKeys.decisionProfile,
    );
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(Uri.decodeComponent(raw));
      if (decoded is! Map<String, Object?>) {
        return null;
      }

      return DecisionProfile.fromJson(decoded);
    } on FormatException {
      return null;
    }
  }

  Future<void> _saveLocal(IdentityScope scope, DecisionProfile profile) async {
    final encoded = Uri.encodeComponent(jsonEncode(profile.toJson()));
    await _scopedPersistence.write(
      scope,
      ScopedDataKeys.decisionProfile,
      encoded,
    );
  }

  SupabaseClient _accountClient() {
    final client = getIt<SupabaseInitializer>().client;
    if (client == null) {
      throw StateError('Supabase is not configured.');
    }
    return client;
  }

  void _ensureUserOwned(IdentityScope scope) {
    if (!scope.isUserOwned) {
      throw ArgumentError.value(scope, 'scope', 'Must be guest or account.');
    }
  }
}
