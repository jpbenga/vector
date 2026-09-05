import '../match_board_item.dart';
import 'competition_structural_metadata.dart';

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
    this.sourceMetadata = const DynamicTierSourceMetadata(),
  });

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

enum DynamicTierInputBuildError {
  missingAnalysisAsOf,
  missingStructuralMetadata,
  unsupportedCompetition,
  unknownCompetitionFormat,
  emptyStandings,
  missingOfficialRank,
  missingPoints,
  missingPlayed,
  missingPodiumAnchor,
  missingRelegationAnchor,
  sourceSnapshotAfterAnalysis,
}

class DynamicTierInputBuildResult {
  const DynamicTierInputBuildResult._({this.input, this.errors = const []});

  factory DynamicTierInputBuildResult.success(DynamicTierInput input) {
    return DynamicTierInputBuildResult._(input: input);
  }

  factory DynamicTierInputBuildResult.failure(
    Iterable<DynamicTierInputBuildError> errors,
  ) {
    return DynamicTierInputBuildResult._(errors: List.unmodifiable(errors));
  }

  final DynamicTierInput? input;
  final List<DynamicTierInputBuildError> errors;

  bool get isValid => input != null && errors.isEmpty;
}

class DynamicTierInputBuilder {
  const DynamicTierInputBuilder();

  DynamicTierInputBuildResult build({
    required String competitionId,
    required int season,
    required DateTime? analysisAsOf,
    required List<TeamStandingSnapshot> leagueStandings,
    required CompetitionStructuralMetadata? metadata,
    String standingsSnapshotIdentity = 'manual-standings-snapshot',
    double? seasonProgress,
    DynamicTierSourceMetadata sourceMetadata =
        const DynamicTierSourceMetadata(),
  }) {
    final errors = <DynamicTierInputBuildError>{};
    if (analysisAsOf == null) {
      errors.add(DynamicTierInputBuildError.missingAnalysisAsOf);
    } else {
      final sourceAsOf = sourceMetadata.sourceAsOf;
      if (sourceAsOf != null && sourceAsOf.isAfter(analysisAsOf)) {
        errors.add(DynamicTierInputBuildError.sourceSnapshotAfterAnalysis);
      }
    }
    if (leagueStandings.isEmpty) {
      errors.add(DynamicTierInputBuildError.emptyStandings);
    }

    if (metadata == null) {
      errors.add(DynamicTierInputBuildError.missingStructuralMetadata);
    } else {
      if (metadata.competitionFormat == CompetitionFormat.unknown) {
        errors.add(DynamicTierInputBuildError.unknownCompetitionFormat);
      }
      if (!metadata.isSupportedV1) {
        errors.add(DynamicTierInputBuildError.unsupportedCompetition);
      }
      if (metadata.podiumAnchor == null) {
        errors.add(DynamicTierInputBuildError.missingPodiumAnchor);
      }
      if (metadata.relegationAnchor == null) {
        errors.add(DynamicTierInputBuildError.missingRelegationAnchor);
      }
    }

    for (final standing in leagueStandings) {
      if (standing.rank == null) {
        errors.add(DynamicTierInputBuildError.missingOfficialRank);
      }
      if (standing.points == null) {
        errors.add(DynamicTierInputBuildError.missingPoints);
      }
      if (standing.played == null) {
        errors.add(DynamicTierInputBuildError.missingPlayed);
      }
    }

    if (errors.isNotEmpty) {
      return DynamicTierInputBuildResult.failure(errors);
    }

    final resolvedMetadata = metadata!;
    final inputRows = leagueStandings
        .map(
          (standing) => DynamicTierInputStanding(
            teamId: standing.teamId,
            teamName: standing.teamName,
            officialRank: standing.rank!,
            points: standing.points!,
            played: standing.played!,
            group: standing.group,
            description: standing.description,
          ),
        )
        .toList(growable: false);

    return DynamicTierInputBuildResult.success(
      DynamicTierInput(
        competitionId: competitionId,
        season: season,
        analysisAsOf: analysisAsOf!,
        competitionFormat: resolvedMetadata.competitionFormat,
        standingsRows: inputRows,
        podiumAnchor: resolvedMetadata.podiumAnchor!,
        relegationAnchor: resolvedMetadata.relegationAnchor!,
        anchorMetadataVersion: resolvedMetadata.anchorMetadataVersion,
        competitionFormatVersion: resolvedMetadata.competitionFormatVersion,
        structuralMetadataVersion: resolvedMetadata.structuralMetadataVersion,
        standingsSnapshotIdentity: standingsSnapshotIdentity,
        seasonProgress: seasonProgress,
        sourceMetadata: sourceMetadata,
      ),
    );
  }
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
