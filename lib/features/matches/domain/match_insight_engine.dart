import '../../onboarding/domain/compiled_decision_profile.dart';
import '../../opportunities/domain/opportunity.dart';
import 'match_board_item.dart';
import 'opportunity_engine_v2.dart';

class MatchInsightEngine {
  const MatchInsightEngine();

  static const _v2 = OpportunityEngineV2();

  List<MatchBoardItem> recommendations(
    List<MatchBoardItem> matches,
    CompiledDecisionProfile profile,
  ) {
    return opportunities(matches, profile)
        .where((opportunity) => opportunity.hasRecommendedMarket)
        .map((opportunity) => opportunity.toMatchBoardItem())
        .toList();
  }

  List<Opportunity> opportunities(
    List<MatchBoardItem> matches,
    CompiledDecisionProfile profile,
  ) {
    final v2Opportunities = _v2.opportunities(matches, profile);
    if (v2Opportunities.isNotEmpty) {
      return v2Opportunities;
    }

    if (!profile.isCompleted) {
      return const [];
    }

    final detectedOpportunities = [
      for (final match in matches)
        if (profile.isCompetitionEnabled(match.competition.id))
          analyzeOpportunity(match, profile),
    ].whereType<Opportunity>().toList();

    detectedOpportunities.sort((a, b) {
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
    });

    return detectedOpportunities;
  }

  Opportunity? analyzeOpportunity(
    MatchBoardItem match,
    CompiledDecisionProfile profile,
  ) {
    final v2Opportunity = _v2.analyzeOpportunity(match, profile);
    if (v2Opportunity != null) {
      return v2Opportunity;
    }

    if (!profile.isCompleted ||
        !profile.isCompetitionEnabled(match.competition.id)) {
      return null;
    }

    return _opportunityFor(match, profile, allowRecommendedMarket: true);
  }

  MatchBoardItem analyze(
    MatchBoardItem match,
    CompiledDecisionProfile profile,
  ) {
    final isInProfile = profile.isCompetitionEnabled(match.competition.id);
    if (isInProfile) {
      final v2Opportunity = _v2.analyzeOpportunity(match, profile);
      if (v2Opportunity != null) {
        return v2Opportunity.toMatchBoardItem();
      }
    }

    final thesis = _bestThesisFor(
      match,
      profile,
      allowRecommendedMarket: isInProfile,
    );
    final recommendedMarket = thesis.recommendedMarket;

    final compatibility =
        isInProfile && thesis.status == MatchThesisStatus.recommended
        ? thesis.confidence
        : 0;

    return match.copyWith(
      primaryMarket: recommendedMarket?.selection,
      profileStatus: isInProfile
          ? MatchProfileStatus.inProfile
          : MatchProfileStatus.outOfProfile,
      compatibility: compatibility,
      signals: _signalsFromThesis(thesis).take(_signalLimit(profile)).toList(),
      thesis: thesis,
    );
  }

  MatchThesis _bestThesisFor(
    MatchBoardItem match,
    CompiledDecisionProfile profile, {
    required bool allowRecommendedMarket,
  }) {
    final opportunity = _opportunityFor(
      match,
      profile,
      allowRecommendedMarket: allowRecommendedMarket,
    );

    return opportunity?.primaryThesis ?? _noThesis(match, profile);
  }

  Opportunity? _opportunityFor(
    MatchBoardItem match,
    CompiledDecisionProfile profile, {
    required bool allowRecommendedMarket,
  }) {
    final candidates = _thesisCandidatesFor(match, profile);

    if (candidates.isNotEmpty) {
      final candidate = candidates.first;
      final compatibleMarkets = <OpportunityMarketCompatibility>[];
      RecommendedMarket? recommendedMarket;
      String? recommendedThesisId;

      if (allowRecommendedMarket) {
        for (final thesis in candidates) {
          final fits = _marketFitsForThesis(match, profile, thesis);
          for (final fit in fits) {
            final isRecommended = recommendedMarket == null;
            compatibleMarkets.add(
              OpportunityMarketCompatibility(
                thesisId: thesis.id,
                market: fit.market,
                selection: fit.selection,
                isRecommended: isRecommended,
              ),
            );

            if (isRecommended) {
              recommendedMarket = RecommendedMarket(
                market: fit.market,
                selection: fit.selection,
              );
              recommendedThesisId = thesis.id;
            }
          }
        }
      }

      final retainedTheses = <MatchThesis>[
        if (recommendedMarket != null && recommendedThesisId != null)
          _recommendedThesis(
            candidates.firstWhere((thesis) => thesis.id == recommendedThesisId),
            recommendedMarket,
          ),
        for (final thesis in candidates)
          if (thesis.id != recommendedThesisId)
            _watchlistThesis(
              match,
              thesis,
              allowRecommendedMarket: allowRecommendedMarket,
            ),
      ];

      return Opportunity(
        sourceMatch: match,
        engineScore: recommendedMarket == null
            ? candidate.baseConfidence.clamp(1, 96).toInt()
            : retainedTheses.first.confidence,
        detectedSignals: _signalsFromThesis(
          retainedTheses.first,
        ).take(_signalLimit(profile)).toList(),
        retainedTheses: retainedTheses,
        compatibleMarkets: compatibleMarkets,
        recommendedMarket: recommendedMarket,
      );
    }

    return null;
  }

  MatchThesis _watchlistThesis(
    MatchBoardItem match,
    _ThesisCandidate candidate, {
    required bool allowRecommendedMarket,
  }) {
    return MatchThesis(
      id: candidate.id,
      title: candidate.title,
      summary:
          '${candidate.summary} Aucun marché activé dans votre profil ne '
          'permet de jouer cette thèse proprement.',
      status: MatchThesisStatus.watchlist,
      confidence: 0,
      supportingEvidence: candidate.supportingEvidence,
      limits: [
        ...candidate.limits,
        if (allowRecommendedMarket)
          const ThesisEvidence(
            label:
                'Thèse détectée, mais aucun marché disponible ne respecte à la fois votre profil et votre type de picks.',
            tone: ThesisEvidenceTone.warning,
          )
        else
          ThesisEvidence(
            label:
                '${match.competition.name} n’est pas activée dans votre profil.',
            tone: ThesisEvidenceTone.neutral,
          ),
      ],
      profileReasons: allowRecommendedMarket
          ? candidate.profileReasons
          : const [],
      arguments: candidate.arguments,
    );
  }

  List<_ThesisCandidate> _thesisCandidatesFor(
    MatchBoardItem match,
    CompiledDecisionProfile profile,
  ) {
    return <_ThesisCandidate?>[
          _solidFavoriteCandidate(match, profile),
          _cautiousDoubleChanceCandidate(match, profile),
          _levelGapCandidate(match, profile),
          _openMatchCandidate(match, profile),
          _closedMatchCandidate(match, profile),
          _credibleOutsiderCandidate(match, profile),
        ]
        .whereType<_ThesisCandidate>()
        .where((candidate) => profile.isThesisAllowed(candidate.id))
        .toList()
      ..sort((a, b) => b.baseConfidence.compareTo(a.baseConfidence));
  }

  MatchThesis _recommendedThesis(
    _ThesisCandidate candidate,
    RecommendedMarket selection,
  ) {
    final confidence = candidate.baseConfidence.clamp(1, 96).toInt();

    return MatchThesis(
      id: candidate.id,
      title: candidate.title,
      summary: candidate.summary,
      status: MatchThesisStatus.recommended,
      confidence: confidence,
      supportingEvidence: candidate.supportingEvidence,
      limits: candidate.limits,
      profileReasons: candidate.profileReasons,
      arguments: candidate.arguments,
      recommendedMarket: selection,
    );
  }

  List<_MarketFit> _marketFitsForThesis(
    MatchBoardItem match,
    CompiledDecisionProfile profile,
    _ThesisCandidate thesis,
  ) {
    final selections = <_MarketFit>[];
    for (final intent in thesis.marketIntents) {
      final market = _marketById(match, intent.marketId);
      final preference = profile.enabledMarket(intent.marketId);
      if (market == null || preference == null) {
        continue;
      }

      final selection = _selectionForIntent(market, intent);
      if (selection == null) {
        continue;
      }

      if (intent.maxOdds != null && selection.odds > intent.maxOdds!) {
        continue;
      }

      selections.add(_MarketFit(market: market, selection: selection));
    }

    return selections;
  }

  MatchMarket? _marketById(MatchBoardItem match, String marketId) {
    for (final market in match.availableMarkets) {
      if (market.id == marketId) {
        return market;
      }
    }

    return null;
  }

  MarketOdds? _selectionForIntent(MatchMarket market, _MarketIntent intent) {
    for (final selection in market.selections) {
      final rawValue = selection.apiFootballValue?.toLowerCase();
      final label = selection.label.toLowerCase();

      final matches = switch (intent.selection) {
        _SelectionIntent.home =>
          rawValue == 'home' || label == 'domicile' || label == '1',
        _SelectionIntent.draw => rawValue == 'draw' || label == 'nul',
        _SelectionIntent.away =>
          rawValue == 'away' || label == 'extérieur' || label == '2',
        _SelectionIntent.homeOrDraw => rawValue == 'home/draw' || label == '1x',
        _SelectionIntent.homeOrAway => rawValue == 'home/away' || label == '12',
        _SelectionIntent.drawOrAway => rawValue == 'draw/away' || label == 'x2',
        _SelectionIntent.over =>
          rawValue?.startsWith('over ${intent.line}') == true ||
              label.startsWith('over ${intent.line}'),
        _SelectionIntent.under =>
          rawValue?.startsWith('under ${intent.line}') == true ||
              label.startsWith('under ${intent.line}'),
      };

      if (matches) {
        return selection;
      }
    }

    return null;
  }

  _ThesisCandidate? _solidFavoriteCandidate(
    MatchBoardItem match,
    CompiledDecisionProfile profile,
  ) {
    final favorite = _marketFavorite(match);
    if (favorite == null || favorite.selection.odds > 2.05) {
      return null;
    }

    final side = favorite.side;
    final support = <ThesisEvidence>[
      ThesisEvidence(
        label:
            '${_teamNameForSide(match, side)} est favori du marché 1N2 à ${favorite.selection.odds.toStringAsFixed(2)}.',
        tone: ThesisEvidenceTone.positive,
      ),
    ];
    final limits = <ThesisEvidence>[];
    var score = 52;

    final standingEdge = _standingEdgeFor(match, side);
    if (standingEdge != null) {
      score += standingEdge.isStrong ? 12 : 6;
      support.add(standingEdge.evidence);
    }

    final formEdge = _formEdgeFor(match, side);
    if (formEdge != null) {
      score += formEdge.isStrong ? 10 : 5;
      support.add(formEdge.evidence);
    }

    final reliabilityEdge = _reliabilityEdgeFor(match, side);
    if (reliabilityEdge != null) {
      score += reliabilityEdge.isStrong ? 8 : 4;
      support.add(reliabilityEdge.evidence);
    }

    if (support.length < 2) {
      return null;
    }

    if (match.analysis.hasAnalysisData == false) {
      limits.add(
        const ThesisEvidence(
          label: 'Données sportives insuffisantes pour valider le favori.',
          tone: ThesisEvidenceTone.warning,
        ),
      );
      score -= 16;
    }

    return _ThesisCandidate(
      id: 'solid_favorite',
      title: 'Favori solide',
      summary:
          '${_teamNameForSide(match, side)} présente le scénario le plus cohérent, mais la cote ne suffit pas seule : elle est validée par des signaux sportifs.',
      baseConfidence: score,
      supportingEvidence: support,
      limits: limits,
      profileReasons: _profileReasons(profile, [
        'solid_favorite',
        'solid_edges',
      ]),
      arguments: _argumentsForSide(match, side, includeMarket: true),
      marketIntents: [
        _MarketIntent(
          marketId: 'matchResult',
          selection: _threeWayIntentForSide(side),
          maxOdds: 2.40,
        ),
      ],
    );
  }

  _ThesisCandidate? _cautiousDoubleChanceCandidate(
    MatchBoardItem match,
    CompiledDecisionProfile profile,
  ) {
    final favorite = _marketFavorite(match);
    if (favorite == null || favorite.selection.odds > 2.35) {
      return null;
    }

    final side = favorite.side;
    final support = <ThesisEvidence>[
      ThesisEvidence(
        label:
            '${_teamNameForSide(match, side)} a le prix le plus bas du 1N2, sans exiger de victoire sèche.',
        tone: ThesisEvidenceTone.positive,
      ),
    ];
    var score = 50;

    final standingEdge = _standingEdgeFor(match, side);
    if (standingEdge != null) {
      score += standingEdge.isStrong ? 9 : 5;
      support.add(standingEdge.evidence);
    }

    final formEdge = _formEdgeFor(match, side);
    if (formEdge != null) {
      score += formEdge.isStrong ? 8 : 4;
      support.add(formEdge.evidence);
    }

    if (support.length < 2) {
      return null;
    }

    return _ThesisCandidate(
      id: 'cautious_double_chance',
      title: 'Double chance prudente',
      summary:
          'Le scénario favorise ${_teamNameForSide(match, side)}, mais le profil de risque invite à couvrir le nul.',
      baseConfidence: score,
      supportingEvidence: support,
      limits: const [
        ThesisEvidence(
          label:
              'La thèse privilégie la couverture plutôt que la cote maximale.',
          tone: ThesisEvidenceTone.neutral,
        ),
      ],
      profileReasons: _profileReasons(profile, ['secure_bets']),
      arguments: _argumentsForSide(match, side, includeMarket: true),
      marketIntents: [
        _MarketIntent(
          marketId: 'doubleChance',
          selection: side == _TeamSide.home
              ? _SelectionIntent.homeOrDraw
              : _SelectionIntent.drawOrAway,
          maxOdds: 2.10,
        ),
      ],
    );
  }

  _ThesisCandidate? _levelGapCandidate(
    MatchBoardItem match,
    CompiledDecisionProfile profile,
  ) {
    final home = match.analysis.homeStanding;
    final away = match.analysis.awayStanding;
    if (home == null ||
        away == null ||
        home.rank == null ||
        away.rank == null) {
      return null;
    }

    final rankGap = (home.rank! - away.rank!).abs();
    final pointsGap = home.points == null || away.points == null
        ? 0
        : (home.points! - away.points!).abs();
    if (rankGap < 5 && pointsGap < 8) {
      return null;
    }

    final side = home.rank! < away.rank! ? _TeamSide.home : _TeamSide.away;
    final favorite = _marketFavorite(match);
    final support = [
      ThesisEvidence(
        label:
            '${match.homeTeam.name} #${home.rank}, ${match.awayTeam.name} #${away.rank}.',
        tone: ThesisEvidenceTone.positive,
      ),
      if (home.points != null && away.points != null)
        ThesisEvidence(
          label: '${home.points} pts contre ${away.points} pts.',
          tone: ThesisEvidenceTone.positive,
        ),
    ];
    final limits = <ThesisEvidence>[];
    if (favorite != null && favorite.side != side) {
      limits.add(
        const ThesisEvidence(
          label:
              'Le marché 1N2 ne confirme pas clairement l’écart de classement.',
          tone: ThesisEvidenceTone.warning,
        ),
      );
    }

    return _ThesisCandidate(
      id: 'level_gap',
      title: 'Écart de niveau',
      summary:
          'Le classement indique une hiérarchie nette en faveur de ${_teamNameForSide(match, side)}.',
      baseConfidence: favorite?.side == side ? 74 : 62,
      supportingEvidence: support,
      limits: limits,
      profileReasons: _profileReasons(profile, ['ranking_gap', 'solid_edges']),
      arguments: _argumentsForSide(match, side, includeMarket: false),
      marketIntents: [
        _MarketIntent(
          marketId: 'doubleChance',
          selection: side == _TeamSide.home
              ? _SelectionIntent.homeOrDraw
              : _SelectionIntent.drawOrAway,
          maxOdds: 2.15,
        ),
        _MarketIntent(
          marketId: 'matchResult',
          selection: _threeWayIntentForSide(side),
          maxOdds: 2.55,
        ),
      ],
    );
  }

  _ThesisCandidate? _openMatchCandidate(
    MatchBoardItem match,
    CompiledDecisionProfile profile,
  ) {
    final climate = _goalClimate(match);
    if (climate == null || climate < 2.75) {
      return null;
    }

    return _ThesisCandidate(
      id: 'open_match',
      title: 'Match ouvert',
      summary:
          'Les moyennes de buts orientent la lecture vers un scénario avec occasions des deux côtés.',
      baseConfidence: climate >= 3.2 ? 76 : 66,
      supportingEvidence: [
        ThesisEvidence(
          label: 'Climat buts estimé : ${climate.toStringAsFixed(2)}.',
          tone: ThesisEvidenceTone.positive,
        ),
        ..._goalAverageEvidence(match),
      ],
      limits: const [],
      profileReasons: _profileReasons(profile, [
        'offensive_match',
        'match_dynamics',
      ]),
      arguments: _rhythmArguments(match, isOpen: true),
      marketIntents: const [
        _MarketIntent(
          marketId: 'goalsTotal',
          selection: _SelectionIntent.over,
          line: '2.5',
          maxOdds: 2.40,
        ),
      ],
    );
  }

  _ThesisCandidate? _closedMatchCandidate(
    MatchBoardItem match,
    CompiledDecisionProfile profile,
  ) {
    final climate = _goalClimate(match);
    if (climate == null || climate > 2.05) {
      return null;
    }

    return _ThesisCandidate(
      id: 'closed_match',
      title: 'Match fermé',
      summary:
          'Les moyennes disponibles suggèrent un rythme plus bas et moins de buts.',
      baseConfidence: climate <= 1.75 ? 74 : 64,
      supportingEvidence: [
        ThesisEvidence(
          label: 'Climat buts estimé : ${climate.toStringAsFixed(2)}.',
          tone: ThesisEvidenceTone.positive,
        ),
        ..._goalAverageEvidence(match),
      ],
      limits: const [],
      profileReasons: _profileReasons(profile, [
        'defensive_match',
        'match_dynamics',
      ]),
      arguments: _rhythmArguments(match, isOpen: false),
      marketIntents: const [
        _MarketIntent(
          marketId: 'goalsTotal',
          selection: _SelectionIntent.under,
          line: '2.5',
          maxOdds: 2.30,
        ),
      ],
    );
  }

  _ThesisCandidate? _credibleOutsiderCandidate(
    MatchBoardItem match,
    CompiledDecisionProfile profile,
  ) {
    final favorite = _marketFavorite(match);
    final outsider = _marketOutsider(match);
    if (favorite == null ||
        outsider == null ||
        outsider.selection.odds > 4.50) {
      return null;
    }

    final side = outsider.side;
    final support = <ThesisEvidence>[];
    var score = 46;

    final standingEdge = _standingEdgeFor(match, side);
    if (standingEdge != null) {
      score += standingEdge.isStrong ? 14 : 8;
      support.add(standingEdge.evidence);
    }

    final formEdge = _formEdgeFor(match, side);
    if (formEdge != null) {
      score += formEdge.isStrong ? 14 : 8;
      support.add(formEdge.evidence);
    }

    final reliabilityEdge = _reliabilityEdgeFor(match, side);
    if (reliabilityEdge != null) {
      score += reliabilityEdge.isStrong ? 8 : 4;
      support.add(reliabilityEdge.evidence);
    }

    if (support.length < 2 || score < 68) {
      return null;
    }

    return _ThesisCandidate(
      id: 'credible_outsider',
      title: 'Outsider crédible',
      summary:
          '${_teamNameForSide(match, side)} est outsider, mais plusieurs signaux sportifs soutiennent une surprise plausible.',
      baseConfidence: score,
      supportingEvidence: [
        ThesisEvidence(
          label:
              'Cote outsider : ${outsider.selection.odds.toStringAsFixed(2)}.',
          tone: ThesisEvidenceTone.warning,
        ),
        ...support,
      ],
      limits: const [
        ThesisEvidence(
          label:
              'Scénario plus volatil : la cote élevée traduit un marché moins favorable.',
          tone: ThesisEvidenceTone.warning,
        ),
      ],
      profileReasons: _profileReasons(profile, ['balanced_opportunities']),
      arguments: _argumentsForSide(match, side, includeMarket: true),
      marketIntents: [
        _MarketIntent(
          marketId: 'doubleChance',
          selection: side == _TeamSide.home
              ? _SelectionIntent.homeOrDraw
              : _SelectionIntent.drawOrAway,
          maxOdds: 2.70,
        ),
        _MarketIntent(
          marketId: 'matchResult',
          selection: _threeWayIntentForSide(side),
          maxOdds: 4.50,
        ),
      ],
    );
  }

  MatchThesis _noThesis(MatchBoardItem match, CompiledDecisionProfile profile) {
    final limits = <ThesisEvidence>[];
    if (!match.analysis.hasAnalysisData) {
      limits.add(
        const ThesisEvidence(
          label:
              'Aucune donnée sportive normalisée ne permet de soutenir une thèse.',
          tone: ThesisEvidenceTone.negative,
        ),
      );
    }

    final favorite = _marketFavorite(match);
    final outsider = _marketOutsider(match);
    if (outsider != null && outsider.selection.odds >= 4.50) {
      limits.add(
        ThesisEvidence(
          label:
              'La cote ${outsider.selection.odds.toStringAsFixed(2)} de ${_teamNameForSide(match, outsider.side)} indique un outsider clair, sans preuve suffisante de surprise.',
          tone: ThesisEvidenceTone.negative,
        ),
      );
    }

    if (favorite != null) {
      limits.add(
        ThesisEvidence(
          label:
              'Le favori du marché est ${_teamNameForSide(match, favorite.side)} à ${favorite.selection.odds.toStringAsFixed(2)}, mais la thèse sportive reste insuffisante.',
          tone: ThesisEvidenceTone.neutral,
        ),
      );
    }

    return MatchThesis(
      id: 'no_sufficient_thesis',
      title: 'Aucune thèse suffisante',
      summary:
          'Copilot ne recommande aucun pari : les données disponibles ne soutiennent pas assez un scénario précis.',
      status: MatchThesisStatus.notRecommended,
      confidence: 0,
      supportingEvidence: const [],
      limits: limits.isEmpty
          ? const [
              ThesisEvidence(
                label:
                    'Marchés disponibles, mais aucun scénario déterministe assez solide.',
                tone: ThesisEvidenceTone.warning,
              ),
            ]
          : limits,
      profileReasons: _profileReasons(profile, [
        'solid_favorite',
        'balanced_match',
        'offensive_match',
      ]),
      arguments: _fallbackArguments(match),
    );
  }

  List<MatchSignal> _signalsFromThesis(MatchThesis thesis) {
    return [
      MatchSignal(
        id: thesis.id,
        title: thesis.title,
        summary: thesis.summary,
        proofs: [
          if (thesis.recommendedMarket != null)
            'Marché proposé : ${thesis.recommendedMarket!.market.label} · ${thesis.recommendedMarket!.selection.label} à ${thesis.recommendedMarket!.selection.odds.toStringAsFixed(2)}.',
          ...thesis.profileReasons,
          ...thesis.supportingEvidence.map((evidence) => evidence.label),
          ...thesis.limits.map((evidence) => evidence.label),
        ],
      ),
    ];
  }

  int _formScore(String form) {
    return form.toUpperCase().split('').take(5).fold<int>(0, (score, result) {
      return score +
          switch (result) {
            'W' => 3,
            'D' => 1,
            _ => 0,
          };
    });
  }

  double? _lossRate(TeamStatisticsSnapshot statistics) {
    final played = statistics.playedTotal;
    final losses = statistics.lossesTotal;
    if (played == null || played <= 0 || losses == null) {
      return null;
    }

    return losses / played;
  }

  String _rateLabel(double rate) => '${(rate * 100).round()}%';

  _MarketSide? _marketFavorite(MatchBoardItem match) {
    final market = _marketById(match, 'matchResult');
    if (market == null || market.selections.length < 3) {
      return null;
    }

    final sides = [
      for (final side in [_TeamSide.home, _TeamSide.draw, _TeamSide.away])
        _marketSideFor(market, side),
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
      for (final side in [_TeamSide.home, _TeamSide.away])
        _marketSideFor(market, side),
    ].whereType<_MarketSide>().toList();
    if (sides.isEmpty) {
      return null;
    }

    sides.sort((a, b) => b.selection.odds.compareTo(a.selection.odds));
    return sides.first;
  }

  _MarketSide? _marketSideFor(MatchMarket market, _TeamSide side) {
    if (side == _TeamSide.draw) {
      final selection = _selectionForIntent(
        market,
        const _MarketIntent(
          marketId: 'matchResult',
          selection: _SelectionIntent.draw,
        ),
      );
      return selection == null
          ? null
          : _MarketSide(side: side, selection: selection);
    }

    final selection = _selectionForIntent(
      market,
      _MarketIntent(
        marketId: 'matchResult',
        selection: _threeWayIntentForSide(side),
      ),
    );
    return selection == null
        ? null
        : _MarketSide(side: side, selection: selection);
  }

  String _teamNameForSide(MatchBoardItem match, _TeamSide side) {
    return switch (side) {
      _TeamSide.home => match.homeTeam.name,
      _TeamSide.away => match.awayTeam.name,
      _TeamSide.draw => 'le nul',
    };
  }

  _TeamSide _opponentSide(_TeamSide side) {
    return switch (side) {
      _TeamSide.home => _TeamSide.away,
      _TeamSide.away => _TeamSide.home,
      _TeamSide.draw => _TeamSide.draw,
    };
  }

  TeamStandingSnapshot? _standingForSide(MatchBoardItem match, _TeamSide side) {
    return switch (side) {
      _TeamSide.home => match.analysis.homeStanding,
      _TeamSide.away => match.analysis.awayStanding,
      _TeamSide.draw => null,
    };
  }

  TeamStatisticsSnapshot? _statisticsForSide(
    MatchBoardItem match,
    _TeamSide side,
  ) {
    return switch (side) {
      _TeamSide.home => match.analysis.homeStatistics,
      _TeamSide.away => match.analysis.awayStatistics,
      _TeamSide.draw => null,
    };
  }

  String? _formForSide(MatchBoardItem match, _TeamSide side) {
    return switch (side) {
      _TeamSide.home =>
        match.analysis.homeStatistics?.form ??
            match.analysis.homeStanding?.form,
      _TeamSide.away =>
        match.analysis.awayStatistics?.form ??
            match.analysis.awayStanding?.form,
      _TeamSide.draw => null,
    };
  }

  List<String> _recentResults(String form) {
    return form
        .trim()
        .toUpperCase()
        .split('')
        .where((result) => result == 'W' || result == 'D' || result == 'L')
        .toList()
        .reversed
        .take(5)
        .toList()
        .reversed
        .toList();
  }

  _SelectionIntent _threeWayIntentForSide(_TeamSide side) {
    return switch (side) {
      _TeamSide.home => _SelectionIntent.home,
      _TeamSide.away => _SelectionIntent.away,
      _TeamSide.draw => _SelectionIntent.draw,
    };
  }

  _Edge? _standingEdgeFor(MatchBoardItem match, _TeamSide side) {
    final home = match.analysis.homeStanding;
    final away = match.analysis.awayStanding;
    if (home == null || away == null) {
      return null;
    }

    final homeRank = home.rank;
    final awayRank = away.rank;
    final homePoints = home.points;
    final awayPoints = away.points;
    if (homeRank == null || awayRank == null) {
      return null;
    }

    final sideIsBetterRanked = switch (side) {
      _TeamSide.home => homeRank < awayRank,
      _TeamSide.away => awayRank < homeRank,
      _TeamSide.draw => false,
    };
    if (!sideIsBetterRanked) {
      return null;
    }

    final rankGap = (homeRank - awayRank).abs();
    final pointsGap = homePoints == null || awayPoints == null
        ? 0
        : (homePoints - awayPoints).abs();

    return _Edge(
      isStrong: rankGap >= 5 || pointsGap >= 8,
      evidence: ThesisEvidence(
        label:
            '${match.homeTeam.name} #$homeRank, ${match.awayTeam.name} #$awayRank${homePoints == null || awayPoints == null ? '' : ' · $homePoints pts contre $awayPoints pts'}.',
        tone: ThesisEvidenceTone.positive,
      ),
    );
  }

  _Edge? _formEdgeFor(MatchBoardItem match, _TeamSide side) {
    final homeForm =
        match.analysis.homeStatistics?.form ??
        match.analysis.homeStanding?.form;
    final awayForm =
        match.analysis.awayStatistics?.form ??
        match.analysis.awayStanding?.form;
    if (homeForm == null || awayForm == null) {
      return null;
    }

    final homeScore = _formScore(homeForm);
    final awayScore = _formScore(awayForm);
    final sideIsBetterForm = switch (side) {
      _TeamSide.home => homeScore > awayScore,
      _TeamSide.away => awayScore > homeScore,
      _TeamSide.draw => false,
    };
    if (!sideIsBetterForm) {
      return null;
    }

    final gap = (homeScore - awayScore).abs();
    return _Edge(
      isStrong: gap >= 5,
      evidence: ThesisEvidence(
        label:
            'Forme récente : ${match.homeTeam.name} $homeForm, ${match.awayTeam.name} $awayForm.',
        tone: ThesisEvidenceTone.positive,
      ),
    );
  }

  _Edge? _reliabilityEdgeFor(MatchBoardItem match, _TeamSide side) {
    final home = match.analysis.homeStatistics;
    final away = match.analysis.awayStatistics;
    if (home == null || away == null) {
      return null;
    }

    final homeLossRate = _lossRate(home);
    final awayLossRate = _lossRate(away);
    if (homeLossRate == null || awayLossRate == null) {
      return null;
    }

    final sideIsMoreReliable = switch (side) {
      _TeamSide.home => homeLossRate < awayLossRate,
      _TeamSide.away => awayLossRate < homeLossRate,
      _TeamSide.draw => false,
    };
    if (!sideIsMoreReliable) {
      return null;
    }

    final gap = (homeLossRate - awayLossRate).abs();
    return _Edge(
      isStrong: gap >= 0.18,
      evidence: ThesisEvidence(
        label:
            'Défaites : ${match.homeTeam.name} ${_rateLabel(homeLossRate)}, ${match.awayTeam.name} ${_rateLabel(awayLossRate)}.',
        tone: ThesisEvidenceTone.positive,
      ),
    );
  }

  double? _goalClimate(MatchBoardItem match) {
    final home = match.analysis.homeStatistics;
    final away = match.analysis.awayStatistics;
    if (home == null || away == null) {
      return null;
    }

    final homeFor = home.goalsForAverageTotal;
    final awayFor = away.goalsForAverageTotal;
    final homeAgainst = home.goalsAgainstAverageTotal;
    final awayAgainst = away.goalsAgainstAverageTotal;
    if (homeFor == null ||
        awayFor == null ||
        homeAgainst == null ||
        awayAgainst == null) {
      return null;
    }

    return (homeFor + awayFor + homeAgainst + awayAgainst) / 2;
  }

  List<ThesisEvidence> _goalAverageEvidence(MatchBoardItem match) {
    final home = match.analysis.homeStatistics;
    final away = match.analysis.awayStatistics;
    if (home == null || away == null) {
      return const [];
    }

    final homeFor = home.goalsForAverageTotal;
    final awayFor = away.goalsForAverageTotal;
    final homeAgainst = home.goalsAgainstAverageTotal;
    final awayAgainst = away.goalsAgainstAverageTotal;

    return [
      if (homeFor != null)
        ThesisEvidence(
          label:
              '${match.homeTeam.name} marque ${homeFor.toStringAsFixed(2)} but(s)/match.',
          tone: ThesisEvidenceTone.neutral,
        ),
      if (awayFor != null)
        ThesisEvidence(
          label:
              '${match.awayTeam.name} marque ${awayFor.toStringAsFixed(2)} but(s)/match.',
          tone: ThesisEvidenceTone.neutral,
        ),
      if (homeAgainst != null)
        ThesisEvidence(
          label:
              '${match.homeTeam.name} encaisse ${homeAgainst.toStringAsFixed(2)} but(s)/match.',
          tone: ThesisEvidenceTone.neutral,
        ),
      if (awayAgainst != null)
        ThesisEvidence(
          label:
              '${match.awayTeam.name} encaisse ${awayAgainst.toStringAsFixed(2)} but(s)/match.',
          tone: ThesisEvidenceTone.neutral,
        ),
    ];
  }

  List<CopilotArgument> _argumentsForSide(
    MatchBoardItem match,
    _TeamSide side, {
    required bool includeMarket,
  }) {
    final opponent = _opponentSide(side);
    final arguments = <CopilotArgument>[
      if (includeMarket) ?_marketFavoriteArgument(match, side),
      ?_rankingGapArgument(match, side),
      ?_poorPerformanceArgument(match, opponent),
      ?_fragileDefenseArgument(match, opponent),
      ?_strongAttackArgument(match, side),
      ?_strongRecentFormArgument(match, side),
      ?_weakRecentFormArgument(match, opponent),
      ?_contradictionArgument(match, side),
    ].whereType<CopilotArgument>().toList();

    return _bestArgumentPerFamily(arguments);
  }

  List<CopilotArgument> _rhythmArguments(
    MatchBoardItem match, {
    required bool isOpen,
  }) {
    final climate = _goalClimate(match);
    final arguments = <CopilotArgument>[
      if (climate != null)
        CopilotArgument(
          id: isOpen ? 'open_match_rhythm' : 'closed_match_rhythm',
          type: isOpen
              ? CopilotArgumentType.openMatch
              : CopilotArgumentType.closedMatch,
          family: CopilotArgumentFamily.rhythm,
          severity: isOpen
              ? climate >= 3.2
                    ? CopilotArgumentSeverity.strong
                    : CopilotArgumentSeverity.moderate
              : climate <= 1.75
              ? CopilotArgumentSeverity.strong
              : CopilotArgumentSeverity.moderate,
          subjectName: 'La rencontre',
          parameters: {'climate': climate},
          evidence: _goalAverageEvidence(match),
          evidenceAction: CopilotEvidenceAction.rhythm,
        ),
      ?_fragileDefenseArgument(match, _TeamSide.home),
      ?_fragileDefenseArgument(match, _TeamSide.away),
      ?_strongAttackArgument(match, _TeamSide.home),
      ?_strongAttackArgument(match, _TeamSide.away),
    ].whereType<CopilotArgument>().toList();

    return _bestArgumentPerFamily(arguments);
  }

  List<CopilotArgument> _fallbackArguments(MatchBoardItem match) {
    return _bestArgumentPerFamily(
      [
        ?_rankingGapArgument(match, _TeamSide.home),
        ?_rankingGapArgument(match, _TeamSide.away),
        ?_poorPerformanceArgument(match, _TeamSide.home),
        ?_poorPerformanceArgument(match, _TeamSide.away),
        ?_fragileDefenseArgument(match, _TeamSide.home),
        ?_fragileDefenseArgument(match, _TeamSide.away),
        ?_strongAttackArgument(match, _TeamSide.home),
        ?_strongAttackArgument(match, _TeamSide.away),
        ?_strongRecentFormArgument(match, _TeamSide.home),
        ?_strongRecentFormArgument(match, _TeamSide.away),
        ?_weakRecentFormArgument(match, _TeamSide.home),
        ?_weakRecentFormArgument(match, _TeamSide.away),
      ].whereType<CopilotArgument>().toList(),
    );
  }

  CopilotArgument? _marketFavoriteArgument(
    MatchBoardItem match,
    _TeamSide side,
  ) {
    final favorite = _marketFavorite(match);
    if (favorite == null || favorite.side != side) {
      return null;
    }

    return CopilotArgument(
      id: 'market_favorite_${side.name}',
      type: CopilotArgumentType.marketFavorite,
      family: CopilotArgumentFamily.market,
      severity: favorite.selection.odds <= 1.70
          ? CopilotArgumentSeverity.strong
          : CopilotArgumentSeverity.moderate,
      subjectName: _teamNameForSide(match, side),
      parameters: {'odds': favorite.selection.odds},
      evidence: [
        ThesisEvidence(
          label:
              '${_teamNameForSide(match, side)} est le prix le plus bas du 1N2 à ${favorite.selection.odds.toStringAsFixed(2)}.',
          tone: ThesisEvidenceTone.neutral,
        ),
      ],
      evidenceAction: CopilotEvidenceAction.market,
    );
  }

  CopilotArgument? _rankingGapArgument(MatchBoardItem match, _TeamSide side) {
    final home = match.analysis.homeStanding;
    final away = match.analysis.awayStanding;
    final target = _standingForSide(match, side);
    final opponent = _standingForSide(match, _opponentSide(side));
    if (home == null ||
        away == null ||
        target?.rank == null ||
        opponent?.rank == null) {
      return null;
    }

    if (target!.rank! >= opponent!.rank!) {
      return null;
    }

    final rankGap = (target.rank! - opponent.rank!).abs();
    final pointsGap = target.points == null || opponent.points == null
        ? 0
        : (target.points! - opponent.points!).abs();
    if (rankGap < 4 && pointsGap < 7) {
      return null;
    }

    return CopilotArgument(
      id: 'ranking_gap_${side.name}',
      type: CopilotArgumentType.rankingGap,
      family: CopilotArgumentFamily.hierarchy,
      severity: rankGap >= 6 || pointsGap >= 10
          ? CopilotArgumentSeverity.strong
          : CopilotArgumentSeverity.moderate,
      subjectName: _teamNameForSide(match, side),
      parameters: {
        'rankGap': rankGap,
        'pointsGap': pointsGap,
        if (target.played != null) 'played': target.played!,
      },
      evidence: [
        ThesisEvidence(
          label:
              '${_teamNameForSide(match, side)} est #${target.rank}, ${_teamNameForSide(match, _opponentSide(side))} #${opponent.rank}.',
          tone: ThesisEvidenceTone.positive,
        ),
        if (target.points != null && opponent.points != null)
          ThesisEvidence(
            label:
                '${target.points} points contre ${opponent.points}, soit $pointsGap point(s) d’écart.',
            tone: ThesisEvidenceTone.positive,
          ),
      ],
      evidenceAction: CopilotEvidenceAction.standings,
    );
  }

  CopilotArgument? _poorPerformanceArgument(
    MatchBoardItem match,
    _TeamSide side,
  ) {
    final standing = _standingForSide(match, side);
    final statistics = _statisticsForSide(match, side);
    final played = statistics?.playedTotal ?? standing?.played;
    final wins = statistics?.winsTotal ?? standing?.wins;
    final losses = statistics?.lossesTotal ?? standing?.losses;
    final points = standing?.points;
    if (played == null || played < 6 || wins == null) {
      return null;
    }

    final winRate = wins / played;
    final lossRate = losses == null || played <= 0 ? 0.0 : losses / played;
    if (winRate > 0.28 && lossRate < 0.50) {
      return null;
    }

    final parameters = <String, Object>{'wins': wins, 'played': played};
    if (points != null) {
      parameters['points'] = points;
    }

    return CopilotArgument(
      id: 'poor_performance_${side.name}',
      type: CopilotArgumentType.poorOverallPerformance,
      family: CopilotArgumentFamily.performance,
      severity: winRate <= 0.18 || lossRate >= 0.62
          ? CopilotArgumentSeverity.strong
          : CopilotArgumentSeverity.moderate,
      subjectName: _teamNameForSide(match, side),
      parameters: parameters,
      evidence: [
        ThesisEvidence(
          label:
              '${_teamNameForSide(match, side)} compte $wins victoire(s) en $played rencontre(s).',
          tone: ThesisEvidenceTone.negative,
        ),
        if (points != null)
          ThesisEvidence(
            label: '$points points obtenus depuis le début de la compétition.',
            tone: ThesisEvidenceTone.negative,
          ),
      ],
      evidenceAction: CopilotEvidenceAction.results,
    );
  }

  CopilotArgument? _fragileDefenseArgument(
    MatchBoardItem match,
    _TeamSide side,
  ) {
    final statistics = _statisticsForSide(match, side);
    final standing = _standingForSide(match, side);
    final concededAverage = statistics?.goalsAgainstAverageTotal;
    final played = statistics?.playedTotal ?? standing?.played;
    final conceded = statistics?.goalsAgainstTotal ?? standing?.goalsAgainst;
    if (concededAverage == null || concededAverage < 1.55) {
      return null;
    }

    final parameters = <String, Object>{'concededAverage': concededAverage};
    if (conceded != null) {
      parameters['conceded'] = conceded;
    }
    if (played != null) {
      parameters['played'] = played;
    }

    return CopilotArgument(
      id: 'fragile_defense_${side.name}',
      type: CopilotArgumentType.fragileDefense,
      family: CopilotArgumentFamily.defense,
      severity: concededAverage >= 2.0
          ? CopilotArgumentSeverity.strong
          : CopilotArgumentSeverity.moderate,
      subjectName: _teamNameForSide(match, side),
      parameters: parameters,
      evidence: [
        ThesisEvidence(
          label:
              '${_teamNameForSide(match, side)} encaisse ${concededAverage.toStringAsFixed(2)} but(s) par rencontre.',
          tone: ThesisEvidenceTone.negative,
        ),
        if (conceded != null && played != null)
          ThesisEvidence(
            label: '$conceded but(s) encaissé(s) en $played match(s).',
            tone: ThesisEvidenceTone.negative,
          ),
      ],
      evidenceAction: CopilotEvidenceAction.defensiveStats,
    );
  }

  CopilotArgument? _strongAttackArgument(MatchBoardItem match, _TeamSide side) {
    final statistics = _statisticsForSide(match, side);
    final standing = _standingForSide(match, side);
    final scoredAverage = statistics?.goalsForAverageTotal;
    final played = statistics?.playedTotal ?? standing?.played;
    final scored = statistics?.goalsForTotal ?? standing?.goalsFor;
    if (scoredAverage == null || scoredAverage < 1.65) {
      return null;
    }

    final parameters = <String, Object>{'scoredAverage': scoredAverage};
    if (scored != null) {
      parameters['scored'] = scored;
    }
    if (played != null) {
      parameters['played'] = played;
    }

    return CopilotArgument(
      id: 'strong_attack_${side.name}',
      type: CopilotArgumentType.strongAttack,
      family: CopilotArgumentFamily.attack,
      severity: scoredAverage >= 2.0
          ? CopilotArgumentSeverity.strong
          : CopilotArgumentSeverity.moderate,
      subjectName: _teamNameForSide(match, side),
      parameters: parameters,
      evidence: [
        ThesisEvidence(
          label:
              '${_teamNameForSide(match, side)} marque ${scoredAverage.toStringAsFixed(2)} but(s) par rencontre.',
          tone: ThesisEvidenceTone.positive,
        ),
        if (scored != null && played != null)
          ThesisEvidence(
            label: '$scored but(s) marqué(s) en $played match(s).',
            tone: ThesisEvidenceTone.positive,
          ),
      ],
      evidenceAction: CopilotEvidenceAction.offensiveStats,
    );
  }

  CopilotArgument? _strongRecentFormArgument(
    MatchBoardItem match,
    _TeamSide side,
  ) {
    final form = _formForSide(match, side);
    if (form == null) {
      return null;
    }

    final lastFive = _recentResults(form);
    if (lastFive.length < 5) {
      return null;
    }

    final wins = lastFive.where((result) => result == 'W').length;
    if (wins < 3) {
      return null;
    }

    return CopilotArgument(
      id: 'strong_form_${side.name}',
      type: CopilotArgumentType.strongRecentForm,
      family: CopilotArgumentFamily.form,
      severity: wins >= 4
          ? CopilotArgumentSeverity.strong
          : CopilotArgumentSeverity.moderate,
      subjectName: _teamNameForSide(match, side),
      parameters: {'wins': wins, 'played': lastFive.length},
      evidence: [
        ThesisEvidence(
          label:
              '${_teamNameForSide(match, side)} reste sur $wins victoire(s) lors de ses ${lastFive.length} derniers matchs.',
          tone: ThesisEvidenceTone.positive,
        ),
      ],
      evidenceAction: CopilotEvidenceAction.form,
    );
  }

  CopilotArgument? _weakRecentFormArgument(
    MatchBoardItem match,
    _TeamSide side,
  ) {
    final form = _formForSide(match, side);
    if (form == null) {
      return null;
    }

    final lastFive = _recentResults(form);
    if (lastFive.length < 5) {
      return null;
    }

    final losses = lastFive.where((result) => result == 'L').length;
    if (losses < 3) {
      return null;
    }

    return CopilotArgument(
      id: 'weak_form_${side.name}',
      type: CopilotArgumentType.weakRecentForm,
      family: CopilotArgumentFamily.form,
      severity: losses >= 4
          ? CopilotArgumentSeverity.strong
          : CopilotArgumentSeverity.moderate,
      subjectName: _teamNameForSide(match, side),
      parameters: {'losses': losses, 'played': lastFive.length},
      evidence: [
        ThesisEvidence(
          label:
              '${_teamNameForSide(match, side)} a perdu $losses de ses ${lastFive.length} derniers matchs.',
          tone: ThesisEvidenceTone.negative,
        ),
      ],
      evidenceAction: CopilotEvidenceAction.form,
    );
  }

  CopilotArgument? _contradictionArgument(
    MatchBoardItem match,
    _TeamSide side,
  ) {
    final opponent = _opponentSide(side);
    final opponentForm = _strongRecentFormArgument(match, opponent);
    if (opponentForm == null) {
      return null;
    }

    return CopilotArgument(
      id: 'contradiction_opponent_form_${opponent.name}',
      type: CopilotArgumentType.contradiction,
      family: CopilotArgumentFamily.contradiction,
      severity: CopilotArgumentSeverity.moderate,
      subjectName: _teamNameForSide(match, opponent),
      parameters: opponentForm.parameters,
      evidence: opponentForm.evidence,
      evidenceAction: CopilotEvidenceAction.form,
    );
  }

  List<CopilotArgument> _bestArgumentPerFamily(
    List<CopilotArgument> arguments,
  ) {
    final selected = <CopilotArgumentFamily, CopilotArgument>{};
    for (final argument in arguments) {
      final existing = selected[argument.family];
      if (existing == null ||
          _argumentScore(argument) > _argumentScore(existing)) {
        selected[argument.family] = argument;
      }
    }

    final values = selected.values.toList()
      ..sort((a, b) {
        final scoreComparison = _argumentScore(b).compareTo(_argumentScore(a));
        if (scoreComparison != 0) {
          return scoreComparison;
        }

        return _familyPriority(a.family).compareTo(_familyPriority(b.family));
      });

    return values.take(4).toList();
  }

  int _argumentScore(CopilotArgument argument) {
    return (argument.severity == CopilotArgumentSeverity.strong ? 100 : 60) -
        _familyPriority(argument.family);
  }

  int _familyPriority(CopilotArgumentFamily family) {
    return switch (family) {
      CopilotArgumentFamily.hierarchy => 0,
      CopilotArgumentFamily.performance => 1,
      CopilotArgumentFamily.defense => 2,
      CopilotArgumentFamily.attack => 3,
      CopilotArgumentFamily.form => 4,
      CopilotArgumentFamily.rhythm => 5,
      CopilotArgumentFamily.market => 6,
      CopilotArgumentFamily.contradiction => 7,
    };
  }

  List<String> _profileReasons(
    CompiledDecisionProfile profile,
    List<String> ids,
  ) {
    final reasons = <String>[];
    for (final id in ids) {
      if (profile.isMatchTypeEnabled(id)) {
        reasons.add('Lien profil : $id est priorisé dans votre profil.');
      }
    }

    return reasons;
  }

  int _signalLimit(CompiledDecisionProfile profile) {
    return 4;
  }
}

class _MarketFit {
  const _MarketFit({required this.market, required this.selection});

  final MatchMarket market;
  final MarketOdds selection;
}

class _ThesisCandidate {
  const _ThesisCandidate({
    required this.id,
    required this.title,
    required this.summary,
    required this.baseConfidence,
    required this.supportingEvidence,
    required this.limits,
    required this.profileReasons,
    required this.arguments,
    required this.marketIntents,
  });

  final String id;
  final String title;
  final String summary;
  final int baseConfidence;
  final List<ThesisEvidence> supportingEvidence;
  final List<ThesisEvidence> limits;
  final List<String> profileReasons;
  final List<CopilotArgument> arguments;
  final List<_MarketIntent> marketIntents;
}

class _MarketIntent {
  const _MarketIntent({
    required this.marketId,
    required this.selection,
    this.line,
    this.maxOdds,
  });

  final String marketId;
  final _SelectionIntent selection;
  final String? line;
  final double? maxOdds;
}

class _MarketSide {
  const _MarketSide({required this.side, required this.selection});

  final _TeamSide side;
  final MarketOdds selection;
}

class _Edge {
  const _Edge({required this.isStrong, required this.evidence});

  final bool isStrong;
  final ThesisEvidence evidence;
}

enum _TeamSide { home, draw, away }

enum _SelectionIntent {
  home,
  draw,
  away,
  homeOrDraw,
  homeOrAway,
  drawOrAway,
  over,
  under,
}
