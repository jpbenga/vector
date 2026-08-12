import 'generated_ticket_pick.dart';

enum TicketOrigin { copilotGenerated, copilotEdited, manual }

enum TicketLifecycleStatus {
  proposed,
  saved,
  exported,
  played,
  won,
  lost,
  cancelled,
}

class ConstraintViolation {
  const ConstraintViolation({required this.ruleId, required this.message});

  final String ruleId;
  final String message;
}

class TicketConstraintValidation {
  const TicketConstraintValidation({
    required this.isValid,
    required this.satisfiedRuleIds,
    required this.violations,
  });

  final bool isValid;
  final List<String> satisfiedRuleIds;
  final List<ConstraintViolation> violations;

  static const valid = TicketConstraintValidation(
    isValid: true,
    satisfiedRuleIds: [
      'individual_odds',
      'selection_count',
      'total_odds',
      'unique_matches',
      'single_ticket_day',
    ],
    violations: [],
  );
}

class GeneratedTicket {
  const GeneratedTicket({
    required this.id,
    required this.strategyId,
    required this.strategyName,
    required this.picks,
    required this.totalOdds,
    required this.selectionCount,
    required this.generatedAt,
    required this.variantIndex,
    this.origin = TicketOrigin.copilotGenerated,
    this.lifecycleStatus = TicketLifecycleStatus.proposed,
    this.constraintValidation = TicketConstraintValidation.valid,
  });

  final String id;
  final String strategyId;
  final String strategyName;
  final List<GeneratedTicketPick> picks;
  final double totalOdds;
  final int selectionCount;
  final DateTime generatedAt;
  final int variantIndex;
  final TicketOrigin origin;
  final TicketLifecycleStatus lifecycleStatus;
  final TicketConstraintValidation constraintValidation;

  List<String> get matchIds => [for (final pick in picks) pick.matchId];

  bool get isConform => constraintValidation.isValid;

  int get averageEngineScore {
    if (picks.isEmpty) {
      return 0;
    }

    final totalScore = picks.fold<int>(
      0,
      (total, pick) => total + pick.engineScore,
    );

    return (totalScore / picks.length).round();
  }
}
