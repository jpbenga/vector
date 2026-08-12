import '../../../core/supabase/supabase_user_scope.dart';

class SupabaseMatchFavoritesRepository {
  const SupabaseMatchFavoritesRepository(this._scope);

  final SupabaseUserScope _scope;

  Future<Set<String>> load() async {
    final rows = await _scope.client
        .from('match_favorites')
        .select('match_id')
        .eq('user_id', _scope.userId);

    return {
      for (final row in rows)
        if (row['match_id'] != null) row['match_id'].toString(),
    };
  }

  Future<void> save(Set<String> favoriteIds) async {
    await _scope.client
        .from('match_favorites')
        .delete()
        .eq('user_id', _scope.userId);

    if (favoriteIds.isEmpty) {
      return;
    }

    await _scope.client.from('match_favorites').insert([
      for (final id in favoriteIds) {'user_id': _scope.userId, 'match_id': id},
    ]);
  }
}
