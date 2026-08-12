class SavedMatchFavoritesStore {
  const SavedMatchFavoritesStore();

  Future<Set<String>> load() async => const {};

  Future<void> save(Set<String> favoriteIds) async {}
}
