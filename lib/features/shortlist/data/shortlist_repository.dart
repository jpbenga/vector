import 'package:supabase_flutter/supabase_flutter.dart';
import '../../generator/domain/generator_context.dart';
import '../domain/shortlist.dart';

abstract interface class ShortlistRepository {
  Future<ShortlistSnapshot> request(
    String action, {
    String? session,
    ShortlistFixture? fixture,
    DateTime? until,
    int? revision,
  });
}

class SupabaseShortlistRepository implements ShortlistRepository {
  SupabaseShortlistRepository(this.client);
  final SupabaseClient? Function() client;
  @override
  Future<ShortlistSnapshot> request(
    String action, {
    String? session,
    ShortlistFixture? fixture,
    DateTime? until,
    int? revision,
  }) async {
    final connection = client();
    if (connection?.auth.currentUser == null) {
      throw StateError('Connectez-vous pour préparer votre Shortlist.');
    }
    try {
      final result = await connection!
          .rpc<Object?>(
            'lector_shortlist',
            params: {
              'p_action': action,
              'p_session': ?session,
              if (fixture != null) ...{
                'p_sport': fixture.sport,
                'p_fixture': fixture.fixtureId,
                'p_date': fixture.date,
              },
              if (until != null) 'p_until': until.toUtc().toIso8601String(),
              'p_revision': ?revision,
              'p_timezone': 'Europe/Paris',
            },
          )
          .timeout(const Duration(seconds: 20));
      return ShortlistSnapshot(generatorMap(result));
    } on PostgrestException catch (e) {
      throw StateError(
        e.code == 'PGRST202'
            ? 'La Shortlist est en cours d’installation.'
            : e.message,
      );
    }
  }
}
