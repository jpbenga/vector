// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter/foundation.dart';

import '../../../core/supabase/supabase_user_scope.dart';
import '../domain/decision_profile.dart';
import 'local_remote_profile_sync.dart';
import 'supabase_decision_profile_repository.dart';

class SavedDecisionProfileStore {
  const SavedDecisionProfileStore();

  static const _storageKey = 'vector.saved_decision_profile.v1';
  static const _cookieKey = 'vector_saved_decision_profile_v1';

  Future<DecisionProfile?> load() async {
    final localProfile = _loadLocal();
    final scope = SupabaseUserScope.current();
    if (scope == null) {
      return localProfile;
    }

    try {
      final remoteRepository = SupabaseDecisionProfileRepository(scope);
      final remoteProfile = await remoteRepository.load();
      final resolvedProfile = resolveSyncedDecisionProfile(
        localProfile: localProfile,
        remoteProfile: remoteProfile,
      );
      if (resolvedProfile == null) {
        return null;
      }

      if (!decisionProfilesEqual(remoteProfile, resolvedProfile)) {
        await remoteRepository.save(resolvedProfile);
      }
      if (!decisionProfilesEqual(localProfile, resolvedProfile)) {
        _saveLocal(resolvedProfile);
      }

      return resolvedProfile;
    } on Object catch (error) {
      debugPrint('Remote decision profile sync failed: $error');
      return localProfile;
    }
  }

  Future<void> save(DecisionProfile profile) async {
    _saveLocal(profile);
    final scope = SupabaseUserScope.current();
    if (scope == null) {
      return;
    }

    try {
      await SupabaseDecisionProfileRepository(scope).save(profile);
    } on Object catch (error) {
      debugPrint('Remote decision profile save failed: $error');
      // Local persistence remains the fallback in dev/offline mode.
    }
  }

  DecisionProfile? _loadLocal() {
    final raw = html.window.localStorage[_storageKey] ?? _cookieValue();
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

  void _saveLocal(DecisionProfile profile) {
    final encoded = Uri.encodeComponent(jsonEncode(profile.toJson()));
    html.window.localStorage[_storageKey] = encoded;
    html.document.cookie =
        '$_cookieKey=$encoded; path=/; max-age=31536000; SameSite=Lax';
  }

  String? _cookieValue() {
    final cookies = html.document.cookie?.split(';') ?? const [];
    for (final cookie in cookies) {
      final separator = cookie.indexOf('=');
      if (separator == -1) {
        continue;
      }

      final key = cookie.substring(0, separator).trim();
      if (key == _cookieKey) {
        return cookie.substring(separator + 1).trim();
      }
    }

    return null;
  }
}
