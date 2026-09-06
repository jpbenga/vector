import '../../onboarding/domain/decision_profile_catalogs.dart';
import '../../matches/domain/market_assessment.dart';
import '../../matches/domain/match_board_item.dart';

class GeneratedTicketPick {
  const GeneratedTicketPick({
    required this.opportunityId,
    required this.matchId,
    required this.homeTeam,
    required this.awayTeam,
    required this.competitionName,
    required this.kickoffLabel,
    this.kickoff,
    required this.marketId,
    required this.marketLabel,
    required this.selectionId,
    required this.selectionLabel,
    required this.odds,
    required this.pickType,
    required this.thesisId,
    required this.opportunityProfileIds,
    required this.engineScore,
  });

  final String opportunityId;
  final String matchId;
  final String homeTeam;
  final String awayTeam;
  final String competitionName;
  final String kickoffLabel;
  final DateTime? kickoff;
  final String marketId;
  final String marketLabel;
  final String selectionId;
  final String selectionLabel;
  final double odds;
  final PickType pickType;
  final String thesisId;
  final List<String> opportunityProfileIds;
  final int engineScore;

  static GeneratedTicketPick? fromBetCandidate(
    MatchBoardItem match,
    BetCandidate candidate,
  ) {
    if (!candidate.isAutomaticallyUsable || candidate.odds <= 1) {
      return null;
    }
    final pickType = pickTypeForOdds(candidate.odds);
    if (pickType == null) {
      return null;
    }
    return GeneratedTicketPick(
      opportunityId: candidate.matchId,
      matchId: candidate.matchId,
      homeTeam: match.homeTeam.name,
      awayTeam: match.awayTeam.name,
      competitionName: match.competition.name,
      kickoffLabel: match.fixture.kickoffLabel,
      kickoff: match.fixture.kickoff,
      marketId: candidate.marketId,
      marketLabel: candidate.marketLabel,
      selectionId: candidate.selectionId,
      selectionLabel: candidate.selectionLabel,
      odds: _normalizeOdds(candidate.odds),
      pickType: pickType,
      thesisId:
          candidate.supportingThesisIds.firstOrNull ?? 'market_assessment',
      opportunityProfileIds: const [],
      engineScore: candidate.supportingReadingIds.length,
    );
  }
}

PickType? pickTypeForOdds(double odds) {
  final normalizedOdds = _normalizeOdds(odds);
  if (normalizedOdds <= 0) {
    return null;
  }
  if (normalizedOdds <= 1.49) {
    return PickType.prudent;
  }
  if (normalizedOdds <= 2.19) {
    return PickType.normal;
  }

  return PickType.audacious;
}

double _normalizeOdds(double odds) => (odds * 100).round() / 100;
