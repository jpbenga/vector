// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;

import '../../../core/supabase/supabase_user_scope.dart';
import 'local_remote_favorites_sync.dart';
import 'supabase_match_favorites_repository.dart';

class SavedMatchFavoritesStore {
  const SavedMatchFavoritesStore();

  static const _storageKey = 'vector.match_explorer_favorites.v1';

  Future<Set<String>> load() async {
    final localFavorites = _loadLocal();
    final scope = SupabaseUserScope.current();
    if (scope == null) {
      return localFavorites;
    }

    try {
      final remoteRepository = SupabaseMatchFavoritesRepository(scope);
      final remoteFavorites = await remoteRepository.load();
      final mergedFavorites = mergeMatchFavoriteIds(
        localFavoriteIds: localFavorites,
        remoteFavoriteIds: remoteFavorites,
      );
      if (!_setEquals(remoteFavorites, mergedFavorites)) {
        await remoteRepository.save(mergedFavorites);
      }
      if (!_setEquals(localFavorites, mergedFavorites)) {
        _saveLocal(mergedFavorites);
      }

      return mergedFavorites;
    } on Object {
      return localFavorites;
    }
  }

  Future<void> save(Set<String> favoriteIds) async {
    _saveLocal(favoriteIds);
    final scope = SupabaseUserScope.current();
    if (scope == null) {
      return;
    }

    try {
      await SupabaseMatchFavoritesRepository(scope).save(favoriteIds);
    } on Object {
      // Local persistence remains the fallback in dev/offline mode.
    }
  }

  Set<String> _loadLocal() {
    final raw = html.window.localStorage[_storageKey];
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

  void _saveLocal(Set<String> favoriteIds) {
    html.window.localStorage[_storageKey] = Uri.encodeComponent(
      jsonEncode(favoriteIds.toList()..sort()),
    );
  }
}

bool _setEquals(Set<String> first, Set<String> second) {
  return first.length == second.length && first.containsAll(second);
}
