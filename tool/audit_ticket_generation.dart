import 'dart:convert';
import 'dart:io';

import 'package:copilot/features/matches/data/match_feed_repository.dart';
import 'package:copilot/features/matches/domain/match_board_item.dart';
import 'package:copilot/features/onboarding/domain/decision_profile.dart';
import 'package:copilot/features/onboarding/domain/decision_profile_catalogs.dart';
import 'package:copilot/features/onboarding/domain/onboarding_answer.dart';
import 'package:copilot/features/onboarding/domain/profile_compiler.dart';
import 'package:copilot/features/tickets/domain/generated_ticket_pick.dart';
import 'package:copilot/features/tickets/domain/ticket_generator.dart';
import 'package:copilot/features/tickets/domain/ticket_strategy.dart';

Future<void> main(List<String> args) async {
  final snapshotPath = args.isEmpty
      ? 'assets/snapshots/focused_match_feed_latest.json'
      : args.first;
  final snapshot = jsonDecode(await File(snapshotPath).readAsString()) as Map;
  final repository = MatchFeedRepositoryFactory().create(
    MatchDataSourceMode.snapshot,
    snapshot: Map<String, Object?>.from(snapshot),
  );

  final profile = _allEnabledProfile();
  final compiledProfile = const ProfileCompiler().compile(profile);
  final opportunities = repository.opportunitiesFor(profile);
  final strategy = _auditedStrategy();
  final result = const TicketGenerator().generate(
    opportunities: opportunities,
    strategies: [strategy],
    profile: compiledProfile,
    generatedAt: DateTime.utc(2026, 8, 9, 12),
  );

  stdout.writeln('Snapshot: $snapshotPath');
  stdout.writeln('Opportunities: ${opportunities.length}');
  stdout.writeln('Status: ${result.status.name}');
  for (final strategyResult in result.strategies) {
    stdout.writeln(
      'Strategy: ${strategyResult.strategy.name} '
      'status=${strategyResult.status.name} '
      'compatible=${strategyResult.compatiblePickCount} '
      'tickets=${strategyResult.tickets.length}',
    );
  }

  final allPicks = [
    for (final opportunity in opportunities)
      ?GeneratedTicketPick.fromOpportunity(opportunity),
  ];
  final groupedAll = <String, List<GeneratedTicketPick>>{};
  for (final pick in allPicks) {
    groupedAll.putIfAbsent(_dayKey(pick.kickoff), () => []).add(pick);
  }

  for (final entry
      in groupedAll.entries.toList()..sort((a, b) => a.key.compareTo(b.key))) {
    final dayAllPicks = entry.value..sort((a, b) => a.odds.compareTo(b.odds));
    final dayPicks = [
      for (final pick in dayAllPicks)
        if (strategy.acceptsIndividualOdds(pick.odds)) pick,
    ];
    stdout.writeln(
      '\n${entry.key}: ${dayPicks.length}/${dayAllPicks.length} '
      'compatible pick(s)',
    );
    for (final pick in dayAllPicks) {
      final marker = strategy.acceptsIndividualOdds(pick.odds) ? 'OK' : '--';
      stdout.writeln(
        '  $marker ${pick.odds.toStringAsFixed(2)}  '
        '${pick.homeTeam} - ${pick.awayTeam}  '
        '${pick.marketLabel}: ${pick.selectionLabel}',
      );
    }
    final validPairs = _validCombos(dayPicks, min: 2, max: 3);
    stdout.writeln('  Valid combos 2.80-3.10: ${validPairs.length}');
    for (final combo in validPairs.take(10)) {
      stdout.writeln(
        '    ${combo.total.toStringAsFixed(2)}  '
        '${combo.picks.map((pick) => pick.odds.toStringAsFixed(2)).join(' x ')}',
      );
    }
  }
}

DecisionProfile _allEnabledProfile() {
  return DecisionProfile(
    onboardingVersion: 'audit',
    answers: [
      OnboardingAnswer(
        questionId: 'competitions',
        orderedOptionIds: [
          for (final competition in CompetitionCatalog.values) competition.id,
        ],
      ),
      OnboardingAnswer(
        questionId: 'markets',
        orderedOptionIds: [
          for (final market in MarketCatalog.values)
            market.sourceOptionIds.first,
        ],
      ),
      OnboardingAnswer(
        questionId: 'opportunity_profiles',
        orderedOptionIds: [
          for (final profile in OpportunityProfileCatalog.values) profile.id,
        ],
      ),
    ],
  );
}

TicketStrategy _auditedStrategy() {
  return TicketStrategy(
    schemaVersion: TicketStrategy.currentSchemaVersion,
    id: 'audit-normal-2-3',
    userId: 'audit',
    name: 'Audit normal 2-3',
    isActive: true,
    pickTypes: const [PickType.normal],
    minimumIndividualOdds: 1.50,
    maximumIndividualOdds: 2.19,
    minimumSelections: 2,
    maximumSelections: 3,
    minimumTotalOdds: 2.80,
    maximumTotalOdds: 3.10,
    priority: 1,
    createdAt: DateTime.utc(2026, 8, 9, 12),
    updatedAt: DateTime.utc(2026, 8, 9, 12),
  );
}

List<_Combo> _validCombos(
  List<GeneratedTicketPick> picks, {
  required int min,
  required int max,
}) {
  final results = <_Combo>[];

  void walk(int start, List<GeneratedTicketPick> selected) {
    if (selected.length >= min) {
      final combo = _Combo(selected);
      if (combo.total >= 2.80 && combo.total <= 3.10) {
        results.add(combo);
      }
    }
    if (selected.length >= max) {
      return;
    }
    for (var index = start; index < picks.length; index++) {
      walk(index + 1, [...selected, picks[index]]);
    }
  }

  walk(0, const []);
  return results..sort((a, b) => a.total.compareTo(b.total));
}

String _dayKey(DateTime? kickoff) {
  final local = kickoff?.toLocal();
  if (local == null) {
    return 'unknown';
  }
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}

class _Combo {
  _Combo(this.picks)
    : total =
          ((picks.fold<double>(1, (total, pick) => total * pick.odds) * 100)
              .round() /
          100);

  final List<GeneratedTicketPick> picks;
  final double total;
}
