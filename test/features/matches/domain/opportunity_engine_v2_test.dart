import 'package:copilot/features/matches/domain/match_board_item.dart';
import 'package:copilot/features/matches/domain/opportunity_engine_v2.dart';
import 'package:copilot/features/matches/domain/structural_tiers/tier_models.dart';
import 'package:copilot/features/onboarding/domain/compiled_decision_profile.dart';
import 'package:copilot/features/onboarding/domain/decision_profile.dart';
import 'package:copilot/features/onboarding/domain/onboarding_answer.dart';
import 'package:copilot/features/onboarding/domain/profile_compiler.dart';
import 'package:copilot/features/opportunities/domain/opportunity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OpportunityEngineV2', () {
    test('creates one combined opportunity with readings and a market', () {
      final opportunities = const OpportunityEngineV2().opportunities([
        _match(),
      ], _profile(markets: ['double_chance'], profiles: ['ranking_gap']));

      expect(opportunities, hasLength(1));
      final opportunity = opportunities.single;
      expect(opportunity.retainedTheses.single.id, 'expected_domination');
      expect(opportunity.supportingReadings.length, greaterThanOrEqualTo(3));
      expect(opportunity.recommendedMarket?.market.id, 'doubleChance');
      expect(opportunity.recommendedMarket?.selection.label, '1X');
      expect(opportunity.argumentCount, greaterThanOrEqualTo(3));
      expect(
        opportunity.copilotArguments.map((argument) => argument.subjectName),
        everyElement(isNot(startsWith('api-team-'))),
      );
      expect(
        opportunity.copilotArguments.map((argument) => argument.subjectName),
        contains('Home'),
      );
      expect(
        opportunity.positiveArguments.map((argument) => argument.subjectName),
        everyElement(isNot(startsWith('api-team-'))),
      );
      expect(
        opportunity.positiveArguments.map((argument) => argument.subjectName),
        contains('Home'),
      );
      expect(opportunity.asOf, DateTime.utc(2026, 7, 30, 8));
      expect(opportunity.thesisAssessments.length, greaterThan(1));
    });

    test(
      'keeps an opportunity visible when no enabled market translates it',
      () {
        final opportunities = const OpportunityEngineV2().opportunities([
          _match(),
        ], _profile(markets: ['match_result'], profiles: ['ranking_gap']));

        expect(opportunities, hasLength(1));
        expect(
          opportunities.single.retainedTheses.single.id,
          'expected_domination',
        );
        expect(opportunities.single.recommendedMarket, isNull);
        expect(opportunities.single.compatibleMarkets, isEmpty);
        expect(
          opportunities.single.retainedTheses.single.status,
          MatchThesisStatus.watchlist,
        );
      },
    );

    test('can produce avoid_match without proposing a market', () {
      final opportunities = const OpportunityEngineV2().opportunities([
        _balancedConflictingMatch(),
      ], _profile(markets: ['double_chance'], profiles: ['solid_favorite']));

      expect(opportunities, hasLength(1));
      expect(opportunities.single.retainedTheses.single.id, 'avoid_match');
      expect(opportunities.single.recommendedMarket, isNull);
      expect(opportunities.single.compatibleMarkets, isEmpty);
    });

    test('does not create opportunities for incomplete profiles', () {
      final profile = const ProfileCompiler().compile(
        const DecisionProfile(onboardingVersion: 'test', answers: []),
      );

      final opportunities = const OpportunityEngineV2().opportunities([
        _match(),
      ], profile);

      expect(opportunities, isEmpty);
    });

    test('keeps full thesis analysis independent from profile completion', () {
      final profile = const ProfileCompiler().compile(
        const DecisionProfile(onboardingVersion: 'test', answers: []),
      );
      final engine = const OpportunityEngineV2();

      expect(engine.opportunities([_match()], profile), isEmpty);
      expect(engine.assessTheses(_match()).length, greaterThan(1));
      expect(
        engine
            .assessTheses(_match())
            .any((assessment) => assessment.id == 'expected_domination'),
        isTrue,
      );
    });

    test('blocks expected_domination through same Tier gate', () {
      final match = _match(
        homeName: 'Vikingur',
        awayName: 'KR Reykjavik',
        homeRank: 1,
        awayRank: 3,
        homePoints: 51,
        awayPoints: 43,
        structuralRelation: _sameTierRelation(),
      );

      final analysis = const OpportunityEngineV2().analyzeMatch(match);
      final assessments = const OpportunityEngineV2().assessTheses(match);
      final domination = assessments.singleWhere(
        (assessment) => assessment.id == 'expected_domination',
      );

      expect(
        analysis.has('ranking_superiority', subjectTeamId: 'api-team-10'),
        true,
      );
      expect(
        analysis.has('structural_level_gap', subjectTeamId: 'api-team-10'),
        false,
      );
      expect(domination.status, ThesisAssessmentStatus.notEligible);
      expect(domination.failedGate, 'EG_EXPECTED_DOMINATION_TIER_GAP');
      expect(domination.clarityScore, 0);
    });

    test(
      'preserves opponent resistance without turning it into contradiction',
      () {
        final assessment = const OpportunityEngineV2()
            .assessTheses(
              _match(
                awayWinsAway: 4,
                awayLossesAway: 0,
                structuralRelation: _structuralRelation(),
              ),
            )
            .singleWhere(
              (assessment) => assessment.id == 'expected_domination',
            );

        expect(assessment.status, ThesisAssessmentStatus.supported);
        expect(
          assessment.resistances.any(
            (item) => item.reading?.id == 'strong_away_team',
          ),
          isTrue,
        );
        expect(
          assessment.contradictions.any(
            (item) => item.reading?.id == 'strong_away_team',
          ),
          isFalse,
        );
      },
    );

    test('marks shared positive form as non-discriminating', () {
      final assessment = const OpportunityEngineV2()
          .assessTheses(_match(awayForm: 'WWDWW'))
          .singleWhere((assessment) => assessment.id == 'expected_domination');

      expect(
        assessment.nonDiscriminating
            .where((item) => item.reading?.id == 'positive_streak')
            .length,
        2,
      );
    });

    test('deduplicates correlated hierarchy evidence for clarity', () {
      final assessment = const OpportunityEngineV2()
          .assessTheses(_match())
          .singleWhere((assessment) => assessment.id == 'expected_domination');
      final supportFamilies = assessment.evidence
          .where(
            (item) =>
                item.relation == ThesisEvidenceRelation.coreSupport ||
                item.relation == ThesisEvidenceRelation.additionalSupport,
          )
          .map((item) => item.family)
          .toSet();

      expect(
        assessment.evidence
            .where(
              (item) =>
                  item.family == CopilotArgumentFamily.hierarchy &&
                  (item.relation == ThesisEvidenceRelation.coreSupport ||
                      item.relation ==
                          ThesisEvidenceRelation.additionalSupport),
            )
            .length,
        greaterThan(1),
      );
      expect(
        supportFamilies.length,
        lessThan(
          assessment.coreSupport.length + assessment.additionalSupport.length,
        ),
      );
    });

    test('can leave an ambiguous match without a strong opportunity', () {
      final opportunities = const OpportunityEngineV2().opportunities([
        _ambiguousMatch(),
      ], _profile(markets: ['double_chance'], profiles: ['ranking_gap']));

      expect(opportunities, isEmpty);
    });
  });
}

CompiledDecisionProfile _profile({
  required List<String> markets,
  required List<String> profiles,
}) {
  return const ProfileCompiler().compile(
    DecisionProfile(
      onboardingVersion: 'test',
      answers: [
        OnboardingAnswer(
          questionId: 'competitions',
          orderedOptionIds: ['eng_premier_league'],
        ),
        OnboardingAnswer(questionId: 'markets', orderedOptionIds: markets),
        OnboardingAnswer(
          questionId: 'opportunity_profiles',
          orderedOptionIds: profiles,
        ),
      ],
    ),
  );
}

MatchBoardItem _match({
  String homeName = 'Home',
  String awayName = 'Away',
  int homeRank = 2,
  int awayRank = 11,
  int homePoints = 26,
  int awayPoints = 11,
  String homeForm = 'WWDWW',
  String awayForm = 'LLDLW',
  int? awayWinsAway,
  int? awayLossesAway,
  MatchStructuralRelation? structuralRelation,
}) {
  return MatchBoardItem(
    fixture: NormalizedFixture(
      id: 'fixture',
      competition: const CompetitionInfo(
        id: '39',
        name: 'Premier League',
        country: CountryInfo(code: 'GB', name: 'Angleterre'),
        season: 2026,
      ),
      homeTeam: TeamInfo(
        id: 'api-team-10',
        name: homeName,
        apiFootballTeamId: 10,
      ),
      awayTeam: TeamInfo(
        id: 'api-team-11',
        name: awayName,
        apiFootballTeamId: 11,
      ),
      kickoffLabel: '20:00',
      kickoff: DateTime.utc(2026, 7, 30, 18),
      status: FixtureStatus.scheduled,
    ),
    primaryMarket: const MarketOdds(
      id: 'market_unavailable',
      label: 'Marché indisponible',
      odds: 0,
    ),
    availableMarkets: const [
      MatchMarket(
        id: 'doubleChance',
        label: 'Double chance',
        selections: [
          MarketOdds(
            id: 'double_chance_1x',
            label: '1X',
            odds: 1.42,
            apiFootballValue: 'Home/Draw',
          ),
        ],
      ),
    ],
    analysis: MatchAnalysisData(
      asOf: DateTime.utc(2026, 7, 30, 8),
      homeStanding: TeamStandingSnapshot(
        teamId: 10,
        teamName: homeName,
        rank: homeRank,
        points: homePoints,
        played: 10,
        wins: 8,
        draws: 2,
        losses: 0,
        goalsFor: 22,
        goalsAgainst: 8,
        form: homeForm,
      ),
      awayStanding: TeamStandingSnapshot(
        teamId: 11,
        teamName: awayName,
        rank: awayRank,
        points: awayPoints,
        played: 10,
        wins: 3,
        draws: 2,
        losses: 5,
        goalsFor: 10,
        goalsAgainst: 18,
        form: awayForm,
      ),
      structuralRelation: structuralRelation ?? _structuralRelation(),
      homeStatistics: TeamStatisticsSnapshot(
        teamId: 10,
        teamName: homeName,
        playedTotal: 10,
        playedHome: 5,
        winsTotal: 8,
        winsHome: 4,
        goalsForAverageTotal: 1.90,
        goalsAgainstAverageTotal: 0.80,
        cleanSheetsTotal: 4,
      ),
      awayStatistics: TeamStatisticsSnapshot(
        teamId: 11,
        teamName: awayName,
        playedTotal: 10,
        playedAway: 5,
        winsAway: awayWinsAway,
        lossesTotal: 5,
        lossesAway: awayLossesAway ?? 3,
        goalsForAverageTotal: 0.90,
        goalsAgainstAverageTotal: 1.85,
      ),
    ),
    compatibility: 0,
    signals: const [],
  );
}

MatchBoardItem _ambiguousMatch() {
  return _balancedConflictingMatch().copyWith(
    analysis: MatchAnalysisData(
      asOf: DateTime.utc(2026, 7, 30, 8),
      homeStanding: const TeamStandingSnapshot(
        teamId: 10,
        teamName: 'Home',
        rank: 7,
        points: 15,
        played: 10,
        form: 'WDLWD',
      ),
      awayStanding: const TeamStandingSnapshot(
        teamId: 11,
        teamName: 'Away',
        rank: 8,
        points: 14,
        played: 10,
        form: 'DWLDW',
      ),
    ),
  );
}

MatchBoardItem _balancedConflictingMatch() {
  return MatchBoardItem(
    fixture: NormalizedFixture(
      id: 'balanced',
      competition: const CompetitionInfo(
        id: '39',
        name: 'Premier League',
        country: CountryInfo(code: 'GB', name: 'Angleterre'),
        season: 2026,
      ),
      homeTeam: const TeamInfo(id: 'home', name: 'Home'),
      awayTeam: const TeamInfo(id: 'away', name: 'Away'),
      kickoffLabel: '20:00',
      kickoff: DateTime.utc(2026, 7, 30, 18),
      status: FixtureStatus.scheduled,
    ),
    primaryMarket: const MarketOdds(
      id: 'market_unavailable',
      label: 'Marché indisponible',
      odds: 0,
    ),
    availableMarkets: const [],
    analysis: MatchAnalysisData(
      asOf: DateTime.utc(2026, 7, 30, 8),
      homeStanding: const TeamStandingSnapshot(
        teamId: 10,
        teamName: 'Home',
        rank: 5,
        points: 18,
        played: 10,
        form: 'WWWWW',
      ),
      awayStanding: const TeamStandingSnapshot(
        teamId: 11,
        teamName: 'Away',
        rank: 6,
        points: 16,
        played: 10,
        form: 'WDWDW',
      ),
      structuralRelation: _balancedRelation(),
      homeStatistics: const TeamStatisticsSnapshot(
        teamId: 10,
        teamName: 'Home',
        playedTotal: 10,
        goalsForAverageTotal: 1.40,
        goalsAgainstAverageTotal: 1.75,
      ),
      awayStatistics: const TeamStatisticsSnapshot(
        teamId: 11,
        teamName: 'Away',
        playedTotal: 10,
        goalsForAverageTotal: 1.30,
        goalsAgainstAverageTotal: 1.20,
      ),
    ),
    compatibility: 0,
    signals: const [],
  );
}

MatchStructuralRelation _balancedRelation() {
  return MatchStructuralRelation(
    competitionId: '39',
    season: 2026,
    analysisAsOf: DateTime.utc(2026, 7, 30, 8),
    tierSystemVersion: 'tier-v1',
    standingsSnapshotIdentity: 'tier-snapshot-balanced',
    homeTeamId: 10,
    awayTeamId: 11,
    homeTeamTier: TierLabel.tier3MiddleChampionship,
    awayTeamTier: TierLabel.tier3MiddleChampionship,
    sameTier: true,
    ordinalTierGap: 0,
    structuralBoundaryGap: 0,
    confirmedBoundariesBetweenTeams: const [],
    tierMaturity: TierMaturity.mature,
    tierStatus: TierSystemStatus.mature,
    championshipTeamCount: 20,
    typicalGap: 1,
    homeOfficialRank: 5,
    awayOfficialRank: 6,
    homePoints: 18,
    awayPoints: 16,
    homeStructuralLevelGap: const StructuralLevelGapAssessment(exists: false),
    awayStructuralLevelGap: const StructuralLevelGapAssessment(exists: false),
    balancedHierarchy: const BalancedHierarchyAssessment(exists: true),
    warnings: const [],
  );
}

MatchStructuralRelation _structuralRelation() {
  return MatchStructuralRelation(
    competitionId: '39',
    season: 2026,
    analysisAsOf: DateTime.utc(2026, 7, 30, 8),
    tierSystemVersion: 'tier-v1',
    standingsSnapshotIdentity: 'tier-snapshot-structural',
    homeTeamId: 10,
    awayTeamId: 11,
    homeTeamTier: TierLabel.tier1Podium,
    awayTeamTier: TierLabel.tier4LowerChampionship,
    sameTier: false,
    ordinalTierGap: 3,
    structuralBoundaryGap: 1,
    confirmedBoundariesBetweenTeams: const [
      ConfirmedStructuralBoundary(
        boundaryIndex: 3,
        upperRank: 3,
        lowerRank: 4,
        rawGap: 12,
        score: 82,
        strength: BoundaryStrength.strong,
        standingsSnapshotIdentity: 'tier-snapshot-structural',
      ),
    ],
    tierMaturity: TierMaturity.mature,
    tierStatus: TierSystemStatus.mature,
    championshipTeamCount: 20,
    typicalGap: 1,
    homeOfficialRank: 2,
    awayOfficialRank: 11,
    homePoints: 26,
    awayPoints: 11,
    homeStructuralLevelGap: const StructuralLevelGapAssessment(
      exists: true,
      strength: StructuralLevelGapStrength.moderate,
    ),
    awayStructuralLevelGap: const StructuralLevelGapAssessment(exists: false),
    balancedHierarchy: const BalancedHierarchyAssessment(exists: false),
    warnings: const [],
  );
}

MatchStructuralRelation _sameTierRelation() {
  return MatchStructuralRelation(
    competitionId: '39',
    season: 2026,
    analysisAsOf: DateTime.utc(2026, 7, 30, 8),
    tierSystemVersion: 'tier-v1',
    standingsSnapshotIdentity: 'tier-snapshot-same-tier',
    homeTeamId: 10,
    awayTeamId: 11,
    homeTeamTier: TierLabel.tier1Podium,
    awayTeamTier: TierLabel.tier1Podium,
    sameTier: true,
    ordinalTierGap: 0,
    structuralBoundaryGap: 0,
    confirmedBoundariesBetweenTeams: const [],
    tierMaturity: TierMaturity.mature,
    tierStatus: TierSystemStatus.mature,
    championshipTeamCount: 12,
    typicalGap: 4,
    homeOfficialRank: 1,
    awayOfficialRank: 3,
    homePoints: 51,
    awayPoints: 43,
    homeStructuralLevelGap: const StructuralLevelGapAssessment(exists: false),
    awayStructuralLevelGap: const StructuralLevelGapAssessment(exists: false),
    balancedHierarchy: const BalancedHierarchyAssessment(exists: false),
    warnings: const [],
  );
}
