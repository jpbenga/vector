import '../../../core/identity/identity_scope.dart';
import '../domain/ticket_strategy.dart';

class SavedTicketStrategyStore {
  const SavedTicketStrategyStore();

  Future<List<TicketStrategy>> load({required IdentityScope scope}) async =>
      const [];

  Future<void> save({
    required IdentityScope scope,
    required List<TicketStrategy> strategies,
  }) async {}
}
