Set<String> mergeMatchFavoriteIds({
  required Set<String> localFavoriteIds,
  required Set<String> remoteFavoriteIds,
}) {
  return {...remoteFavoriteIds, ...localFavoriteIds};
}
