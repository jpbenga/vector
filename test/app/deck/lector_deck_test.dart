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
    void Function()? onOpenExplorer,
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
      onOpenExplorer: onOpenExplorer ?? _noop,
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

  test('for me exposes Explorer before All and Generator', () {
    expect(
      ids(
        LectorDeckContext(
          scope: LectorDeckScope.forMe,
          selectedDate: DateTime(2026, 8, 31),
          today: DateTime(2026, 9, 1),
        ),
      ),
      ['explorer', 'all', 'generator'],
    );
  });

  test('for me exposes the temporary exploration filter count', () {
    final actions = resolver.resolve(
      context: const LectorDeckContext(
        scope: LectorDeckScope.forMe,
        activeExplorationFilterCount: 4,
      ),
      capabilities: capabilities(),
    );

    final explorer = actions.singleWhere((action) => action.id == 'explorer');
    expect(explorer.isPrimary, isTrue);
    expect(explorer.badgeCount, 4);
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
    'generator exposes the match browser without manual strategy actions',
    () {
      final actions = resolver.resolve(
        context: const LectorDeckContext(scope: LectorDeckScope.generator),
        capabilities: capabilities(),
      );

      expect([for (final action in actions) action.id], ['all']);
      expect(actions.map((a) => a.id), isNot(contains('strategies')));
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
        ['ticket-history', 'all'],
      );
      expect(actions.first.isPrimary, isTrue);

      final withoutSavedTickets = resolver.resolve(
        context: const LectorDeckContext(
          scope: LectorDeckScope.generator,
          hasGeneratorResults: true,
        ),
        capabilities: capabilities(),
      );

      expect([for (final action in withoutSavedTickets) action.id], ['all']);
      expect(withoutSavedTickets.first.isPrimary, isFalse);
    },
  );

  test(
    'match detail stays on readings and assistant even for historical draft states',
    () {
      expect(
        ids(
          const LectorDeckContext(
            scope: LectorDeckScope.matchDetail,
            ticketState: LectorDeckTicketState.canAdd,
          ),
        ),
        ['readings', 'generator'],
      );

      expect(
        ids(
          const LectorDeckContext(
            scope: LectorDeckScope.matchDetail,
            ticketState: LectorDeckTicketState.selected,
          ),
        ),
        ['readings', 'generator'],
      );
    },
  );

  test('match detail hides disabled Add when another selection blocks it', () {
    expect(
      ids(
        const LectorDeckContext(
          scope: LectorDeckScope.matchDetail,
          ticketState: LectorDeckTicketState.blockedByAnotherSelection,
        ),
      ),
      ['readings', 'generator'],
    );
  });
}

void _noop() {}
