enum InternalBookmakerId { betfair, pinnacle, bwin, bet365, oneXBet, unibet }

enum InternalMarketId {
  matchResult,
  doubleChance,
  goalsTotal,
  bothTeamsScore,
  teamTotalHome,
  teamTotalAway,
  cornersTotal,
  cardsTotal,
}

enum InternalSelectionSide { home, draw, away, yes, no, over, under }

class BookmakerMapping {
  const BookmakerMapping({
    required this.internalId,
    required this.apiFootballId,
    required this.displayName,
  });

  final InternalBookmakerId internalId;
  final int apiFootballId;
  final String displayName;
}

class MarketMapping {
  const MarketMapping({
    required this.internalId,
    required this.apiFootballBetId,
    required this.displayName,
    required this.isMvp,
  });

  final InternalMarketId internalId;
  final int apiFootballBetId;
  final String displayName;
  final bool isMvp;
}

class NormalizedMarketSelection {
  const NormalizedMarketSelection({
    required this.marketId,
    required this.side,
    this.line,
    this.secondarySide,
  });

  final InternalMarketId marketId;
  final InternalSelectionSide side;
  final double? line;
  final InternalSelectionSide? secondarySide;

  String get stableId {
    final parts = [
      marketId.name,
      side.name,
      if (secondarySide != null) secondarySide!.name,
      if (line != null) line!.toStringAsFixed(2),
    ];

    return parts.join(':');
  }
}

class OddsNormalizationCatalog {
  const OddsNormalizationCatalog._();

  static const targetBookmakers = [
    BookmakerMapping(
      internalId: InternalBookmakerId.betfair,
      apiFootballId: 3,
      displayName: 'Betfair',
    ),
    BookmakerMapping(
      internalId: InternalBookmakerId.pinnacle,
      apiFootballId: 4,
      displayName: 'Pinnacle',
    ),
    BookmakerMapping(
      internalId: InternalBookmakerId.bwin,
      apiFootballId: 6,
      displayName: 'Bwin',
    ),
    BookmakerMapping(
      internalId: InternalBookmakerId.bet365,
      apiFootballId: 8,
      displayName: 'Bet365',
    ),
    BookmakerMapping(
      internalId: InternalBookmakerId.oneXBet,
      apiFootballId: 11,
      displayName: '1xBet',
    ),
    BookmakerMapping(
      internalId: InternalBookmakerId.unibet,
      apiFootballId: 16,
      displayName: 'Unibet',
    ),
  ];

  static const mvpMarkets = [
    MarketMapping(
      internalId: InternalMarketId.matchResult,
      apiFootballBetId: 1,
      displayName: '1 N 2',
      isMvp: true,
    ),
    MarketMapping(
      internalId: InternalMarketId.goalsTotal,
      apiFootballBetId: 5,
      displayName: 'Over / Under buts',
      isMvp: true,
    ),
    MarketMapping(
      internalId: InternalMarketId.bothTeamsScore,
      apiFootballBetId: 8,
      displayName: 'But pour les 2 équipes',
      isMvp: true,
    ),
    MarketMapping(
      internalId: InternalMarketId.doubleChance,
      apiFootballBetId: 12,
      displayName: 'Double chance',
      isMvp: true,
    ),
    MarketMapping(
      internalId: InternalMarketId.teamTotalHome,
      apiFootballBetId: 16,
      displayName: 'Total buts domicile',
      isMvp: true,
    ),
    MarketMapping(
      internalId: InternalMarketId.teamTotalAway,
      apiFootballBetId: 17,
      displayName: 'Total buts extérieur',
      isMvp: true,
    ),
    MarketMapping(
      internalId: InternalMarketId.cornersTotal,
      apiFootballBetId: 45,
      displayName: 'Over / Under corners',
      isMvp: true,
    ),
    MarketMapping(
      internalId: InternalMarketId.cardsTotal,
      apiFootballBetId: 80,
      displayName: 'Over / Under cartons',
      isMvp: true,
    ),
  ];

  static BookmakerMapping? bookmakerForApiFootballId(int bookmakerId) {
    for (final mapping in targetBookmakers) {
      if (mapping.apiFootballId == bookmakerId) {
        return mapping;
      }
    }

    return null;
  }

  static MarketMapping? marketForApiFootballBetId(int betId) {
    for (final mapping in mvpMarkets) {
      if (mapping.apiFootballBetId == betId) {
        return mapping;
      }
    }

    return null;
  }

  static NormalizedMarketSelection? normalizeSelection({
    required int apiFootballBetId,
    required String rawValue,
  }) {
    final market = marketForApiFootballBetId(apiFootballBetId);
    if (market == null) {
      return null;
    }

    return switch (market.internalId) {
      InternalMarketId.matchResult => _normalizeThreeWay(
        market.internalId,
        rawValue,
      ),
      InternalMarketId.doubleChance => _normalizeDoubleChance(rawValue),
      InternalMarketId.goalsTotal ||
      InternalMarketId.teamTotalHome ||
      InternalMarketId.teamTotalAway ||
      InternalMarketId.cornersTotal ||
      InternalMarketId.cardsTotal => _normalizeOverUnder(
        market.internalId,
        rawValue,
      ),
      InternalMarketId.bothTeamsScore => _normalizeYesNo(
        market.internalId,
        rawValue,
      ),
    };
  }

  static NormalizedMarketSelection? _normalizeThreeWay(
    InternalMarketId marketId,
    String rawValue,
  ) {
    final side = switch (rawValue.trim().toLowerCase()) {
      'home' => InternalSelectionSide.home,
      'draw' => InternalSelectionSide.draw,
      'away' => InternalSelectionSide.away,
      _ => null,
    };

    if (side == null) {
      return null;
    }

    return NormalizedMarketSelection(marketId: marketId, side: side);
  }

  static NormalizedMarketSelection? _normalizeDoubleChance(String rawValue) {
    final normalized = rawValue.trim().toLowerCase();

    return switch (normalized) {
      'home/draw' => const NormalizedMarketSelection(
        marketId: InternalMarketId.doubleChance,
        side: InternalSelectionSide.home,
        secondarySide: InternalSelectionSide.draw,
      ),
      'home/away' => const NormalizedMarketSelection(
        marketId: InternalMarketId.doubleChance,
        side: InternalSelectionSide.home,
        secondarySide: InternalSelectionSide.away,
      ),
      'draw/away' => const NormalizedMarketSelection(
        marketId: InternalMarketId.doubleChance,
        side: InternalSelectionSide.draw,
        secondarySide: InternalSelectionSide.away,
      ),
      _ => null,
    };
  }

  static NormalizedMarketSelection? _normalizeOverUnder(
    InternalMarketId marketId,
    String rawValue,
  ) {
    final match = RegExp(
      r'^(over|under)\s+([0-9]+(?:\.[0-9]+)?)$',
      caseSensitive: false,
    ).firstMatch(rawValue.trim());
    if (match == null) {
      return null;
    }

    final side = switch (match.group(1)!.toLowerCase()) {
      'over' => InternalSelectionSide.over,
      'under' => InternalSelectionSide.under,
      _ => null,
    };
    final line = double.tryParse(match.group(2)!);

    if (side == null || line == null) {
      return null;
    }

    return NormalizedMarketSelection(
      marketId: marketId,
      side: side,
      line: line,
    );
  }

  static NormalizedMarketSelection? _normalizeYesNo(
    InternalMarketId marketId,
    String rawValue,
  ) {
    final side = switch (rawValue.trim().toLowerCase()) {
      'yes' => InternalSelectionSide.yes,
      'no' => InternalSelectionSide.no,
      _ => null,
    };

    if (side == null) {
      return null;
    }

    return NormalizedMarketSelection(marketId: marketId, side: side);
  }
}
