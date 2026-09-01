import '../../../core/identity/identity_scope.dart';

class SavedMatchFavoritesStore {
  const SavedMatchFavoritesStore();

  Future<Set<String>> load({required IdentityScope scope}) async => const {};

  Future<void> save({
    required IdentityScope scope,
    required Set<String> favoriteIds,
  }) async {}
}
