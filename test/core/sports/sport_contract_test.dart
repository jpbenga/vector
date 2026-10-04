import 'package:copilot/core/sports/domain/sport.dart';
import 'package:copilot/core/sports/domain/sport_module.dart';
import 'package:copilot/core/sports/domain/sport_snapshot.dart';
import 'package:copilot/features/sports/domain/sport_module_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'overlapping provider IDs and account resources cannot cross sports',
    () {
      SportEntityId id(
        SportId sport,
        SportEntityKind kind, {
        String provider = 'provider',
      }) => SportEntityId(
        sport: sport,
        provider: provider,
        kind: kind,
        value: '61',
      );
      final football = id(SportId.football, SportEntityKind.team);
      final hockey = id(SportId.hockey, SportEntityKind.team);
      expect(football, isNot(hockey));
      expect(hockey, isNot(id(SportId.hockey, SportEntityKind.match)));
      expect(
        hockey,
        isNot(id(SportId.hockey, SportEntityKind.team, provider: 'other')),
      );
      expect({football.key, hockey.key}.length, 2);
      final keys = [
        for (final sport in SportId.values)
          sportStorageKey(
            sport: sport,
            identityKey: 'account:a',
            resource: 'readings',
          ),
      ];
      expect(keys.toSet().length, SportId.values.length);
      expect(
        keys.first,
        isNot(
          sportStorageKey(
            sport: SportId.football,
            identityKey: 'account:b',
            resource: 'readings',
          ),
        ),
      );
      expect(() => SportId.parse('unknown'), throwsFormatException);
    },
  );

  test(
    'hockey publication accepts empty covered days and rejects football contamination',
    () {
      final header = SportSnapshot<SportId>(
        sport: SportId.hockey,
        schemaVersion: 1,
        capturedAt: DateTime.utc(2026, 10, 3, 23),
        windowStart: DateTime.utc(2026, 10, 4),
        windowEnd: DateTime.utc(2026, 10, 6),
        items: [],
        sportOf: (sport) => sport,
      );
      expect(header.items, isEmpty);
      expect(header.covers(DateTime(2026, 10, 5)), isTrue);
      expect(header.covers(DateTime(2026, 10, 7)), isFalse);
      expect(
        () => SportSnapshot<SportId>(
          sport: SportId.hockey,
          schemaVersion: 1,
          capturedAt: header.capturedAt,
          windowStart: header.windowStart,
          windowEnd: header.windowEnd,
          items: [SportId.football],
          sportOf: (sport) => sport,
        ),
        throwsArgumentError,
      );
    },
  );

  test(
    'module registry is complete and scenarios depend on implemented readings',
    () {
      expect(
        SportModuleRegistry.modules.map((m) => m.sport).toSet(),
        SportId.values.toSet(),
      );
      final hockey = SportModuleRegistry.forSport(SportId.hockey);
      expect(hockey.stage, SportModuleStage.preparation);
      expect(hockey.capabilities.contains(SportCapability.fixtures), isFalse);
      for (final scenario in hockey.scenarios) {
        expect(
          scenario.requiredReadingIds.every(
            (id) => hockey.readings.any((r) => r.id == id && r.implemented),
          ),
          isTrue,
        );
      }
      expect(
        SportModuleRegistry.forSport(SportId.football).stage,
        SportModuleStage.active,
      );
    },
  );
}
