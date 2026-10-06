import 'dart:convert';
import '../../identity/identity_scope.dart';
import '../../identity/scoped_persistence.dart';
import '../domain/sport.dart';
import '../domain/sport_reading_preferences.dart';

/// First functional preview: browser-local, isolated by identity and sport.
/// Football's existing local and Supabase profile keys are never touched.
class SportReadingPreferencesStore {
  const SportReadingPreferencesStore({
    this.persistence = const ScopedPersistence(),
  });
  final ScopedPersistence persistence;

  String _key(SportId sport) => 'sports.${sport.key}.reading_preferences.v1';
  void _validate(IdentityScope scope) {
    if (!scope.isUserOwned || scope.id.trim().isEmpty) {
      throw ArgumentError('Sport preferences need a user-owned identity.');
    }
  }

  Future<SportReadingPreferences> load(
    IdentityScope scope,
    SportId sport,
  ) async {
    _validate(scope);
    final raw = await persistence.read(scope, _key(sport));
    if (raw == null) return SportReadingPreferences(sport: sport);
    try {
      return SportReadingPreferences.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
        sport,
      );
    } on Object {
      // A corrupt/cross-sport record can never silently enable recommendations.
      return SportReadingPreferences(sport: sport);
    }
  }

  Future<void> save(
    IdentityScope scope,
    SportReadingPreferences preferences,
  ) async {
    _validate(scope);
    SportReadingPreferences.fromJson(preferences.toJson(), preferences.sport);
    await persistence.write(
      scope,
      _key(preferences.sport),
      jsonEncode(preferences.toJson()),
    );
  }
}
