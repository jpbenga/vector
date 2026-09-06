import 'dart:convert';
import 'dart:io';

import 'package:copilot/features/matches/data/match_feed_repository.dart';
import 'package:copilot/features/matches/data/supabase_match_feed_snapshot_repository.dart';
import 'package:copilot/features/matches/domain/match_board_item.dart';
import 'package:copilot/features/matches/domain/opportunity_engine_v2.dart';
import 'package:copilot/features/onboarding/domain/compiled_decision_profile.dart';
import 'package:copilot/features/onboarding/domain/decision_profile.dart';
import 'package:copilot/features/onboarding/domain/decision_profile_catalogs.dart';
import 'package:copilot/features/onboarding/domain/onboarding_answer.dart';
import 'package:copilot/features/onboarding/domain/profile_compiler.dart';
import 'package:copilot/features/tickets/domain/generated_ticket_pick.dart';
import 'package:copilot/features/tickets/domain/ticket_generator.dart';
import 'package:copilot/features/tickets/domain/ticket_strategy.dart';

void main(List<String> args) {
  final path = args.isEmpty
      ? '/private/tmp/lector_window_snapshots_0209.json'
      : args.first;
  final diagnosticDay = args.length < 2
      ? DateTime.now().toLocal().toIso8601String().substring(0, 10)
      : args[1];
  final rows = jsonDecode(File(path).readAsStringSync()) as List<Object?>;
  final payload = mergeMatchFeedSnapshotRows(rows);
  if (payload == null) {
    stderr.writeln('No merged payload.');
    exitCode = 1;
    return;
  }

  final repository = SnapshotMatchFeedRepository(snapshot: payload);
  final profile = DecisionProfile(
    onboardingVersion: 'runtime-diagnostic',
    answers: [
      OnboardingAnswer(
        questionId: 'competitions',
        orderedOptionIds: [
          for (final competition in RuntimeCompetitionCatalog.values)
            competition.id,
        ],
      ),
      const OnboardingAnswer(
        questionId: 'markets',
        orderedOptionIds: [
          'match_result',
          'double_chance',
          'goals_over_under',
          'both_teams_score',
          'team_scores',
        ],
      ),
      const OnboardingAnswer(
        questionId: 'opportunity_profiles',
        orderedOptionIds: [
          'solid_favorite',
          'struggling_team',
          'offensive_match',
          'ranking_gap',
          'credible_outsider',
          'fragile_defense',
          'prolific_attack',
          'positive_series',
          'negative_series',
        ],
      ),
    ],
  );
  final compiled = const ProfileCompiler().compile(profile);
  final engine = const OpportunityEngineV2();
  final matches = repository.allMatches();
  final intelligences = [
    for (final match in matches) engine.buildIntelligence(match),
  ];
  final opportunities = repository.opportunitiesFor(profile);
  final day = DateTime.parse(diagnosticDay);

  bool onDay(DateTime? value) {
    final local = value?.toLocal();
    return local != null &&
        local.year == day.year &&
        local.month == day.month &&
        local.day == day.day;
  }

  final matchesForDay = matches
      .where((match) => onDay(match.fixture.kickoff))
      .toList();
  final opportunitiesForDay = opportunities
      .where((opportunity) => onDay(opportunity.kickoff))
      .toList();
  final personalizedMatches = repository.personalizedFor(profile);
  final generatorResult = const TicketGenerator().generate(
    matches: personalizedMatches,
    strategies: [_diagnosticStrategy()],
    profile: compiled,
    targetDate: day,
    generatedAt: day.toUtc(),
  );
  final generatorCandidates = personalizedMatches
      .where((match) => onDay(match.fixture.kickoff))
      .expand(
        (match) => match.betCandidates.map(
          (candidate) => GeneratedTicketPick.fromBetCandidate(match, candidate),
        ),
      )
      .whereType<GeneratedTicketPick>()
      .length;
  final producedIds = intelligences
      .expand((item) => item.thesisAssessments)
      .where((assessment) => assessment.isSupported)
      .map((assessment) => assessment.id)
      .toSet();
  final allowedIds = _allowedThesisIds(compiled);

  stdout.writeln('matches=${matches.length}');
  stdout.writeln('matches_$diagnosticDay=${matchesForDay.length}');
  stdout.writeln('intelligences=${intelligences.length}');
  stdout.writeln('opportunities=${opportunities.length}');
  stdout.writeln('opportunities_$diagnosticDay=${opportunitiesForDay.length}');
  stdout.writeln('generator.profile_completed=${compiled.isCompleted}');
  stdout.writeln('generator.active_strategies=1');
  stdout.writeln('generator.candidates_$diagnosticDay=$generatorCandidates');
  stdout.writeln('generator.status=${generatorResult.status.name}');
  stdout.writeln('generator.tickets=${generatorResult.tickets.length}');
  for (final result in generatorResult.strategies) {
    stdout.writeln(
      'generator.strategy=${result.strategy.id} status=${result.status.name} '
      'compatible_picks=${result.compatiblePickCount} tickets=${result.tickets.length}',
    );
  }
  stdout.writeln(
    'profile_scenarios=${profile.optionIdsFor('opportunity_profiles')}',
  );
  stdout.writeln(
    'compiled_scenarios=${compiled.matchTypes.values.where((item) => item.enabled).map((item) => item.id).toList()}',
  );
  stdout.writeln('allowed_thesis_ids=${allowedIds.toList()..sort()}');
  stdout.writeln('supported_thesis_ids=${producedIds.toList()..sort()}');
  stdout.writeln(
    'intersection=${producedIds.intersection(allowedIds).toList()..sort()}',
  );
  stdout.writeln('matches_by_date=${_matchesByDate(matches)}');
  stdout.writeln(
    'matches_by_league_$diagnosticDay=${_matchesByLeague(matchesForDay)}',
  );
  for (final intelligence in intelligences.where(
    (item) => onDay(item.match.fixture.kickoff),
  )) {
    final supported = intelligence.thesisAssessments
        .where((assessment) => assessment.isSupported)
        .map((assessment) => assessment.id)
        .toList();
    final eligible = intelligence.thesisAssessments
        .where((assessment) => !assessment.isSupported)
        .map((assessment) => '${assessment.id}:${assessment.status.name}')
        .toList();
    stdout.writeln(
      'match=${intelligence.match.homeTeam.name}-${intelligence.match.awayTeam.name} '
      'league=${intelligence.match.competition.id} supported=$supported other=$eligible',
    );
  }
  for (final opportunity in opportunitiesForDay) {
    final assessment = opportunity.thesisAssessments
        .where((item) => item.id == opportunity.primaryThesis.id)
        .firstOrNull;
    stdout.writeln(
      'evidence_trace match=${opportunity.matchId} thesis=${opportunity.primaryThesis.id} '
      'card_contradictions=${opportunity.contradictionCount} '
      'opportunity_contradictions=${opportunity.contradictoryReadings.length} '
      'assessment_contradictions=${assessment?.contradictions.length ?? 0} '
      'assessment_resistances=${assessment?.resistances.length ?? 0}',
    );
  }
}

TicketStrategy _diagnosticStrategy() {
  final now = DateTime.utc(2026, 1, 1);
  return TicketStrategy(
    schemaVersion: TicketStrategy.currentSchemaVersion,
    id: 'diagnostic',
    userId: 'diagnostic',
    name: 'Diagnostic',
    isActive: true,
    pickTypes: const [PickType.prudent, PickType.normal, PickType.audacious],
    minimumIndividualOdds: 0,
    maximumIndividualOdds: null,
    minimumSelections: 1,
    maximumSelections: 3,
    minimumTotalOdds: 1.20,
    maximumTotalOdds: null,
    priority: 1,
    createdAt: now,
    updatedAt: now,
  );
}

Set<String> _allowedThesisIds(CompiledDecisionProfile compiled) {
  final ids = <String>{};
  for (final definition in OpportunityProfileCatalog.values) {
    if (compiled.isOpportunityProfileEnabled(definition.id)) {
      ids.addAll(definition.thesisIds);
    }
  }
  return ids;
}

Map<String, int> _matchesByDate(List<MatchBoardItem> matches) {
  final result = <String, int>{};
  for (final match in matches) {
    final value = match.fixture.kickoff?.toLocal().toIso8601String().substring(
      0,
      10,
    );
    if (value != null) {
      result[value] = (result[value] ?? 0) + 1;
    }
  }
  return result;
}

Map<String, int> _matchesByLeague(List<MatchBoardItem> matches) {
  final result = <String, int>{};
  for (final match in matches) {
    final key = '${match.competition.id}:${match.competition.name}';
    result[key] = (result[key] ?? 0) + 1;
  }
  return result;
}
