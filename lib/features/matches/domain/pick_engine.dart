import '../../onboarding/domain/compiled_decision_profile.dart';
import '../../opportunities/domain/opportunity.dart';
import '../../tickets/domain/generated_ticket_pick.dart';

class PickEngine {
  const PickEngine();

  List<GeneratedTicketPick> eligiblePicks({
    required List<Opportunity> opportunities,
    required CompiledDecisionProfile profile,
  }) {
    if (!profile.isCompleted) {
      return const [];
    }

    final picksByMatchId = <String, GeneratedTicketPick>{};
    for (final opportunity in opportunities) {
      final pick = eligiblePick(opportunity: opportunity, profile: profile);
      if (pick == null) {
        continue;
      }

      picksByMatchId.putIfAbsent(pick.matchId, () => pick);
    }

    return picksByMatchId.values.toList(growable: false);
  }

  GeneratedTicketPick? eligiblePick({
    required Opportunity opportunity,
    required CompiledDecisionProfile profile,
  }) {
    final recommendedMarket = opportunity.recommendedMarket;
    if (recommendedMarket == null) {
      return null;
    }

    if (profile.enabledMarket(recommendedMarket.market.id) == null) {
      return null;
    }

    return GeneratedTicketPick.fromOpportunity(opportunity);
  }
}
