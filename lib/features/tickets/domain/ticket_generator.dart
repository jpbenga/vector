import '../../onboarding/domain/compiled_decision_profile.dart';
import '../../matches/domain/market_assessment.dart';
import '../../matches/domain/match_board_item.dart';
import 'generated_ticket.dart';
import 'generated_ticket_pick.dart';
import 'ticket_generation_result.dart';
import 'ticket_strategy.dart';

class TicketGenerator {
  const TicketGenerator({
    this.maxVariantsPerStrategy = 3,
    this.maxCandidatesPerStrategy = 18,
    this.maxCombinationsEvaluatedPerStrategy = 600,
  });

  final int maxVariantsPerStrategy;
  final int maxCandidatesPerStrategy;
  final int maxCombinationsEvaluatedPerStrategy;

  TicketGenerationResult generate({
    required List<MatchBoardItem> matches,
    required List<TicketStrategy> strategies,
    required CompiledDecisionProfile profile,
    DateTime? targetDate,
    DateTime? generatedAt,
  }) {
    if (!profile.isCompleted) {
      return const TicketGenerationResult(
        status: TicketGenerationStatus.profileIncomplete,
        strategies: [],
      );
    }

    final activeStrategies =
        strategies.where((strategy) => strategy.isActive).toList()
          ..sort((a, b) {
            final priorityComparison = a.priority.compareTo(b.priority);
            if (priorityComparison != 0) {
              return priorityComparison;
            }

            return a.id.compareTo(b.id);
          });

    if (activeStrategies.isEmpty) {
      return const TicketGenerationResult(
        status: TicketGenerationStatus.noActiveStrategy,
        strategies: [],
      );
    }

    final usablePicks = _usablePicksFromCandidates(
      matches,
      profile: profile,
      targetDate: targetDate,
    );
    final timestamp = generatedAt ?? DateTime.now().toUtc();
    final strategyResults = [
      for (final strategy in activeStrategies)
        _generateForStrategy(strategy, usablePicks, timestamp),
    ];

    return TicketGenerationResult(
      status: _overallStatus(strategyResults),
      strategies: strategyResults,
    );
  }

  StrategyTicketGenerationResult _generateForStrategy(
    TicketStrategy strategy,
    List<GeneratedTicketPick> usablePicks,
    DateTime generatedAt,
  ) {
    if (!_isStrategyValid(strategy)) {
      return StrategyTicketGenerationResult(
        strategy: strategy,
        status: TicketGenerationStatus.invalidStrategyConfiguration,
        compatiblePickCount: 0,
        tickets: const [],
      );
    }

    final compatiblePicks =
        usablePicks
            .where(
              (pick) =>
                  strategy.allowsPickType(pick.pickType) &&
                  strategy.acceptsIndividualOdds(pick.odds),
            )
            .toList()
          ..sort(_comparePicks);

    if (compatiblePicks.isEmpty) {
      return StrategyTicketGenerationResult(
        strategy: strategy,
        status: TicketGenerationStatus.noUsableOpportunity,
        compatiblePickCount: 0,
        tickets: const [],
      );
    }

    if (compatiblePicks.length < strategy.minimumSelections) {
      return StrategyTicketGenerationResult(
        strategy: strategy,
        status: TicketGenerationStatus.notEnoughCompatiblePicks,
        compatiblePickCount: compatiblePicks.length,
        tickets: const [],
      );
    }

    final combinations = <_TicketCombination>[];
    var dayGroupsWithEnoughPicks = 0;
    for (final dayPicks in _groupPicksByTicketDay(compatiblePicks).values) {
      final limitedDayPicks = dayPicks.take(maxCandidatesPerStrategy).toList();
      if (limitedDayPicks.length < strategy.minimumSelections) {
        continue;
      }

      dayGroupsWithEnoughPicks += 1;
      combinations.addAll(_validCombinations(strategy, limitedDayPicks));
    }

    if (dayGroupsWithEnoughPicks == 0) {
      return StrategyTicketGenerationResult(
        strategy: strategy,
        status: TicketGenerationStatus.notEnoughCompatiblePicks,
        compatiblePickCount: compatiblePicks.length,
        tickets: const [],
      );
    }

    if (combinations.isEmpty) {
      return StrategyTicketGenerationResult(
        strategy: strategy,
        status: TicketGenerationStatus.noCombinationWithinTotalOdds,
        compatiblePickCount: compatiblePicks.length,
        tickets: const [],
      );
    }

    combinations.sort((a, b) => _compareCombinations(a, b, strategy: strategy));

    final selected = <_TicketCombination>[];
    for (final combination in combinations) {
      if (selected.length >= maxVariantsPerStrategy) {
        break;
      }

      if (selected.any((existing) => existing.sameMatchIdsAs(combination))) {
        continue;
      }

      selected.add(combination);
    }

    return StrategyTicketGenerationResult(
      strategy: strategy,
      status: TicketGenerationStatus.generated,
      compatiblePickCount: compatiblePicks.length,
      tickets: [
        for (final entry in selected.indexed)
          GeneratedTicket(
            id: '${strategy.id}-variant-${entry.$1 + 1}',
            strategyId: strategy.id,
            strategyName: strategy.name,
            picks: entry.$2.picks,
            totalOdds: entry.$2.totalOdds,
            selectionCount: entry.$2.picks.length,
            generatedAt: generatedAt,
            variantIndex: entry.$1 + 1,
            constraintValidation: _validateTicket(strategy, entry.$2.picks),
          ),
      ],
    );
  }

  Map<String?, List<GeneratedTicketPick>> _groupPicksByTicketDay(
    List<GeneratedTicketPick> picks,
  ) {
    final groups = <String?, List<GeneratedTicketPick>>{};
    for (final pick in picks) {
      groups.putIfAbsent(_dayKey(pick.kickoff), () => []).add(pick);
    }
    return groups;
  }

  TicketConstraintValidation _validateTicket(
    TicketStrategy strategy,
    List<GeneratedTicketPick> picks,
  ) {
    final satisfied = <String>[];
    final violations = <ConstraintViolation>[];
    final totalOdds = _totalOdds(picks);

    if (picks.every(
      (pick) =>
          strategy.allowsPickType(pick.pickType) &&
          strategy.acceptsIndividualOdds(pick.odds),
    )) {
      satisfied.add('individual_odds');
    } else {
      violations.add(
        const ConstraintViolation(
          ruleId: 'individual_odds',
          message: 'Une cote individuelle ne respecte pas la stratégie.',
        ),
      );
    }

    if (picks.length >= strategy.minimumSelections &&
        picks.length <= strategy.maximumSelections) {
      satisfied.add('selection_count');
    } else {
      violations.add(
        const ConstraintViolation(
          ruleId: 'selection_count',
          message: 'Le nombre de sélections ne respecte pas la stratégie.',
        ),
      );
    }

    if (strategy.acceptsTotalOdds(totalOdds)) {
      satisfied.add('total_odds');
    } else {
      violations.add(
        const ConstraintViolation(
          ruleId: 'total_odds',
          message: 'La cote totale ne respecte pas la stratégie.',
        ),
      );
    }

    final matchIds = picks.map((pick) => pick.matchId).toSet();
    if (matchIds.length == picks.length) {
      satisfied.add('unique_matches');
    } else {
      violations.add(
        const ConstraintViolation(
          ruleId: 'unique_matches',
          message: 'Un match apparaît plusieurs fois dans le ticket.',
        ),
      );
    }

    if (_hasSingleTicketDay(picks)) {
      satisfied.add('single_ticket_day');
    } else {
      violations.add(
        const ConstraintViolation(
          ruleId: 'single_ticket_day',
          message: 'Toutes les sélections doivent appartenir au même jour.',
        ),
      );
    }

    return TicketConstraintValidation(
      isValid: violations.isEmpty,
      satisfiedRuleIds: List.unmodifiable(satisfied),
      violations: List.unmodifiable(violations),
    );
  }

  List<GeneratedTicketPick> _usablePicksFromCandidates(
    List<MatchBoardItem> matches, {
    required CompiledDecisionProfile profile,
    DateTime? targetDate,
  }) {
    final picksByMatchId = <String, GeneratedTicketPick>{};
    final targetDayKey = targetDate == null ? null : _dayKey(targetDate);
    for (final match in matches) {
      if (targetDayKey != null &&
          _dayKey(match.fixture.kickoff) != targetDayKey) {
        continue;
      }
      final candidate = selectSuggestedBetCandidate(
        match.betCandidates.where(
          (candidate) => profile.enabledMarket(candidate.marketId) != null,
        ),
      );
      if (candidate == null) {
        continue;
      }
      final pick = GeneratedTicketPick.fromBetCandidate(match, candidate);
      if (pick != null) {
        picksByMatchId[pick.matchId] = pick;
      }
    }
    return picksByMatchId.values.toList()..sort(_comparePicks);
  }

  List<_TicketCombination> _validCombinations(
    TicketStrategy strategy,
    List<GeneratedTicketPick> picks,
  ) {
    final results = <_TicketCombination>[];
    var evaluated = 0;
    final maxSelectionCount = strategy.maximumSelections.clamp(0, picks.length);

    void walk(int start, List<GeneratedTicketPick> selected) {
      if (evaluated >= maxCombinationsEvaluatedPerStrategy) {
        return;
      }

      if (selected.length >= strategy.minimumSelections) {
        evaluated += 1;
        final combination = _TicketCombination(selected);
        if (strategy.acceptsTotalOdds(combination.totalOdds)) {
          results.add(combination);
        }
      }

      if (selected.length >= maxSelectionCount) {
        return;
      }

      for (var index = start; index < picks.length; index++) {
        final next = picks[index];
        if (selected.any((pick) => pick.matchId == next.matchId)) {
          continue;
        }
        if (!_canShareTicketDay(selected, next)) {
          continue;
        }

        walk(index + 1, [...selected, next]);
      }
    }

    walk(0, const []);
    return results;
  }

  int _comparePicks(GeneratedTicketPick a, GeneratedTicketPick b) {
    final scoreComparison = b.engineScore.compareTo(a.engineScore);
    if (scoreComparison != 0) {
      return scoreComparison;
    }

    final profileCountComparison = b.opportunityProfileIds.length.compareTo(
      a.opportunityProfileIds.length,
    );
    if (profileCountComparison != 0) {
      return profileCountComparison;
    }

    return a.matchId.compareTo(b.matchId);
  }

  int _compareCombinations(
    _TicketCombination a,
    _TicketCombination b, {
    required TicketStrategy strategy,
  }) {
    final distanceComparison = _totalOddsDistanceCents(
      a,
      strategy,
    ).compareTo(_totalOddsDistanceCents(b, strategy));
    if (distanceComparison != 0) {
      return distanceComparison;
    }

    final scoreComparison = b.score.compareTo(a.score);
    if (scoreComparison != 0) {
      return scoreComparison;
    }

    final profileCountComparison = b.profileCount.compareTo(a.profileCount);
    if (profileCountComparison != 0) {
      return profileCountComparison;
    }

    return a.stableKey.compareTo(b.stableKey);
  }

  int _totalOddsDistanceCents(
    _TicketCombination combination,
    TicketStrategy strategy,
  ) {
    final totalCents = _oddsCents(combination.totalOdds);
    final minCents = _oddsCents(strategy.minimumTotalOdds);
    final max = strategy.maximumTotalOdds;
    if (max == null) {
      return (totalCents - minCents).abs();
    }

    final target = ((minCents + _oddsCents(max)) / 2).round();
    return (totalCents - target).abs();
  }

  bool _isStrategyValid(TicketStrategy strategy) {
    return strategy.hasMathematicallyPossibleTicket;
  }

  TicketGenerationStatus _overallStatus(
    List<StrategyTicketGenerationResult> results,
  ) {
    if (results.any((result) => result.hasTickets)) {
      return TicketGenerationStatus.generated;
    }

    if (results.every(
      (result) =>
          result.status == TicketGenerationStatus.invalidStrategyConfiguration,
    )) {
      return TicketGenerationStatus.invalidStrategyConfiguration;
    }

    if (results.every(
      (result) => result.status == TicketGenerationStatus.noUsableOpportunity,
    )) {
      return TicketGenerationStatus.noUsableOpportunity;
    }

    if (results.every(
      (result) =>
          result.status == TicketGenerationStatus.notEnoughCompatiblePicks,
    )) {
      return TicketGenerationStatus.notEnoughCompatiblePicks;
    }

    return TicketGenerationStatus.noCombinationWithinTotalOdds;
  }
}

class _TicketCombination {
  _TicketCombination(List<GeneratedTicketPick> picks)
    : picks = List.unmodifiable(
        List<GeneratedTicketPick>.of(picks)..sort(_comparePickMatchIds),
      ),
      totalOdds = _totalOdds(picks);

  final List<GeneratedTicketPick> picks;
  final double totalOdds;

  int get score =>
      picks.fold<int>(0, (total, pick) => total + pick.engineScore);

  int get profileCount => picks.fold<int>(
    0,
    (total, pick) => total + pick.opportunityProfileIds.length,
  );

  String get stableKey => matchIds.join('|');

  List<String> get matchIds => [for (final pick in picks) pick.matchId];

  bool sameMatchIdsAs(_TicketCombination other) {
    return stableKey == other.stableKey;
  }
}

bool _canShareTicketDay(
  List<GeneratedTicketPick> selected,
  GeneratedTicketPick next,
) {
  final nextDayKey = _dayKey(next.kickoff);
  if (selected.isEmpty) {
    return true;
  }

  return selected.every((pick) => _dayKey(pick.kickoff) == nextDayKey);
}

bool _hasSingleTicketDay(List<GeneratedTicketPick> picks) {
  if (picks.isEmpty) {
    return false;
  }

  final firstDayKey = _dayKey(picks.first.kickoff);
  return picks.every((pick) => _dayKey(pick.kickoff) == firstDayKey);
}

String? _dayKey(DateTime? value) {
  if (value == null) {
    return null;
  }

  final local = value.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}

int _comparePickMatchIds(GeneratedTicketPick a, GeneratedTicketPick b) {
  return a.matchId.compareTo(b.matchId);
}

double _totalOdds(List<GeneratedTicketPick> picks) {
  var numerator = BigInt.one;
  var denominator = BigInt.one;

  for (final pick in picks) {
    numerator *= BigInt.from(_oddsCents(pick.odds));
    denominator *= BigInt.from(100);
  }

  final totalCents = _roundDiv(numerator * BigInt.from(100), denominator);
  return totalCents / 100;
}

int _roundDiv(BigInt numerator, BigInt denominator) {
  final quotient = numerator ~/ denominator;
  final remainder = numerator.remainder(denominator).abs();
  final shouldRoundUp = remainder * BigInt.from(2) >= denominator.abs();
  return (shouldRoundUp ? quotient + BigInt.one : quotient).toInt();
}

int _oddsCents(double odds) => (odds * 100).round();
