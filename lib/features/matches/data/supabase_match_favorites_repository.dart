import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/identity/identity_scope.dart';

class SupabaseMatchFavoritesRepository {
  SupabaseMatchFavoritesRepository({
    required this.client,
    required IdentityScope scope,
  }) : assert(scope.isAccount),
       _userId = scope.id;

  final SupabaseClient client;
  final String _userId;

  Future<Set<String>> load() async {
    final rows = await client
        .from('match_favorites')
        .select('match_id')
        .eq('user_id', _userId);

    return {
      for (final row in rows)
        if (row['match_id'] != null) row['match_id'].toString(),
    };
  }

  Future<void> save(Set<String> favoriteIds) async {
    await client.from('match_favorites').delete().eq('user_id', _userId);

    if (favoriteIds.isEmpty) {
      return;
    }

    await client.from('match_favorites').insert([
      for (final id in favoriteIds) {'user_id': _userId, 'match_id': id},
    ]);
  }
}
