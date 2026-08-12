import '../domain/saved_ticket.dart';

class SavedTicketStore {
  const SavedTicketStore();

  Future<List<SavedTicket>> load() async => const [];

  Future<void> saveAll(List<SavedTicket> tickets) async {}

  Future<void> upsert(SavedTicket ticket) async {
    final tickets = await load();
    final updated = [
      for (final savedTicket in tickets)
        if (savedTicket.id != ticket.id) savedTicket,
      ticket,
    ];
    await saveAll(updated);
  }

  Future<void> delete(String ticketId) async {}
}
