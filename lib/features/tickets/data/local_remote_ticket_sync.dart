import '../domain/saved_ticket.dart';
import '../domain/ticket_strategy.dart';

List<TicketStrategy> mergeTicketStrategies({
  required List<TicketStrategy> localStrategies,
  required List<TicketStrategy> remoteStrategies,
}) {
  final byId = <String, TicketStrategy>{};
  for (final strategy in remoteStrategies) {
    byId[strategy.id] = strategy;
  }

  for (final strategy in localStrategies) {
    final existing = byId[strategy.id];
    if (existing == null ||
        !existing.updatedAt.toUtc().isAfter(strategy.updatedAt.toUtc())) {
      byId[strategy.id] = strategy;
    }
  }

  return byId.values.toList()..sort((a, b) {
    final priorityComparison = a.priority.compareTo(b.priority);
    if (priorityComparison != 0) {
      return priorityComparison;
    }
    return a.createdAt.compareTo(b.createdAt);
  });
}

List<SavedTicket> mergeSavedTickets({
  required List<SavedTicket> localTickets,
  required List<SavedTicket> remoteTickets,
}) {
  final byId = <String, SavedTicket>{};
  for (final ticket in remoteTickets) {
    byId[ticket.id] = ticket;
  }

  for (final ticket in localTickets) {
    final existing = byId[ticket.id];
    if (existing == null ||
        !existing.updatedAt.toUtc().isAfter(ticket.updatedAt.toUtc())) {
      byId[ticket.id] = ticket;
    }
  }

  return byId.values.toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
}

bool ticketStrategiesEqual(
  List<TicketStrategy> first,
  List<TicketStrategy> second,
) {
  return _jsonListsEqual(
    [for (final strategy in first) strategy.toJson()],
    [for (final strategy in second) strategy.toJson()],
  );
}

bool savedTicketsEqual(List<SavedTicket> first, List<SavedTicket> second) {
  return _jsonListsEqual(
    [for (final ticket in first) ticket.toJson()],
    [for (final ticket in second) ticket.toJson()],
  );
}

bool _jsonListsEqual(List<Object?> first, List<Object?> second) {
  if (first.length != second.length) {
    return false;
  }

  for (var index = 0; index < first.length; index++) {
    if (!_deepEquals(first[index], second[index])) {
      return false;
    }
  }

  return true;
}

bool _deepEquals(Object? first, Object? second) {
  if (first is Map && second is Map) {
    if (first.length != second.length) {
      return false;
    }
    for (final key in first.keys) {
      if (!second.containsKey(key) || !_deepEquals(first[key], second[key])) {
        return false;
      }
    }
    return true;
  }

  if (first is List && second is List) {
    if (first.length != second.length) {
      return false;
    }
    for (var index = 0; index < first.length; index++) {
      if (!_deepEquals(first[index], second[index])) {
        return false;
      }
    }
    return true;
  }

  return first == second;
}
