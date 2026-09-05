import 'package:copilot/features/matches/domain/structural_tiers/standings_snapshot_identity.dart';
import 'package:copilot/features/matches/domain/structural_tiers/tier_input.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StandingsSnapshotIdentityBuilder', () {
    test('builds the same hash for equivalent unordered rows', () {
      final first = _builder.build(
        competitionId: '39',
        season: 2026,
        analysisAsOf: _analysisAsOf,
        standingsRows: [_row(2, 58), _row(1, 60), _row(3, 57)],
        tierSystemVersion: 'tier-v1',
        anchorMetadataVersion: 'anchor-v1',
        competitionFormatVersion: 'format-v1',
        sourceMetadata: DynamicTierSourceMetadata(
          sourceAsOf: _analysisAsOf,
          sourceFetchedAt: DateTime.utc(2026, 9, 2, 9),
        ),
      );
      final second = _builder.build(
        competitionId: '39',
        season: 2026,
        analysisAsOf: _analysisAsOf,
        standingsRows: [_row(3, 57), _row(2, 58), _row(1, 60)],
        tierSystemVersion: 'tier-v1',
        anchorMetadataVersion: 'anchor-v1',
        competitionFormatVersion: 'format-v1',
        sourceMetadata: DynamicTierSourceMetadata(
          sourceAsOf: _analysisAsOf,
          sourceFetchedAt: DateTime.utc(2026, 9, 2, 10),
        ),
      );

      expect(
        first.canonicalStandingsStateHash.value,
        second.canonicalStandingsStateHash.value,
      );
      expect(first.value, second.value);
    });

    test('changes hash when points, rank or played changes', () {
      final base = _hash([_row(1, 60), _row(2, 58), _row(3, 57)]);

      expect(_hash([_row(1, 61), _row(2, 58), _row(3, 57)]), isNot(base));
      expect(
        _hash([_row(2, 60, teamId: 1), _row(1, 58, teamId: 2), _row(3, 57)]),
        isNot(base),
      );
      expect(
        _hash([_row(1, 60, played: 21), _row(2, 58), _row(3, 57)]),
        isNot(base),
      );
    });

    test(
      'changes identity when structural metadata or tier version changes',
      () {
        final base = _identity(
          tierSystemVersion: 'tier-v1',
          anchorMetadataVersion: 'anchor-v1',
          competitionFormatVersion: 'format-v1',
        );

        expect(
          _identity(
            tierSystemVersion: 'tier-v2',
            anchorMetadataVersion: 'anchor-v1',
            competitionFormatVersion: 'format-v1',
          ).value,
          isNot(base.value),
        );
        expect(
          _identity(
            tierSystemVersion: 'tier-v1',
            anchorMetadataVersion: 'anchor-v2',
            competitionFormatVersion: 'format-v1',
          ).value,
          isNot(base.value),
        );
        expect(
          _identity(
            tierSystemVersion: 'tier-v1',
            anchorMetadataVersion: 'anchor-v1',
            competitionFormatVersion: 'format-v2',
          ).value,
          isNot(base.value),
        );
      },
    );

    test(
      'excludes volatile source timestamps from the structural identity',
      () {
        final first = _identity(sourceFetchedAt: DateTime.utc(2026, 9, 2, 9));
        final second = _identity(sourceFetchedAt: DateTime.utc(2026, 9, 2, 10));

        expect(
          first.canonicalStandingsStateHash.value,
          second.canonicalStandingsStateHash.value,
        );
        expect(first.value, second.value);
        expect(
          first.provenance.sourceFetchedAt,
          isNot(second.provenance.sourceFetchedAt),
        );
      },
    );

    test('excludes display-only team names from the hash', () {
      final first = _hash([_row(1, 60, teamName: 'Team A'), _row(2, 58)]);
      final second = _hash([
        _row(1, 60, teamName: 'TEAM A'),
        _row(2, 58, teamName: 'Team B'),
      ]);

      expect(first, second);
    });

    test('includes description only when structural policy consumes it', () {
      final rows = [
        _row(1, 60, description: 'Promotion'),
        _row(2, 58),
        _row(3, 57),
      ];
      final preserveOnly = _builder.canonicalHash(
        competitionId: '39',
        season: 2026,
        standingsRows: rows,
        tierSystemVersion: 'tier-v1',
        anchorMetadataVersion: 'anchor-v1',
        competitionFormatVersion: 'format-v1',
      );
      final consumed = _builder.canonicalHash(
        competitionId: '39',
        season: 2026,
        standingsRows: rows,
        tierSystemVersion: 'tier-v1',
        anchorMetadataVersion: 'anchor-v1',
        competitionFormatVersion: 'format-v1',
        includeDescriptionInHash: true,
      );

      expect(preserveOnly.value, isNot(consumed.value));
      expect(
        preserveOnly.canonicalSerialization,
        contains('descriptionIncluded=false'),
      );
      expect(
        consumed.canonicalSerialization,
        contains('descriptionIncluded=true'),
      );
    });

    test(
      'extracts source metadata from the current snapshot payload shape',
      () {
        final metadata = DynamicTierSourceMetadata.fromSnapshotPayload({
          'schema_version': 1,
          'captured_at': '2026-09-02T08:00:00Z',
          'as_of': '2026-09-02T07:55:00Z',
          'snapshot_created_at': '2026-09-02T08:01:00Z',
        });

        expect(metadata.sourceAsOf, DateTime.utc(2026, 9, 2, 7, 55));
        expect(metadata.sourceFetchedAt, DateTime.utc(2026, 9, 2, 8, 1));
        expect(metadata.providerSnapshotVersion, '1');
      },
    );
  });
}

final _builder = StandingsSnapshotIdentityBuilder();
final _analysisAsOf = DateTime.utc(2026, 9, 2, 12);

String _hash(List<DynamicTierInputStanding> rows) {
  return _builder
      .canonicalHash(
        competitionId: '39',
        season: 2026,
        standingsRows: rows,
        tierSystemVersion: 'tier-v1',
        anchorMetadataVersion: 'anchor-v1',
        competitionFormatVersion: 'format-v1',
      )
      .value;
}

StandingsSnapshotIdentity _identity({
  String tierSystemVersion = 'tier-v1',
  String anchorMetadataVersion = 'anchor-v1',
  String competitionFormatVersion = 'format-v1',
  DateTime? sourceFetchedAt,
}) {
  return _builder.build(
    competitionId: '39',
    season: 2026,
    analysisAsOf: _analysisAsOf,
    standingsRows: [_row(1, 60), _row(2, 58), _row(3, 57)],
    tierSystemVersion: tierSystemVersion,
    anchorMetadataVersion: anchorMetadataVersion,
    competitionFormatVersion: competitionFormatVersion,
    sourceMetadata: DynamicTierSourceMetadata(
      sourceAsOf: _analysisAsOf,
      sourceFetchedAt: sourceFetchedAt,
    ),
  );
}

DynamicTierInputStanding _row(
  int rank,
  int points, {
  int? teamId,
  int played = 20,
  String? teamName,
  String? description,
}) {
  return DynamicTierInputStanding(
    teamId: teamId ?? rank,
    teamName: teamName ?? 'Team ${teamId ?? rank}',
    officialRank: rank,
    points: points,
    played: played,
    group: 'Premier League',
    description: description,
  );
}
