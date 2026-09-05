import 'dart:convert';
import 'dart:io';

import 'package:copilot/features/matches/data/match_feed_repository.dart';
import 'package:copilot/features/matches/data/supabase_match_feed_snapshot_repository.dart';
import 'package:copilot/features/matches/domain/match_board_item.dart';
import 'package:copilot/features/matches/domain/opportunity_engine_v2.dart';
import 'package:copilot/features/onboarding/domain/decision_profile.dart';
import 'package:copilot/features/onboarding/domain/decision_profile_catalogs.dart';
import 'package:copilot/features/onboarding/domain/onboarding_answer.dart';
import 'package:copilot/features/onboarding/domain/profile_compiler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const diagnosticEnabled = bool.fromEnvironment(
    'LECTOR_ENABLE_RUNTIME_DIAGNOSTIC',
  );

  test(
    'runtime snapshot diagnostic',
    () {
      const diagnosticPath = String.fromEnvironment(
        'LECTOR_DIAGNOSTIC_SNAPSHOT_PATH',
        defaultValue: '/private/tmp/lector_window_snapshots_0209.json',
      );
      final rows =
          jsonDecode(File(diagnosticPath).readAsStringSync()) as List<Object?>;
      final payload = mergeMatchFeedSnapshotRows(rows);
      expect(payload, isNotNull);

      final repository = SnapshotMatchFeedRepository(snapshot: payload!);
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
      final personalized = repository.personalizedFor(profile);
      final diagnosticDay = const String.fromEnvironment(
        'LECTOR_DIAGNOSTIC_DAY',
        defaultValue: '2026-09-02',
      );
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
      final personalizedForDay = personalized
          .where((match) => onDay(match.fixture.kickoff))
          .toList();
      final producedIds = intelligences
          .expand((item) => item.thesisAssessments)
          .where((assessment) => assessment.isSupported)
          .map((assessment) => assessment.id)
          .toSet();
      final allowedIds = <String>{};
      for (final definition in OpportunityProfileCatalog.values) {
        if (compiled.isOpportunityProfileEnabled(definition.id)) {
          allowedIds.addAll(definition.thesisIds);
        }
      }

      // ignore: avoid_print
      print('matches=${matches.length}');
      // ignore: avoid_print
      print('matches_$diagnosticDay=${matchesForDay.length}');
      // ignore: avoid_print
      print('intelligences=${intelligences.length}');
      // ignore: avoid_print
      print('opportunities=${opportunities.length}');
      // ignore: avoid_print
      print('opportunities_$diagnosticDay=${opportunitiesForDay.length}');
      // ignore: avoid_print
      print('personalized=${personalized.length}');
      // ignore: avoid_print
      print('personalized_$diagnosticDay=${personalizedForDay.length}');
      // ignore: avoid_print
      print(
        'profile_scenarios=${profile.optionIdsFor('opportunity_profiles')}',
      );
      // ignore: avoid_print
      print(
        'compiled_scenarios=${compiled.matchTypes.values.where((item) => item.enabled).map((item) => item.id).toList()}',
      );
      // ignore: avoid_print
      print('allowed_thesis_ids=${allowedIds.toList()..sort()}');
      // ignore: avoid_print
      print('supported_thesis_ids=${producedIds.toList()..sort()}');
      // ignore: avoid_print
      print(
        'intersection=${producedIds.intersection(allowedIds).toList()..sort()}',
      );
      // ignore: avoid_print
      print('matches_by_date=${_matchesByDate(matches)}');
      // ignore: avoid_print
      print(
        'matches_by_league_$diagnosticDay=${_matchesByLeague(matchesForDay)}',
      );
      // ignore: avoid_print
      print(
        'personalized_by_league_$diagnosticDay=${_matchesByLeague(personalizedForDay)}',
      );
      // ignore: avoid_print
      print(
        'personalized_signal_ids=${_signalIds(personalized).toList()..sort()}',
      );
      // ignore: avoid_print
      print('personalized_by_profile=${_personalizedByProfile(repository)}');
      for (final intelligence in intelligences.where(
        (item) => onDay(item.match.fixture.kickoff),
      )) {
        final supported = intelligence.thesisAssessments
            .where((assessment) => assessment.isSupported)
            .map((assessment) => assessment.id)
            .toList();
        // ignore: avoid_print
        print(
          'match=${intelligence.match.homeTeam.name}-${intelligence.match.awayTeam.name} '
          'league=${intelligence.match.competition.id} supported=$supported',
        );
      }
    },
    skip: diagnosticEnabled
        ? false
        : 'Requires a local runtime snapshot. Run with '
              '--dart-define=LECTOR_ENABLE_RUNTIME_DIAGNOSTIC=true.',
  );
}

Map<String, int> _personalizedByProfile(
  SnapshotMatchFeedRepository repository,
) {
  final result = <String, int>{};
  for (final definition in OpportunityProfileCatalog.values) {
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
        OnboardingAnswer(
          questionId: 'opportunity_profiles',
          orderedOptionIds: [definition.id],
        ),
      ],
    );
    result[definition.id] = repository.personalizedFor(profile).length;
  }
  return result;
}

Set<String> _signalIds(List<MatchBoardItem> matches) {
  return {
    for (final match in matches)
      if (match.thesis != null) match.thesis!.id,
    for (final match in matches)
      for (final signal in match.signals) signal.id,
  };
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
