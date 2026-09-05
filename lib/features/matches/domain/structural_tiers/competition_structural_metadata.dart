enum CompetitionFormat {
  standardRoundRobin,
  splitLeague,
  playoffsOnly,
  aperturaClausura,
  conference,
  groupedCompetition,
  unknown,
}

enum StructuralSupportStatus { supportedV1, unsupportedV1, unknown }

enum StructuralAnchorSource {
  lectorOverride,
  competitionMetadata,
  providerDescription,
}

enum StandingDescriptionMappingTarget {
  podiumAnchor,
  qualification,
  directRelegationAnchor,
  relegationPlayoff,
  championshipGroup,
  relegationGroup,
  ignored,
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

class StandingDescriptionMapping {
  const StandingDescriptionMapping({
    required this.providerDescription,
    required this.target,
    required this.source,
  });

  final String providerDescription;
  final StandingDescriptionMappingTarget target;
  final StructuralAnchorSource source;
}

class StandingDescriptionPolicy {
  const StandingDescriptionPolicy({this.mappings = const []});

  static const preserveOnly = StandingDescriptionPolicy();

  final List<StandingDescriptionMapping> mappings;

  StandingDescriptionMapping? mappingFor(String description) {
    for (final mapping in mappings) {
      if (mapping.providerDescription == description) {
        return mapping;
      }
    }
    return null;
  }
}

class CompetitionStructuralMetadata {
  const CompetitionStructuralMetadata({
    required this.competitionId,
    required this.season,
    required this.competitionFormat,
    required this.supportStatus,
    required this.anchorMetadataVersion,
    required this.competitionFormatVersion,
    required this.structuralMetadataVersion,
    this.podiumAnchor,
    this.relegationAnchor,
    this.descriptionPolicy = StandingDescriptionPolicy.preserveOnly,
  });

  final String competitionId;
  final int season;
  final CompetitionFormat competitionFormat;
  final StructuralSupportStatus supportStatus;
  final CompetitionStructuralAnchor? podiumAnchor;
  final CompetitionStructuralAnchor? relegationAnchor;
  final StandingDescriptionPolicy descriptionPolicy;
  final String anchorMetadataVersion;
  final String competitionFormatVersion;
  final String structuralMetadataVersion;

  bool get isSupportedV1 =>
      supportStatus == StructuralSupportStatus.supportedV1 &&
      competitionFormat == CompetitionFormat.standardRoundRobin;

  bool get hasRequiredAnchors =>
      podiumAnchor != null && relegationAnchor != null;
}

abstract interface class CompetitionStructuralMetadataRepository {
  CompetitionStructuralMetadata? metadataFor({
    required String competitionId,
    required int season,
  });
}

class StaticCompetitionStructuralMetadataRepository
    implements CompetitionStructuralMetadataRepository {
  const StaticCompetitionStructuralMetadataRepository({
    this.metadata = CompetitionStructuralMetadataCatalog.values,
  });

  final List<CompetitionStructuralMetadata> metadata;

  @override
  CompetitionStructuralMetadata? metadataFor({
    required String competitionId,
    required int season,
  }) {
    CompetitionStructuralMetadata? seasonAgnosticMatch;
    for (final item in metadata) {
      if (item.competitionId != competitionId) {
        continue;
      }
      if (item.season == season) {
        return item;
      }
      if (item.season == CompetitionStructuralMetadataCatalog.anySeason) {
        seasonAgnosticMatch = item;
      }
    }
    return seasonAgnosticMatch;
  }
}

class CompetitionStructuralMetadataCatalog {
  const CompetitionStructuralMetadataCatalog._();

  static const anySeason = 0;
  static const structuralMetadataVersion = 'structural-metadata-v1';
  static const anchorMetadataVersion = 'anchor-metadata-v1';
  static const competitionFormatVersion = 'competition-format-v1';

  // Explicit first V1 seed. This is not a universal fallback rule.
  static const premierLeague2026 = CompetitionStructuralMetadata(
    competitionId: '39',
    season: 2026,
    competitionFormat: CompetitionFormat.standardRoundRobin,
    supportStatus: StructuralSupportStatus.supportedV1,
    podiumAnchor: CompetitionStructuralAnchor(
      startRank: 1,
      endRank: 3,
      source: StructuralAnchorSource.lectorOverride,
    ),
    relegationAnchor: CompetitionStructuralAnchor(
      startRank: 18,
      endRank: 20,
      source: StructuralAnchorSource.lectorOverride,
    ),
    anchorMetadataVersion: anchorMetadataVersion,
    competitionFormatVersion: competitionFormatVersion,
    structuralMetadataVersion: structuralMetadataVersion,
  );

  static const championsLeague2026 = CompetitionStructuralMetadata(
    competitionId: '2',
    season: 2026,
    competitionFormat: CompetitionFormat.groupedCompetition,
    supportStatus: StructuralSupportStatus.unsupportedV1,
    anchorMetadataVersion: anchorMetadataVersion,
    competitionFormatVersion: competitionFormatVersion,
    structuralMetadataVersion: structuralMetadataVersion,
  );

  static const values = <CompetitionStructuralMetadata>[
    premierLeague2026,
    championsLeague2026,
  ];
}
