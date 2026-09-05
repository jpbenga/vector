import '../../onboarding/domain/compiled_decision_profile.dart';
import '../../opportunities/domain/opportunity.dart';
import 'football_analyzer.dart';
import 'football_reading.dart';
import 'match_board_item.dart';

class MatchIntelligence {
  const MatchIntelligence({
    required this.match,
    required this.analysis,
    required this.thesisAssessments,
  });

  final MatchBoardItem match;
  final FootballAnalysis analysis;
  final List<ThesisAssessment> thesisAssessments;
}

class OpportunityEngineV2 {
  const OpportunityEngineV2({this.analyzer = const FootballAnalyzer()});

  final FootballAnalyzer analyzer;

  FootballAnalysis analyzeMatch(MatchBoardItem match, {DateTime? asOf}) {
    return analyzer.analyze(match, asOf: asOf);
  }

  List<ThesisAssessment> assessTheses(MatchBoardItem match, {DateTime? asOf}) {
    final analysis = analyzeMatch(match, asOf: asOf);
    return _assessments(match, analysis);
  }

  MatchIntelligence buildIntelligence(MatchBoardItem match, {DateTime? asOf}) {
    final analysis = analyzeMatch(match, asOf: asOf);
    return MatchIntelligence(
      match: match,
      analysis: analysis,
      thesisAssessments: List.unmodifiable(_assessments(match, analysis)),
    );
  }

  List<Opportunity> opportunities(
    List<MatchBoardItem> matches,
    CompiledDecisionProfile profile,
  ) {
    final opportunities = [
      for (final match in matches) analyzeOpportunity(match, profile),
    ].whereType<Opportunity>().toList()..sort(_compareOpportunities);

    return opportunities;
  }

  List<Opportunity> opportunitiesFromIntelligence(
    Iterable<MatchIntelligence> intelligences,
    CompiledDecisionProfile profile,
  ) {
    final opportunities = [
      for (final intelligence in intelligences)
        analyzeOpportunityFromIntelligence(intelligence, profile),
    ].whereType<Opportunity>().toList()..sort(_compareOpportunities);

    return opportunities;
  }

  Opportunity? analyzeOpportunity(
    MatchBoardItem match,
    CompiledDecisionProfile profile, {
    bool allowRecommendedMarket = true,
    DateTime? asOf,
  }) {
    return analyzeOpportunityFromIntelligence(
      buildIntelligence(match, asOf: asOf),
      profile,
      allowRecommendedMarket: allowRecommendedMarket,
    );
  }

  Opportunity? analyzeOpportunityFromIntelligence(
    MatchIntelligence intelligence,
    CompiledDecisionProfile profile, {
    bool allowRecommendedMarket = true,
  }) {
    final match = intelligence.match;
    final analysis = intelligence.analysis;
    if (!profile.isCompleted ||
        !profile.isCompetitionEnabled(match.competition.id)) {
      return null;
    }

    final candidates = _candidates(
      match,
      analysis,
    ).where((candidate) => profile.isThesisAllowed(candidate.id)).toList();
    if (candidates.isEmpty) {
      return null;
    }

    candidates.sort((a, b) {
      final clarityComparison = b.clarityScore.compareTo(a.clarityScore);
      if (clarityComparison != 0) {
        return clarityComparison;
      }

      return b.priority.compareTo(a.priority);
    });

    final selected = candidates.first;
    final compatibleMarkets = allowRecommendedMarket
        ? _compatibleMarkets(match, profile, selected)
        : const <OpportunityMarketCompatibility>[];
    final recommended = compatibleMarkets
        .where((market) => market.isRecommended)
        .firstOrNull;
    final recommendedMarket = recommended == null
        ? null
        : RecommendedMarket(
            market: recommended.market,
            selection: recommended.selection,
          );
    final thesis = _thesisFor(match, selected, recommendedMarket);

    return Opportunity(
      sourceMatch: match,
      engineScore: _internalScore(selected),
      detectedSignals: [_signalFor(thesis)],
      retainedTheses: [thesis],
      compatibleMarkets: compatibleMarkets,
      recommendedMarket: recommendedMarket,
      supportingReadings: selected.supportingReadings,
      contradictoryReadings: selected.contradictoryReadings,
      thesisAssessments: intelligence.thesisAssessments,
      asOf: analysis.asOf,
    );
  }

  MatchBoardItem personalizeMatchFromIntelligence(
    MatchIntelligence intelligence,
    CompiledDecisionProfile profile,
  ) {
    final match = intelligence.match;
    final opportunity = analyzeOpportunityFromIntelligence(
      intelligence,
      profile,
    );
    if (opportunity != null) {
      return opportunity.toMatchBoardItem();
    }

    final isCompetitionEnabled = profile.isCompetitionEnabled(
      match.competition.id,
    );
    final profileReadings = isCompetitionEnabled
        ? _profileReadings(intelligence.analysis, profile)
        : const <FootballReading>[];

    return match.copyWith(
      profileStatus: isCompetitionEnabled
          ? MatchProfileStatus.inProfile
          : MatchProfileStatus.outOfProfile,
      compatibility: _readingCompatibility(profileReadings),
      signals: _signalsForReadings(match, profileReadings),
    );
  }

  List<FootballReading> _profileReadings(
    FootballAnalysis analysis,
    CompiledDecisionProfile profile,
  ) {
    return analysis.supportingReadings
        .where((reading) => profile.isReadingAllowed(reading.id))
        .toList(growable: false);
  }

  int _readingCompatibility(List<FootballReading> readings) {
    if (readings.isEmpty) {
      return 0;
    }

    final strongest = readings
        .map(_readingScore)
        .reduce((a, b) => a > b ? a : b);
    return (strongest + (readings.length - 1) * 6).clamp(0, 88).toInt();
  }

  int _readingScore(FootballReading reading) {
    return switch (reading.strength) {
      ReadingStrength.strong => 72,
      ReadingStrength.moderate => 58,
      ReadingStrength.weak => 42,
    };
  }

  List<MatchSignal> _signalsForReadings(
    MatchBoardItem match,
    List<FootballReading> readings,
  ) {
    return [
      for (final reading in readings.take(4)) _signalForReading(match, reading),
    ];
  }

  MatchSignal _signalForReading(MatchBoardItem match, FootballReading reading) {
    final subjectName = _subjectNameFor(match, reading);
    final title = _readingTitle(reading, subjectName);
    final evidenceLabels = [
      for (final evidence in reading.evidence)
        if (evidence.label.trim().isNotEmpty) evidence.label,
    ];

    return MatchSignal(
      id: reading.id,
      title: title,
      summary: _readingSummary(reading, subjectName),
      proofs: evidenceLabels.isEmpty
          ? [title]
          : evidenceLabels.take(3).toList(),
    );
  }

  String _readingTitle(FootballReading reading, String subjectName) {
    return switch (reading.id) {
      'balanced_hierarchy' => 'Hiérarchie proche',
      'ranking_superiority' => 'Avantage au classement pour $subjectName',
      'structural_level_gap' => 'Écart de niveau pour $subjectName',
      'positive_streak' => 'Dynamique positive pour $subjectName',
      'negative_streak' => 'Dynamique négative pour $subjectName',
      'improving_form' => 'Dynamique en hausse pour $subjectName',
      'declining_form' => 'Dynamique en baisse pour $subjectName',
      'strong_home_team' => '$subjectName solide à domicile',
      'weak_home_team' => '$subjectName fragile à domicile',
      'strong_away_team' => '$subjectName solide à l’extérieur',
      'weak_away_team' => '$subjectName fragile à l’extérieur',
      'home_away_mismatch' => 'Avantage domicile / extérieur',
      'prolific_attack' => 'Attaque prolifique pour $subjectName',
      'scoring_difficulty' => 'Production offensive faible pour $subjectName',
      'solid_defense' => 'Défense solide pour $subjectName',
      'fragile_defense' => 'Défense fragile pour $subjectName',
      'frequent_clean_sheet' => 'Clean sheets fréquents pour $subjectName',
      'open_match_profile' => 'Match ouvert',
      'frequent_over_25' => 'Tendance over 2,5 buts',
      'closed_match_profile' => 'Match fermé',
      'frequent_under_25' => 'Tendance under 2,5 buts',
      'high_xg_creation' => 'Création xG élevée pour $subjectName',
      'low_xg_creation' => 'Création xG faible pour $subjectName',
      'high_xg_conceded' => 'xG concédés élevés pour $subjectName',
      'offensive_underperformance' =>
        'Sous-performance offensive pour $subjectName',
      'offensive_overperformance' =>
        'Surperformance offensive pour $subjectName',
      'defensive_underperformance' =>
        'Sous-performance défensive pour $subjectName',
      'defensive_overperformance' =>
        'Surperformance défensive pour $subjectName',
      'misleading_result' => 'Résultats à nuancer pour $subjectName',
      _ => 'Lecture détectée pour $subjectName',
    };
  }

  String _readingSummary(FootballReading reading, String subjectName) {
    final evidence = reading.evidence.firstOrNull?.label;
    if (evidence != null && evidence.trim().isNotEmpty) {
      return evidence;
    }
    return 'Cette rencontre correspond à une lecture configurée pour $subjectName.';
  }

  int _compareOpportunities(Opportunity a, Opportunity b) {
    final scoreComparison = b.engineScore.compareTo(a.engineScore);
    if (scoreComparison != 0) {
      return scoreComparison;
    }

    final aKickoff = a.kickoff;
    final bKickoff = b.kickoff;
    if (aKickoff != null && bKickoff != null) {
      return aKickoff.compareTo(bKickoff);
    }

    return a.homeTeam.name.compareTo(b.homeTeam.name);
  }

  List<ThesisAssessment> _assessments(
    MatchBoardItem match,
    FootballAnalysis analysis,
  ) {
    final candidates = _candidates(match, analysis);
    final byId = <String, _OpportunityCandidate>{
      for (final candidate in candidates) candidate.id: candidate,
    };

    return [
      _expectedDominationAssessment(match, analysis),
      for (final spec in _canonicalThesisSpecs)
        if (spec.id != 'expected_domination')
          _assessmentForSpec(spec, byId[spec.id]),
    ];
  }

  ThesisAssessment _assessmentForSpec(
    _ThesisSpec spec,
    _OpportunityCandidate? candidate,
  ) {
    if (candidate == null) {
      return ThesisAssessment(
        id: spec.id,
        title: spec.title,
        subjectSide: ReadingSubjectSide.match,
        status: ThesisAssessmentStatus.eligibleButUnsupported,
        clarityScore: 0,
        evidence: const [
          ThesisEvidenceAssessment(
            relation: ThesisEvidenceRelation.evidenceUnavailable,
            family: CopilotArgumentFamily.performance,
            label: 'Aucune combinaison discriminante suffisante.',
          ),
        ],
      );
    }
    return candidate.assessment;
  }

  List<_OpportunityCandidate> _candidates(
    MatchBoardItem match,
    FootballAnalysis analysis,
  ) {
    final result = <_OpportunityCandidate>[
      ?_expectedDomination(match, analysis),
      ?_favoriteWithProtection(match, analysis),
      ?_convergentOpenMatch(match, analysis),
      ?_convergentClosedMatch(match, analysis),
      ?_credibleOutsider(match, analysis),
      ?_teamInSeriousDifficulty(match, analysis),
      ?_controlledFavorite(match, analysis),
      ?_bothSidesCanScore(match, analysis),
      ?_oneSidedScoring(match, analysis),
      ?_teamBetterThanResults(match, analysis),
      ?_teamWorseThanResults(match, analysis),
      ?_avoidMatch(match, analysis),
    ];

    final byId = <String, _OpportunityCandidate>{};
    for (final candidate in result) {
      byId.putIfAbsent(candidate.id, () => candidate);
    }

    return byId.values.toList(growable: false);
  }

  _OpportunityCandidate? _expectedDomination(
    MatchBoardItem match,
    FootballAnalysis analysis,
  ) {
    for (final side in [ReadingSubjectSide.home, ReadingSubjectSide.away]) {
      final assessment = _expectedDominationAssessmentForSide(
        match,
        analysis,
        side,
      );
      if (!assessment.isSupported) {
        continue;
      }
      final team = _teamForSide(match, side);
      final supporting = assessment.evidence
          .where(
            (item) =>
                item.relation == ThesisEvidenceRelation.coreSupport ||
                item.relation == ThesisEvidenceRelation.additionalSupport,
          )
          .map((item) => item.reading)
          .whereType<FootballReading>()
          .toList(growable: false);
      final contradictions = assessment.contradictions
          .map((item) => item.reading)
          .whereType<FootballReading>()
          .toList(growable: false);
      return _OpportunityCandidate(
        id: 'expected_domination',
        title: 'Domination attendue',
        summary:
            '${team.name} réunit une supériorité structurelle, une dynamique favorable et un contexte de match cohérent.',
        subjectSide: side,
        supportingReadings: supporting,
        contradictoryReadings: contradictions,
        marketIntents: [
          _MarketIntent('matchResult', _selectionForSide(side)),
          _MarketIntent('doubleChance', _doubleChanceForSide(side)),
        ],
        priority: 90,
        evidenceAssessments: assessment.evidence,
      );
    }

    return null;
  }

  ThesisAssessment _expectedDominationAssessment(
    MatchBoardItem match,
    FootballAnalysis analysis,
  ) {
    final home = _expectedDominationAssessmentForSide(
      match,
      analysis,
      ReadingSubjectSide.home,
    );
    final away = _expectedDominationAssessmentForSide(
      match,
      analysis,
      ReadingSubjectSide.away,
    );
    if (home.isSupported && away.isSupported) {
      return home.clarityScore >= away.clarityScore ? home : away;
    }
    if (home.isSupported) {
      return home;
    }
    if (away.isSupported) {
      return away;
    }
    if (home.status == ThesisAssessmentStatus.notEligible) {
      return home;
    }
    if (away.status == ThesisAssessmentStatus.notEligible) {
      return away;
    }
    return home.clarityScore >= away.clarityScore ? home : away;
  }

  ThesisAssessment _expectedDominationAssessmentForSide(
    MatchBoardItem match,
    FootballAnalysis analysis,
    ReadingSubjectSide side,
  ) {
    final relation = match.analysis.structuralRelation;
    final team = _teamForSide(match, side);
    final opponent = _teamForSide(match, _opponent(side));
    final evidence = <ThesisEvidenceAssessment>[];

    if (relation?.sameTier ?? false) {
      evidence.add(
        ThesisEvidenceAssessment(
          relation: ThesisEvidenceRelation.resistance,
          family: CopilotArgumentFamily.hierarchy,
          label: 'Même Tier: domination attendue non éligible.',
        ),
      );
      return ThesisAssessment(
        id: 'expected_domination',
        title: 'Domination attendue',
        subjectSide: side,
        status: ThesisAssessmentStatus.notEligible,
        failedGate: 'EG_EXPECTED_DOMINATION_TIER_GAP',
        clarityScore: 0,
        evidence: evidence,
      );
    }

    final structural = _readingsFor(analysis, team.id, [
      'structural_level_gap',
    ]);
    for (final reading in structural) {
      evidence.add(
        ThesisEvidenceAssessment(
          relation: ThesisEvidenceRelation.coreSupport,
          family: _familyForReading(reading),
          label: _labelForReading(reading),
          reading: reading,
        ),
      );
    }

    for (final reading in _readingsFor(analysis, team.id, [
      'ranking_superiority',
      'form_advantage',
    ])) {
      evidence.add(
        ThesisEvidenceAssessment(
          relation: ThesisEvidenceRelation.additionalSupport,
          family: _familyForReading(reading),
          label: _labelForReading(reading),
          reading: reading,
        ),
      );
    }

    _addDirectionalFormEvidence(
      evidence,
      analysis,
      subjectTeamId: team.id,
      opponentTeamId: opponent.id,
    );
    _addDirectionalVenueEvidence(evidence, analysis, match, subjectSide: side);

    for (final reading in _contradictionsFor(analysis, team.id)) {
      evidence.add(
        ThesisEvidenceAssessment(
          relation: ThesisEvidenceRelation.contradiction,
          family: _familyForReading(reading),
          label: _labelForReading(reading),
          reading: reading,
        ),
      );
    }

    final clarity = _clarityScoreForEvidence(evidence);
    final supportedFamilies = _supportFamilyCount(evidence);
    final hasCore = evidence.any(
      (item) => item.relation == ThesisEvidenceRelation.coreSupport,
    );

    return ThesisAssessment(
      id: 'expected_domination',
      title: 'Domination attendue',
      subjectSide: side,
      status: hasCore && supportedFamilies >= 3
          ? ThesisAssessmentStatus.supported
          : ThesisAssessmentStatus.eligibleButUnsupported,
      clarityScore: clarity,
      evidence: evidence.isEmpty
          ? const [
              ThesisEvidenceAssessment(
                relation: ThesisEvidenceRelation.evidenceUnavailable,
                family: CopilotArgumentFamily.hierarchy,
                label: 'Aucun écart structurel exploitable.',
              ),
            ]
          : List.unmodifiable(evidence),
    );
  }

  _OpportunityCandidate? _favoriteWithProtection(
    MatchBoardItem match,
    FootballAnalysis analysis,
  ) {
    final favorite = _marketFavorite(match);
    if (favorite == null || favorite.side == ReadingSubjectSide.match) {
      return null;
    }

    final team = _teamForSide(match, favorite.side);
    final supporting = _readingsFor(analysis, team.id, [
      'ranking_superiority',
      'solid_defense',
    ]);
    final contradictions = _contradictionsFor(analysis, team.id);
    if (supporting.length >= 2 && contradictions.isNotEmpty) {
      return _OpportunityCandidate(
        id: 'favorite_with_protection',
        title: 'Favori avec protection',
        summary:
            '${team.name} reste supérieur, mais un point de vigilance invite à couvrir le scénario.',
        subjectSide: favorite.side,
        supportingReadings: supporting,
        contradictoryReadings: contradictions.take(1).toList(),
        marketIntents: [
          _MarketIntent('doubleChance', _doubleChanceForSide(favorite.side)),
        ],
        priority: 82,
      );
    }

    return null;
  }

  _OpportunityCandidate? _convergentOpenMatch(
    MatchBoardItem match,
    FootballAnalysis analysis,
  ) {
    final supporting = [
      ...analysis.detected(id: 'open_match_profile'),
      ...analysis.detected(id: 'frequent_over_25'),
      ...analysis.detected(id: 'high_xg_creation'),
      ...analysis.detected(id: 'fragile_defense'),
      ...analysis.detected(id: 'high_xg_conceded'),
    ];
    if (supporting.length < 3) {
      return null;
    }

    return _OpportunityCandidate(
      id: 'convergent_open_match',
      title: 'Match ouvert',
      summary:
          'Les lectures d’attaque, de défense et de rythme convergent vers une rencontre favorable aux buts.',
      subjectSide: ReadingSubjectSide.match,
      supportingReadings: supporting,
      contradictoryReadings: analysis.contradictoryReadings,
      marketIntents: const [
        _MarketIntent('goalsTotal', _SelectionIntent.over25),
        _MarketIntent('bothTeamsScore', _SelectionIntent.yes),
      ],
      priority: 78,
    );
  }

  _OpportunityCandidate? _convergentClosedMatch(
    MatchBoardItem match,
    FootballAnalysis analysis,
  ) {
    final supporting = [
      ...analysis.detected(id: 'closed_match_profile'),
      ...analysis.detected(id: 'frequent_under_25'),
      ...analysis.detected(id: 'solid_defense'),
      ...analysis.detected(id: 'frequent_clean_sheet'),
      ...analysis.detected(id: 'scoring_difficulty'),
    ];
    if (supporting.length < 3) {
      return null;
    }

    return _OpportunityCandidate(
      id: 'convergent_closed_match',
      title: 'Match fermé',
      summary:
          'Les défenses, la faible création offensive et le rythme historique orientent vers peu de buts.',
      subjectSide: ReadingSubjectSide.match,
      supportingReadings: supporting,
      contradictoryReadings: analysis.contradictoryReadings,
      marketIntents: const [
        _MarketIntent('goalsTotal', _SelectionIntent.under25),
      ],
      priority: 76,
    );
  }

  _OpportunityCandidate? _credibleOutsider(
    MatchBoardItem match,
    FootballAnalysis analysis,
  ) {
    final outsider = _marketOutsider(match);
    if (outsider == null) {
      return null;
    }

    final favorite = _marketFavorite(match);
    if (favorite == null || outsider.selection.odds > 4.50) {
      return null;
    }

    final team = _teamForSide(match, outsider.side);
    final opponent = _teamForSide(match, _opponent(outsider.side));
    final supporting = [
      ...analysis.detected(id: 'balanced_hierarchy'),
      ..._readingsFor(analysis, team.id, [
        'positive_streak',
        'strong_home_team',
        'high_xg_creation',
      ]),
      ..._readingsFor(analysis, opponent.id, [
        'negative_streak',
        'declining_form',
        'fragile_defense',
      ]),
    ];
    if (supporting.length < 3) {
      return null;
    }

    return _OpportunityCandidate(
      id: 'credible_outsider',
      title: 'Outsider crédible',
      summary:
          '${team.name} est moins attendu par le marché, mais plusieurs lectures réduisent l’écart théorique.',
      subjectSide: outsider.side,
      supportingReadings: supporting,
      contradictoryReadings: _contradictionsFor(analysis, team.id),
      marketIntents: [
        _MarketIntent('doubleChance', _doubleChanceForSide(outsider.side)),
        _MarketIntent('matchResult', _selectionForSide(outsider.side)),
      ],
      priority: 74,
    );
  }

  _OpportunityCandidate? _teamInSeriousDifficulty(
    MatchBoardItem match,
    FootballAnalysis analysis,
  ) {
    for (final side in [ReadingSubjectSide.home, ReadingSubjectSide.away]) {
      final team = _teamForSide(match, side);
      final supporting = _readingsFor(analysis, team.id, [
        'negative_streak',
        'scoring_difficulty',
        'fragile_defense',
        side == ReadingSubjectSide.away ? 'weak_away_team' : 'weak_home_team',
      ]);
      if (supporting.length >= 3) {
        final opponentSide = _opponent(side);
        return _OpportunityCandidate(
          id: 'team_in_serious_difficulty',
          title: 'Équipe en difficulté',
          summary:
              '${team.name} cumule mauvais résultats, faible production offensive et fragilité défensive.',
          subjectSide: side,
          supportingReadings: supporting,
          contradictoryReadings: _contradictionsFor(analysis, team.id),
          marketIntents: [
            _MarketIntent('doubleChance', _doubleChanceForSide(opponentSide)),
            _MarketIntent('matchResult', _selectionForSide(opponentSide)),
          ],
          priority: 72,
        );
      }
    }

    return null;
  }

  _OpportunityCandidate? _controlledFavorite(
    MatchBoardItem match,
    FootballAnalysis analysis,
  ) {
    final favorite = _marketFavorite(match);
    if (favorite == null) {
      return null;
    }

    final team = _teamForSide(match, favorite.side);
    final opponent = _teamForSide(match, _opponent(favorite.side));
    final supporting = [
      ..._readingsFor(analysis, team.id, [
        'ranking_superiority',
        'solid_defense',
      ]),
      ..._readingsFor(analysis, opponent.id, ['scoring_difficulty']),
      ...analysis.detected(id: 'closed_match_profile'),
    ];
    if (supporting.length < 3) {
      return null;
    }

    return _OpportunityCandidate(
      id: 'controlled_favorite',
      title: 'Favori en contrôle',
      summary:
          '${team.name} possède les moyens de contrôler la rencontre sans scénario très ouvert.',
      subjectSide: favorite.side,
      supportingReadings: supporting,
      contradictoryReadings: _contradictionsFor(analysis, team.id),
      marketIntents: [
        _MarketIntent('matchResult', _selectionForSide(favorite.side)),
        _MarketIntent('doubleChance', _doubleChanceForSide(favorite.side)),
      ],
      priority: 70,
    );
  }

  _OpportunityCandidate? _bothSidesCanScore(
    MatchBoardItem match,
    FootballAnalysis analysis,
  ) {
    final homeCreation =
        analysis.has('high_xg_creation', subjectTeamId: match.homeTeam.id) ||
        analysis.has('prolific_attack', subjectTeamId: match.homeTeam.id);
    final awayCreation =
        analysis.has('high_xg_creation', subjectTeamId: match.awayTeam.id) ||
        analysis.has('prolific_attack', subjectTeamId: match.awayTeam.id);
    final fragile =
        analysis.detected(id: 'fragile_defense').isNotEmpty ||
        analysis.detected(id: 'high_xg_conceded').isNotEmpty;
    if (!homeCreation || !awayCreation || !fragile) {
      return null;
    }

    final supporting = [
      ..._readingsFor(analysis, match.homeTeam.id, [
        'high_xg_creation',
        'prolific_attack',
      ]),
      ..._readingsFor(analysis, match.awayTeam.id, [
        'high_xg_creation',
        'prolific_attack',
      ]),
      ...analysis.detected(id: 'fragile_defense'),
      ...analysis.detected(id: 'high_xg_conceded'),
    ];

    return _OpportunityCandidate(
      id: 'both_sides_can_score',
      title: 'Les deux équipes peuvent marquer',
      summary:
          'Les deux attaques disposent d’arguments et au moins une défense concède trop.',
      subjectSide: ReadingSubjectSide.match,
      supportingReadings: supporting,
      contradictoryReadings: analysis.contradictoryReadings,
      marketIntents: const [
        _MarketIntent('bothTeamsScore', _SelectionIntent.yes),
      ],
      priority: 68,
    );
  }

  _OpportunityCandidate? _oneSidedScoring(
    MatchBoardItem match,
    FootballAnalysis analysis,
  ) {
    for (final side in [ReadingSubjectSide.home, ReadingSubjectSide.away]) {
      final team = _teamForSide(match, side);
      final opponent = _teamForSide(match, _opponent(side));
      final supporting = [
        ..._readingsFor(analysis, team.id, [
          'prolific_attack',
          'high_xg_creation',
        ]),
        ..._readingsFor(analysis, opponent.id, [
          'fragile_defense',
          'high_xg_conceded',
          'scoring_difficulty',
        ]),
        ..._readingsFor(analysis, team.id, ['solid_defense']),
      ];
      if (supporting.length >= 3) {
        return _OpportunityCandidate(
          id: 'one_sided_scoring',
          title: 'Pression offensive à sens unique',
          summary:
              '${team.name} combine production offensive et opposition fragilisée.',
          subjectSide: side,
          supportingReadings: supporting,
          contradictoryReadings: _contradictionsFor(analysis, team.id),
          marketIntents: [
            _MarketIntent(
              side == ReadingSubjectSide.home
                  ? 'teamTotalHome'
                  : 'teamTotalAway',
              _SelectionIntent.over05,
            ),
            _MarketIntent('matchResult', _selectionForSide(side)),
          ],
          priority: 66,
        );
      }
    }

    return null;
  }

  _OpportunityCandidate? _teamBetterThanResults(
    MatchBoardItem match,
    FootballAnalysis analysis,
  ) {
    for (final side in [ReadingSubjectSide.home, ReadingSubjectSide.away]) {
      final team = _teamForSide(match, side);
      final supporting = _readingsFor(analysis, team.id, [
        'negative_streak',
        'offensive_underperformance',
        'high_xg_creation',
      ]);
      if (supporting.length >= 3) {
        return _OpportunityCandidate(
          id: 'team_better_than_results',
          title: 'Meilleur que les résultats',
          summary:
              '${team.name} obtient peu de résultats, mais sa production d’occasions reste meilleure que les scores.',
          subjectSide: side,
          supportingReadings: supporting,
          contradictoryReadings: _contradictionsFor(analysis, team.id),
          marketIntents: [
            _MarketIntent('doubleChance', _doubleChanceForSide(side)),
          ],
          priority: 64,
        );
      }
    }

    return null;
  }

  _OpportunityCandidate? _teamWorseThanResults(
    MatchBoardItem match,
    FootballAnalysis analysis,
  ) {
    for (final side in [ReadingSubjectSide.home, ReadingSubjectSide.away]) {
      final team = _teamForSide(match, side);
      final supporting = _readingsFor(analysis, team.id, [
        'positive_streak',
        'offensive_overperformance',
        'defensive_overperformance',
      ]);
      if (supporting.length >= 3) {
        return _OpportunityCandidate(
          id: 'team_worse_than_results',
          title: 'Résultats à nuancer',
          summary:
              '${team.name} reste sur de bons résultats, mais les xG fragilisent leur solidité.',
          subjectSide: side,
          supportingReadings: supporting,
          contradictoryReadings: _contradictionsFor(analysis, team.id),
          marketIntents: const [],
          priority: 60,
        );
      }
    }

    return null;
  }

  _OpportunityCandidate? _avoidMatch(
    MatchBoardItem match,
    FootballAnalysis analysis,
  ) {
    final supporting = [
      ...analysis.detected(id: 'balanced_hierarchy'),
      ...analysis.detected(id: 'conflicting_signals'),
      ...analysis.detected(id: 'insufficient_data'),
    ];
    if (supporting.length < 2) {
      return null;
    }

    return _OpportunityCandidate(
      id: 'avoid_match',
      title: 'Match à éviter',
      summary:
          'La rencontre ne présente pas une lecture suffisamment claire pour proposer un marché automatiquement.',
      subjectSide: ReadingSubjectSide.match,
      supportingReadings: supporting,
      contradictoryReadings: analysis.contradictoryReadings,
      marketIntents: const [],
      priority: 10,
    );
  }

  void _addDirectionalFormEvidence(
    List<ThesisEvidenceAssessment> evidence,
    FootballAnalysis analysis, {
    required String subjectTeamId,
    required String opponentTeamId,
  }) {
    final subjectPositive = analysis.detected(
      id: 'positive_streak',
      subjectTeamId: subjectTeamId,
    );
    final opponentPositive = analysis.detected(
      id: 'positive_streak',
      subjectTeamId: opponentTeamId,
    );
    if (subjectPositive.isNotEmpty && opponentPositive.isNotEmpty) {
      for (final reading in [...subjectPositive, ...opponentPositive]) {
        evidence.add(
          ThesisEvidenceAssessment(
            relation: ThesisEvidenceRelation.nonDiscriminating,
            family: _familyForReading(reading),
            label: _labelForReading(reading),
            reading: reading,
          ),
        );
      }
      return;
    }

    for (final reading in subjectPositive) {
      evidence.add(
        ThesisEvidenceAssessment(
          relation: ThesisEvidenceRelation.additionalSupport,
          family: _familyForReading(reading),
          label: _labelForReading(reading),
          reading: reading,
        ),
      );
    }
    for (final reading in opponentPositive) {
      evidence.add(
        ThesisEvidenceAssessment(
          relation: ThesisEvidenceRelation.resistance,
          family: _familyForReading(reading),
          label: _labelForReading(reading),
          reading: reading,
        ),
      );
    }
  }

  void _addDirectionalVenueEvidence(
    List<ThesisEvidenceAssessment> evidence,
    FootballAnalysis analysis,
    MatchBoardItem match, {
    required ReadingSubjectSide subjectSide,
  }) {
    final subject = _teamForSide(match, subjectSide);
    final opponentSide = _opponent(subjectSide);
    final opponent = _teamForSide(match, opponentSide);
    final subjectStrongId = subjectSide == ReadingSubjectSide.home
        ? 'strong_home_team'
        : 'strong_away_team';
    final subjectWeakId = subjectSide == ReadingSubjectSide.home
        ? 'weak_home_team'
        : 'weak_away_team';
    final opponentStrongId = opponentSide == ReadingSubjectSide.home
        ? 'strong_home_team'
        : 'strong_away_team';
    final opponentWeakId = opponentSide == ReadingSubjectSide.home
        ? 'weak_home_team'
        : 'weak_away_team';

    for (final reading in _readingsFor(analysis, subject.id, [
      subjectStrongId,
    ])) {
      evidence.add(
        ThesisEvidenceAssessment(
          relation: ThesisEvidenceRelation.additionalSupport,
          family: _familyForReading(reading),
          label: _labelForReading(reading),
          reading: reading,
        ),
      );
    }
    for (final reading in _readingsFor(analysis, opponent.id, [
      opponentWeakId,
    ])) {
      evidence.add(
        ThesisEvidenceAssessment(
          relation: ThesisEvidenceRelation.additionalSupport,
          family: _familyForReading(reading),
          label: _labelForReading(reading),
          reading: reading,
        ),
      );
    }
    for (final reading in _readingsFor(analysis, opponent.id, [
      opponentStrongId,
    ])) {
      evidence.add(
        ThesisEvidenceAssessment(
          relation: ThesisEvidenceRelation.resistance,
          family: _familyForReading(reading),
          label: _labelForReading(reading),
          reading: reading,
        ),
      );
    }
    for (final reading in _readingsFor(analysis, subject.id, [subjectWeakId])) {
      evidence.add(
        ThesisEvidenceAssessment(
          relation: ThesisEvidenceRelation.resistance,
          family: _familyForReading(reading),
          label: _labelForReading(reading),
          reading: reading,
        ),
      );
    }

    final hasPositiveVenue = evidence.any(
      (item) =>
          item.reading?.id == subjectStrongId ||
          item.reading?.id == opponentWeakId,
    );
    for (final reading in analysis.detected(id: 'home_away_mismatch')) {
      evidence.add(
        ThesisEvidenceAssessment(
          relation: hasPositiveVenue
              ? ThesisEvidenceRelation.additionalSupport
              : ThesisEvidenceRelation.nonDiscriminating,
          family: _familyForReading(reading),
          label: _labelForReading(reading),
          reading: reading,
        ),
      );
    }
  }

  List<OpportunityMarketCompatibility> _compatibleMarkets(
    MatchBoardItem match,
    CompiledDecisionProfile profile,
    _OpportunityCandidate candidate,
  ) {
    final result = <OpportunityMarketCompatibility>[];
    for (final intent in candidate.marketIntents) {
      final market = _marketById(match, intent.marketId);
      final preference = profile.enabledMarket(intent.marketId);
      if (market == null || preference == null) {
        continue;
      }

      final selection = _selectionForIntent(market, intent.selection);
      if (selection == null) {
        continue;
      }

      result.add(
        OpportunityMarketCompatibility(
          thesisId: candidate.id,
          market: market,
          selection: selection,
          isRecommended: result.isEmpty,
        ),
      );
    }

    return result;
  }

  MatchThesis _thesisFor(
    MatchBoardItem match,
    _OpportunityCandidate candidate,
    RecommendedMarket? recommendedMarket,
  ) {
    final arguments = [
      for (final reading in candidate.supportingReadings)
        reading.toCopilotArgument(subjectName: _subjectNameFor(match, reading)),
      for (final reading in candidate.contradictoryReadings)
        reading.toCopilotArgument(subjectName: _subjectNameFor(match, reading)),
    ];

    return MatchThesis(
      id: candidate.id,
      title: candidate.title,
      summary: candidate.summary,
      status: candidate.id == 'avoid_match'
          ? MatchThesisStatus.notRecommended
          : recommendedMarket == null
          ? MatchThesisStatus.watchlist
          : MatchThesisStatus.recommended,
      confidence: _internalScore(candidate),
      supportingEvidence: [
        for (final reading in candidate.supportingReadings)
          reading.toThesisEvidence(),
      ],
      limits: [
        for (final reading in candidate.contradictoryReadings)
          reading.toThesisEvidence(),
        if (candidate.id != 'avoid_match' && recommendedMarket == null)
          const ThesisEvidence(
            label:
                'Opportunity détectée, mais aucun marché activé ne la traduit proprement.',
            tone: ThesisEvidenceTone.warning,
          ),
      ],
      profileReasons: [
        '${candidate.supportingReadings.length} argument(s)',
        '${candidate.contradictoryReadings.length} point(s) de vigilance',
      ],
      arguments: arguments,
      recommendedMarket: recommendedMarket,
    );
  }

  String _subjectNameFor(MatchBoardItem match, FootballReading reading) {
    if (reading.subjectTeamId == match.homeTeam.id) {
      return match.homeTeam.name;
    }
    if (reading.subjectTeamId == match.awayTeam.id) {
      return match.awayTeam.name;
    }
    if (reading.subjectTeamId == match.id) {
      return 'La rencontre';
    }
    return reading.subjectTeamId;
  }

  MatchSignal _signalFor(MatchThesis thesis) {
    return MatchSignal(
      id: thesis.id,
      title: thesis.title,
      summary: thesis.summary,
      proofs: [
        ...thesis.profileReasons,
        ...thesis.supportingEvidence.map((evidence) => evidence.label),
        ...thesis.limits.map((evidence) => evidence.label),
      ],
    );
  }

  int _internalScore(_OpportunityCandidate candidate) {
    return candidate.clarityScore;
  }

  List<FootballReading> _readingsFor(
    FootballAnalysis analysis,
    String teamId,
    List<String> ids,
  ) {
    return [
      for (final id in ids) ...analysis.detected(id: id, subjectTeamId: teamId),
      for (final id in ids)
        ...analysis.detected(id: id, subjectTeamId: analysis.fixtureId),
    ];
  }

  List<FootballReading> _contradictionsFor(
    FootballAnalysis analysis,
    String teamId,
  ) {
    return analysis.contradictoryReadings
        .where(
          (reading) =>
              reading.subjectTeamId == teamId ||
              reading.subjectTeamId == analysis.fixtureId,
        )
        .toList(growable: false);
  }

  MatchMarket? _marketById(MatchBoardItem match, String marketId) {
    for (final market in match.availableMarkets) {
      if (market.id == marketId) {
        return market;
      }
    }

    return null;
  }

  MarketOdds? _selectionForIntent(MatchMarket market, _SelectionIntent intent) {
    for (final selection in market.selections) {
      final rawValue = selection.apiFootballValue?.toLowerCase();
      final label = selection.label.toLowerCase();
      final matches = switch (intent) {
        _SelectionIntent.home =>
          rawValue == 'home' || label == 'domicile' || label == '1',
        _SelectionIntent.draw => rawValue == 'draw' || label == 'nul',
        _SelectionIntent.away =>
          rawValue == 'away' || label == 'extérieur' || label == '2',
        _SelectionIntent.homeOrDraw => rawValue == 'home/draw' || label == '1x',
        _SelectionIntent.homeOrAway => rawValue == 'home/away' || label == '12',
        _SelectionIntent.drawOrAway => rawValue == 'draw/away' || label == 'x2',
        _SelectionIntent.over25 =>
          rawValue == 'over 2.5' || label.contains('over 2.5'),
        _SelectionIntent.under25 =>
          rawValue == 'under 2.5' || label.contains('under 2.5'),
        _SelectionIntent.over05 =>
          rawValue == 'over 0.5' || label.contains('over 0.5'),
        _SelectionIntent.yes => rawValue == 'yes' || label == 'oui',
        _SelectionIntent.no => rawValue == 'no' || label == 'non',
      };

      if (matches) {
        return selection;
      }
    }

    return null;
  }

  _MarketSide? _marketFavorite(MatchBoardItem match) {
    final market = _marketById(match, 'matchResult');
    if (market == null || market.selections.length < 3) {
      return null;
    }

    final sides = [
      _marketSideFor(market, ReadingSubjectSide.home),
      _marketSideFor(market, ReadingSubjectSide.away),
    ].whereType<_MarketSide>().toList();
    if (sides.isEmpty) {
      return null;
    }

    sides.sort((a, b) => a.selection.odds.compareTo(b.selection.odds));
    return sides.first;
  }

  _MarketSide? _marketOutsider(MatchBoardItem match) {
    final market = _marketById(match, 'matchResult');
    if (market == null || market.selections.length < 3) {
      return null;
    }

    final sides = [
      _marketSideFor(market, ReadingSubjectSide.home),
      _marketSideFor(market, ReadingSubjectSide.away),
    ].whereType<_MarketSide>().toList();
    if (sides.isEmpty) {
      return null;
    }

    sides.sort((a, b) => b.selection.odds.compareTo(a.selection.odds));
    return sides.first;
  }

  _MarketSide? _marketSideFor(MatchMarket market, ReadingSubjectSide side) {
    final selection = _selectionForIntent(market, _selectionForSide(side));
    return selection == null ? null : _MarketSide(side, selection);
  }

  TeamInfo _teamForSide(MatchBoardItem match, ReadingSubjectSide side) {
    return side == ReadingSubjectSide.home ? match.homeTeam : match.awayTeam;
  }

  ReadingSubjectSide _opponent(ReadingSubjectSide side) {
    return side == ReadingSubjectSide.home
        ? ReadingSubjectSide.away
        : ReadingSubjectSide.home;
  }

  _SelectionIntent _selectionForSide(ReadingSubjectSide side) {
    return side == ReadingSubjectSide.home
        ? _SelectionIntent.home
        : _SelectionIntent.away;
  }

  _SelectionIntent _doubleChanceForSide(ReadingSubjectSide side) {
    return side == ReadingSubjectSide.home
        ? _SelectionIntent.homeOrDraw
        : _SelectionIntent.drawOrAway;
  }
}

class _OpportunityCandidate {
  const _OpportunityCandidate({
    required this.id,
    required this.title,
    required this.summary,
    required this.subjectSide,
    required this.supportingReadings,
    required this.contradictoryReadings,
    required this.marketIntents,
    required this.priority,
    this.evidenceAssessments = const [],
  });

  final String id;
  final String title;
  final String summary;
  final ReadingSubjectSide subjectSide;
  final List<FootballReading> supportingReadings;
  final List<FootballReading> contradictoryReadings;
  final List<_MarketIntent> marketIntents;
  final int priority;
  final List<ThesisEvidenceAssessment> evidenceAssessments;

  int get clarityScore => _clarityScoreForEvidence(assessmentEvidence);

  List<ThesisEvidenceAssessment> get assessmentEvidence {
    if (evidenceAssessments.isNotEmpty) {
      return evidenceAssessments;
    }
    return [
      for (final reading in supportingReadings)
        ThesisEvidenceAssessment(
          relation: ThesisEvidenceRelation.additionalSupport,
          family: _familyForReading(reading),
          label: _labelForReading(reading),
          reading: reading,
        ),
      for (final reading in contradictoryReadings)
        ThesisEvidenceAssessment(
          relation: ThesisEvidenceRelation.contradiction,
          family: _familyForReading(reading),
          label: _labelForReading(reading),
          reading: reading,
        ),
    ];
  }

  ThesisAssessment get assessment {
    return ThesisAssessment(
      id: id,
      title: title,
      subjectSide: subjectSide,
      status: ThesisAssessmentStatus.supported,
      clarityScore: clarityScore,
      evidence: assessmentEvidence,
    );
  }
}

class _MarketIntent {
  const _MarketIntent(this.marketId, this.selection);

  final String marketId;
  final _SelectionIntent selection;
}

class _MarketSide {
  const _MarketSide(this.side, this.selection);

  final ReadingSubjectSide side;
  final MarketOdds selection;
}

class _ThesisSpec {
  const _ThesisSpec(this.id, this.title);

  final String id;
  final String title;
}

const _canonicalThesisSpecs = [
  _ThesisSpec('expected_domination', 'Domination attendue'),
  _ThesisSpec('favorite_with_protection', 'Favori avec protection'),
  _ThesisSpec('convergent_open_match', 'Match ouvert'),
  _ThesisSpec('convergent_closed_match', 'Match fermé'),
  _ThesisSpec('credible_outsider', 'Outsider crédible'),
  _ThesisSpec('team_in_serious_difficulty', 'Équipe en difficulté'),
  _ThesisSpec('controlled_favorite', 'Favori en contrôle'),
  _ThesisSpec('both_sides_can_score', 'Les deux équipes peuvent marquer'),
  _ThesisSpec('one_sided_scoring', 'Pression offensive à sens unique'),
  _ThesisSpec('team_better_than_results', 'Meilleur que les résultats'),
  _ThesisSpec('team_worse_than_results', 'Résultats à nuancer'),
  _ThesisSpec('avoid_match', 'Match à éviter'),
];

CopilotArgumentFamily _familyForReading(FootballReading reading) {
  return reading.toCopilotArgument(subjectName: '').family;
}

String _labelForReading(FootballReading reading) {
  return reading.evidence.isEmpty ? reading.id : reading.evidence.first.label;
}

int _clarityScoreForEvidence(List<ThesisEvidenceAssessment> evidence) {
  final coreFamilies = <CopilotArgumentFamily>{};
  final supportFamilies = <CopilotArgumentFamily>{};
  var resistanceCount = 0;
  var contradictionCount = 0;

  for (final item in evidence) {
    switch (item.relation) {
      case ThesisEvidenceRelation.coreSupport:
        coreFamilies.add(item.family);
        break;
      case ThesisEvidenceRelation.additionalSupport:
        supportFamilies.add(item.family);
        break;
      case ThesisEvidenceRelation.resistance:
        resistanceCount += 1;
        break;
      case ThesisEvidenceRelation.contradiction:
        contradictionCount += 1;
        break;
      case ThesisEvidenceRelation.nonDiscriminating:
      case ThesisEvidenceRelation.notRelevant:
      case ThesisEvidenceRelation.evidenceUnavailable:
        break;
    }
  }

  supportFamilies.removeAll(coreFamilies);
  final score =
      coreFamilies.length * 28 +
      supportFamilies.length * 14 -
      resistanceCount * 10 -
      contradictionCount * 18;
  return score.clamp(0, 96);
}

int _supportFamilyCount(List<ThesisEvidenceAssessment> evidence) {
  final families = <CopilotArgumentFamily>{};
  for (final item in evidence) {
    if (item.relation == ThesisEvidenceRelation.coreSupport ||
        item.relation == ThesisEvidenceRelation.additionalSupport) {
      families.add(item.family);
    }
  }
  return families.length;
}

enum _SelectionIntent {
  home,
  draw,
  away,
  homeOrDraw,
  homeOrAway,
  drawOrAway,
  over25,
  under25,
  over05,
  yes,
  no,
}
