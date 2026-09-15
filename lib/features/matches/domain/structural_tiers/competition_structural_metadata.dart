import '../match_board_item.dart';
import 'tier_parameters.dart';

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
  tierDefinition,
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

class StandingsCompetitionStructuralMetadataResolver {
  const StandingsCompetitionStructuralMetadataResolver();

  CompetitionStructuralMetadata? resolve({
    required String competitionId,
    required int season,
    required List<TeamStandingSnapshot> leagueStandings,
  }) {
    if (leagueStandings.length < DynamicTierParameters.supportedMinTeams ||
        leagueStandings.length > DynamicTierParameters.supportedMaxTeams) {
      return null;
    }

    final ordered = [...leagueStandings]
      ..sort((left, right) => (left.rank ?? 0).compareTo(right.rank ?? 0));
    for (var index = 0; index < ordered.length; index += 1) {
      final standing = ordered[index];
      if (standing.rank != index + 1 ||
          standing.points == null ||
          standing.played == null ||
          standing.played! < 0) {
        return null;
      }
    }

    final groups = ordered
        .map((standing) => _normalized(standing.group))
        .where((group) => group.isNotEmpty)
        .toSet();
    if (groups.length > 1) {
      return null;
    }

    final lastDescription = ordered.last.description?.trim();
    final normalizedLastDescription = _normalized(lastDescription);
    if (!_isRelegationZoneDescription(normalizedLastDescription)) {
      return null;
    }

    var relegationStartIndex = ordered.length - 1;
    while (relegationStartIndex > 0 &&
        _normalized(ordered[relegationStartIndex - 1].description) ==
            normalizedLastDescription) {
      relegationStartIndex -= 1;
    }
    final relegationStartRank = ordered[relegationStartIndex].rank!;
    if (relegationStartRank <= 3) {
      return null;
    }

    return CompetitionStructuralMetadata(
      competitionId: competitionId,
      season: season,
      competitionFormat: CompetitionFormat.standardRoundRobin,
      supportStatus: StructuralSupportStatus.supportedV1,
      podiumAnchor: const CompetitionStructuralAnchor(
        startRank: 1,
        endRank: 3,
        source: StructuralAnchorSource.tierDefinition,
      ),
      relegationAnchor: CompetitionStructuralAnchor(
        startRank: relegationStartRank,
        endRank: ordered.last.rank!,
        source: StructuralAnchorSource.providerDescription,
        sourceDescription: lastDescription,
      ),
      descriptionPolicy: StandingDescriptionPolicy(
        mappings: [
          StandingDescriptionMapping(
            providerDescription: lastDescription!,
            target: _relegationMappingTarget(normalizedLastDescription),
            source: StructuralAnchorSource.providerDescription,
          ),
        ],
      ),
      anchorMetadataVersion:
          CompetitionStructuralMetadataCatalog.dynamicAnchorMetadataVersion,
      competitionFormatVersion:
          CompetitionStructuralMetadataCatalog.dynamicFormatVersion,
      structuralMetadataVersion:
          CompetitionStructuralMetadataCatalog.dynamicStructuralMetadataVersion,
    );
  }

  static String _normalized(String? value) => value?.trim().toLowerCase() ?? '';

  static bool _isRelegationZoneDescription(String value) {
    return value.contains('relegation');
  }

  static StandingDescriptionMappingTarget _relegationMappingTarget(
    String value,
  ) {
    if (value.contains('playoff') ||
        value.contains('play-off') ||
        value.contains('play off')) {
      return StandingDescriptionMappingTarget.relegationPlayoff;
    }
    if (value.contains('group') || value.contains('round')) {
      return StandingDescriptionMappingTarget.relegationGroup;
    }
    return StandingDescriptionMappingTarget.directRelegationAnchor;
  }
}

class CompetitionStructuralMetadataCatalog {
  const CompetitionStructuralMetadataCatalog._();

  static const anySeason = 0;
  static const structuralMetadataVersion = 'structural-metadata-v1';
  static const anchorMetadataVersion = 'anchor-metadata-v1';
  static const competitionFormatVersion = 'competition-format-v1';
  static const dynamicAnchorMetadataVersion = 'snapshot-anchor-v2';
  static const dynamicFormatVersion = 'snapshot-format-v2';
  static const dynamicStructuralMetadataVersion = 'snapshot-structure-v2';

  static const values = <CompetitionStructuralMetadata>[];
}
