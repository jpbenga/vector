import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'tier_input.dart';

class CanonicalStandingsStateHash {
  const CanonicalStandingsStateHash({
    required this.value,
    required this.canonicalSerialization,
  });

  final String value;
  final String canonicalSerialization;
}

class StandingsSnapshotIdentity {
  const StandingsSnapshotIdentity({
    required this.competitionId,
    required this.season,
    required this.canonicalStandingsStateHash,
    required this.tierSystemVersion,
    required this.anchorMetadataVersion,
    required this.competitionFormatVersion,
    required this.provenance,
  });

  final String competitionId;
  final int season;
  final CanonicalStandingsStateHash canonicalStandingsStateHash;
  final String tierSystemVersion;
  final String anchorMetadataVersion;
  final String competitionFormatVersion;
  final StructuralSnapshotProvenance provenance;

  String get value {
    return [
      'competitionId=${_canonicalScalar(competitionId)}',
      'season=$season',
      'tierSystemVersion=${_canonicalScalar(tierSystemVersion)}',
      'anchorMetadataVersion=${_canonicalScalar(anchorMetadataVersion)}',
      'competitionFormatVersion=${_canonicalScalar(competitionFormatVersion)}',
      'canonicalStandingsStateHash=${canonicalStandingsStateHash.value}',
    ].join('\n');
  }

  ChampionshipTierTemporalLineageKey get lineageKey {
    return ChampionshipTierTemporalLineageKey(
      competitionId: competitionId,
      season: season,
      tierSystemVersion: tierSystemVersion,
      anchorMetadataVersion: anchorMetadataVersion,
      competitionFormatVersion: competitionFormatVersion,
    );
  }
}

class StructuralSnapshotProvenance {
  const StructuralSnapshotProvenance({
    required this.analysisAsOf,
    this.sourceAsOf,
    this.sourceFetchedAt,
    this.providerSnapshotVersion,
  });

  final DateTime analysisAsOf;
  final DateTime? sourceAsOf;
  final DateTime? sourceFetchedAt;
  final String? providerSnapshotVersion;

  bool get isTemporalSafe {
    final source = sourceAsOf;
    return source == null || !source.isAfter(analysisAsOf);
  }
}

class ChampionshipTierTemporalLineageKey {
  const ChampionshipTierTemporalLineageKey({
    required this.competitionId,
    required this.season,
    required this.tierSystemVersion,
    required this.anchorMetadataVersion,
    required this.competitionFormatVersion,
  });

  final String competitionId;
  final int season;
  final String tierSystemVersion;
  final String anchorMetadataVersion;
  final String competitionFormatVersion;

  String get value {
    return [
      'competitionId=${_canonicalScalar(competitionId)}',
      'season=$season',
      'tierSystemVersion=${_canonicalScalar(tierSystemVersion)}',
      'anchorMetadataVersion=${_canonicalScalar(anchorMetadataVersion)}',
      'competitionFormatVersion=${_canonicalScalar(competitionFormatVersion)}',
    ].join('\n');
  }
}

class ChampionshipTierSnapshotCacheKey {
  const ChampionshipTierSnapshotCacheKey({
    required this.competitionId,
    required this.season,
    required this.canonicalStandingsStateHash,
    required this.tierSystemVersion,
    required this.anchorMetadataVersion,
    required this.competitionFormatVersion,
  });

  final String competitionId;
  final int season;
  final String canonicalStandingsStateHash;
  final String tierSystemVersion;
  final String anchorMetadataVersion;
  final String competitionFormatVersion;

  String get value {
    return [
      'competitionId=${_canonicalScalar(competitionId)}',
      'season=$season',
      'canonicalStandingsStateHash=$canonicalStandingsStateHash',
      'tierSystemVersion=${_canonicalScalar(tierSystemVersion)}',
      'anchorMetadataVersion=${_canonicalScalar(anchorMetadataVersion)}',
      'competitionFormatVersion=${_canonicalScalar(competitionFormatVersion)}',
    ].join('\n');
  }
}

class StandingsSnapshotIdentityBuilder {
  const StandingsSnapshotIdentityBuilder();

  StandingsSnapshotIdentity build({
    required String competitionId,
    required int season,
    required DateTime analysisAsOf,
    required Iterable<DynamicTierInputStanding> standingsRows,
    required String tierSystemVersion,
    required String anchorMetadataVersion,
    required String competitionFormatVersion,
    required DynamicTierSourceMetadata sourceMetadata,
    bool includeDescriptionInHash = false,
  }) {
    final provenance = StructuralSnapshotProvenance(
      analysisAsOf: analysisAsOf.toUtc(),
      sourceAsOf: sourceMetadata.sourceAsOf?.toUtc(),
      sourceFetchedAt: sourceMetadata.sourceFetchedAt?.toUtc(),
      providerSnapshotVersion: sourceMetadata.providerSnapshotVersion,
    );
    final hash = canonicalHash(
      competitionId: competitionId,
      season: season,
      standingsRows: standingsRows,
      tierSystemVersion: tierSystemVersion,
      anchorMetadataVersion: anchorMetadataVersion,
      competitionFormatVersion: competitionFormatVersion,
      includeDescriptionInHash: includeDescriptionInHash,
    );

    return StandingsSnapshotIdentity(
      competitionId: competitionId,
      season: season,
      canonicalStandingsStateHash: hash,
      tierSystemVersion: tierSystemVersion,
      anchorMetadataVersion: anchorMetadataVersion,
      competitionFormatVersion: competitionFormatVersion,
      provenance: provenance,
    );
  }

  CanonicalStandingsStateHash canonicalHash({
    required String competitionId,
    required int season,
    required Iterable<DynamicTierInputStanding> standingsRows,
    required String tierSystemVersion,
    required String anchorMetadataVersion,
    required String competitionFormatVersion,
    bool includeDescriptionInHash = false,
  }) {
    final serialization = canonicalSerialization(
      competitionId: competitionId,
      season: season,
      standingsRows: standingsRows,
      tierSystemVersion: tierSystemVersion,
      anchorMetadataVersion: anchorMetadataVersion,
      competitionFormatVersion: competitionFormatVersion,
      includeDescriptionInHash: includeDescriptionInHash,
    );
    final digest = sha256.convert(utf8.encode(serialization));
    return CanonicalStandingsStateHash(
      value: digest.toString(),
      canonicalSerialization: serialization,
    );
  }

  String canonicalSerialization({
    required String competitionId,
    required int season,
    required Iterable<DynamicTierInputStanding> standingsRows,
    required String tierSystemVersion,
    required String anchorMetadataVersion,
    required String competitionFormatVersion,
    bool includeDescriptionInHash = false,
  }) {
    final orderedRows = standingsRows.toList()
      ..sort((a, b) {
        final rankComparison = a.officialRank.compareTo(b.officialRank);
        if (rankComparison != 0) {
          return rankComparison;
        }
        return a.teamId.compareTo(b.teamId);
      });

    return [
      'canonicalFormat=lector-standings-structural-v1',
      'competitionId=${_canonicalScalar(competitionId)}',
      'season=$season',
      'tierSystemVersion=${_canonicalScalar(tierSystemVersion)}',
      'anchorMetadataVersion=${_canonicalScalar(anchorMetadataVersion)}',
      'competitionFormatVersion=${_canonicalScalar(competitionFormatVersion)}',
      'descriptionIncluded=${includeDescriptionInHash ? 'true' : 'false'}',
      for (final row in orderedRows)
        'row=${_canonicalRow(row, includeDescriptionInHash)}',
    ].join('\n');
  }

  static String _canonicalRow(
    DynamicTierInputStanding row,
    bool includeDescriptionInHash,
  ) {
    return [
      row.teamId,
      row.officialRank,
      row.points,
      row.played,
      row.group,
      if (includeDescriptionInHash) row.description,
    ].map(_canonicalScalar).join('|');
  }
}

String _canonicalScalar(Object? value) {
  if (value is DateTime) {
    return jsonEncode(value.toUtc().toIso8601String());
  }
  return jsonEncode(value);
}
