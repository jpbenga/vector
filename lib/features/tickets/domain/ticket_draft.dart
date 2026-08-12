import '../../matches/domain/match_board_item.dart';
import '../../opportunities/domain/opportunity.dart';

class TicketDraftSelection {
  const TicketDraftSelection({
    required this.id,
    required this.matchId,
    required this.homeTeam,
    required this.awayTeam,
    required this.homeLogoUrl,
    required this.awayLogoUrl,
    required this.marketId,
    required this.marketLabel,
    required this.selectionId,
    required this.selectionLabel,
    required this.odds,
    this.competitionName,
    this.bookmakerName,
  });

  final String id;
  final String matchId;
  final String homeTeam;
  final String awayTeam;
  final String? homeLogoUrl;
  final String? awayLogoUrl;
  final String marketId;
  final String marketLabel;
  final String selectionId;
  final String selectionLabel;
  final double odds;
  final String? competitionName;
  final String? bookmakerName;

  String get matchLabel => '$homeTeam - $awayTeam';

  String get marketSelectionLabel {
    if (marketLabel.toLowerCase().contains('double chance')) {
      return '$selectionLabel (Double chance)';
    }
    if (marketLabel.toLowerCase().contains('both') ||
        marketLabel.toLowerCase().contains('deux équipes')) {
      return 'BTTS ($selectionLabel)';
    }
    return '$selectionLabel ($marketLabel)';
  }

  static TicketDraftSelection? fromOpportunity(Opportunity opportunity) {
    final recommendedMarket = opportunity.recommendedMarket;
    if (recommendedMarket == null || recommendedMarket.selection.odds <= 1) {
      return null;
    }

    return fromMatchSelection(
      opportunity.toMatchBoardItem(),
      recommendedMarket.market,
      recommendedMarket.selection,
    );
  }

  static TicketDraftSelection? fromMatchSelection(
    MatchBoardItem match,
    MatchMarket market,
    MarketOdds selection,
  ) {
    if (selection.odds <= 1) {
      return null;
    }

    final normalizedOdds = _normalizeOdds(selection.odds);
    final id = [
      match.id,
      market.id,
      selection.id,
      selection.apiFootballValue ?? selection.label,
      market.bookmakerId?.toString() ?? market.bookmakerName ?? 'bookmaker',
    ].join('|');

    return TicketDraftSelection(
      id: id,
      matchId: match.id,
      homeTeam: match.homeTeam.name,
      awayTeam: match.awayTeam.name,
      homeLogoUrl: match.homeTeam.logoUrl,
      awayLogoUrl: match.awayTeam.logoUrl,
      competitionName: match.fixture.competition.name,
      marketId: market.id,
      marketLabel: market.label,
      selectionId: selection.id,
      selectionLabel: selection.label,
      odds: normalizedOdds,
      bookmakerName: market.bookmakerName ?? selection.bookmakerName,
    );
  }
}

class TicketDraft {
  const TicketDraft({required this.selections});

  final List<TicketDraftSelection> selections;

  static const empty = TicketDraft(selections: []);

  bool get isEmpty => selections.isEmpty;

  bool get isNotEmpty => selections.isNotEmpty;

  int get selectionCount => selections.length;

  bool contains(String selectionId) {
    return selections.any((selection) => selection.id == selectionId);
  }

  bool containsMatch(String matchId) {
    return selections.any((selection) => selection.matchId == matchId);
  }

  bool containsAnotherSelectionForMatch(TicketDraftSelection selection) {
    return selections.any(
      (existing) =>
          existing.matchId == selection.matchId && existing.id != selection.id,
    );
  }

  bool canToggle(TicketDraftSelection selection) {
    return contains(selection.id) || !containsMatch(selection.matchId);
  }

  TicketDraft toggle(TicketDraftSelection selection) {
    if (contains(selection.id)) {
      return remove(selection.id);
    }

    return add(selection);
  }

  TicketDraft add(TicketDraftSelection selection) {
    if (contains(selection.id) || containsMatch(selection.matchId)) {
      return this;
    }

    return TicketDraft(selections: [...selections, selection]);
  }

  TicketDraft remove(String selectionId) {
    return TicketDraft(
      selections: [
        for (final selection in selections)
          if (selection.id != selectionId) selection,
      ],
    );
  }

  double get totalOdds {
    if (selections.isEmpty) {
      return 0;
    }

    var numerator = BigInt.one;
    var denominator = BigInt.one;
    for (final selection in selections) {
      numerator *= BigInt.from((selection.odds * 100).round());
      denominator *= BigInt.from(100);
    }

    final totalCents = _roundDiv(numerator * BigInt.from(100), denominator);
    return totalCents / 100;
  }
}

double _normalizeOdds(double odds) => (odds * 100).round() / 100;

int _roundDiv(BigInt numerator, BigInt denominator) {
  final quotient = numerator ~/ denominator;
  final remainder = numerator.remainder(denominator).abs();
  final shouldRoundUp = remainder * BigInt.from(2) >= denominator.abs();
  return (shouldRoundUp ? quotient + BigInt.one : quotient).toInt();
}
