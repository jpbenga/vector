import 'generated_ticket.dart';
import 'ticket_strategy.dart';

enum TicketGenerationStatus {
  generated,
  profileIncomplete,
  noActiveStrategy,
  noUsableOpportunity,
  notEnoughCompatiblePicks,
  noCombinationWithinTotalOdds,
  invalidStrategyConfiguration,
}

class TicketGenerationResult {
  const TicketGenerationResult({
    required this.status,
    required this.strategies,
  });

  final TicketGenerationStatus status;
  final List<StrategyTicketGenerationResult> strategies;

  List<GeneratedTicket> get tickets => [
    for (final strategy in strategies) ...strategy.tickets,
  ];

  bool get hasTickets => tickets.isNotEmpty;
}

class StrategyTicketGenerationResult {
  const StrategyTicketGenerationResult({
    required this.strategy,
    required this.status,
    required this.compatiblePickCount,
    required this.tickets,
  });

  final TicketStrategy strategy;
  final TicketGenerationStatus status;
  final int compatiblePickCount;
  final List<GeneratedTicket> tickets;

  bool get hasTickets => tickets.isNotEmpty;
}
