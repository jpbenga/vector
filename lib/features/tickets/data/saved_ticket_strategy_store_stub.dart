import '../domain/ticket_strategy.dart';

class SavedTicketStrategyStore {
  const SavedTicketStrategyStore();

  Future<List<TicketStrategy>> load() async => const [];

  Future<void> save(List<TicketStrategy> strategies) async {}
}
