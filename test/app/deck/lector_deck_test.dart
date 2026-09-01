import 'package:copilot/app/deck/lector_deck.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const resolver = LectorDeckActionResolver();

  LectorDeckCapabilities capabilities({
    void Function()? onOpenForMe,
    void Function()? onOpenAll,
    void Function()? onOpenGenerator,
    void Function()? onGoToday,
    void Function()? onOpenStrategies,
    void Function()? onRecalculate,
    void Function()? onOpenTicketHistory,
    void Function()? onAddToTicket,
    void Function()? onRemoveFromTicket,
    void Function()? onOpenCurrentTicket,
    void Function()? onOpenReadings,
  }) {
    return LectorDeckCapabilities(
      onOpenForMe: onOpenForMe ?? _noop,
      onOpenAll: onOpenAll ?? _noop,
      onOpenGenerator: onOpenGenerator ?? _noop,
      onGoToday: onGoToday ?? _noop,
      onOpenStrategies: onOpenStrategies ?? _noop,
      onRecalculate: onRecalculate ?? _noop,
      onOpenTicketHistory: onOpenTicketHistory ?? _noop,
      onAddToTicket: onAddToTicket ?? _noop,
      onRemoveFromTicket: onRemoveFromTicket ?? _noop,
      onOpenCurrentTicket: onOpenCurrentTicket ?? _noop,
      onOpenReadings: onOpenReadings ?? _noop,
    );
  }

  List<String> ids(
    LectorDeckContext context, {
    LectorDeckCapabilities? withCapabilities,
  }) {
    return [
      for (final action in resolver.resolve(
        context: context,
        capabilities: withCapabilities ?? capabilities(),
      ))
        action.id,
    ];
  }

  test('for me exposes only All and Generator in V1', () {
    expect(
      ids(
        LectorDeckContext(
          scope: LectorDeckScope.forMe,
          selectedDate: DateTime(2026, 8, 31),
          today: DateTime(2026, 9, 1),
        ),
      ),
      ['all', 'generator'],
    );
  });

  test('all can expose Today only outside today', () {
    expect(
      ids(
        LectorDeckContext(
          scope: LectorDeckScope.all,
          selectedDate: DateTime(2026, 8, 31),
          today: DateTime(2026, 9, 1),
        ),
      ),
      ['for-me', 'today', 'generator'],
    );

    expect(
      ids(
        LectorDeckContext(
          scope: LectorDeckScope.all,
          selectedDate: DateTime(2026, 9, 1),
          today: DateTime(2026, 9, 1),
        ),
      ),
      ['for-me', 'generator'],
    );
  });

  test(
    'generator without results prioritizes strategies without active strategy',
    () {
      final actions = resolver.resolve(
        context: const LectorDeckContext(scope: LectorDeckScope.generator),
        capabilities: capabilities(),
      );

      expect(
        [for (final action in actions) action.id],
        ['strategies', 'recalculate', 'all'],
      );
      expect(
        actions.singleWhere((action) => action.id == 'strategies').isPrimary,
        isTrue,
      );
    },
  );

  test(
    'generator with results prioritizes history only with saved tickets',
    () {
      final actions = resolver.resolve(
        context: const LectorDeckContext(
          scope: LectorDeckScope.generator,
          hasGeneratorResults: true,
          hasSavedTickets: true,
        ),
        capabilities: capabilities(),
      );

      expect(
        [for (final action in actions) action.id],
        ['ticket-history', 'recalculate', 'strategies'],
      );
      expect(actions.first.isPrimary, isTrue);

      final withoutSavedTickets = resolver.resolve(
        context: const LectorDeckContext(
          scope: LectorDeckScope.generator,
          hasGeneratorResults: true,
        ),
        capabilities: capabilities(),
      );

      expect(
        [for (final action in withoutSavedTickets) action.id],
        ['recalculate', 'strategies'],
      );
      expect(withoutSavedTickets.first.isPrimary, isTrue);
    },
  );

  test('match detail switches from Add to current ticket and remove', () {
    expect(
      ids(
        const LectorDeckContext(
          scope: LectorDeckScope.matchDetail,
          ticketState: LectorDeckTicketState.canAdd,
        ),
      ),
      ['add-to-ticket', 'readings', 'generator'],
    );

    expect(
      ids(
        const LectorDeckContext(
          scope: LectorDeckScope.matchDetail,
          ticketState: LectorDeckTicketState.selected,
        ),
      ),
      ['current-ticket', 'readings', 'remove-from-ticket'],
    );
  });

  test('match detail hides disabled Add when another selection blocks it', () {
    expect(
      ids(
        const LectorDeckContext(
          scope: LectorDeckScope.matchDetail,
          ticketState: LectorDeckTicketState.blockedByAnotherSelection,
        ),
      ),
      ['current-ticket', 'readings', 'generator'],
    );
  });
}

void _noop() {}
