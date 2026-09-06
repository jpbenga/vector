import '../../onboarding/domain/compiled_decision_profile.dart';
import '../../tickets/domain/generated_ticket_pick.dart';
import 'market_assessment.dart';
import 'match_board_item.dart';

class PickEngine {
  const PickEngine();

  List<GeneratedTicketPick> eligiblePicks({
    required List<MatchBoardItem> matches,
    required CompiledDecisionProfile profile,
  }) {
    if (!profile.isCompleted) {
      return const [];
    }

    final picksByMatchId = <String, GeneratedTicketPick>{};
    for (final match in matches) {
      final candidate = selectSuggestedBetCandidate(
        match.betCandidates.where(
          (candidate) => profile.enabledMarket(candidate.marketId) != null,
        ),
      );
      if (candidate == null) {
        continue;
      }
      final pick = GeneratedTicketPick.fromBetCandidate(match, candidate);
      if (pick != null) {
        picksByMatchId[pick.matchId] = pick;
      }
    }

    return picksByMatchId.values.toList(growable: false);
  }

  GeneratedTicketPick? eligiblePick({
    required MatchBoardItem match,
    required int candidateIndex,
    required CompiledDecisionProfile profile,
  }) {
    if (candidateIndex < 0 || candidateIndex >= match.betCandidates.length) {
      return null;
    }
    final candidate = match.betCandidates[candidateIndex];

    if (profile.enabledMarket(candidate.marketId) == null) {
      return null;
    }

    return GeneratedTicketPick.fromBetCandidate(match, candidate);
  }
}
