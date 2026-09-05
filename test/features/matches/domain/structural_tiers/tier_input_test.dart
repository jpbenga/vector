import 'package:copilot/features/matches/domain/match_board_item.dart';
import 'package:copilot/features/matches/domain/structural_tiers/competition_structural_metadata.dart';
import 'package:copilot/features/matches/domain/structural_tiers/tier_input.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DynamicTierInputBuilder', () {
    test(
      'builds a deterministic input contract from standings and metadata',
      () {
        final analysisAsOf = DateTime.utc(2026, 7, 30, 8);
        final result = const DynamicTierInputBuilder().build(
          competitionId: 'test-league',
          season: 2026,
          analysisAsOf: analysisAsOf,
          leagueStandings: [
            _standing(
              teamId: 10,
              teamName: 'Home',
              rank: 1,
              points: 40,
              played: 20,
              group: 'Test League',
              description: 'Promotion - Champions League (Qualification)',
            ),
            _standing(
              teamId: 11,
              teamName: 'Away',
              rank: 2,
              points: 36,
              played: 20,
              group: 'Test League',
            ),
            _standing(
              teamId: 12,
              teamName: 'Bottom',
              rank: 3,
              points: 12,
              played: 20,
              group: 'Test League',
              description: 'Relegation',
            ),
          ],
          metadata: _supportedMetadata(),
          sourceMetadata: DynamicTierSourceMetadata(
            sourceAsOf: analysisAsOf,
            providerSnapshotVersion: 'snapshot-v1',
          ),
        );

        expect(result.isValid, isTrue);
        expect(result.errors, isEmpty);
        expect(result.input?.competitionId, 'test-league');
        expect(result.input?.season, 2026);
        expect(result.input?.analysisAsOf, analysisAsOf);
        expect(
          result.input?.competitionFormat,
          CompetitionFormat.standardRoundRobin,
        );
        expect(result.input?.podiumAnchor.startRank, 1);
        expect(result.input?.relegationAnchor.startRank, 3);
        expect(result.input?.standingsRows, hasLength(3));
        expect(result.input?.standingsRows.first.officialRank, 1);
        expect(result.input?.standingsRows.first.points, 40);
        expect(result.input?.standingsRows.first.played, 20);
        expect(
          result.input?.standingsRows.first.description,
          'Promotion - Champions League (Qualification)',
        );
        expect(result.input?.standingsRows.last.description, 'Relegation');
        expect(
          result.input?.sourceMetadata.providerSnapshotVersion,
          'snapshot-v1',
        );
        expect(result.input?.anchorMetadataVersion, 'anchor-test-v1');
        expect(result.input?.competitionFormatVersion, 'format-test-v1');
        expect(result.input?.structuralMetadataVersion, 'structural-test-v1');
      },
    );

    test('rejects missing analysisAsOf instead of falling back to now', () {
      final result = const DynamicTierInputBuilder().build(
        competitionId: 'test-league',
        season: 2026,
        analysisAsOf: null,
        leagueStandings: [
          _standing(teamId: 10, teamName: 'Home', rank: 1),
          _standing(teamId: 11, teamName: 'Away', rank: 2),
          _standing(teamId: 12, teamName: 'Bottom', rank: 3),
        ],
        metadata: _supportedMetadata(),
      );

      expect(result.isValid, isFalse);
      expect(result.input, isNull);
      expect(
        result.errors,
        contains(DynamicTierInputBuildError.missingAnalysisAsOf),
      );
    });

    test('rejects standings rows missing required structural fields', () {
      final result = const DynamicTierInputBuilder().build(
        competitionId: 'test-league',
        season: 2026,
        analysisAsOf: DateTime.utc(2026, 7, 30, 8),
        leagueStandings: const [
          TeamStandingSnapshot(teamId: 10, teamName: 'Home'),
        ],
        metadata: _supportedMetadata(),
      );

      expect(result.isValid, isFalse);
      expect(result.input, isNull);
      expect(
        result.errors,
        containsAll([
          DynamicTierInputBuildError.missingOfficialRank,
          DynamicTierInputBuildError.missingPoints,
          DynamicTierInputBuildError.missingPlayed,
        ]),
      );
    });

    test('rejects a source snapshot newer than analysisAsOf', () {
      final analysisAsOf = DateTime.utc(2026, 7, 30, 8);
      final result = const DynamicTierInputBuilder().build(
        competitionId: 'test-league',
        season: 2026,
        analysisAsOf: analysisAsOf,
        leagueStandings: [
          _standing(teamId: 10, teamName: 'Home', rank: 1),
          _standing(teamId: 11, teamName: 'Away', rank: 2),
          _standing(teamId: 12, teamName: 'Bottom', rank: 3),
        ],
        metadata: _supportedMetadata(),
        sourceMetadata: DynamicTierSourceMetadata(
          sourceAsOf: analysisAsOf.add(const Duration(minutes: 1)),
        ),
      );

      expect(result.isValid, isFalse);
      expect(
        result.errors,
        contains(DynamicTierInputBuildError.sourceSnapshotAfterAnalysis),
      );
    });

    test('rejects missing or unsupported structural metadata', () {
      final missing = const DynamicTierInputBuilder().build(
        competitionId: 'unknown',
        season: 2026,
        analysisAsOf: DateTime.utc(2026, 7, 30, 8),
        leagueStandings: [
          _standing(teamId: 10, teamName: 'Home', rank: 1),
          _standing(teamId: 11, teamName: 'Away', rank: 2),
          _standing(teamId: 12, teamName: 'Bottom', rank: 3),
        ],
        metadata: null,
      );
      final unsupported = const DynamicTierInputBuilder().build(
        competitionId: 'split',
        season: 2026,
        analysisAsOf: DateTime.utc(2026, 7, 30, 8),
        leagueStandings: [
          _standing(teamId: 10, teamName: 'Home', rank: 1),
          _standing(teamId: 11, teamName: 'Away', rank: 2),
          _standing(teamId: 12, teamName: 'Bottom', rank: 3),
        ],
        metadata: _unsupportedMetadata(),
      );

      expect(
        missing.errors,
        contains(DynamicTierInputBuildError.missingStructuralMetadata),
      );
      expect(missing.input, isNull);
      expect(
        unsupported.errors,
        contains(DynamicTierInputBuildError.unsupportedCompetition),
      );
      expect(unsupported.input, isNull);
    });

    test('rejects supported metadata without required anchors', () {
      final result = const DynamicTierInputBuilder().build(
        competitionId: 'test-league',
        season: 2026,
        analysisAsOf: DateTime.utc(2026, 7, 30, 8),
        leagueStandings: [
          _standing(teamId: 10, teamName: 'Home', rank: 1),
          _standing(teamId: 11, teamName: 'Away', rank: 2),
          _standing(teamId: 12, teamName: 'Bottom', rank: 3),
        ],
        metadata: _metadataWithoutAnchors(),
      );

      expect(result.isValid, isFalse);
      expect(
        result.errors,
        containsAll([
          DynamicTierInputBuildError.missingPodiumAnchor,
          DynamicTierInputBuildError.missingRelegationAnchor,
        ]),
      );
    });
  });
}

TeamStandingSnapshot _standing({
  required int teamId,
  required String teamName,
  required int rank,
  int points = 30,
  int played = 20,
  String? group,
  String? description,
}) {
  return TeamStandingSnapshot(
    teamId: teamId,
    teamName: teamName,
    rank: rank,
    points: points,
    played: played,
    group: group,
    description: description,
  );
}

CompetitionStructuralMetadata _supportedMetadata() {
  return const CompetitionStructuralMetadata(
    competitionId: 'test-league',
    season: 2026,
    competitionFormat: CompetitionFormat.standardRoundRobin,
    supportStatus: StructuralSupportStatus.supportedV1,
    podiumAnchor: CompetitionStructuralAnchor(
      startRank: 1,
      endRank: 1,
      source: StructuralAnchorSource.lectorOverride,
    ),
    relegationAnchor: CompetitionStructuralAnchor(
      startRank: 3,
      endRank: 3,
      source: StructuralAnchorSource.lectorOverride,
    ),
    anchorMetadataVersion: 'anchor-test-v1',
    competitionFormatVersion: 'format-test-v1',
    structuralMetadataVersion: 'structural-test-v1',
  );
}

CompetitionStructuralMetadata _unsupportedMetadata() {
  return const CompetitionStructuralMetadata(
    competitionId: 'split',
    season: 2026,
    competitionFormat: CompetitionFormat.splitLeague,
    supportStatus: StructuralSupportStatus.unsupportedV1,
    anchorMetadataVersion: 'anchor-test-v1',
    competitionFormatVersion: 'format-test-v1',
    structuralMetadataVersion: 'structural-test-v1',
  );
}

CompetitionStructuralMetadata _metadataWithoutAnchors() {
  return const CompetitionStructuralMetadata(
    competitionId: 'test-league',
    season: 2026,
    competitionFormat: CompetitionFormat.standardRoundRobin,
    supportStatus: StructuralSupportStatus.supportedV1,
    anchorMetadataVersion: 'anchor-test-v1',
    competitionFormatVersion: 'format-test-v1',
    structuralMetadataVersion: 'structural-test-v1',
  );
}
