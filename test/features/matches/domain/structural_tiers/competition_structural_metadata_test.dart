import 'package:copilot/features/matches/domain/structural_tiers/competition_structural_metadata.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CompetitionStructuralMetadata', () {
    test('resolves explicit supported V1 metadata from static catalog', () {
      const repository = StaticCompetitionStructuralMetadataRepository();

      final metadata = repository.metadataFor(
        competitionId: '39',
        season: 2026,
      );

      expect(metadata, isNotNull);
      expect(metadata!.competitionFormat, CompetitionFormat.standardRoundRobin);
      expect(metadata.supportStatus, StructuralSupportStatus.supportedV1);
      expect(metadata.isSupportedV1, isTrue);
      expect(metadata.hasRequiredAnchors, isTrue);
      expect(metadata.podiumAnchor?.startRank, 1);
      expect(metadata.podiumAnchor?.endRank, 3);
      expect(
        metadata.podiumAnchor?.source,
        StructuralAnchorSource.lectorOverride,
      );
      expect(metadata.relegationAnchor?.startRank, 18);
      expect(metadata.relegationAnchor?.endRank, 20);
      expect(
        metadata.anchorMetadataVersion,
        CompetitionStructuralMetadataCatalog.anchorMetadataVersion,
      );
      expect(
        metadata.competitionFormatVersion,
        CompetitionStructuralMetadataCatalog.competitionFormatVersion,
      );
      expect(
        metadata.structuralMetadataVersion,
        CompetitionStructuralMetadataCatalog.structuralMetadataVersion,
      );
    });

    test('marks unsupported known formats without guessing anchors', () {
      const repository = StaticCompetitionStructuralMetadataRepository();

      final metadata = repository.metadataFor(competitionId: '2', season: 2026);

      expect(metadata, isNotNull);
      expect(metadata!.competitionFormat, CompetitionFormat.groupedCompetition);
      expect(metadata.supportStatus, StructuralSupportStatus.unsupportedV1);
      expect(metadata.isSupportedV1, isFalse);
      expect(metadata.hasRequiredAnchors, isFalse);
      expect(metadata.podiumAnchor, isNull);
      expect(metadata.relegationAnchor, isNull);
    });

    test(
      'returns null for competitions without explicit structural metadata',
      () {
        const repository = StaticCompetitionStructuralMetadataRepository();

        final metadata = repository.metadataFor(
          competitionId: '9999',
          season: 2026,
        );

        expect(metadata, isNull);
      },
    );

    test('supports exact provider description mappings without parsing', () {
      const policy = StandingDescriptionPolicy(
        mappings: [
          StandingDescriptionMapping(
            providerDescription: 'Relegation - OBOS-ligaen',
            target: StandingDescriptionMappingTarget.directRelegationAnchor,
            source: StructuralAnchorSource.providerDescription,
          ),
        ],
      );

      expect(
        policy.mappingFor('Relegation - OBOS-ligaen')?.target,
        StandingDescriptionMappingTarget.directRelegationAnchor,
      );
      expect(policy.mappingFor('Relegation'), isNull);
    });
  });
}
