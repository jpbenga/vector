import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/identity/identity_scope.dart';
import '../../../core/identity/scoped_data_keys.dart';
import '../../../core/identity/scoped_persistence.dart';
import '../../../core/supabase/supabase_initializer.dart';
import 'supabase_match_favorites_repository.dart';

class SavedMatchFavoritesStore {
  const SavedMatchFavoritesStore({this.persistence});

  static const legacyStorageKey = 'vector.match_explorer_favorites.v1';

  final ScopedPersistence? persistence;

  Future<Set<String>> load({required IdentityScope scope}) async {
    _ensureUserOwned(scope);
    if (scope.isGuest) {
      return _loadLocal(scope);
    }

    try {
      final remoteRepository = SupabaseMatchFavoritesRepository(
        client: _accountClient(),
        scope: scope,
      );
      final remoteFavorites = await remoteRepository.load();
      await _saveLocal(scope, remoteFavorites);
      return remoteFavorites;
    } on Object catch (error) {
      debugPrint('Remote match favorites load failed: $error');
      return _loadLocal(scope);
    }
  }

  Future<void> save({
    required IdentityScope scope,
    required Set<String> favoriteIds,
  }) async {
    _ensureUserOwned(scope);
    if (scope.isGuest) {
      await _saveLocal(scope, favoriteIds);
      return;
    }

    try {
      await SupabaseMatchFavoritesRepository(
        client: _accountClient(),
        scope: scope,
      ).save(favoriteIds);
      await _saveLocal(scope, favoriteIds);
    } on Object catch (error) {
      debugPrint('Remote match favorites save failed: $error');
      rethrow;
    }
  }

  ScopedPersistence get _scopedPersistence =>
      persistence ?? const ScopedPersistence();

  Future<Set<String>> _loadLocal(IdentityScope scope) async {
    final raw = await _scopedPersistence.read(
      scope,
      ScopedDataKeys.matchFavorites,
    );
    if (raw == null || raw.isEmpty) {
      return const {};
    }

    try {
      final decoded = jsonDecode(Uri.decodeComponent(raw));
      if (decoded is! List) {
        return const {};
      }

      return decoded.whereType<String>().toSet();
    } on FormatException {
      return const {};
    }
  }

  Future<void> _saveLocal(IdentityScope scope, Set<String> favoriteIds) async {
    await _scopedPersistence.write(
      scope,
      ScopedDataKeys.matchFavorites,
      Uri.encodeComponent(jsonEncode(favoriteIds.toList()..sort())),
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
