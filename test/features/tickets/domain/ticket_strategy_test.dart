import 'package:copilot/features/onboarding/domain/decision_profile_catalogs.dart';
import 'package:copilot/features/tickets/domain/ticket_strategy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TicketStrategy', () {
    test('supports inclusive constraints and multiple pickTypes', () {
      final createdAt = DateTime.utc(2026, 8);
      final strategy = TicketStrategy(
        schemaVersion: TicketStrategy.currentSchemaVersion,
        id: 'fun',
        userId: 'user-1',
        name: 'Fun',
        isActive: true,
        pickTypes: const [PickType.normal, PickType.audacious],
        minimumIndividualOdds: 1.50,
        maximumIndividualOdds: null,
        minimumSelections: 3,
        maximumSelections: 5,
        minimumTotalOdds: 8,
        maximumTotalOdds: null,
        priority: 1,
        createdAt: createdAt,
        updatedAt: createdAt,
      );

      expect(strategy.allowsPickType(PickType.prudent), isFalse);
      expect(strategy.allowsPickType(PickType.normal), isTrue);
      expect(strategy.allowsPickType(PickType.audacious), isTrue);
      expect(strategy.acceptsIndividualOdds(1.49), isFalse);
      expect(strategy.acceptsIndividualOdds(1.50), isTrue);
      expect(strategy.acceptsIndividualOdds(4.20), isTrue);
      expect(strategy.acceptsSelectionCount(2), isFalse);
      expect(strategy.acceptsSelectionCount(3), isTrue);
      expect(strategy.acceptsSelectionCount(5), isTrue);
      expect(strategy.acceptsSelectionCount(6), isFalse);
      expect(strategy.acceptsTotalOdds(7.99), isFalse);
      expect(strategy.acceptsTotalOdds(8), isTrue);
      expect(strategy.acceptsTotalOdds(32.40), isTrue);
    });

    test('applies inclusive closed total odds bounds', () {
      final createdAt = DateTime.utc(2026, 8);
      final strategy = TicketStrategy(
        schemaVersion: TicketStrategy.currentSchemaVersion,
        id: 'safe-1',
        userId: 'user-1',
        name: 'Safe 1',
        isActive: true,
        pickTypes: const [PickType.prudent],
        minimumIndividualOdds: 1.20,
        maximumIndividualOdds: 1.49,
        minimumSelections: 2,
        maximumSelections: 2,
        minimumTotalOdds: 1.35,
        maximumTotalOdds: 1.79,
        priority: 1,
        createdAt: createdAt,
        updatedAt: createdAt,
      );

      expect(strategy.acceptsTotalOdds(1.34), isFalse);
      expect(strategy.acceptsTotalOdds(1.35), isTrue);
      expect(strategy.acceptsTotalOdds(1.79), isTrue);
      expect(strategy.acceptsTotalOdds(1.80), isFalse);
    });

    test('serializes and restores persisted strategy data', () {
      final createdAt = DateTime.utc(2026, 8);
      final source = TicketStrategy(
        schemaVersion: TicketStrategy.currentSchemaVersion,
        id: 'fun',
        userId: 'user-1',
        name: 'Fun',
        isActive: false,
        pickTypes: const [PickType.normal, PickType.audacious],
        minimumIndividualOdds: 1.50,
        maximumIndividualOdds: 2.80,
        minimumSelections: 3,
        maximumSelections: 5,
        minimumTotalOdds: 8,
        maximumTotalOdds: null,
        priority: 2,
        createdAt: createdAt,
        updatedAt: createdAt,
      );

      final restored = TicketStrategy.fromJson(source.toJson());

      expect(restored.id, 'fun');
      expect(restored.userId, 'user-1');
      expect(restored.name, 'Fun');
      expect(restored.isActive, isFalse);
      expect(restored.pickTypes, [PickType.normal, PickType.audacious]);
      expect(restored.minimumIndividualOdds, 1.50);
      expect(restored.maximumIndividualOdds, 2.80);
      expect(restored.minimumSelections, 3);
      expect(restored.maximumSelections, 5);
      expect(restored.minimumTotalOdds, 8);
      expect(restored.maximumTotalOdds, isNull);
      expect(restored.priority, 2);
      expect(restored.createdAt, createdAt);
      expect(restored.updatedAt, createdAt);
    });

    test('migrates legacy pickTypes into default individual odds bounds', () {
      final restored = TicketStrategy.fromJson({
        'schemaVersion': 1,
        'id': 'balanced',
        'userId': 'user-1',
        'name': 'Balanced',
        'isActive': true,
        'pickTypes': ['prudent', 'normal'],
        'minimumSelections': 2,
        'maximumSelections': 3,
        'minimumTotalOdds': 2,
        'maximumTotalOdds': 3,
        'priority': 1,
        'createdAt': DateTime.utc(2026, 8).toIso8601String(),
        'updatedAt': DateTime.utc(2026, 8).toIso8601String(),
      });

      expect(restored.minimumIndividualOdds, 1.20);
      expect(restored.maximumIndividualOdds, 2.19);
      expect(restored.hasMathematicallyPossibleTicket, isTrue);
    });

    test('derives compatibility pickTypes from individual odds bounds', () {
      expect(TicketStrategy.pickTypesForIndividualOdds(1.20, 1.49), [
        PickType.prudent,
      ]);
      expect(TicketStrategy.pickTypesForIndividualOdds(1.35, 2.10), [
        PickType.prudent,
        PickType.normal,
      ]);
      expect(TicketStrategy.pickTypesForIndividualOdds(1.20, null), [
        PickType.prudent,
        PickType.normal,
        PickType.audacious,
      ]);
      expect(TicketStrategy.pickTypesForIndividualOdds(2.20, null), [
        PickType.audacious,
      ]);
    });

    test('detects mathematically impossible odds constraints', () {
      final createdAt = DateTime.utc(2026, 8);
      final strategy = TicketStrategy(
        schemaVersion: TicketStrategy.currentSchemaVersion,
        id: 'impossible',
        userId: 'user-1',
        name: 'Impossible',
        isActive: true,
        pickTypes: const [PickType.prudent],
        minimumIndividualOdds: 1.20,
        maximumIndividualOdds: 1.49,
        minimumSelections: 2,
        maximumSelections: 2,
        minimumTotalOdds: 5,
        maximumTotalOdds: null,
        priority: 1,
        createdAt: createdAt,
        updatedAt: createdAt,
      );

      expect(strategy.hasValidBounds, isTrue);
      expect(strategy.hasMathematicallyPossibleTicket, isFalse);
    });
  });
}
