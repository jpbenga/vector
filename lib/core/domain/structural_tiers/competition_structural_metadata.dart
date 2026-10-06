enum CompetitionFormat {
  standardRoundRobin,
  splitLeague,
  playoffsOnly,
  aperturaClausura,
  conference,
  groupedCompetition,
  unknown,
}

enum StructuralAnchorSource {
  tierDefinition,
  lectorOverride,
  competitionMetadata,
  providerDescription,
}

class CompetitionStructuralAnchor {
  const CompetitionStructuralAnchor({
    required this.startRank,
    required this.endRank,
    required this.source,
    this.sourceDescription,
  }) : assert(startRank > 0),
       assert(endRank >= startRank);

  final int startRank;
  final int endRank;
  final StructuralAnchorSource source;
  final String? sourceDescription;

  bool containsRank(int rank) => rank >= startRank && rank <= endRank;
}
