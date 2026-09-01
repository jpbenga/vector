import 'dart:convert';
import 'dart:io';

import 'package:copilot/features/matches/data/match_feed_repository.dart';
import 'package:copilot/features/matches/domain/match_board_item.dart';
import 'package:copilot/features/onboarding/domain/decision_profile.dart';
import 'package:copilot/features/onboarding/domain/decision_profile_catalogs.dart';
import 'package:copilot/features/onboarding/domain/onboarding_answer.dart';
import 'package:copilot/features/opportunities/domain/opportunity.dart';

Future<void> main(List<String> args) async {
  final snapshotPath = args.isEmpty
      ? 'assets/snapshots/focused_match_feed_latest.json'
      : args.first;
  final selectedDay = args.length < 2
      ? DateTime(2026, 8, 30)
      : DateTime.parse(args[1]);
  final snapshot = jsonDecode(await File(snapshotPath).readAsString()) as Map;
  final repository = MatchFeedRepositoryFactory().create(
    MatchDataSourceMode.snapshot,
    snapshot: Map<String, Object?>.from(snapshot),
  );
  final opportunities = repository.opportunitiesFor(_allEnabledProfile());
  final dated = opportunities
      .where((opportunity) => _isOpportunityOnDate(opportunity, selectedDay))
      .toList();
  final ordered = [...dated]..sort(_compareStories);

  stdout.writeln('Snapshot: $snapshotPath');
  stdout.writeln('Selected date: ${_dateKey(selectedDay)}');
  stdout.writeln('Total opportunities: ${opportunities.length}');
  stdout.writeln('Dated opportunities: ${dated.length}');
  stdout.writeln(
    'Available opportunity dates: ${_availableDates(opportunities)}',
  );
  stdout.writeln('');

  for (var index = 0; index < ordered.length; index++) {
    final opportunity = ordered[index];
    final thesis = opportunity.primaryThesis;
    final support = opportunity.supportingReadings;
    final contradictions = opportunity.contradictoryReadings;
    stdout.writeln(
      '#${index + 1} ${opportunity.homeTeam.name} - ${opportunity.awayTeam.name}',
    );
    stdout.writeln(
      '  kickoff=${opportunity.kickoff?.toLocal()} '
      'competition=${opportunity.competition.name}',
    );
    stdout.writeln(
      '  thesis="${thesis.title}" id=${thesis.id} '
      'priority=${_scenarioPriority(thesis.id)} '
      'engineScore=${opportunity.engineScore} '
      'confidence=${thesis.confidence} '
      'storyScore=${_storyScore(opportunity.toMatchBoardItem())}',
    );
    stdout.writeln(
      '  displayedTitle="${_readingTitle(opportunity.toMatchBoardItem())}" '
      'displayedCount="${_convergentReadingCountLabel(_convergentReadingCount(opportunity.toMatchBoardItem()))}"',
    );
    stdout.writeln(
      '  support=${support.length}: '
      '${support.map((reading) => '${reading.id}:${reading.strength.name}').join(', ')}',
    );
    stdout.writeln(
      '  arguments=${thesis.arguments.length}: '
      '${thesis.arguments.map((argument) => argument.id).join(', ')}',
    );
    stdout.writeln(
      '  contradictions=${contradictions.length}: '
      '${contradictions.map((reading) => reading.id).join(', ')}',
    );
    stdout.writeln(
      '  profiles=${opportunity.opportunityProfileIds.join(', ')} '
      'recommendedMarket=${opportunity.recommendedMarket?.market.id ?? '-'}',
    );
    stdout.writeln('');
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

int _compareStories(Opportunity a, Opportunity b) {
  final scoreComparison = _storyScore(
    b.toMatchBoardItem(),
  ).compareTo(_storyScore(a.toMatchBoardItem()));
  if (scoreComparison != 0) {
    return scoreComparison;
  }
  return _compareMatches(a.toMatchBoardItem(), b.toMatchBoardItem());
}

int _storyScore(MatchBoardItem match) {
  final thesis = match.thesis;
  if (thesis == null) {
    return match.signals.length;
  }
  return thesis.confidence + thesis.arguments.length * 12;
}

int _convergentReadingCount(MatchBoardItem match) {
  final thesis = match.thesis;
  if (thesis != null) {
    final supportingArguments = thesis.arguments.where((argument) {
      return argument.family != CopilotArgumentFamily.market &&
          argument.family != CopilotArgumentFamily.contradiction;
    }).length;
    if (supportingArguments > 0) {
      return supportingArguments;
    }
    if (thesis.supportingEvidence.isNotEmpty) {
      return thesis.supportingEvidence.length;
    }
  }
  return match.signals.length;
}

String _convergentReadingCountLabel(int count) {
  if (count <= 0) {
    return 'Lecture détectée';
  }
  return count == 1 ? '1 lecture convergente' : '$count lectures convergentes';
}

String _readingTitle(MatchBoardItem match) {
  final title = match.thesis?.title.trim();
  if (title != null && title.isNotEmpty) {
    return _freeReadingCopy(title);
  }
  final signal = match.signals.isEmpty ? null : match.signals.first.title;
  if (signal != null && signal.trim().isNotEmpty) {
    return _freeReadingCopy(signal);
  }
  return 'Match à suivre';
}

String _freeReadingCopy(String value) {
  return value
      .replaceAll('Marché recommandé', 'Lecture recommandée')
      .replaceAll('marché recommandé', 'lecture recommandée')
      .replaceAll('Cote', 'Signal')
      .replaceAll('cote', 'signal');
}

int _scenarioPriority(String thesisId) {
  return switch (thesisId) {
    'expected_domination' => 90,
    'favorite_with_protection' => 82,
    'convergent_open_match' => 78,
    'convergent_closed_match' => 76,
    'credible_outsider' => 74,
    'team_in_serious_difficulty' => 72,
    'controlled_favorite' => 70,
    'both_sides_can_score' => 68,
    'one_sided_scoring' => 66,
    'team_better_than_results' => 64,
    'team_worse_than_results' => 60,
    'avoid_match' => 10,
    _ => 0,
  };
}

int _compareMatches(MatchBoardItem a, MatchBoardItem b) {
  final aKickoff = a.fixture.kickoff;
  final bKickoff = b.fixture.kickoff;
  if (aKickoff != null && bKickoff != null) {
    final kickoffComparison = aKickoff.compareTo(bKickoff);
    if (kickoffComparison != 0) {
      return kickoffComparison;
    }
  } else if (aKickoff != null) {
    return -1;
  } else if (bKickoff != null) {
    return 1;
  }
  return a.homeTeam.name.compareTo(b.homeTeam.name);
}

bool _isOpportunityOnDate(Opportunity opportunity, DateTime selectedDate) {
  final kickoff = opportunity.kickoff?.toLocal();
  if (kickoff == null) {
    final now = DateTime.now();
    return _isSameDay(selectedDate, DateTime(now.year, now.month, now.day));
  }

  return _isSameDay(kickoff, selectedDate);
}

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String _dateKey(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

String _availableDates(List<Opportunity> opportunities) {
  final dates = <String>{};
  for (final opportunity in opportunities) {
    final kickoff = opportunity.kickoff?.toLocal();
    dates.add(kickoff == null ? 'unknown' : _dateKey(kickoff));
  }
  final ordered = dates.toList()..sort();
  return ordered.join(', ');
}
