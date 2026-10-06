import 'dart:convert';
import 'package:copilot/core/identity/identity_scope.dart';
import 'package:copilot/core/identity/scoped_persistence.dart';
import 'package:copilot/core/persistence/local_key_value_store.dart';
import 'package:copilot/core/sports/data/sport_reading_preferences_store.dart';
import 'package:copilot/core/sports/domain/sport.dart';
import 'package:copilot/core/sports/domain/sport_reading_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryPreferencesStorage implements LocalKeyValueStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> delete(String key) async => values.remove(key);
}

void main() {
  const account = IdentityScope.account('one');
  late MemoryPreferencesStorage memory;
  late ScopedPersistence persistence;
  late SportReadingPreferencesStore store;
  final hockey = SportReadingPreferences(
    sport: SportId.hockey,
    competitionKeys: ['hockey:api-hockey:competition:35'],
    readingIds: ['winning_streak'],
  );
  setUp(() {
    memory = MemoryPreferencesStorage();
    persistence = ScopedPersistence(store: memory);
    store = SportReadingPreferencesStore(persistence: persistence);
  });

  test('new users have no automatically enabled sport preferences', () async {
    final loaded = await store.load(account, SportId.hockey);
    expect(loaded.isConfigured, isFalse);
    expect(loaded.competitionKeys, isEmpty);
    expect(loaded.readingIds, isEmpty);
  });

  test(
    'preferences survive reload and stay isolated by sport and identity',
    () async {
      await store.save(account, hockey);
      final restored = await store.load(account, SportId.hockey);
      expect(restored.toJson(), hockey.toJson());
      expect(
        (await store.load(account, SportId.football)).isConfigured,
        isFalse,
      );
      expect(
        (await store.load(
          const IdentityScope.account('two'),
          SportId.hockey,
        )).isConfigured,
        isFalse,
      );
      expect(
        (await store.load(
          const IdentityScope.guest('one'),
          SportId.hockey,
        )).isConfigured,
        isFalse,
      );
      await store.save(
        const IdentityScope.guest('one'),
        SportReadingPreferences(sport: SportId.hockey),
      );
      expect((await store.load(account, SportId.hockey)).isConfigured, isTrue);
    },
  );

  test('football profile keys remain byte for byte intact', () async {
    await persistence.write(account, 'profile', '{"signals":["form_gap"]}');
    await store.save(account, hockey);
    expect(
      await persistence.read(account, 'profile'),
      '{"signals":["form_gap"]}',
    );
    expect(memory.values.length, 2);
  });

  test(
    'partial choices and disabled readings never configure For me',
    () async {
      for (final preferences in [
        SportReadingPreferences(
          sport: SportId.hockey,
          readingIds: ['winning_streak'],
        ),
        SportReadingPreferences(
          sport: SportId.hockey,
          competitionKeys: hockey.competitionKeys,
        ),
        SportReadingPreferences(sport: SportId.hockey),
      ]) {
        await store.save(account, preferences);
        expect(
          (await store.load(account, SportId.hockey)).isConfigured,
          isFalse,
        );
      }
    },
  );

  test('corrupt, cross-sport and wrong-version records abstain', () async {
    for (final raw in [
      'invalid-json',
      jsonEncode({...hockey.toJson(), 'sport': 'football'}),
      jsonEncode({
        ...hockey.toJson(),
        'competitions': ['football:api-football:competition:35'],
      }),
      jsonEncode({...hockey.toJson(), 'version': 2}),
    ]) {
      await persistence.write(
        account,
        'sports.hockey.reading_preferences.v1',
        raw,
      );
      expect((await store.load(account, SportId.hockey)).isConfigured, isFalse);
    }
  });

  test('cannot save foreign competitions or ownerless preferences', () async {
    await expectLater(
      store.save(
        account,
        SportReadingPreferences(
          sport: SportId.hockey,
          competitionKeys: ['football:api-football:competition:35'],
          readingIds: ['winning_streak'],
        ),
      ),
      throwsFormatException,
    );
    for (final scope in [
      const IdentityScope.device(),
      const IdentityScope.legacyUnowned(),
      const IdentityScope.account(''),
    ]) {
      await expectLater(store.save(scope, hockey), throwsArgumentError);
    }
    expect(memory.values, isEmpty);
  });
}
