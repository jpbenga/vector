import '../../onboarding/domain/decision_profile_catalogs.dart';
import '../../opportunities/domain/opportunity.dart';

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

  static GeneratedTicketPick? fromOpportunity(Opportunity opportunity) {
    final recommendedMarket = opportunity.recommendedMarket;
    if (recommendedMarket == null || recommendedMarket.selection.odds < 1.20) {
      return null;
    }

    final pickType = pickTypeForOdds(recommendedMarket.selection.odds);
    if (pickType == null) {
      return null;
    }

    return GeneratedTicketPick(
      opportunityId: opportunity.matchId,
      matchId: opportunity.matchId,
      homeTeam: opportunity.homeTeam.name,
      awayTeam: opportunity.awayTeam.name,
      competitionName: opportunity.competition.name,
      kickoffLabel: opportunity.fixture.kickoffLabel,
      kickoff: opportunity.fixture.kickoff,
      marketId: recommendedMarket.market.id,
      marketLabel: recommendedMarket.market.label,
      selectionId: recommendedMarket.selection.id,
      selectionLabel: recommendedMarket.selection.label,
      odds: _normalizeOdds(recommendedMarket.selection.odds),
      pickType: pickType,
      thesisId: opportunity.primaryThesis.id,
      opportunityProfileIds: opportunity.opportunityProfileIds,
      engineScore: opportunity.engineScore,
    );
  }
}

PickType? pickTypeForOdds(double odds) {
  final normalizedOdds = _normalizeOdds(odds);
  if (normalizedOdds < 1.20) {
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
