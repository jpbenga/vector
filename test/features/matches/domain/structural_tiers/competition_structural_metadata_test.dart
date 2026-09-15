import 'package:copilot/features/matches/domain/match_board_item.dart';
import 'package:copilot/features/matches/domain/structural_tiers/competition_structural_metadata.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CompetitionStructuralMetadata', () {
    test('resolves a standard league from its current standings', () {
      const resolver = StandingsCompetitionStructuralMetadataResolver();

      final metadata = resolver.resolve(
        competitionId: '9999',
        season: 2031,
        leagueStandings: _standardStandings(
          teamCount: 18,
          directRelegationCount: 2,
        ),
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
        StructuralAnchorSource.tierDefinition,
      );
      expect(metadata.relegationAnchor?.startRank, 17);
      expect(metadata.relegationAnchor?.endRank, 18);
      expect(
        metadata.relegationAnchor?.source,
        StructuralAnchorSource.providerDescription,
      );
      expect(
        metadata.descriptionPolicy
            .mappingFor('Relegation - Division 2')
            ?.target,
        StandingDescriptionMappingTarget.directRelegationAnchor,
      );
    });

    test('keeps the default catalog free of league-specific rules', () {
      const repository = StaticCompetitionStructuralMetadataRepository();

      expect(repository.metadataFor(competitionId: '39', season: 2026), isNull);
      expect(
        repository.metadataFor(competitionId: '103', season: 2026),
        isNull,
      );
      expect(
        repository.metadataFor(competitionId: '113', season: 2026),
        isNull,
      );
    });

    test('derives the Eliteserien anchors without a competition rule', () {
      const resolver = StandingsCompetitionStructuralMetadataResolver();

      final standings = _standardStandings(
        teamCount: 16,
        directRelegationCount: 2,
      );
      standings[13] = _standing(
        rank: 14,
        teamCount: 16,
        description: 'Eliteserien (Relegation)',
      );
      final metadata = resolver.resolve(
        competitionId: '103',
        season: 2026,
        leagueStandings: standings,
      );

      expect(metadata, isNotNull);
      expect(metadata!.relegationAnchor?.startRank, 15);
      expect(metadata.relegationAnchor?.endRank, 16);
    });

    test('resolves another standard league without adding its id', () {
      const resolver = StandingsCompetitionStructuralMetadataResolver();

      final metadata = resolver.resolve(
        competitionId: '113',
        season: 2026,
        leagueStandings: _standardStandings(
          teamCount: 16,
          directRelegationCount: 2,
          relegationDescription: 'Relegation',
        ),
      );

      expect(metadata, isNotNull);
      expect(metadata!.relegationAnchor?.startRank, 15);
      expect(metadata.relegationAnchor?.endRank, 16);
    });

    test(
      'keeps tiers available while one regular table advertises future playoff groups',
      () {
        const resolver = StandingsCompetitionStructuralMetadataResolver();
        final standings = [
          for (var rank = 1; rank <= 12; rank += 1)
            _standing(
              rank: rank,
              teamCount: 12,
              group: 'Besta deild',
              description: rank <= 6 ? 'Play-offs' : 'Relegation Playoffs',
            ),
        ];

        final metadata = resolver.resolve(
          competitionId: '164',
          season: 2026,
          leagueStandings: standings,
        );

        expect(metadata, isNotNull);
        expect(
          metadata!.competitionFormat,
          CompetitionFormat.standardRoundRobin,
        );
        expect(metadata.relegationAnchor?.startRank, 7);
        expect(metadata.relegationAnchor?.endRank, 12);
        expect(
          metadata.descriptionPolicy.mappingFor('Relegation Playoffs')?.target,
          StandingDescriptionMappingTarget.relegationPlayoff,
        );
      },
    );

    test('rejects split or grouped standings', () {
      const resolver = StandingsCompetitionStructuralMetadataResolver();
      final standings = _standardStandings(
        teamCount: 12,
        directRelegationCount: 2,
      );
      for (var index = 0; index < standings.length; index += 1) {
        standings[index] = _standing(
          rank: index + 1,
          teamCount: 12,
          group: index < 6 ? 'Championship Group' : 'Relegation Group',
          description: standings[index].description,
        );
      }

      final metadata = resolver.resolve(
        competitionId: '244',
        season: 2026,
        leagueStandings: standings,
      );

      expect(metadata, isNull);
    });

    test('does not invent a relegation zone when none is available', () {
      const resolver = StandingsCompetitionStructuralMetadataResolver();
      final standings = _standardStandings(
        teamCount: 18,
        directRelegationCount: 2,
      );
      for (var index = 0; index < standings.length; index += 1) {
        standings[index] = _standing(rank: index + 1, teamCount: 18);
      }

      final metadata = resolver.resolve(
        competitionId: '8888',
        season: 2031,
        leagueStandings: standings,
      );

      expect(metadata, isNull);
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

List<TeamStandingSnapshot> _standardStandings({
  required int teamCount,
  required int directRelegationCount,
  String relegationDescription = 'Relegation - Division 2',
}) {
  return [
    for (var rank = 1; rank <= teamCount; rank += 1)
      _standing(
        rank: rank,
        teamCount: teamCount,
        description: rank > teamCount - directRelegationCount
            ? relegationDescription
            : null,
      ),
  ];
}

TeamStandingSnapshot _standing({
  required int rank,
  required int teamCount,
  String group = 'Standard League',
  String? description,
}) {
  return TeamStandingSnapshot(
    teamId: rank,
    teamName: 'Team $rank',
    rank: rank,
    points: (teamCount - rank) * 2,
    played: 12,
    group: group,
    description: description,
  );
}
