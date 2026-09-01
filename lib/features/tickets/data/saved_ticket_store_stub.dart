import '../../../core/identity/identity_scope.dart';
import '../domain/saved_ticket.dart';

class SavedTicketStore {
  const SavedTicketStore();

  Future<List<SavedTicket>> load({required IdentityScope scope}) async =>
      const [];

  Future<void> saveAll({
    required IdentityScope scope,
    required List<SavedTicket> tickets,
  }) async {}

  Future<void> upsert({
    required IdentityScope scope,
    required SavedTicket ticket,
  }) async {
    final tickets = await load(scope: scope);
    final updated = [
      for (final savedTicket in tickets)
        if (savedTicket.id != ticket.id) savedTicket,
      ticket,
    ];
    await saveAll(scope: scope, tickets: updated);
  }

  Future<void> delete({
    required IdentityScope scope,
    required String ticketId,
  }) async {}
}
