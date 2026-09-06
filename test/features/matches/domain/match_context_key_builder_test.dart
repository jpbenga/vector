import 'package:copilot/features/matches/domain/match_board_item.dart';
import 'package:copilot/features/matches/domain/match_context_key_builder.dart';
import 'package:copilot/features/matches/domain/match_context_key_models.dart';
import 'package:copilot/features/matches/domain/structural_tiers/tier_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const referenceBuilder = ChampionshipContextReferenceBuilder();
  const keyBuilder = MatchContextKeyBuilder();

  group('ChampionshipContextReferenceBuilder', () {
    test('keeps a homogeneous distribution without a remarkable zone', () {
      final reference = referenceBuilder.build(
        _match(_standings(List<int>.filled(10, 15))),
      )!;

      final attack = reference.distributionFor(
        ChampionshipContextMetric.goalsFor,
      )!;

      expect(attack.highZone, isNull);
      expect(attack.lowZone, isNull);
    });

    test('does not elevate an extreme without a Tukey-separated boundary', () {
      final reference = referenceBuilder.build(
        _match(_standings([30, 29, 28, 27, 26, 25, 24, 23, 22, 21])),
      )!;

      final attack = reference.distributionFor(
        ChampionshipContextMetric.goalsFor,
      )!;

      expect(attack.highZone, isNull);
      expect(attack.lowZone, isNull);
    });

    test('detects a compact high edge zone beyond the Tukey upper fence', () {
      final reference = referenceBuilder.build(
        _match(_standings([50, 49, 40, 39, 38, 37, 36, 35, 34, 33])),
      )!;

      final attack = reference.distributionFor(
        ChampionshipContextMetric.goalsFor,
      )!;

      expect(attack.highZone?.values.map((value) => value.teamId), [1, 2]);
      expect(attack.highZone!.separationGap, greaterThan(attack.upperFence));
      expect(
        attack.highZone!.internalSpan,
        lessThan(attack.highZone!.separationGap),
      );
      expect(attack.lowZone, isNull);
    });

    test('detects a compact low edge zone beyond the Tukey upper fence', () {
      final reference = referenceBuilder.build(
        _match(_standings([50, 49, 48, 47, 46, 45, 44, 43, 40, 10])),
      )!;

      final attack = reference.distributionFor(
        ChampionshipContextMetric.goalsFor,
      )!;

      expect(attack.lowZone?.values.map((value) => value.teamId), [10]);
      expect(attack.lowZone!.separationGap, greaterThan(attack.upperFence));
      expect(attack.highZone, isNull);
    });

    test('detects independent high and low edge zones', () {
      final reference = referenceBuilder.build(
        _match(
          _standings([
            100,
            99,
            50,
            49,
            48,
            47,
            46,
            45,
            44,
            2,
            1,
          ], forms: List<String>.filled(11, 'WWDDL')),
        ),
      )!;

      final attack = reference.distributionFor(
        ChampionshipContextMetric.goalsFor,
      )!;

      expect(attack.highZone?.values.map((value) => value.teamId), [1, 2]);
      expect(attack.lowZone?.values.map((value) => value.teamId), [10, 11]);
    });

    test('rejects a separated but non-compact edge group', () {
      final reference = referenceBuilder.build(
        _match(_standings([50, 47, 44, 41, 38, 28, 27, 26, 25, 24])),
      )!;

      final attack = reference.distributionFor(
        ChampionshipContextMetric.goalsFor,
      )!;

      expect(attack.highZone, isNull);
    });

    test('keeps equal values contiguous inside a zone', () {
      final reference = referenceBuilder.build(
        _match(_standings([50, 50, 40, 39, 38, 37, 36, 35, 34, 33])),
      )!;

      final attack = reference.distributionFor(
        ChampionshipContextMetric.goalsFor,
      )!;

      expect(attack.highZone?.values.map((value) => value.teamId), [1, 2]);
    });

    test('abstains from Tukey distributions below ten exploitable teams', () {
      final reference = referenceBuilder.build(
        _match(_standings(const [50, 49, 40, 39, 38, 37, 36, 35, 34])),
      );

      expect(reference, isNotNull);
      expect(reference!.distributions, isEmpty);
    });

    test('abstains when tied borders do not define a unique compact zone', () {
      final reference = referenceBuilder.build(
        _match(_standings([50, 30, 10, 9, 8, 7, 6, 5, 4, 3])),
      )!;

      expect(
        reference.distributionFor(ChampionshipContextMetric.goalsFor)!.highZone,
        isNull,
      );
    });
  });

  group('MatchContextKeyBuilder', () {
    test(
      'builds composed opposition from qualified attack and defense zones',
      () {
        final match = _match(
          _standings(
            [100, 40, 39, 38, 37, 36, 35, 34, 33, 32],
            goalsAgainst: [20, 100, 50, 49, 48, 47, 46, 45, 44, 43],
          ),
        );
        final reference = referenceBuilder.build(match)!;

        final keys = keyBuilder.build(match, reference: reference);

        final opposition = keys.singleWhere(
          (key) => key.family == MatchContextKeyFamily.opposition,
        );
        expect(opposition.family, MatchContextKeyFamily.opposition);
        expect(opposition.sourceFamilies, {
          MatchContextKeyFamily.attack,
          MatchContextKeyFamily.defense,
        });
      },
    );

    test(
      'does not turn the complementary K League defense group into a key',
      () {
        final match = _match(
          _standings(
            List<int>.filled(12, 30),
            goalsAgainst: [57, 39, 37, 32, 32, 29, 29, 29, 27, 25, 23, 21],
            points: List<int>.filled(12, 30),
            forms: List<String>.filled(12, 'WWDDL'),
            played: List<int>.filled(12, 26),
          ),
          homeStandingIndex: 7,
          awayStandingIndex: 3,
        );
        final reference = referenceBuilder.build(match)!;
        final defense = reference.distributionFor(
          ChampionshipContextMetric.goalsAgainst,
        )!;

        expect(defense.highZone?.values.map((value) => value.teamId), [1]);
        expect(defense.lowZone, isNull);
        expect(
          keyBuilder
              .build(match, reference: reference)
              .where((key) => key.family == MatchContextKeyFamily.defense),
          isEmpty,
        );
      },
    );

    test('does not derive keys from a post-kickoff analysis snapshot', () {
      final match = _match(
        _standings([50, 49, 40, 39, 38, 37, 36, 35, 34, 33]),
        asOf: DateTime.utc(2026, 9, 6, 20),
      );
      final reference = referenceBuilder.build(match)!;

      expect(keyBuilder.build(match, reference: reference), isEmpty);
    });

    test('keeps Structure independent from Tukey qualification', () {
      final match = _match(
        _standings(List<int>.filled(10, 15)),
        structuralRelation: _structuralRelation(),
      );
      final reference = referenceBuilder.build(match)!;

      expect(
        keyBuilder.build(match, reference: reference).single.family,
        MatchContextKeyFamily.structure,
      );
    });

    test('keeps Structure available when form data is unavailable', () {
      final match = _match(
        _standings(
          List<int>.filled(10, 15),
          played: List<int>.filled(10, 1),
          forms: List<String>.filled(10, ''),
        ),
        structuralRelation: _structuralRelation(),
      );
      final reference = referenceBuilder.build(match)!;

      expect(reference.distributionFor(ChampionshipContextMetric.form), isNull);
      expect(
        keyBuilder.build(match, reference: reference).single.family,
        MatchContextKeyFamily.structure,
      );
    });

    test('builds hierarchy from a relative PPG edge zone', () {
      final standings = _standings(
        [50, 49, 40, 39, 38, 37, 36, 35, 34, 33],
        points: [50, 49, 40, 39, 38, 37, 36, 35, 34, 33],
      );
      final match = _match(standings, awayStandingIndex: 2);
      final reference = referenceBuilder.build(match)!;

      final hierarchy = keyBuilder
          .build(match, reference: reference)
          .singleWhere((key) => key.family == MatchContextKeyFamily.hierarchy);

      expect(hierarchy.semanticScope, 'official_positioning');
      expect(hierarchy.facts['homeRank'], 1);
      expect(hierarchy.facts['awayRank'], 3);
    });

    test('builds form from a relative form edge zone', () {
      const forms = [
        'WWWWW',
        'WWWWD',
        'WWWLL',
        'WWDDL',
        'WWDLL',
        'WDDDL',
        'WDDLL',
        'WLLLD',
        'WLLLL',
        'DDLLL',
      ];
      final match = _match(_standings(List<int>.filled(10, 15), forms: forms));
      final reference = referenceBuilder.build(match)!;

      final form = keyBuilder
          .build(match, reference: reference)
          .singleWhere((key) => key.family == MatchContextKeyFamily.form);

      expect(form.facts['homeForm'], 'WWWWW');
      expect(form.facts['awayForm'], 'WWWWD');
    });
  });
}

MatchBoardItem _match(
  List<TeamStandingSnapshot> standings, {
  DateTime? asOf,
  MatchStructuralRelation? structuralRelation,
  int homeStandingIndex = 0,
  int awayStandingIndex = 1,
}) {
  final snapshotAsOf = asOf ?? DateTime.utc(2026, 9, 5, 12);
  return MatchBoardItem(
    fixture: NormalizedFixture(
      id: 'fixture',
      competition: const CompetitionInfo(
        id: 'test-league',
        name: 'Test League',
        country: CountryInfo(code: 'FR', name: 'France'),
        season: 2026,
      ),
      homeTeam: TeamInfo(
        id: 'home',
        name: 'Home',
        apiFootballTeamId: homeStandingIndex + 1,
      ),
      awayTeam: TeamInfo(
        id: 'away',
        name: 'Away',
        apiFootballTeamId: awayStandingIndex + 1,
      ),
      kickoffLabel: '20:00',
      kickoff: DateTime.utc(2026, 9, 5, 20),
      status: FixtureStatus.scheduled,
    ),
    primaryMarket: const MarketOdds(id: '1', label: '1', odds: 1.5),
    compatibility: 0,
    signals: const [],
    analysis: MatchAnalysisData(
      asOf: snapshotAsOf,
      homeStanding: standings[homeStandingIndex],
      awayStanding: standings[awayStandingIndex],
      leagueStandings: standings,
      structuralRelation: structuralRelation,
    ),
  );
}

MatchStructuralRelation _structuralRelation() {
  final asOf = DateTime.utc(2026, 9, 5, 12);
  return MatchStructuralRelation(
    competitionId: 'test-league',
    season: 2026,
    analysisAsOf: asOf,
    tierSystemVersion: 'tier-v1',
    standingsSnapshotIdentity: 'snapshot',
    homeTeamId: 1,
    awayTeamId: 2,
    homeTeamTier: TierLabel.tier1Podium,
    awayTeamTier: TierLabel.tier4LowerChampionship,
    sameTier: false,
    ordinalTierGap: 3,
    structuralBoundaryGap: 1,
    confirmedBoundariesBetweenTeams: [
      ConfirmedStructuralBoundary(
        boundaryIndex: 1,
        upperRank: 1,
        lowerRank: 2,
        rawGap: 8,
        score: 0.9,
        strength: BoundaryStrength.strong,
        standingsSnapshotIdentity: 'snapshot',
      ),
    ],
    tierMaturity: TierMaturity.mature,
    tierStatus: TierSystemStatus.mature,
    championshipTeamCount: 10,
    typicalGap: 1,
    homeOfficialRank: 1,
    awayOfficialRank: 2,
    homePoints: 30,
    awayPoints: 29,
    homeStructuralLevelGap: const StructuralLevelGapAssessment(exists: true),
    awayStructuralLevelGap: const StructuralLevelGapAssessment(exists: false),
    balancedHierarchy: const BalancedHierarchyAssessment(exists: false),
    warnings: const [],
  );
}

List<TeamStandingSnapshot> _standings(
  List<int> goalsFor, {
  List<int>? goalsAgainst,
  List<int>? points,
  List<String>? forms,
  List<int>? played,
}) {
  const defaultForms = [
    'WWWWW',
    'WWWWD',
    'WWWDD',
    'WWDDL',
    'WDDLL',
    'DDDLL',
    'DDLLL',
    'DLLLL',
    'LLLLD',
    'LLLLL',
  ];
  return [
    for (var index = 0; index < goalsFor.length; index += 1)
      TeamStandingSnapshot(
        teamId: index + 1,
        teamName: 'Team ${index + 1}',
        rank: index + 1,
        points: points?[index] ?? 30 - index,
        played: played?[index] ?? 10,
        goalsFor: goalsFor[index],
        goalsAgainst: goalsAgainst?[index] ?? 20 + index,
        form: forms?[index] ?? defaultForms[index],
      ),
  ];
}
