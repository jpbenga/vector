import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/debug/runtime_personalization_diagnostic.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/identity/identity_scope.dart';
import '../../../core/identity/scoped_data_keys.dart';
import '../../../core/identity/scoped_persistence.dart';
import '../../../core/supabase/supabase_initializer.dart';
import '../domain/decision_profile.dart';
import '../domain/profile_compiler.dart';
import 'supabase_decision_profile_repository.dart';

class SavedDecisionProfileStore {
  const SavedDecisionProfileStore({this.persistence});

  static const legacyStorageKey = 'vector.saved_decision_profile.v1';
  static const legacyCookieKey = 'vector_saved_decision_profile_v1';

  final ScopedPersistence? persistence;

  Future<DecisionProfile?> load({required IdentityScope scope}) async {
    _ensureUserOwned(scope);
    if (scope.isGuest) {
      final local = await _loadLocal(scope);
      _traceLoad(
        source: 'local state',
        scope: scope,
        persistedProfile: local,
        effectiveProfile: local,
        fallbackApplied: false,
        fallbackReason: 'guest scope',
      );
      return local;
    }

    try {
      RuntimePersonalizationDiagnostic.instance.recordLifecycle(
        'profile fetch started',
        fields: {'scope': scope.stableKey},
      );
      final remoteRepository = SupabaseDecisionProfileRepository(
        client: _accountClient(),
        scope: scope,
      );
      final remoteProfile = await remoteRepository.load();
      if (remoteProfile == null) {
        await _scopedPersistence.delete(scope, ScopedDataKeys.decisionProfile);
        _traceLoad(
          source: 'Supabase',
          scope: scope,
          persistedProfile: null,
          effectiveProfile: null,
          fallbackApplied: false,
          fallbackReason: 'no active profile row',
        );
        return null;
      }

      await _saveLocal(scope, remoteProfile);
      _traceLoad(
        source: 'Supabase',
        scope: scope,
        persistedProfile: remoteProfile,
        effectiveProfile: remoteProfile,
        fallbackApplied: false,
        fallbackReason: 'none',
      );
      return remoteProfile;
    } on Object catch (error) {
      debugPrint('Remote decision profile load failed: $error');
      final local = await _loadLocal(scope);
      _traceLoad(
        source: local == null ? 'default' : 'cache',
        scope: scope,
        persistedProfile: local,
        effectiveProfile: local,
        fallbackApplied: true,
        fallbackReason: 'Supabase profile fetch failed: $error',
      );
      return local;
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

  void _traceLoad({
    required String source,
    required IdentityScope scope,
    required DecisionProfile? persistedProfile,
    required DecisionProfile? effectiveProfile,
    required bool fallbackApplied,
    required String fallbackReason,
  }) {
    if (!RuntimePersonalizationDiagnostic.instance.isEnabled) return;
    final effective =
        effectiveProfile ??
        const DecisionProfile(onboardingVersion: '2.0', answers: []);
    RuntimePersonalizationDiagnostic.instance.recordLifecycle(
      'profile fetch completed',
      fields: {'source': source, 'scope': scope.stableKey},
    );
    RuntimePersonalizationDiagnostic.instance.recordProfile(
      source: source,
      sessionUserId: scope.isAccount ? scope.id : null,
      persistedProfile: persistedProfile,
      effectiveProfile: effective,
      compiledProfile: const ProfileCompiler().compile(effective),
      fallbackApplied: fallbackApplied,
      fallbackReason: fallbackReason,
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
