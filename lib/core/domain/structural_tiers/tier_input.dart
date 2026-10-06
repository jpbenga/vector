import 'competition_structural_metadata.dart';
import 'tier_parameters.dart';

class DynamicTierInput {
  const DynamicTierInput({
    required this.competitionId,
    required this.season,
    required this.analysisAsOf,
    required this.competitionFormat,
    required this.standingsRows,
    required this.podiumAnchor,
    required this.relegationAnchor,
    required this.anchorMetadataVersion,
    required this.competitionFormatVersion,
    required this.structuralMetadataVersion,
    this.standingsSnapshotIdentity = 'manual-standings-snapshot',
    this.seasonProgress,
    this.minimumTeams = DynamicTierParameters.supportedMinTeams,
    this.maximumTeams = DynamicTierParameters.supportedMaxTeams,
    this.supportedFormats = const {CompetitionFormat.standardRoundRobin},
    this.sourceMetadata = const DynamicTierSourceMetadata(),
  });

  final int minimumTeams, maximumTeams;
  final Set<CompetitionFormat> supportedFormats;
  final String competitionId;
  final int season;
  final DateTime analysisAsOf;
  final CompetitionFormat competitionFormat;
  final List<DynamicTierInputStanding> standingsRows;
  final CompetitionStructuralAnchor podiumAnchor;
  final CompetitionStructuralAnchor relegationAnchor;
  final String anchorMetadataVersion;
  final String competitionFormatVersion;
  final String structuralMetadataVersion;
  final String standingsSnapshotIdentity;
  final double? seasonProgress;
  final DynamicTierSourceMetadata sourceMetadata;
}

class DynamicTierSourceMetadata {
  const DynamicTierSourceMetadata({
    this.sourceAsOf,
    this.sourceFetchedAt,
    this.providerSnapshotVersion,
  });

  factory DynamicTierSourceMetadata.fromSnapshotPayload(
    Map<String, Object?> snapshot,
  ) {
    return DynamicTierSourceMetadata(
      sourceAsOf:
          _dateTimeValue(snapshot['as_of']) ??
          _dateTimeValue(snapshot['source_as_of']) ??
          _dateTimeValue(snapshot['captured_at']),
      sourceFetchedAt:
          _dateTimeValue(snapshot['source_fetched_at']) ??
          _dateTimeValue(snapshot['fetched_at']) ??
          _dateTimeValue(snapshot['snapshot_created_at']),
      providerSnapshotVersion:
          snapshot['provider_snapshot_version']?.toString() ??
          snapshot['schema_version']?.toString(),
    );
  }

  final DateTime? sourceAsOf;
  final DateTime? sourceFetchedAt;
  final String? providerSnapshotVersion;
}

class DynamicTierInputStanding {
  const DynamicTierInputStanding({
    required this.teamId,
    required this.teamName,
    required this.officialRank,
    required this.points,
    required this.played,
    this.group,
    this.description,
  });

  final int teamId;
  final String teamName;
  final int officialRank;
  final int points;
  final int played;
  final String? group;
  final String? description;
}

DateTime? _dateTimeValue(Object? value) {
  if (value is DateTime) {
    return value.toUtc();
  }
  if (value is! String || value.trim().isEmpty) {
    return null;
  }
  return DateTime.tryParse(value)?.toUtc();
}
